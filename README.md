## Raffle Contract

### About
**Raffle contract is a smart contract that lets anyone buy a ticket.**
**The contract then calls Chainlink VRF for a verifiably random number and settles the lottery.**
**We use ChainLink Automation to run this draw at regular intervals.**

# 🎰 Provably Fair On-Chain Raffle

A decentralized, automated raffle system built with Solidity, powered by **Chainlink VRF v2.5** for verifiable randomness and **Chainlink Automation** for trustless upkeep execution.

---

## Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Contract Architecture](#contract-architecture)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [Testing](#testing)
- [Security Considerations](#security-considerations)
- [Contract Details](#contract-details)
- [Network Configuration](#network-configuration)
- [Acknowledgements](#acknowledgements)

---

## Overview

This project implements a fully on-chain raffle where:

- Anyone can enter by paying an entrance fee
- A winner is selected at a fixed time interval using Chainlink VRF v2.5 (cryptographically verifiable randomness)
- Winner selection and prize distribution are automated via Chainlink Automation — no manual intervention required
- The entire process is transparent and auditable on-chain

---

## How It Works

1. Players call `enterRaffle()` and send the entrance fee in ETH
2. Chainlink Automation calls `checkUpkeep()` at regular intervals
3. When enough time has passed, there are players, and the raffle is open — `checkUpkeep()` returns `true`
4. Chainlink Automation then calls `performUpkeep()`, which requests a random number from Chainlink VRF v2.5 and locks the raffle in `Calculating` state
5. Chainlink VRF fulfills the request by calling `fulfillRandomWords()` with a verifiably random number
6. The random number is used to select a winner from the players array
7. The entire prize pool is transferred to the winner, the players array is reset, and a new round begins

---

## Contract Architecture

```
src/
└── Raffle.sol              # Core raffle logic

script/
├── DeployRaffle.s.sol      # Deployment script with auto subscription setup
├── HelperConfig.s.sol      # Network-specific configuration
└── Interactions.s.sol      # Subscription management scripts (create/fund/addConsumer)

test/
├── unit/
│   └── Raffle.t.sol        # Unit tests for Raffle contract
└── integration/
    └── InteractionsTest.t.sol  # Integration tests for deployment scripts
```

### Key Contracts

**`Raffle.sol`** — The core contract. Inherits `VRFConsumerBaseV2Plus` from Chainlink. Manages player entries, upkeep checks, VRF requests, and winner payouts.

**`DeployRaffle.s.sol`** — Deployment script that handles the full setup pipeline: creates a VRF subscription (if needed), funds it, deploys Raffle, and registers it as a VRF consumer — all in one run.

**`HelperConfig.s.sol`** — Abstracts network-specific values (VRF coordinator address, gas lane, subscription ID, etc.) for both Sepolia testnet and local Anvil. Deploys mocks automatically on Anvil.

**`Interactions.s.sol`** — Modular scripts for VRF subscription management: `createSubscription`, `fundSubscription`, `addConsumer`. Can be run standalone or composed by DeployRaffle.

---

## Project Structure

```
.
├── src/
│   └── Raffle.sol
├── script/
│   ├── DeployRaffle.s.sol
│   ├── HelperConfig.s.sol
│   └── Interactions.s.sol
├── test/
│   ├── unit/
│   │   └── Raffle.t.sol
│   ├── integration/
│   │   └── InteractionsTest.t.sol
│   └── mocks/
│       └── LinkToken.sol
├── foundry.toml
└── README.md
```

---

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)

### Installation

```bash
git clone https://github.com/<your-username>/foundry-raffle
cd foundry-raffle
forge install
```

### Environment Setup

Create a `.env` file in the root:

```env
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<YOUR_KEY>
PRIVATE_KEY=<YOUR_PRIVATE_KEY>
ETHERSCAN_API_KEY=<YOUR_ETHERSCAN_KEY>
```

Load the environment:

```bash
source .env
```

---

## Deployment

### Local (Anvil)

Spins up a local chain, deploys mock VRF coordinator and LINK token, creates and funds a subscription, deploys Raffle, and registers it as a consumer — all automatically.

```bash
# Start Anvil in a separate terminal
anvil

# Deploy
forge script script/DeployRaffle.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Sepolia Testnet

Before deploying to Sepolia, ensure your `HelperConfig.s.sol` has the correct `subscriptionId` for your Chainlink VRF subscription. You can create one at [vrf.chain.link](https://vrf.chain.link).

```bash
forge script script/DeployRaffle.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Standalone Subscription Scripts

```bash
# Create a new VRF subscription
forge script script/Interactions.s.sol:createSubscription --rpc-url $SEPOLIA_RPC_URL --broadcast

# Fund an existing subscription
forge script script/Interactions.s.sol:fundSubscription --rpc-url $SEPOLIA_RPC_URL --broadcast

# Add a consumer to a subscription
forge script script/Interactions.s.sol:addConsumer --rpc-url $SEPOLIA_RPC_URL --broadcast
```

---

## Testing

### Run All Tests

```bash
forge test
```

### Run with Verbosity

```bash
forge test -vvv
```

### Run Specific Test

```bash
forge test --match-test testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney -vvv
```

### Fork Tests (Sepolia)

Some tests are skipped on local Anvil (`skipFork` modifier) and are intended to run against a live fork:

```bash
forge test --fork-url $SEPOLIA_RPC_URL
```

### Test Coverage

```bash
forge coverage
```

### Test Summary

| Test | Description |
|---|---|
| `testRaffleInitializesInOpenState` | Raffle starts in Open state |
| `testRaffleEntranceFee` | Reverts if entrance fee is too low |
| `testRaffleRecordsPlayersWhenTheyEnter` | Player address stored correctly |
| `testEnteringRaffleEmitsEvent` | `RaffleEnter` event emitted on entry |
| `testDontAllowPlayersToEnterWhenRaffleIsCalculating` | Blocks entry during VRF request |
| `testCheckUpkeepReturnsFalseIfDeadlineNotPassed` | No upkeep before interval elapsed |
| `testCheckUpkeepReturnsFalseIfNoPlayers` | No upkeep with empty players array |
| `testCheckUpkeepReturnsFalseIfRaffleNotOpen` | No upkeep during Calculating state |
| `testPerformUpkeepRevertsIfUpkeepNotNeeded` | `performUpkeep` reverts correctly |
| `testPerformUpkeepEmitsEventWhenRequestRandomWordsIsCalled` | VRF request event emitted |
| `testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId` | State updates to Calculating |
| `testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep` | VRF callback access control |
| `testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney` | Full end-to-end winner flow |
| `testCreateSubscriptionReturnsSubId` | Subscription creation returns valid ID |
| `testFundSubscriptionIncreasesBalance` | Funding increases subscription balance |
| `testOnlyOwnerCanAddConsumer` | Non-owner cannot add consumer |
| `testAddConsumerEmitsEvent` | Consumer addition emits event |

---

## Security Considerations

**Reentrancy** — `fulfillRandomWords` follows the CEI (Checks-Effects-Interactions) pattern: state is fully reset before the external ETH transfer to the winner.

**Access Control on VRF Callback** — `fulfillRandomWords` is `internal override`, callable only by the inherited `VRFConsumerBaseV2Plus` base contract, which validates the caller is the registered VRF coordinator.

**Randomness** — Randomness is sourced from Chainlink VRF v2.5 which provides on-chain verifiable cryptographic proofs. The contract does not use block hash, timestamp, or any miner-manipulable value as a randomness source.

**State Locking** — The raffle is set to `Calculating` state upon calling `performUpkeep`, blocking new entries and preventing duplicate upkeep calls until the VRF response arrives.

**Single Winner Per Round** — `NUM_WORDS = 1` ensures exactly one random word is requested per round, preventing ambiguity in winner selection.

**Failed Transfer** — If the ETH transfer to the winner fails, `fulfillRandomWords` reverts via a custom `Raffle__TransferFailed` error. Note that the raffle state and players array have already been reset at this point — if you need stronger guarantees, consider a pull-payment pattern.

---

## Contract Details

### State Variables

| Variable | Type | Description |
|---|---|---|
| `i_subscriptionId` | `uint256` | Chainlink VRF subscription ID |
| `i_entranceFee` | `uint256` | Minimum ETH to enter the raffle |
| `i_keyHash` | `bytes32` | VRF gas lane key hash |
| `i_callbackGasLimit` | `uint32` | Gas limit for VRF callback |
| `s_players` | `address payable[]` | Current round participants |
| `s_recentWinner` | `address payable` | Most recent winner |
| `s_deadlineTimestamp` | `uint256` | Unix timestamp when next draw is eligible |
| `s_raffleState` | `raffleState` | Current state: Open or Calculating |
| `raffleInterval` | `uint256` | Duration of each raffle round in seconds |

### Events

| Event | Emitted When |
|---|---|
| `RaffleEnter(address indexed player)` | A player enters the raffle |
| `RequestedRaffleWinner(uint256 indexed requestId)` | VRF randomness is requested |
| `WinnerPicked(address indexed winner)` | Winner is selected and paid |

### Custom Errors

| Error | Triggered When |
|---|---|
| `Raffle__TicketHasLowerCap` | `msg.value` below entrance fee |
| `Raffle__RaffleNotOpen` | Entry attempted during Calculating state |
| `Raffle__UpkeepNotNeeded` | `performUpkeep` called when conditions not met |
| `Raffle__TransferFailed` | ETH transfer to winner fails |

### Getter Functions

| Function | Returns |
|---|---|
| `getNumberOfPlayers()` | Current player count |
| `getRecentWinner()` | Address of last winner |
| `getRaffleState()` | Current `raffleState` enum value |
| `getLastTimeStamp()` | `s_deadlineTimestamp` |

---

## Network Configuration

| Parameter | Sepolia | Anvil (Local) |
|---|---|---|
| VRF Coordinator | `0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B` | Mock (deployed by HelperConfig) |
| LINK Token | `0x779877A7B0D9E8603169DdbD7836e478b4624789` | Mock LinkToken |
| Gas Lane | `0x787d74ca...` | `0x787d74ca...` (ignored by mock) |
| Entrance Fee | 0.01 ETH | 0.01 ETH |
| Interval | 30 seconds | 30 seconds |
| Callback Gas Limit | 500,000 | 500,000 |

---

## Acknowledgements

Built following the [Cyfrin Updraft](https://updraft.cyfrin.io/) Smart Contract Development curriculum.

- [Chainlink VRF v2.5 Docs](https://docs.chain.link/vrf)
- [Chainlink Automation Docs](https://docs.chain.link/chainlink-automation)
- [Foundry Book](https://book.getfoundry.sh/)