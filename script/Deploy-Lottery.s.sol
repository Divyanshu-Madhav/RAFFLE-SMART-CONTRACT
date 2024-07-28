// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract Deploy is Script {
    function run() external returns (Lottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address vrfCoordinatorV2,
            uint256 entranceFee,
            bytes32 gas_lane,
            uint64 sub_id,
            uint32 callbackGasLimit,
            uint256 interval,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        if (sub_id == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            sub_id = createSubscription.createSubscription(vrfCoordinatorV2,deployerKey);
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinatorV2, sub_id, link,deployerKey);
        }
        vm.startBroadcast(deployerKey);
        Lottery lottery = new Lottery(
            vrfCoordinatorV2,
            entranceFee,
            gas_lane,
            sub_id,
            callbackGasLimit,
            interval
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(vrfCoordinatorV2, sub_id, address(lottery),deployerKey);
        return (lottery, helperConfig);
    }
}
