// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GuessingGame} from "../src/GuessingGame.sol";

contract GuessingGameTest is Test {
    GuessingGame public game;
    address public admin = makeAddr("admin");
    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");
    address public player3 = makeAddr("player3");

    function setUp() public {
        vm.prank(admin);
        game = new GuessingGame(admin);
    }

    // Admin Tests
    function test_AdminIsSetCorrectly() public view {
        assertEq(game.admin(), admin);
    }

    function test_OnlyAdminCanDisableSignUp() public {
        assertTrue(game.isSignUpEnabled());

        // Non-admin cannot disable signup
        vm.prank(player1);
        vm.expectRevert("Only the game host or admin can call this function.");
        game.disableSignUp();

        // Admin can disable signup
        vm.prank(admin);
        game.disableSignUp();
        assertFalse(game.isSignUpEnabled());
    }

    // SignUp Tests
    function test_SuccessfulSignUp() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("What is 2+2?", "4");

        (uint256 playerId, string memory question, bytes32 answer, uint256 points) =
            game.addressToPlayerProfile(player1);

        assertEq(playerId, 1);
        assertEq(question, "What is 2+2?");
        assertEq(points, 0);
        assertTrue(answer != bytes32(0));
        assertEq(game.playerAddresses(0), player1);
    }

    function test_CannotSignUpTwice() public {
        vm.deal(player1, 1 ether);
        vm.startPrank(player1);
        game.signUp{value: 0.01 ether}("Question 1", "Answer 1");

        vm.expectRevert("You are already signed up.");
        game.signUp{value: 0.01 ether}("Question 2", "Answer 2");
        vm.stopPrank();
    }

    function test_CannotSignUpWhenDisabled() public {
        vm.prank(admin);
        game.disableSignUp();

        vm.prank(player1);
        vm.expectRevert("Sign-up is disabled.");
        game.signUp("Question", "Answer");
    }

    // Guessing Tests
    function testFuzz_CorrectGuess(string memory question, string memory answer) public {
        vm.assume(bytes(question).length > 0 && bytes(answer).length > 0);

        // Setup players with funds
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);

        // Player 1 signs up and creates question
        vm.prank(player1);
        game.signUp{value: 0.01 ether}(question, answer);

        // Player 2 signs up
        vm.prank(player2);
        game.signUp{value: 0.01 ether}("Different question", "Different answer");

        // Player 2 correctly guesses Player 1's question
        vm.prank(player2);
        game.guessAnswer(1, answer);

        // Verify points were awarded
        (,,, uint256 points) = game.addressToPlayerProfile(player2);
        assertEq(points, 1);
    }

    function test_IncorrectGuess() public {
        // Setup players with funds
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);

        // Player 1 signs up
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("What is 2+2?", "4");

        // Player 2 signs up
        vm.prank(player2);
        game.signUp{value: 0.01 ether}("Another question", "answer");

        // Player 2 incorrectly guesses Player 1's question
        vm.prank(player2);
        game.guessAnswer(1, "5");

        // Verify no points were awarded
        (,,, uint256 points) = game.addressToPlayerProfile(player2);
        assertEq(points, 0);
    }

    function test_CannotGuessOwnQuestion() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("What is 2+2?", "4");

        vm.prank(player1);
        vm.expectRevert("You cannot answer your own question.");
        game.guessAnswer(1, "4");
    }

    function test_CannotGuessQuestionTwice() public {
        // Setup players with funds
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);

        // Player 1 signs up
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Question 1", "Answer 1");

        // Player 2 signs up
        vm.prank(player2);
        game.signUp{value: 0.01 ether}("Question 2", "Answer 2");

        // Player 2 guesses Player 1's question
        vm.prank(player2);
        game.guessAnswer(1, "Answer 1");

        // Player 2 tries to guess the same question again
        vm.prank(player2);
        vm.expectRevert("You have already answered this question.");
        game.guessAnswer(1, "Answer 1");
    }

    function test_CannotGuessInvalidQuestion() public {
        vm.deal(player1, 1 ether);
        // Player 1 signs up
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Question 1", "Answer 1");

        // Try to guess non-existent question
        vm.prank(player1);
        vm.expectRevert("Invalid question ID.");
        game.guessAnswer(999, "Any answer");
    }

    function test_NonPlayerCannotGuess() public {
        vm.deal(player1, 1 ether);
        // Player 1 signs up
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Question 1", "Answer 1");

        // Non-player tries to guess
        vm.prank(player3);
        vm.expectRevert("You must be a signed up player to call this function.");
        game.guessAnswer(1, "Answer 1");
    }

    function test_MultiplePlayersAndGuesses() public {
        // Setup players with funds
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        vm.deal(player3, 1 ether);

        // Set up three players
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Q1", "A1");

        vm.prank(player2);
        game.signUp{value: 0.01 ether}("Q2", "A2");

        vm.prank(player3);
        game.signUp{value: 0.01 ether}("Q3", "A3");

        // Players guess each other's questions
        vm.prank(player2);
        game.guessAnswer(1, "A1"); // Correct

        vm.prank(player3);
        game.guessAnswer(1, "Wrong"); // Incorrect

        vm.prank(player1);
        game.guessAnswer(2, "A2"); // Correct

        // Check final points
        (,,, uint256 points1) = game.addressToPlayerProfile(player1);
        (,,, uint256 points2) = game.addressToPlayerProfile(player2);
        (,,, uint256 points3) = game.addressToPlayerProfile(player3);

        assertEq(points1, 1);
        assertEq(points2, 1);
        assertEq(points3, 0);
    }

    // Distribution Tests
    function test_DistributeCashToWinner() public {
        // Setup players with funds
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        vm.deal(player3, 1 ether);

        // Players sign up with 0.01 ether each
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Q1", "A1");

        vm.prank(player2);
        game.signUp{value: 0.01 ether}("Q2", "A2");

        vm.prank(player3);
        game.signUp{value: 0.01 ether}("Q3", "A3");

        // Player 2 gets 2 points
        vm.prank(player2);
        game.guessAnswer(1, "A1"); // Correct
        vm.prank(player2);
        game.guessAnswer(3, "A3"); // Correct

        // Player 1 gets 1 point
        vm.prank(player1);
        game.guessAnswer(2, "A2"); // Correct

        // Record initial balances
        uint256 initialWinnerBalance = player2.balance;
        uint256 contractBalance = address(game).balance;

        // End game and distribute
        vm.prank(admin);
        game.disableSignUp();

        vm.prank(admin);
        game.distributeCash();

        // Verify winner received all funds
        assertEq(player2.balance, initialWinnerBalance + contractBalance);
        assertEq(address(game).balance, 0);
    }

    function test_DistributeCashFailsIfGameActive() public {
        vm.prank(admin);
        vm.expectRevert("Game must be ended before distributing prize");
        game.distributeCash();
    }

    function test_DistributeCashFailsWithNoPlayers() public {
        // End game
        vm.prank(admin);
        game.disableSignUp();

        vm.prank(admin);
        vm.expectRevert("No players in the game");
        game.distributeCash();
    }

    function test_DistributeCashFailsWithNoFunds() public {
        // Setup player without funds
        vm.prank(player1);
        vm.expectRevert("You must pay at least 0.01 ether to sign up.");
        game.signUp("Q1", "A1");
    }

    function test_OnlyAdminCanDistributeCash() public {
        vm.prank(player1);
        vm.expectRevert("Only the game host or admin can call this function.");
        game.distributeCash();
    }

    // Reset Tests
    function test_ResetGameClearsAllState() public {
        // Setup initial game state
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);

        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Q1", "A1");

        vm.prank(player2);
        game.signUp{value: 0.01 ether}("Q2", "A2");

        // Player 2 answers correctly
        vm.prank(player2);
        game.guessAnswer(1, "A1");

        // End game
        vm.prank(admin);
        game.disableSignUp();

        // Reset game
        vm.prank(admin);
        game.resetGame();

        // Verify state is cleared by checking that first address is zero
        vm.expectRevert(); // Should revert when trying to access index 0
        game.playerAddresses(0);

        assertTrue(game.isSignUpEnabled());

        // Verify player profiles are cleared
        (uint256 playerId,,, uint256 points) = game.addressToPlayerProfile(player1);
        assertEq(playerId, 0);
        assertEq(points, 0);

        // Verify questions are cleared
        (uint256 qId,,,) = game.questionIdToQuestion(1);
        assertEq(qId, 0);

        // Verify player can sign up again
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("New Q", "New A");
        (playerId,,,) = game.addressToPlayerProfile(player1);
        assertEq(playerId, 1);
    }

    function test_OnlyAdminCanResetGame() public {
        vm.prank(player1);
        vm.expectRevert("Only the game host or admin can call this function.");
        game.resetGame();
    }

    function test_CannotResetActiveGame() public {
        vm.prank(admin);
        vm.expectRevert("Must end game before resetting");
        game.resetGame();
    }

    function test_FullGameCycle() public {
        // 1. Setup players with funds
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);

        // 2. Players sign up
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Q1", "A1");

        vm.prank(player2);
        game.signUp{value: 0.01 ether}("Q2", "A2");

        // 3. Players make guesses
        vm.prank(player2);
        game.guessAnswer(1, "A1"); // Correct

        // 4. End game
        vm.prank(admin);
        game.disableSignUp();

        // 5. Distribute prizes
        uint256 initialWinnerBalance = player2.balance;
        vm.prank(admin);
        game.distributeCash();

        // 6. Reset game
        vm.prank(admin);
        game.resetGame();

        // 7. Verify everything is reset and winner got paid
        vm.expectRevert(); // Should revert when trying to access index 0 of empty array
        game.playerAddresses(0);

        assertTrue(game.isSignUpEnabled());
        assertGt(player2.balance, initialWinnerBalance);
        assertEq(address(game).balance, 0);

        // 8. Verify all mappings are cleared
        // Check addressToPlayerProfile is cleared
        (uint256 playerId1,,, uint256 points1) = game.addressToPlayerProfile(player1);
        (uint256 playerId2,,, uint256 points2) = game.addressToPlayerProfile(player2);
        assertEq(playerId1, 0);
        assertEq(playerId2, 0);
        assertEq(points1, 0);
        assertEq(points2, 0);

        // Check questionIdToQuestion is cleared
        (uint256 qId1,,,) = game.questionIdToQuestion(1);
        (uint256 qId2,,,) = game.questionIdToQuestion(2);
        assertEq(qId1, 0);
        assertEq(qId2, 0);

        // Check playerIdToQuestionIdToIsAnswered is cleared
        assertFalse(game.playerIdToQuestionIdToIsAnswered(1, 1));
        assertFalse(game.playerIdToQuestionIdToIsAnswered(2, 1));
        assertFalse(game.playerIdToQuestionIdToIsAnswered(1, 2));
        assertFalse(game.playerIdToQuestionIdToIsAnswered(2, 2));

        // Check playerIdToPoints is cleared
        assertEq(game.playerIdToPoints(player1), 0);
        assertEq(game.playerIdToPoints(player2), 0);
    }

    // Pausable Tests
    function test_PauseAndUnpause() public {
        // Initially not paused
        assertFalse(game.paused());
        
        // Non-admin cannot pause
        vm.prank(player1);
        vm.expectRevert("Only the game host or admin can call this function.");
        game.togglePause();
        
        // Admin can pause
        vm.prank(admin);
        game.togglePause();
        assertTrue(game.paused());
        
        // Admin can unpause
        vm.prank(admin);
        game.togglePause();
        assertFalse(game.paused());
    }
    
    function test_CannotSignUpWhenPaused() public {
        // Pause the game
        vm.prank(admin);
        game.togglePause();
        
        // Try to sign up
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        vm.expectRevert("Contract is paused");
        game.signUp{value: 0.01 ether}("Question", "Answer");
    }
    
    function test_CannotGuessWhenPaused() public {
        // Setup
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Q1", "A1");
        
        vm.prank(player2);
        game.signUp{value: 0.01 ether}("Q2", "A2");
        
        // Pause the game
        vm.prank(admin);
        game.togglePause();
        
        // Try to guess
        vm.prank(player2);
        vm.expectRevert("Contract is paused");
        game.guessAnswer(1, "A1");
    }
    
    function test_CannotDistributeCashWhenPaused() public {
        // Setup
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Q1", "A1");
        
        vm.prank(admin);
        game.disableSignUp();
        
        // Pause the game
        vm.prank(admin);
        game.togglePause();
        
        // Try to distribute cash
        vm.prank(admin);
        vm.expectRevert("Contract is paused");
        game.distributeCash();
    }
    
    function test_PauseBlocksAllFunctions() public {
        // This test verifies that all functions with the whenNotPaused modifier are blocked when paused
        
        // Setup
        vm.deal(player1, 0.01 ether);
        
        // Pause the contract
        vm.prank(admin);
        game.togglePause();
        assertTrue(game.paused(), "Contract should be paused");
        
        // Try to call each function with whenNotPaused modifier
        
        // 1. signUp
        vm.prank(player1);
        vm.expectRevert("Contract is paused");
        game.signUp{value: 0.01 ether}("Q1", "A1");
        
        // 2. disableSignUp
        vm.prank(admin);
        vm.expectRevert("Contract is paused");
        game.disableSignUp();
        
        // 3. guessAnswer (need to set up first)
        vm.prank(admin);
        game.togglePause(); // Unpause temporarily
        
        vm.prank(player1);
        game.signUp{value: 0.01 ether}("Q1", "A1");
        
        vm.prank(admin);
        game.togglePause(); // Pause again
        
        vm.prank(player1);
        vm.expectRevert("Contract is paused");
        game.guessAnswer(1, "A1");
        
        // 4. distributeCash
        vm.prank(admin);
        vm.expectRevert("Contract is paused");
        game.distributeCash();
        
        // 5. resetGame
        vm.prank(admin);
        vm.expectRevert("Contract is paused");
        game.resetGame();
    }
}
