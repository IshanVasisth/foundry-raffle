// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Raffle Contract
 * @author Ishan
 * @notice Implements ChainLink VRF v2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    //Errors
    error Raffle__TicketHasLowerCap(uint256 required, uint256 sent);
    error Raffle__TransferFailed();
    error Raffle__DeadlineHasPassed(uint256 currentTime, uint256 deadline);
    error Raffle__DeadlineHasNotPassed(uint256 currentTime, uint256 deadline);
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    //Type declarations
    enum raffleState {
        Open,
        Calculating
    }

    //State variables
    uint256 public immutable i_subscriptionId;
    uint256 public immutable i_entranceFee;
    address payable[] public s_players;
    address payable private s_recentWinner;
    uint16 public constant REQUESTCONFIRMATIONS = 3; //minimum
    uint32 private constant NUM_WORDS = 1;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint256 public s_deadlineTimestamp;
    raffleState public s_raffleState;
    uint256 public raffleInterval;
    uint256 private s_requestId;


    //Events
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 subscriptionId,
        address vrfCoordinator,
        uint256 entranceFee,
        uint256 interval,
        bytes32 gasLane,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        raffleInterval = interval;
        s_deadlineTimestamp = block.timestamp + interval;
        i_keyHash = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = raffleState.Open;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__TicketHasLowerCap(i_entranceFee, msg.value);
        }
        if (s_raffleState != raffleState.Open) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev conditions needed for upkeepNeeded to be true:
     * 1. The current timestamp should be greater than the deadline timestamp.
     * 2. The raffle should be in open state.
     * 3. There should be at least 1 player in the raffle.
     * @param - ignored
     * @return upkeepNeeded - true if its time to restart the raffle
     * @return
     */

    function checkUpkeep(
        //chainlink automation will call this function over and over again when it returns true it will performUpkeep
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        if (
            block.timestamp >= s_deadlineTimestamp &&
            s_raffleState == raffleState.Open &&
            s_players.length > 0
        ) {
            upkeepNeeded = true;
        } else {
            upkeepNeeded = false;
        }
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        //Generating a random number using chainlink VRF
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = raffleState.Calculating;
        s_requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUESTCONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                ) // new parameter
            })
        );
        emit RequestedRaffleWinner(s_requestId);
    }

    // getter functions

    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] calldata _randomWords
    ) internal override {
        //Checks

        //Effects (Internal contract state)
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        s_recentWinner = s_players[indexOfWinner];

        //Resetting the state of the contract
        s_raffleState = raffleState.Open;
        s_players = new address payable[](0);
        s_deadlineTimestamp = block.timestamp + raffleInterval;

        //Interactions (External contract state)
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        require(success, Raffle__TransferFailed());
        emit WinnerPicked(s_recentWinner);
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns(raffleState) {
        return s_raffleState;
    }

    function getLastTimeStamp() public view returns(uint256){
        return s_deadlineTimestamp;
    }
}
