// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PointPool.sol";
import "./IChallengeManager.sol";
/**
 * @title ChallengeManager
 * @dev This contract manages challenges and quests for the PointPool system.
 * It allows creating, completing, and tracking progress of challenges and quests.
 */
contract ChallengeManager is IChallengeManager {
    PointPool public immutable pointPool;

    /**
     * @dev Enum representing different types of challenges
     */
    enum ChallengeType {
        LiquidityProvision,
        Swapping,
        TimeBased
    }
    /**
     * @dev Struct representing a challenge
     */
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
    /**
     * @dev Struct representing a quest (a collection of challenges)
     */
    struct Quest {
        string name;
        uint256[] challengeIds;
        uint256 rewardPoints;
        uint256 badgeId;
    }

    // Array to store all challenges
    Challenge[] public challenges;
    // Array to store all quests
    Quest[] public quests;
    // Mapping to track completed challenges for each user
    mapping(address => mapping(uint256 => bool)) public completedChallenges;
    // Mapping to track completed quests for each user
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

    /**
     * @dev Constructor to set up the ChallengeManager
     * @param _pointPool Address of the PointPool contract
     */
    constructor(address _pointPool) {
        pointPool = PointPool(_pointPool);
    }
    /**
     * @dev Creates a new challenge
     * @param name Name of the challenge
     * @param description Description of the challenge
     * @param challengeType Type of the challenge (LiquidityProvision, Swapping, or TimeBased)
     * @param requiredAmount Amount required to complete the challenge
     * @param rewardPoints Points awarded for completing the challenge
     * @param badgeId ID of the badge awarded for completing the challenge
     * @param startTime Start time of the challenge
     * @param endTime End time of the challenge
     */
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
    /**
     * @dev Creates a new quest
     * @param name Name of the quest
     * @param challengeIds Array of challenge IDs that make up the quest
     * @param rewardPoints Points awarded for completing the quest
     * @param badgeId ID of the badge awarded for completing the quest
     */
    function createQuest(
        string memory name,
        uint256[] memory challengeIds,
        uint256 rewardPoints,
        uint256 badgeId
    ) external {
        quests.push(Quest(name, challengeIds, rewardPoints, badgeId));
        emit QuestCreated(quests.length - 1, name);
    }
    /**
     * @dev Allows a user to complete a challenge
     * @param challengeId ID of the challenge to complete
     */
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
    /**
     * @dev Allows a user to complete a quest
     * @param questId ID of the quest to complete
     */
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
    /**
     * @dev Returns the total number of challenges
     * @return uint256 The number of challenges
     */
    function getChallengeCount() external view returns (uint256) {
        return challenges.length;
    }
    /**
     * @dev Gets the progress of a user for a specific challenge
     * @param user Address of the user
     * @param challengeId ID of the challenge
     * @return completed Boolean indicating if the challenge is completed
     * @return progress Current progress towards completing the challenge
     */
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
    /**
     * @dev Gets the progress of a user for a specific quest
     * @param user Address of the user
     * @param questId ID of the quest
     * @return completed Boolean indicating if the quest is completed
     * @return challengesCompleted Number of challenges completed in the quest
     */
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
    /**
     * @dev Deactivates a challenge
     * @param challengeId ID of the challenge to deactivate
     */

    function deactivateChallenge(uint256 challengeId) external {
        require(challengeId < challenges.length, "Invalid challenge ID");
        challenges[challengeId].isActive = false;
    }
}
