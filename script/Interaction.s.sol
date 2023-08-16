// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionFromCfg() public returns (uint64) {
        HelperConfig cfg = new HelperConfig();
        (, , address coordinator, , , , , uint deployerKey) = cfg
            .activeNetworkConfig();
        return createSubscription(coordinator, deployerKey);
    }

    function createSubscription(
        address coordinator,
        uint deployerKey
    ) public returns (uint64) {
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(coordinator).createSubscription();
        vm.stopBroadcast();
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionFromCfg();
    }
}

contract FundSubscription is Script {
    uint96 public FUND_AMOUNT = 3 ether;

    function fundSubscriptionWithCfg() public {
        HelperConfig cfg = new HelperConfig();
        (
            ,
            ,
            address coordinator,
            ,
            uint64 subID,
            ,
            address link,
            uint deployerKey
        ) = cfg.activeNetworkConfig();

        fundSubscription(coordinator, subID, link, deployerKey);
    }

    function fundSubscription(
        address coordinator,
        uint64 subId,
        address link,
        uint deployerKey
    ) public {
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(coordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                coordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionWithCfg();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address coordinator,
        uint64 subId,
        uint deployerKey
    ) public {
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(coordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingCfg(address raffle) public {
        HelperConfig cfg = new HelperConfig();
        (, , address coordinator, , uint64 subID, , , uint deployerKey) = cfg
            .activeNetworkConfig();

        // vm.startBroadcast(deployerKey);
        addConsumer(raffle, coordinator, subID, deployerKey);
        // vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingCfg(raffle);
    }
}
