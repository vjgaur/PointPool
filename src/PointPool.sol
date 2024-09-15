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

/**
 * @title PointPool
 * @dev A contract that implements a point system for Uniswap V4 liquidity providers and traders.
 * It uses Chainlink price feeds to dynamically allocate points based on the USD value of ETH.
 */
contract PointPool is ERC20, BaseHook {
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    AggregatorV3Interface public immutable ethUsdPriceFeed;

    constructor(
        IPoolManager _manager,
        string memory _name,
        string memory _symbol,
        address _ethUsdPriceFeed
    ) BaseHook(_manager) ERC20(_name, _symbol, 18) {
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
    }

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

    mapping(address => uint256) public userPoints;

    function addPoints(address user, uint256 amount) internal {
        userPoints[user] += amount;
        _mint(user, amount);
    }

    function getUserPoints(address user) external view returns (uint256) {
        return userPoints[user];
    }

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
        return (this.afterSwap.selector, 0);
    }
    function afterAddLiquidity(
        address sender,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        uint256 ethAmount = uint256(abs(delta.amount0()));
        uint256 pointsToAward = calculatePoints(ethAmount);
        addPoints(sender, pointsToAward);
        return (this.afterAddLiquidity.selector, delta);
    }

    function abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }
    function getEthUsdPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH-USD price");
        return uint256(price);
    }

    function calculatePoints(
        uint256 ethAmount
    ) internal view returns (uint256) {
        uint256 ethUsdPrice = getEthUsdPrice();
        // Convert ETH amount to USD value (ETH has 18 decimals, Chainlink price has 8 decimals)
        uint256 usdValue = (ethAmount * ethUsdPrice) / 1e18;
        // Award 1 point per $10 of value
        return usdValue / (10 * 1e8);
    }
}
