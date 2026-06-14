//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {createSubscription, fundSubscription, addConsumer} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";
import {Vm} from "forge-std/Vm.sol";

contract InteractionsTest is Test {
    Raffle public _raffle;
    HelperConfig _helperConfig;

    HelperConfig.NetworkConfig public config;

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle _deployRaffle = new DeployRaffle();
        (_raffle, _helperConfig) = _deployRaffle.deployRaffle();
        config = _helperConfig.getActiveNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                           CREATESUBSCRIPTION
    //////////////////////////////////////////////////////////////*/
    // placeholder test to satisfy parser/linter
    function testCreateSubscriptionReturnsSubId() public skipFork {
        //Arrange
        createSubscription _createSub = new createSubscription();
        //Act
        (uint256 _subId, address _vrfCoordinator) = _createSub
            ._createSubscription(config.vrfCoordinator, config.account);
        //assert
        assert(_subId > 0);
        assert(_vrfCoordinator == config.vrfCoordinator);
    }

    /*//////////////////////////////////////////////////////////////
                            FUNDSUBSCRIPTION
    //////////////////////////////////////////////////////////////*/

    function testFundSubscriptionIncreasesBalance() public {
        //Arrange
        (uint256 initialBalance, , , , ) = VRFCoordinatorV2_5Mock(
            config.vrfCoordinator
        ).getSubscription(config.subscriptionId);
        fundSubscription _fundSub = new fundSubscription();
        //Act
        _fundSub._fundSubscription(
            config.vrfCoordinator,
            config.subscriptionId,
            config.linkToken,
            config.account
        );
        (uint96 balanceAfter, , , , ) = VRFCoordinatorV2_5Mock(
            config.vrfCoordinator
        ).getSubscription(config.subscriptionId);

        //assert
        if (block.chainid == 31337) {
            assert(
                uint256(balanceAfter) - uint256(initialBalance) ==
                    _fundSub.FUND_AMOUNT()
            );
        } else {
            assert(
                uint256(balanceAfter) - uint256(initialBalance) ==
                    _fundSub.FUND_AMOUNT() / 10
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ADDCONSUMER
    //////////////////////////////////////////////////////////////*/
    //only the owner of the subId can call the addConsumer
    function testOnlyOwnerCanAddConsumer() public {
        //Arrange
        address user = makeAddr("ishan");
        addConsumer _addConsumer = new addConsumer();
        Raffle __raffle = new Raffle(
            config.subscriptionId,
            config.vrfCoordinator,
            config.entranceFee,
            config.interval,
            config.gasLane,
            config.callbackGasLimit
        );
        address oldaccount = config.account;
        config.account = user;
        //Act and assert
        //vm.prank(user); - addConsumerUsingConfig uses vm broadcast but broadcast and prank arent compatible
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionAPI.MustBeSubOwner.selector,
                oldaccount
            )
        );
        _addConsumer.addConsumerUsingConfig(address(__raffle), config);
    }

    function testAddConsumerEmitsEvent() public {
        //Arrange
        addConsumer _addConsumer = new addConsumer();
        address newConsumer = makeAddr("newConsumer");
        //Act and assert
        vm.expectEmit(true, false, false, false, config.vrfCoordinator);
        emit SubscriptionAPI.SubscriptionConsumerAdded(
            config.subscriptionId,
            newConsumer
        );
        _addConsumer.addConsumerUsingConfig(newConsumer, config);
    }
}
