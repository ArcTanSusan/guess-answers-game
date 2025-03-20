// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {GuessingGame} from "../src/GuessingGame.sol";

contract GuessingGameDeploy is Script {
    GuessingGame public guesssingGame;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        guesssingGame = new GuessingGame(0x694AA1769357215DE4FAC081bf1f309aDC325306);

        vm.stopBroadcast();
    }
}
