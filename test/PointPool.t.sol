// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/PointPool.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";


/**
 * @title MockEthUsdPriceFeed
 * @dev A mock implementation of the Chainlink AggregatorV3Interface for testing purposes
 */
contract MockEthUsdPriceFeed is AggregatorV3Interface {
    int256 private price;

    constructor(int256 _price) {
        price = _price;
    }

    /**
     * @dev Returns the latest round data, including the mocked price
     */
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, price, 0, 0, 0);
    }

    // Implement other required functions with empty bodies
    function decimals() external pure returns (uint8) {
        return 8;
    }
    function description() external pure returns (string memory) {
        return "";
    }
    function version() external pure returns (uint256) {
        return 0;
    }
    function getRoundData(
        uint80
    ) external pure returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 0, 0, 0, 0);
    }

    contract PointPoolTest is Test {}
}
