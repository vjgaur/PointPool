// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import "forge-std/console.sol";
import {PointPool} from "../src/PointPool.sol";

contract MockEthUsdPriceFeed {
    int256 private price;

    constructor(int256 _price) {
        price = _price;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, price, 0, 0, 0);
    }
}

contract PointPoolTest is Test, Deployers {
    using CurrencyLibrary for Currency;

    PointPool pointPool;
    MockERC20 token;
    Currency ethCurrency = Currency.wrap(address(0));
    Currency tokenCurrency;
    MockEthUsdPriceFeed mockPriceFeed;

    function setUp() public {
        deployFreshManagerAndRouters();
        require(address(manager) != address(0), "Manager address is zero");
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency = Currency.wrap(address(token));
        token.mint(address(this), 1000 ether);
        token.mint(address(1), 1000 ether);

        mockPriceFeed = new MockEthUsdPriceFeed(2000 * 1e8); // $2000 per ETH

        console.log("Deploying PointPool with manager:", address(manager));
        console.log("Using mock price feed at:", address(mockPriceFeed));

        uint160 flags = uint160(
            Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        address pointPoolAddress = address(
            uint160(
                uint256(keccak256(abi.encode(keccak256("PointPool"), flags)))
            )
        );

        deployCodeTo(
            "PointPool.sol",
            abi.encode(
                IPoolManager(address(manager)),
                "Points Token",
                "PP",
                address(mockPriceFeed)
            ),
            pointPoolAddress
        );

        pointPool = PointPool(pointPoolAddress);

        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);

        (key, ) = initPool(
            ethCurrency,
            tokenCurrency,
            pointPool,
            3000,
            SQRT_PRICE_1_1,
            ZERO_BYTES
        );
    }

    function testAfterAddLiquidity() public {
        uint256 initialBalance = pointPool.balanceOf(address(this));

        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

        (uint256 amount0Delta, ) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            sqrtPriceAtTickLower,
            sqrtPriceAtTickUpper,
            1 ether
        );

        modifyLiquidityRouter.modifyLiquidity{value: amount0Delta}(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        uint256 finalBalance = pointPool.balanceOf(address(this));
        uint256 expectedPoints = (amount0Delta * 2000) / (10 * 1e18); // 1 point per $10

        assertApproxEqAbs(finalBalance - initialBalance, expectedPoints, 1e15);
    }

    function testAfterSwap() public {
        uint256 initialBalance = pointPool.balanceOf(address(this));

        swapRouter.swap{value: 0.1 ether}(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -0.1 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );

        uint256 finalBalance = pointPool.balanceOf(address(this));
        uint256 expectedPoints = (0.1 ether * 2000) / (10 * 1e18); // 1 point per $10

        assertApproxEqAbs(finalBalance - initialBalance, expectedPoints, 1e15);
    }
}
