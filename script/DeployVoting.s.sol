// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Voting} from "../src/Voting.sol";
import {Token} from "./DeployToken.s.sol";
import {DeployToken} from "./DeployToken.s.sol";

contract DeployVoting is Script{
    function run() external returns(Voting){
        vm.startBroadcast();
        Voting voting = new Voting(0x90193C961A926261B756D1E5bb255e67ff9498A1);
        vm.stopBroadcast();
        return voting;
    }
}