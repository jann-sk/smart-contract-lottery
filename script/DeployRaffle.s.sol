// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperCfg = new HelperConfig();
        (
            uint fee,
            uint interval,
            address coordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint deployerKey
        ) = helperCfg.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription cs = new CreateSubscription();
            subscriptionId = cs.createSubscription(coordinator, deployerKey);

            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(
                coordinator,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            fee,
            interval,
            coordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addCons = new AddConsumer();
        addCons.addConsumer(
            address(raffle),
            coordinator,
            subscriptionId,
            deployerKey
        );
        return (raffle, helperCfg);
    }
}
