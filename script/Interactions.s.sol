//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract createSubscription is Script, CodeConstants {
    function createSubscriptionUsingConfig()
        public
        returns (uint256 subId, address)
    {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getActiveNetworkConfig()
            .vrfCoordinator;
        //create a subscription
        (subId, vrfCoordinator) = _createSubscription(
            vrfCoordinator,
            helperConfig.getActiveNetworkConfig().account
        );
        return (subId, vrfCoordinator);
    }

    function _createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = VRFCoordinatorV2_5Mock(
            vrfCoordinator
        );
        console.log("Creating subscription on chain Id", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = vrfCoordinatorMock.createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is:", subId);
        console.log(
            "Please update your helper config with this Id to fund your subscription and run the raffle"
        );

        return (subId, vrfCoordinator);
    }

    function run() external {
        createSubscriptionUsingConfig();
    }
}

contract fundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 300 ether; //3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getActiveNetworkConfig()
            .vrfCoordinator;
        uint256 subId = helperConfig.getActiveNetworkConfig().subscriptionId;
        address linkToken = helperConfig.getActiveNetworkConfig().linkToken;
        address account = helperConfig.getActiveNetworkConfig().account;
        _fundSubscription(vrfCoordinator, subId, linkToken, account);
    }

    function _fundSubscription(
        address vrfCoordinator,
        uint256 subId,
        address linkToken,
        address account
    ) public {
        console.log("Funding subscription on chain Id", block.chainid);
        console.log("Funding with Link token at address", linkToken);
        if (block.chainid == CodeConstants.ANVIL_CHAINID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT / 10,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }

        console.log("Subscription funded with 3 LINK");
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract addConsumer is Script, CodeConstants {
    function run() external {
        address consumer = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getActiveNetworkConfig();

        addConsumerUsingConfig(consumer, config);
    }

    function addConsumerUsingConfig(
        address consumer,
        HelperConfig.NetworkConfig memory config
    ) public {
        uint256 subId = config.subscriptionId;
        address vrfCoordinator = config.vrfCoordinator;
        console.log(
            "Adding consumer to subscription on chain Id",
            block.chainid
        );
        console.log("Consumer address is", consumer);
        console.log("VRF Coordinator address is", vrfCoordinator);
        console.log("Subscription Id is", subId);
        vm.startBroadcast(config.account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();
        console.log("Consumer added to subscription");
    }
}
