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
    bool private _locked;
    bool public paused = false;

    address[] public playerAddresses;

    mapping(address => PlayerProfile) public addressToPlayerProfile;
    mapping(uint256 => PlayerProfile) public questionIdToQuestion;

    mapping(uint256 => mapping(uint256 => bool)) public playerIdToQuestionIdToIsAnswered;

    // Track player points
    mapping(address => uint256) public playerIdToPoints;

    // Address of contract owner or admin AKA the game host.
    address public admin;

    // Events
    event PlayerSignedUp(address indexed player, uint256 indexed playerId, string question);
    event AnswerGuessed(address indexed player, uint256 indexed questionId, bool correct);
    event GameEnded(bool signUpDisabled);
    event PrizeDistributed(address indexed winner, uint256 amount);
    event GameReset();
    event EmergencyPause(bool isPaused);

    constructor(address _admin) {
        admin = _admin;
    }

    // Add reentrancy guard modifier
    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
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

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    // Emergency pause function
    function togglePause() public adminOnly {
        paused = !paused;
        emit EmergencyPause(paused);
    }

    // Sign up can include your own answer, question.
    function signUp(string calldata questionString, string memory answer) public payable whenNotPaused {
        require(isSignUpEnabled, "Sign-up is disabled.");

        // Check if player is already signed up using the mapping
        require(addressToPlayerProfile[msg.sender].playerId == 0, "You are already signed up.");

        // Check if player has enough balance to sign up
        require(msg.value >= 0.01 ether, "You must pay at least 0.01 ether to sign up.");

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

        // Emit event for player sign up
        emit PlayerSignedUp(msg.sender, playerId, questionString);
    }

    function disableSignUp() public adminOnly whenNotPaused {
        // Functionality to disable sign-up process
        isSignUpEnabled = false;
        emit GameEnded(true);
    }

    function guessAnswer(uint256 questionId, string calldata guessedAnswer) public payable playerOnly whenNotPaused {
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

        // Answer question
        bytes32 guessedAnswerHash = keccak256(abi.encodePacked(guessedAnswer));
        bool isCorrectAnswer = questionIdToQuestion[questionId].answer == guessedAnswerHash;

        // Mark question as answered by user?
        playerIdToQuestionIdToIsAnswered[addressToPlayerProfile[msg.sender].playerId][questionId] = true;

        // Increment the points.
        if (isCorrectAnswer) {
            addressToPlayerProfile[msg.sender].totalPoints += 1;
        }

        // Emit event for player guessing
        emit AnswerGuessed(msg.sender, questionId, isCorrectAnswer);
    }

    function distributeCash() public nonReentrant adminOnly whenNotPaused {
        require(!isSignUpEnabled, "Game must be ended before distributing prize");
        require(playerAddresses.length > 0, "No players in the game");

        // Find player with highest points
        address winnerAddress = playerAddresses[0];
        uint256 highestPoints = addressToPlayerProfile[winnerAddress].totalPoints;

        for (uint256 i = 1; i < playerAddresses.length; i++) {
            address playerAddress = playerAddresses[i];
            uint256 playerPoints = addressToPlayerProfile[playerAddress].totalPoints;

            if (playerPoints > highestPoints) {
                highestPoints = playerPoints;
                winnerAddress = playerAddress;
            }
        }

        // Get contract balance
        uint256 prizePool = address(this).balance;
        require(prizePool > 0, "No funds to distribute");

        // Apply checks-effects-interactions pattern
        payable(winnerAddress).transfer(prizePool);

        // Emit event for prize distribution
        emit PrizeDistributed(winnerAddress, prizePool);
    }

    function resetGame() public adminOnly whenNotPaused {
        require(!isSignUpEnabled, "Must end game before resetting");

        // Clear player profiles, questions, and points
        for (uint256 i = 0; i < playerAddresses.length; i++) {
            address playerAddress = playerAddresses[i];
            uint256 playerId = addressToPlayerProfile[playerAddress].playerId;

            delete addressToPlayerProfile[playerAddress];

            delete questionIdToQuestion[i + 1];

            delete playerIdToPoints[playerAddress];

            for (uint256 j = 1; j <= playerAddresses.length; j++) {
                delete playerIdToQuestionIdToIsAnswered[playerId][j];
            }
        }

        // Clear all player addresses
        delete playerAddresses;

        // Re-enable signups for new game
        isSignUpEnabled = true;

        // Emit event for game reset
        emit GameReset();
    }
    // Fallback function for receive 
    // Reject direct ETH transfers
    receive() external payable {
        revert("Direct ETH transfers not allowed.");
    }
    
    // Also reject fallback calls with ETH
    fallback() external payable {
        revert("Direct ETH transfers not allowed.");
    }
}
