//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Raffle} from "../src/Raffle.sol";
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {createSubscription, fundSubscription, addConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external {
        deployRaffle();
    }

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getActiveNetworkConfig();
        if (config.subscriptionId == 0) {
            //create subscription and fund it
            //create the subscription and change the subscription id in the helper config
            createSubscription createSubscriptionScript = new createSubscription();
            (
                config.subscriptionId,
                config.vrfCoordinator
            ) = createSubscriptionScript._createSubscription(
                config.vrfCoordinator,
                config.account
            );
            helperConfig.setSubscriptionId(config.subscriptionId);
            //funding the subscription
            fundSubscription fundSubscriptionScript = new fundSubscription();
            fundSubscriptionScript._fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.linkToken,
                config.account
            );
        }

        vm.startBroadcast();
        Raffle lottery = new Raffle(
            config.subscriptionId,
            config.vrfCoordinator,
            config.entranceFee,
            config.interval,
            config.gasLane,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        addConsumer _addRaffle = new addConsumer();
        _addRaffle.addConsumerUsingConfig(address(lottery), config);
        return (lottery, helperConfig);
    }
}
