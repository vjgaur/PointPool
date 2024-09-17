// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

//import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IChallengeManager.sol";
/**
 * @title PointPool
 * @dev This contract implements a gamified point system for Uniswap V4 liquidity providers and traders.
 * It uses Chainlink price feeds to dynamically allocate points based on the USD value of ETH.
 * The contract also includes a level and badge system to reward user engagement.
 */
contract PointPool is ERC20, BaseHook, AccessControl {
    // Define a role for the ChallengeManager to ensure only it can award points and badges

    bytes32 public constant CHALLENGE_MANAGER_ROLE =
        keccak256("CHALLENGE_MANAGER_ROLE");

    // Use libraries for currency and balance delta operations
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    // Chainlink price feed for ETH/USD conversion
    AggregatorV3Interface public immutable ethUsdPriceFeed;
    // Mappings to track user levels, badges, liquidity provided, and swap volume
    mapping(address => uint256) public userLevels;
    mapping(address => uint256) public userBadges;

    mapping(address => uint256) private liquidityProvided;
    mapping(address => uint256) private swapVolume;

    // Constants for level calculation and maximum level
    uint256 public constant POINTS_PER_LEVEL = 100;
    uint256 public constant MAX_LEVEL = 100;
    IChallengeManager public challengeManager;

    event LevelUp(address indexed user, uint256 newLevel);
    event BadgeEarned(address indexed user, uint256 badgeId);

    /**
     * @dev Constructor to set up the PointPool contract
     * @param _manager The Uniswap V4 pool manager
     * @param _name The name of the ERC20 token
     * @param _symbol The symbol of the ERC20 token
     * @param _ethUsdPriceFeed The address of the Chainlink ETH/USD price feed
     */
    constructor(
        IPoolManager _manager,
        string memory _name,
        string memory _symbol,
        address _ethUsdPriceFeed
    ) BaseHook(_manager) ERC20(_name, _symbol, 18) {
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(CHALLENGE_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Defines the permissions for the Uniswap V4 hook
     * @return Hooks.Permissions The set of permissions for this hook
     */
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: true,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    /**
     * @dev Hook called after a swap operation
     * @param sender The address initiating the swap
     * @param params The swap parameters
     * @param delta The balance change resulting from the swap
     * @return bytes4 The function selector
     * @return int128 Always returns 0 (required by the interface)
     */
    function afterSwap(
        address sender,
        PoolKey calldata,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, int128) {
        if (!params.zeroForOne) return (this.afterSwap.selector, 0);
        uint256 ethAmount;
        if (params.amountSpecified < 0) {
            ethAmount = uint256(-params.amountSpecified);
        } else {
            ethAmount = uint256(abs(delta.amount0()));
        }
        uint256 pointsToAward = calculatePoints(ethAmount);
        addPoints(sender, pointsToAward);
        recordSwap(sender, ethAmount);
        return (this.afterSwap.selector, 0);
    }
    /**
     * @dev Hook called after adding liquidity
     * @param sender The address adding liquidity
     * @param delta The balance change resulting from adding liquidity
     * @return bytes4 The function selector
     */
    function afterAddLiquidity(
        address sender,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) external returns (bytes4) {
        uint256 ethAmount = uint256(abs(delta.amount0()));
        uint256 pointsToAward = calculatePoints(ethAmount);
        addPoints(sender, pointsToAward);
        recordLiquidityProvision(sender, ethAmount);
        return BaseHook.afterAddLiquidity.selector;
    }
    /**
     * @dev Helper function to calculate the absolute value of an int256
     * @param x The input value
     * @return uint256 The absolute value
     */
    function abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }
    /**
     * @dev Fetches the current ETH/USD price from the Chainlink price feed
     * @return uint256 The current ETH/USD price
     */
    function getEthUsdPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH-USD price");
        return uint256(price);
    }

    /**
     * @dev Calculates the number of points to award based on the ETH amount
     * @param ethAmount The amount of ETH
     * @return uint256 The number of points to award
     */
    function calculatePoints(
        uint256 ethAmount
    ) internal view returns (uint256) {
        uint256 ethUsdPrice = getEthUsdPrice();
        // Convert ETH amount to USD value (ETH has 18 decimals, Chainlink price has 8 decimals)
        uint256 usdValue = (ethAmount * ethUsdPrice) / 1e18;
        // Award 1 point per $10 of value
        return usdValue / (10 * 1e8);
    }
    /**
     * @dev Calculates the user's level based on their point total
     * @param points The user's total points
     * @return uint256 The user's level
     */
    function calculateLevel(uint256 points) public pure returns (uint256) {
        return (points / POINTS_PER_LEVEL) + 1;
    }

    /**
     * @dev Awards a badge to a user
     * @param user The address of the user
     * @param badgeId The ID of the badge to award
     */
    function awardBadge(address user, uint256 badgeId) internal {
        if ((userBadges[user] & (1 << badgeId)) == 0) {
            userBadges[user] |= (1 << badgeId);
            emit BadgeEarned(user, badgeId);
        }
    }

    /**
     * @dev Checks if a user has leveled up and awards badges accordingly
     * @param user The address of the user
     */
    function checkLevelUpAndBadges(address user) internal {
        uint256 newLevel = calculateLevel(ERC20(address(this)).balanceOf(user));
        if (newLevel > userLevels[user]) {
            userLevels[user] = newLevel;
            emit LevelUp(user, newLevel);

            // Award badges based on level milestones
            if (newLevel >= 10) awardBadge(user, 0); // Bronze badge
            if (newLevel >= 25) awardBadge(user, 1); // Silver badge
            if (newLevel >= 50) awardBadge(user, 2); // Gold badge
            if (newLevel == MAX_LEVEL) awardBadge(user, 3); // Max level badge
        }
    }
    /**
     * @dev Records the amount of liquidity provided by a user
     * @param user The address of the user
     * @param amount The amount of liquidity provided
     */
    function recordLiquidityProvision(address user, uint256 amount) internal {
        liquidityProvided[user] += amount;
    }

    /**
     * @dev Records the swap volume for a user
     * @param user The address of the user
     * @param amount The amount of the swap
     */
    function recordSwap(address user, uint256 amount) internal {
        swapVolume[user] += amount;
    }

    /**
     * @dev Retrieves the total liquidity provided by a user
     * @param user The address of the user
     * @return uint256 The total liquidity provided
     */
    function getLiquidityProvided(
        address user
    ) external view returns (uint256) {
        return liquidityProvided[user];
    }

    /**
     * @dev Retrieves the total swap volume for a user
     * @param user The address of the user
     * @return uint256 The total swap volume
     */
    function getSwapVolume(address user) external view returns (uint256) {
        return swapVolume[user];
    }
    /**
     * @dev Adds points to a user's balance and checks for level ups
     * @param user The address of the user
     * @param points The number of points to add
     */
    function addPoints(address user, uint256 points) internal {
        _mint(user, points);
        checkLevelUpAndBadges(user);
    }
    /**
     * @dev Sets the ChallengeManager contract address
     * @param _challengeManager The address of the ChallengeManager contract
     */
    function setChallengeManager(
        address _challengeManager
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(CHALLENGE_MANAGER_ROLE, _challengeManager);
        challengeManager = IChallengeManager(_challengeManager);
    }
    /**
     * @dev Awards points and a badge to a user (can only be called by the ChallengeManager)
     * @param user The address of the user
     * @param points The number of points to award
     * @param badgeId The ID of the badge to award
     */
    function awardPointsAndBadge(
        address user,
        uint256 points,
        uint256 badgeId
    ) external onlyRole(CHALLENGE_MANAGER_ROLE) {
        addPoints(user, points);
        awardBadge(user, badgeId);
    }
}
