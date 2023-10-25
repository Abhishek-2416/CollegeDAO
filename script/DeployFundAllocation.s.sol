// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {FundAllocation} from "../src/FundAllocation.sol";

contract DeployFundAllocation is Script {
    function run() external returns(FundAllocation) {
        vm.startBroadcast();
        FundAllocation fundAllocation = new FundAllocation(0x90193C961A926261B756D1E5bb255e67ff9498A1);
        vm.stopBroadcast();
        return fundAllocation;
    }
}