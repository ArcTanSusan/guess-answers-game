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
        vm.prank(player1);
        game.signUp("What is 2+2?", "4");

        (uint256 playerId, string memory question, bytes32 answer, uint256 points) = 
            game.addressToPlayerProfile(player1);

        assertEq(playerId, 1);
        assertEq(question, "What is 2+2?");
        assertEq(points, 0);
        assertTrue(answer != bytes32(0));
        assertEq(game.playerAddresses(0), player1);
    }

    function test_CannotSignUpTwice() public {
        vm.startPrank(player1);
        game.signUp("Question 1", "Answer 1");
        
        vm.expectRevert("You are already signed up.");
        game.signUp("Question 2", "Answer 2");
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
        
        // Player 1 signs up and creates question
        vm.prank(player1);
        game.signUp(question, answer);

        // Player 2 signs up
        vm.prank(player2);
        game.signUp("Different question", "Different answer");

        // Player 2 correctly guesses Player 1's question
        vm.prank(player2);
        game.guessAnswer(1, answer);

        // Verify points were awarded
        (,,, uint256 points) = game.addressToPlayerProfile(player2);
        assertEq(points, 1);
    }

    function test_IncorrectGuess() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp("What is 2+2?", "4");

        // Player 2 signs up
        vm.prank(player2);
        game.signUp("Another question", "answer");

        // Player 2 incorrectly guesses Player 1's question
        vm.prank(player2);
        game.guessAnswer(1, "5");

        // Verify no points were awarded
        (,,, uint256 points) = game.addressToPlayerProfile(player2);
        assertEq(points, 0);
    }

    function test_CannotGuessOwnQuestion() public {
        vm.prank(player1);
        game.signUp("What is 2+2?", "4");

        vm.prank(player1);
        vm.expectRevert("You cannot answer your own question.");
        game.guessAnswer(1, "4");
    }

    function test_CannotGuessQuestionTwice() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp("Question 1", "Answer 1");

        // Player 2 signs up
        vm.prank(player2);
        game.signUp("Question 2", "Answer 2");

        // Player 2 guesses Player 1's question
        vm.prank(player2);
        game.guessAnswer(1, "Answer 1");

        // Player 2 tries to guess the same question again
        vm.prank(player2);
        vm.expectRevert("You have already answered this question.");
        game.guessAnswer(1, "Answer 1");
    }

    function test_CannotGuessInvalidQuestion() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp("Question 1", "Answer 1");

        // Try to guess non-existent question
        vm.prank(player1);
        vm.expectRevert("Invalid question ID.");
        game.guessAnswer(999, "Any answer");
    }

    function test_NonPlayerCannotGuess() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp("Question 1", "Answer 1");

        // Non-player tries to guess
        vm.prank(player3);
        vm.expectRevert("You must be a signed up player to call this function.");
        game.guessAnswer(1, "Answer 1");
    }

    function test_MultiplePlayersAndGuesses() public {
        // Set up three players
        vm.prank(player1);
        game.signUp("Q1", "A1");

        vm.prank(player2);
        game.signUp("Q2", "A2");

        vm.prank(player3);
        game.signUp("Q3", "A3");

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
}
