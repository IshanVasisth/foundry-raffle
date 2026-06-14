// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {DeployRaffle} from "../script/DeployRaffle.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public __raffle;
    HelperConfig public __helperConfig;
    address user = makeAddr("user");
    uint256 subscriptionId;
    address vrfCoordinator;
    uint256 entranceFee;
    uint256 interval;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 public constant ENTRANCE_FEE = 0.01 ether;
    event RequestedRaffleWinner(uint256 indexed requestId);

    //Modifiers
    modifier raffleEnteredAndTimePassed() {
        vm.prank(user);
        __raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    modifier skipFork() {
        if (block.chainid != 31337){
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (__raffle, __helperConfig) = deployer.deployRaffle();
        vm.deal(user, 10 ether);
        HelperConfig.NetworkConfig memory config = __helperConfig
            .getActiveNetworkConfig();
        subscriptionId = config.subscriptionId;
        vrfCoordinator = config.vrfCoordinator;
        entranceFee = config.entranceFee;
        interval = config.interval;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testRaffleInitializesInOpenState() public view {
        assert(__raffle.s_raffleState() == Raffle.raffleState.Open);
    }

    function testRaffleEntranceFee() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__TicketHasLowerCap.selector,
                ENTRANCE_FEE,
                0.009 ether
            )
        );
        __raffle.enterRaffle{value: 0.009 ether}();
        vm.stopPrank();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.startPrank(user);
        __raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.stopPrank();
        assertEq(user, __raffle.s_players(0));
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.expectEmit(true, false, false, false, address(__raffle));
        emit Raffle.RaffleEnter(user);
        vm.prank(user);
        __raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    function testDontAllowPlayersToEnterWhenRaffleIsCalculating()
        public
        raffleEnteredAndTimePassed
    {
        //Arrange
        vm.startPrank(user);
        __raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.stopPrank();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 3);
        __raffle.performUpkeep("");

        //Act
        vm.startPrank(user);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        __raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfDeadlineNotPassed() public {
        //Arrange
        vm.startPrank(user);
        __raffle.enterRaffle{value: ENTRANCE_FEE}(); //s.players length is one
        vm.stopPrank();
        vm.warp(block.timestamp + interval - 1);

        //Act
        (bool upkeepNeeded, ) = __raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNoPlayers() public {
        //Arrange
        vm.roll(block.number + 3);
        vm.warp(block.timestamp + interval + 1); //since enough time has passed and enough blocks have passed, upkeep is needed but since there are no players, upkeep is not needed
        //Act
        (bool upkeepNeeded, ) = __raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen()
        public
        raffleEnteredAndTimePassed
    {
        //Arrange
        __raffle.performUpkeep(""); //closes the raffle to the state calculating

        //Act
        (bool upkeepNeeded, ) = __raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepRevertsIfUpkeepNotNeeded() public {
        //Arrange
        vm.startPrank(user);
        __raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.stopPrank();
        vm.warp(block.timestamp + interval - 1); //since enough time has not passed, upkeep is not needed

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                address(__raffle).balance,
                __raffle.getNumberOfPlayers(),
                0
            )
        );
        __raffle.performUpkeep("");
    }

    function testPerformUpkeepEmitsEventWhenRequestRandomWordsIsCalled()
        public
        raffleEnteredAndTimePassed skipFork
    {
        //Arrange

        //Act and Assert
        vm.expectEmit(true, false, false, false, address(__raffle));
        emit RequestedRaffleWinner(1);
        __raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        //Arrange
        vm.recordLogs();
        __raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //assert
        assert(uint256(requestId) > 0);
        assert(__raffle.s_raffleState() == Raffle.raffleState.Calculating);
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork{
        //Arrange
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(__raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed skipFork 
    {
        // Arrange

        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            __raffle.enterRaffle{value: ENTRANCE_FEE}(); //this enters 3 more players into the raffle
        }

        uint256 startingTimeStamp = __raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        vm.recordLogs();
        __raffle.performUpkeep(""); //this will change the state of the raffle to calculating and request random words from chainlink vrf
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];



        //Act
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(__raffle)
        );

        //Assert
        address recentWinner = __raffle.getRecentWinner();
        Raffle.raffleState raffleState = __raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = __raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(expectedWinner == recentWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
