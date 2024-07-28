// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address vrfCoordinatorV2,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatorV2, deployerKey);
    }

    function createSubscription(
        address vrfCoordinatorv2,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 sub_id = VRFCoordinatorV2Mock(vrfCoordinatorv2)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", sub_id);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return sub_id;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            address vrfCoordinatorV2,
            ,
            ,
            uint64 sub_id,
            ,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinatorV2, sub_id, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinatorv2,
        uint64 sub_id,
        address link,
        uint256 deployerKey
    ) public {
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinatorv2).fundSubscription(
                sub_id,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinatorv2,
                FUND_AMOUNT,
                abi.encode(sub_id)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address lottery) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            address vrfCoordinatorV2,
            ,
            ,
            uint64 sub_id,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(vrfCoordinatorV2, sub_id, lottery, deployerKey);
    }

    function addConsumer(
        address vrfCoordinatorv2,
        uint64 sub_id,
        address lottery,
        uint256 deployerKey
    ) public {
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinatorv2).addConsumer(sub_id, lottery);
        vm.stopBroadcast();
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );
        addConsumerUsingConfig(lottery);
    }
}
