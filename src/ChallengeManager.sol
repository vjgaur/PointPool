// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PointPool.sol";
import "./IChallengeManager.sol";

contract ChallengeManager is IChallengeManager {
    PointPool public immutable pointPool;
    enum ChallengeType {
        LiquidityProvision,
        Swapping,
        TimeBased
    }

    struct Challenge {
        string name;
        string description;
        ChallengeType challengeType;
        uint256 requiredAmount;
        uint256 rewardPoints;
        uint256 badgeId;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }

    struct Quest {
        string name;
        uint256[] challengeIds;
        uint256 rewardPoints;
        uint256 badgeId;
    }

    Challenge[] public challenges;
    Quest[] public quests;
    mapping(address => mapping(uint256 => bool)) public completedChallenges;
    mapping(address => mapping(uint256 => bool)) public completedQuests;

    event ChallengeCreated(
        uint256 indexed challengeId,
        string name,
        ChallengeType challengeType,
        uint256 requiredAmount,
        uint256 rewardPoints
    );
    event ChallengeCompleted(
        address indexed user,
        uint256 indexed challengeId,
        uint256 rewardPoints
    );
    event QuestCreated(uint256 indexed questId, string name);
    event QuestCompleted(address indexed user, uint256 indexed questId);

    constructor(address _pointPool) {
        pointPool = PointPool(_pointPool);
    }

    function createChallenge(
        string memory name,
        string memory description,
        ChallengeType challengeType,
        uint256 requiredAmount,
        uint256 rewardPoints,
        uint256 badgeId,
        uint256 startTime,
        uint256 endTime
    ) external {
        challenges.push(
            Challenge(
                name,
                description,
                challengeType,
                requiredAmount,
                rewardPoints,
                badgeId,
                startTime,
                endTime,
                true
            )
        );
        emit ChallengeCreated(
            challenges.length - 1,
            name,
            challengeType,
            requiredAmount,
            rewardPoints
        );
    }

    function createQuest(
        string memory name,
        uint256[] memory challengeIds,
        uint256 rewardPoints,
        uint256 badgeId
    ) external {
        quests.push(Quest(name, challengeIds, rewardPoints, badgeId));
        emit QuestCreated(quests.length - 1, name);
    }

    function completeChallenge(uint256 challengeId) external {
        require(challengeId < challenges.length, "Invalid challenge ID");
        Challenge storage challenge = challenges[challengeId];
        require(challenge.isActive, "Challenge is not active");
        require(
            !completedChallenges[msg.sender][challengeId],
            "Challenge already completed"
        );
        require(
            block.timestamp >= challenge.startTime &&
                block.timestamp <= challenge.endTime,
            "Challenge is not active at this time"
        );

        bool requirementMet = false;
        if (challenge.challengeType == ChallengeType.LiquidityProvision) {
            requirementMet =
                pointPool.getLiquidityProvided(msg.sender) >=
                challenge.requiredAmount;
        } else if (challenge.challengeType == ChallengeType.Swapping) {
            requirementMet =
                pointPool.getSwapVolume(msg.sender) >= challenge.requiredAmount;
        } else if (challenge.challengeType == ChallengeType.TimeBased) {
            requirementMet = true; // Time-based challenges are completed just by calling this function within the time frame
        }

        require(requirementMet, "Challenge requirements not met");

        completedChallenges[msg.sender][challengeId] = true;
        pointPool.awardPointsAndBadge(
            msg.sender,
            challenge.rewardPoints,
            challenge.badgeId
        );

        emit ChallengeCompleted(
            msg.sender,
            challengeId,
            challenge.rewardPoints
        );
    }

    function completeQuest(uint256 questId) external {
        require(questId < quests.length, "Invalid quest ID");
        Quest storage quest = quests[questId];
        require(
            !completedQuests[msg.sender][questId],
            "Quest already completed"
        );

        for (uint i = 0; i < quest.challengeIds.length; i++) {
            require(
                completedChallenges[msg.sender][quest.challengeIds[i]],
                "Not all challenges in the quest are completed"
            );
        }

        completedQuests[msg.sender][questId] = true;
        pointPool.awardPointsAndBadge(
            msg.sender,
            quest.rewardPoints,
            quest.badgeId
        );

        emit QuestCompleted(msg.sender, questId);
    }

    function getChallengeCount() external view returns (uint256) {
        return challenges.length;
    }

    function getChallengeProgress(
        address user,
        uint256 challengeId
    ) external view returns (bool completed, uint256 progress) {
        require(challengeId < challenges.length, "Invalid challenge ID");
        Challenge storage challenge = challenges[challengeId];

        completed = completedChallenges[user][challengeId];
        if (challenge.challengeType == ChallengeType.LiquidityProvision) {
            progress = pointPool.getLiquidityProvided(user);
        } else if (challenge.challengeType == ChallengeType.Swapping) {
            progress = pointPool.getSwapVolume(user);
        } else {
            progress = completed ? challenge.requiredAmount : 0;
        }
    }
    function getQuestProgress(
        address user,
        uint256 questId
    ) external view returns (bool completed, uint256 challengesCompleted) {
        require(questId < quests.length, "Invalid quest ID");
        Quest storage quest = quests[questId];

        completed = completedQuests[user][questId];
        for (uint i = 0; i < quest.challengeIds.length; i++) {
            if (completedChallenges[user][quest.challengeIds[i]]) {
                challengesCompleted++;
            }
        }
    }

    function deactivateChallenge(uint256 challengeId) external {
        require(challengeId < challenges.length, "Invalid challenge ID");
        challenges[challengeId].isActive = false;
    }
}
