// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// This will contain player profile information and question information.
struct PlayerProfile {
    uint256 playerId;
    string question;
    bytes32 answer;
    uint256 totalPoints;
}

contract GuessingGame {
    bool public isSignUpEnabled = true;

    address[] public playerAddresses;

    mapping(address => PlayerProfile) public addressToPlayerProfile;
    mapping(uint256 => PlayerProfile) public questionIdToQuestion;

    mapping(uint256 => mapping(uint256 => bool)) public playerIdToQuestionIdToIsAnswered;

    // Track player points
    mapping(address => uint256) public playerIdToPoints;

    // Address of contract owner or admin AKA the game host.
    address public admin;

    uint256 private MINIMUM_BET = 100 gwei;

    constructor(address _admin) {
        admin = _admin;
    }

    modifier adminOnly() {
        require(msg.sender == admin, "Only the game host or admin can call this function.");
        _;
    }

    modifier playerOnly() {
        require(
            addressToPlayerProfile[msg.sender].playerId != 0, "You must be a signed up player to call this function."
        );
        _;
    }

    // Set and get minimum bet
    function setMinimumBet(uint256 _min) public adminOnly {
        MINIMUM_BET = _min;
    }

    function getMinimumBet() public view returns (uint256) {
        return MINIMUM_BET;
    }

    // Sign up can include your own answer, question.
    function signUp(string calldata questionString, string memory answer) public {
        require(isSignUpEnabled, "Sign-up is disabled.");

        // Check if player is already signed up using the mapping
        require(addressToPlayerProfile[msg.sender].playerId == 0, "You are already signed up.");

        // Create a new player profile
        uint256 playerId = playerAddresses.length + 1;
        PlayerProfile memory newProfile = PlayerProfile({
            playerId: playerId, // Start from 1 so 0 means not registered
            question: questionString,
            answer: keccak256(abi.encodePacked(answer)),
            totalPoints: 0
        });

        // Store the profile
        addressToPlayerProfile[msg.sender] = newProfile;
        questionIdToQuestion[playerId] = newProfile;
        playerAddresses.push(msg.sender);

        // TODO: Emit Event for Player Sign Up
    }

    function disableSignUp() public adminOnly {
        // Functionality to disable sign-up process
        isSignUpEnabled = false;
    }

    function guessAnswer(uint256 questionId, string calldata guessedAnswer) public payable playerOnly {
        // Check for valid question
        require(questionIdToQuestion[questionId].playerId != 0, "Invalid question ID.");

        // Check that player has not already answered this question
        require(
            playerIdToQuestionIdToIsAnswered[addressToPlayerProfile[msg.sender].playerId][questionId] == false,
            "You have already answered this question."
        );

        // Check that msg.sender is not answering his own question
        require(
            questionIdToQuestion[questionId].playerId != addressToPlayerProfile[msg.sender].playerId,
            "You cannot answer your own question."
        );
        require(msg.value >= MINIMUM_BET, "Below Minimum");
        // Answer question
        bytes32 guessedAnswerHash = keccak256(abi.encodePacked(guessedAnswer));
        bool isCorrectAnswer = questionIdToQuestion[questionId].answer == guessedAnswerHash;

        // Mark question as answered by user
        playerIdToQuestionIdToIsAnswered[addressToPlayerProfile[msg.sender].playerId][questionId] = true;

        // If answer is correct, award points
        if (isCorrectAnswer) {
            addressToPlayerProfile[msg.sender].totalPoints++;
        }

        // TODO: Emit Event for Player Guessing
    }

    /// @notice Distributes winnings based on the total points
    function distributeWinnings() public adminOnly {
        for (uint256 i = 0; i < playerAddresses.length; i++) {
            address playerAddress = playerAddresses[i];
            PlayerProfile memory playerProfile = addressToPlayerProfile[playerAddress];
            uint256 amount = playerProfile.totalPoints * MINIMUM_BET;
            payable(playerAddress).transfer(amount);
        }

        // resets everything
        isSignUpEnabled = true;
        for (uint256 i = 0; i < playerAddresses.length; i++) {
            address playerAddress = playerAddresses[i];
            delete addressToPlayerProfile[playerAddress];
            delete questionIdToQuestion[i + 1];
            delete playerIdToPoints[playerAddress];
        }
    }
}
