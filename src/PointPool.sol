// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointPool is ERC20, Ownable, BaseHook {
    constructor(
        IPoolManager _poolManager
    )
        ERC20("PointPool", "PP", 18) // Added decimals parameter
        Ownable(msg.sender) // OpenZeppelin's Ownable doesn't take parameters in the constructor
        BaseHook(_poolManager)
    {
        _transferOwnership(msg.sender); // Set the owner explicitly
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

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4) {
        uint256 pointsToAward = uint256(
            uint128(-delta.amount0()) + uint256(uint128(-delta.amount1()))
        );
        addPoints(sender, pointsToAward);
        return BaseHook.afterAddLiquidity.selector;
    }


}
