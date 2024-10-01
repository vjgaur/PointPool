# PointPool: Gamified Liquidity Provision for Uniswap V4

[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.26-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Test-green)](https://book.getfoundry.sh/)

## Overview

This project implements a gamification layer on top of Uniswap V4 for decentralized exchange of fungible assets. It introduces a point system, levels, badges, challenges, and quests to enhance user engagement in liquidity provision and trading activities.

:warning: **Disclaimer**: This implementation is currently in development and is not production-ready. It is intended for educational and demonstration purposes.

## Main Concepts

- **Points**: Earned for providing liquidity and making swaps.
- **Levels**: Users level up as they accumulate points.
- **Badges**: Special achievements unlocked at various milestones.
- **Challenges**: Time-bound tasks that reward users with extra points and badges.
- **Quests**: A series of challenges that offer substantial rewards upon completion.

## Solidity Features and Practices Demonstrated

- Integration with Uniswap V4 hooks.
- Use of OpenZeppelin's AccessControl for role-based permissions.
- Implementation of ERC20 token standard for point representation.
- Interaction with Chainlink price feeds for dynamic point calculation.

## Configuration

### Constants

- `POINTS_PER_LEVEL`: Number of points required to level up.
- `MAX_LEVEL`: The maximum achievable level.

## Extrinsics

<details>
<summary><strong>addLiquidity</strong></summary>

Allows users to add liquidity to a Uniswap V4 pool and earn points.

#### Parameters:

- `sender`: The address adding liquidity.
- `amount0`: The amount of token0 being added.
- `amount1`: The amount of token1 being added.

#### Events:

- `LiquidityAdded(address indexed user, uint256 amount0, uint256 amount1, uint256 pointsEarned)`

#### Errors:

- `InsufficientLiquidity`: When the provided liquidity is too low.

</details>

<details>
<summary><strong>completeChallenge</strong></summary>

Allows users to complete a challenge and earn rewards.

#### Parameters:

- `challengeId`: The ID of the challenge being completed.

#### Events:

- `ChallengeCompleted(address indexed user, uint256 indexed challengeId, uint256 pointsEarned)`

#### Errors:

- `ChallengeNotActive`: When the challenge is not currently active.
- `ChallengeAlreadyCompleted`: When the user has already completed this challenge.

</details>

### Deployment

1. Deploy the PointPool contract:
   ```bash
   forge create src/PointPool.sol:PointPool --constructor-args <UNISWAP_MANAGER> "PointPool" "PP" <ETH_USD_PRICE_FEED>
   ```
   2.Deploy the ChallengeManager contract:

```bash
forge create src/ChallengeManager.sol:ChallengeManager --constructor-args <POINT_POOL_ADDRESS>
```

# Interaction

Add liquidity to earn points:

```bash
cast send <POINT_POOL_ADDRESS> "addLiquidity(uint256,uint256)" 1000000000000000000 1000000000000000000
```

Complete a challenge:

```bash
cast send <CHALLENGE_MANAGER_ADDRESS> "completeChallenge(uint256)" 1
```

Development and Testing
To run the test suite

```bash
forge test
```

To run a specific test:

```bash
forge test --match-test testAddLiquidity
```

Contribution
Contributions to PointPool are welcome. Please ensure that your code adheres to the Solidity style guide and all tests pass before submitting a pull request.
