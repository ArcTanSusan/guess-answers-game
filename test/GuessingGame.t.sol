// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GuessingGame} from "../src/GuessingGame.sol";

contract GuessingGameTest is Test {
    GuessingGame game;
    address admin = address(0x1);
    address player1 = address(0x2);
    address player2 = address(0x3);

    function setUp() public {
        // Deploy the game contract with the admin address
        game = new GuessingGame(admin);
    }

    function testSignUp() public {
        // Player signs up
        vm.prank(player1);
        game.signUp();

        // Verify player is signed up
        assertTrue(game.playersMap(player1), "Player 1 should be signed up.");
        assertEq(game.getPlayersCount(), 1, "Players count should be 1.");
    }

    function testSignUpDisabled() public {
        // Disable sign-up
        vm.prank(admin);
        game.disableSignUp();

        // Attempt to sign up after disabling sign-up
        vm.prank(player2);
        vm.expectRevert("Sign-up is disabled.");
        game.signUp();
    }

    function testCreateAnswerKey() public {
        // Player 1 signs up
        vm.prank(player1);
        game.signUp();

        // Player 2 signs up
        vm.prank(player2);
        game.signUp();

        // Player 1 creates an answer key
        vm.prank(player1);
        game.createAnswerKey("Is the sky blue?", true);

        // Player 2 creates an answer key
        vm.prank(player2);
        game.createAnswerKey("Is the ocean blue?", true);

        // Verify the questionId mapping for both players
        assertEq(
            game.playerIdToQuestionId(player1),
            0,
            "Player 1 should have questionId 0."
        );
        assertEq(
            game.playerIdToQuestionId(player2),
            1,
            "Player 2 should have questionId 1."
        );

        // Verify the answers for the questions
        assertTrue(
            game.questionIdToAnswer(0, "Is the sky blue?"),
            "The answer for the question should be true."
        );
        assertTrue(
            game.questionIdToAnswer(1, "Is the ocean blue?"),
            "The answer for the question should be true."
        );
    }

    function testCreateAnswerKeyMultiple() public {
        // Player signs up
        vm.prank(player1);
        game.signUp();

        // Player creates an answer key
        vm.prank(player1);
        game.createAnswerKey("What is 2 + 2?", true);

        // Attempt to create another answer key
        vm.prank(player1);
        vm.expectRevert("You have already created 1 answer key.");
        game.createAnswerKey("What is 3 + 3?", false);
    }

    function testHasEachPlayerCreatedAnswersKey() public {
        // Player 1 signs up and creates an answer key
        vm.prank(player1);
        game.signUp();
        vm.prank(player1);
        game.createAnswerKey("What is 2 + 2?", true);

        // Player 2 signs up
        vm.prank(player2);
        game.signUp();

        // Admin checks if each player has created an answer key
        vm.prank(admin);
        assertFalse(
            game.hasEachPlayerCreatedAnswersKey(),
            "Not all players have created an answer key."
        );

        // Player 2 creates an answer key
        vm.prank(player2);
        game.createAnswerKey("Am I a robot?", true);

        // Check again after disabling sign-up
        vm.prank(admin);
        assertTrue(
            game.hasEachPlayerCreatedAnswersKey(),
            "All players should have created an answer key."
        );
    }
}
