// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract GuessingGame {
    address[] public playersList;

    mapping(address => bool) public playersMap;
    mapping(address playerId => uint256 questionId) public playerIdToQuestionId;
    mapping(string question => uint256 questionId) public questionToQuestionId;
    mapping(uint256 questionId => mapping(string question => bool answer))
        public questionIdToAnswer;
    // Track whether a player has created a question
    mapping(address => bool) public playerHasCreatedQuestion;
    // Address of contract owner or admin AKA the game host.
    address public admin;
    bool public isSignUpEnabled = true;

    constructor(address _admin) {
        admin = _admin;
    }

    modifier adminOnly() {
        require(
            msg.sender == admin,
            "Only the game host or admin can call this function."
        );
        _;
    }

    modifier playerOnly() {
        require(
            playersMap[msg.sender],
            "You must be a signed up player to call this function."
        );
        _;
    }

    function getPlayersCount() public view returns (uint256) {
        return playersList.length;
    }

    function signUp() public {
        require(isSignUpEnabled, "Sign-up is disabled.");
        if (!playersMap[msg.sender]) {
            playersList.push(msg.sender);
            playersMap[msg.sender] = true;
        }
    }

    function disableSignUp() public adminOnly {
        // Functionality to disable sign-up process
        isSignUpEnabled = false;
    }

    function createAnswerKey(
        string calldata question,
        bool answer
    ) public playerOnly {
        // Functionality to create answers key. Only 1 player can create only 1 question maximum!
        // Check that the same player is not creating more than 1 question.
        require(
            !playerHasCreatedQuestion[msg.sender],
            "You have already created 1 answer key."
        );
        require(
            playersList.length > 0,
            "No players available to assign questionId."
        );
        uint256 questionId;
        bool found = false;

        for (uint256 i = 0; i < playersList.length; i++) {
            if (playersList[i] == msg.sender) {
                questionId = i; // Assign the index as questionId. This only works for 1 player creating only 1 question.
                found = true;
                break;
            }
        }
        require(found, "Player not found in playersList."); // Ensure the player is in the list
        questionToQuestionId[question] = questionId;
        playerIdToQuestionId[msg.sender] = questionId;
        questionIdToAnswer[questionId][question] = answer;
        playerHasCreatedQuestion[msg.sender] = true;
    }

    function hasEachPlayerCreatedAnswersKey()
        public
        view
        adminOnly
        returns (bool)
    {
        // Only the admin can check if all players have created answers key
        // Check if all players have created an answer key
        uint256 playersCount = playersList.length;
        for (uint256 i = 0; i < playersCount; i++) {
            if (!playerHasCreatedQuestion[playersList[i]]) {
                return false; // If any player hasn't created an answer key, return false
            }
        }
        return true; // All players have created an answer key
    }
}
