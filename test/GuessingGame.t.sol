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
        vm.startPrank(player2);
        uint256 minimumBet = game.getMinimumBet();
        deal(player2, minimumBet);
        game.guessAnswer{value: minimumBet}(1, answer);
        vm.stopPrank();

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

        // Player 2 makes incorrect guess with minimum bet
        vm.startPrank(player2);
        uint256 minimumBet = game.getMinimumBet();
        deal(player2, minimumBet);
        game.guessAnswer{value: minimumBet}(1, "wrong answer");
        vm.stopPrank();

        // Verify no points were awarded
        (,,, uint256 points) = game.addressToPlayerProfile(player2);
        assertEq(points, 0);
    }

    function test_NonPlayerCannotGuess() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp("Question 1", "Answer 1");

        // Non-player tries to guess
        vm.startPrank(player2);
        uint256 minimumBet = game.getMinimumBet();
        deal(player2, minimumBet);
        vm.expectRevert("You must be a signed up player to call this function.");
        game.guessAnswer{value: minimumBet}(1, "Answer 1");
        vm.stopPrank();
    }

    function test_CannotGuessWithoutMinimumBet() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp("Question 1", "Answer 1");

        // Player 2 signs up but tries to guess without minimum bet
        vm.startPrank(player2);
        game.signUp("Question 2", "Answer 2");
        vm.expectRevert("Below Minimum");
        game.guessAnswer{value: 0}(1, "Answer 1");
        vm.stopPrank();
    }

    function test_CannotGuessInvalidQuestion() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp("Question 1", "Answer 1");

        // Player 2 signs up and tries to guess invalid question
        vm.startPrank(player2);
        game.signUp("Question 2", "Answer 2");
        uint256 minimumBet = game.getMinimumBet();
        deal(player2, minimumBet);
        vm.expectRevert("Invalid question ID.");
        game.guessAnswer{value: minimumBet}(999, "Any answer");
        vm.stopPrank();
    }

    function test_CannotGuessQuestionTwice() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp("Question 1", "Answer 1");
        // Player 2 signs up and guesses correctly
        vm.startPrank(player2);
        game.signUp("Question 2", "Answer 2");
        uint256 minimumBet = game.getMinimumBet();
        deal(player2, minimumBet * 2);
        game.guessAnswer{value: minimumBet}(1, "Answer 1");

        // Player 2 tries to guess the same question again
        vm.expectRevert("You have already answered this question.");
        game.guessAnswer{value: minimumBet}(1, "Answer 1");
        vm.stopPrank();
    }

    function test_CannotGuessOwnQuestion() public {
        // Player 1 signs up
        vm.startPrank(player1);
        game.signUp("Question 1", "Answer 1");
        uint256 minimumBet = game.getMinimumBet();
        deal(player1, minimumBet);
        vm.expectRevert("You cannot answer your own question.");
        game.guessAnswer{value: minimumBet}(1, "Answer 1");
        vm.stopPrank();
    }

    function test_MultiplePlayersAndGuesses() public {
        // Set up three players
        vm.prank(player1);
        game.signUp("Q1", "A1");

        vm.prank(player2);
        game.signUp("Q2", "A2");

        vm.prank(player3);
        game.signUp("Q3", "A3");

        // Player 2 correctly guesses Player 1's question
        vm.startPrank(player2);
        uint256 minimumBet = game.getMinimumBet();
        deal(player2, minimumBet);
        game.guessAnswer{value: minimumBet}(1, "A1");
        vm.stopPrank();

        // Player 3 correctly guesses Player 1's and Player 2's questions
        vm.startPrank(player3);
        deal(player3, minimumBet * 2);
        game.guessAnswer{value: minimumBet}(1, "A1");
        game.guessAnswer{value: minimumBet}(2, "A2");
        vm.stopPrank();

        // Verify points
        (,,, uint256 points2) = game.addressToPlayerProfile(player2);
        (,,, uint256 points3) = game.addressToPlayerProfile(player3);
        assertEq(points2, 1);
        assertEq(points3, 2);
    }

    function test_DistributeWinnings() public {
        // Set up initial balances
        uint256 minimumBet = game.getMinimumBet();
        deal(player1, minimumBet);
        deal(player2, minimumBet * 2);
        deal(player3, minimumBet * 3);
        deal(address(game), minimumBet * 10); // Fund contract for payouts

        // Players sign up
        vm.prank(player1);
        game.signUp("Q1", "A1");

        vm.prank(player2);
        game.signUp("Q2", "A2");

        vm.prank(player3);
        game.signUp("Q3", "A3");

        // Player 2 correctly guesses Player 1's question
        vm.startPrank(player2);
        game.guessAnswer{value: minimumBet}(1, "A1"); // Bet is returned immediately on correct guess
        vm.stopPrank();

        // Player 3 correctly guesses both Player 1's and Player 2's questions
        vm.startPrank(player3);
        game.guessAnswer{value: minimumBet}(1, "A1"); // Bet is returned immediately on correct guess
        game.guessAnswer{value: minimumBet}(2, "A2"); // Bet is returned immediately on correct guess
        vm.stopPrank();

        // Record intermediate balances (after correct guesses but before distribution)
        uint256 player1BalanceBeforeDistribution = player1.balance;
        uint256 player2BalanceBeforeDistribution = player2.balance;
        uint256 player3BalanceBeforeDistribution = player3.balance;

        // Distribute winnings
        vm.prank(admin);
        game.distributeWinnings();

        // Check balances after distribution
        // Player 1: 0 points = 0 winnings
        // Player 2: 1 point = 1 * minimumBet winnings
        // Player 3: 2 points = 2 * minimumBet winnings
        assertEq(player1.balance, player1BalanceBeforeDistribution);
        assertEq(player2.balance, player2BalanceBeforeDistribution + minimumBet);
        assertEq(player3.balance, player3BalanceBeforeDistribution + (minimumBet * 2));

        // Verify game state is reset
        assertTrue(game.isSignUpEnabled());

        // Check player profiles are cleared
        (uint256 player1Id,,, uint256 player1Points) = game.addressToPlayerProfile(player1);
        (uint256 player2Id,,, uint256 player2Points) = game.addressToPlayerProfile(player2);
        (uint256 player3Id,,, uint256 player3Points) = game.addressToPlayerProfile(player3);

        assertEq(player1Id, 0);
        assertEq(player2Id, 0);
        assertEq(player3Id, 0);
        assertEq(player1Points, 0);
        assertEq(player2Points, 0);
        assertEq(player3Points, 0);

        // Check questions are cleared
        (uint256 q1Id,,,) = game.questionIdToQuestion(1);
        (uint256 q2Id,,,) = game.questionIdToQuestion(2);
        (uint256 q3Id,,,) = game.questionIdToQuestion(3);

        assertEq(q1Id, 0);
        assertEq(q2Id, 0);
        assertEq(q3Id, 0);
    }

    function test_OnlyAdminCanDistributeWinnings() public {
        vm.prank(player1);
        vm.expectRevert("Only the game host or admin can call this function.");
        game.distributeWinnings();
    }
}
