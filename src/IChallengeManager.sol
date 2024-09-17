// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IChallengeManager {
    function completeChallenge(uint256 challengeId) external;
}
