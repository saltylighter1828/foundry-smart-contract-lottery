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

import {
    VRFConsumerBaseV2Plus
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/** @title Sample Raffle Contract
 *  @author Antony Cheng
 *  @notice This contract is for creating a sample raffle
 *  @dev This implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* errors */
    error Raffle__SendMoreToEnterRaffle(); //have Raffle__ before error name to avoid confusion with other contracts
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    /* Type Declarations */
    enum RaffleState {
        //enter enum "RaffleState" into state variable
        //instead of using booleans, use enums to create new states (types) because during block confirmations we don't want new entries
        OPEN, //each state can be converted to intergers - e.g. OPEN = 0
        CALCULATING // CALCULATING = 1
    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable I_ENTRANCE_FEE;
    uint256 private immutable I_INTERVAL; // @dev The duration of each raffle round in seconds
    bytes32 private immutable I_KEYHASH;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint32 private immutable I_CALLBACK_GAS_LIMIT;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState; // start as open

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    //If the inherited vrf contract has a constructor, we need to also pass it in our own constructor.
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane, // keyHash
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTRANCE_FEE = entranceFee;
        I_INTERVAL = interval;
        I_KEYHASH = gasLane;
        I_SUBSCRIPTION_ID = subscriptionId;
        I_CALLBACK_GAS_LIMIT = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; //which is also the same as RaffleState(0) - defaulting to be OPEN - code is more readable this way
    }
    function enterRaffle() external payable {
        //require(msg.value >= I_ENTRANCE_FEE, Raffle__SendMoreToEnterRaffle); only works with specific version and compiler
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        //1.everytime storage updates, you want to emit an event
        //2. why? makes migration easier, and you can track contract activity off-chain
        //3. Makes front end 'indexing' easier
        emit RaffleEntered(msg.sender);
    }
    //When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true.
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is in an "open" state.
     * 3. The contract has ETH.
     * 4. Implicitly, your subscription is funded with LINK.
     * @param - ignored
     * @return upkeepNeeded - true if it is time to start the lottery
     * @return - ignored
     */
    function checkUpkeep(
        bytes memory /* checkData - if you want to customize, before memory was calldata because more gas efficient but doesn't work with the performUpkeep function */
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */ //bool upkeepNeeded in paramater defaults to false
        )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            I_INTERVAL);
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    //1. Get a random number
    //2. Use that number to pick a random winner
    //3. Be automatically triggered
    function performUpkeep(bytes calldata /* performData */) external {
        // check to see if enough time has passed

        (bool upkeepNeeded, ) = checkUpkeep("");
        /*swap the bytes calldata, from calldata to memory in the checkupKeep function to fix error (""). becuase called data can only be generated from user's transcation but not from smart contract */
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING; //change state to calculating during block confirmations

        //if enough time has passed, get a random number 2.5
        // 1. Request RNG from Chainlink VRFv2.5
        // 2. Get RNG give us a random number (callback function)
        // requestId = s_vrfCoordinator.requestRandomWords(

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: I_KEYHASH, //Gas Lane = Gas price
                subId: I_SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: I_CALLBACK_GAS_LIMIT, //how much your willing to pay for callback gas
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId); //This is redundant as the vrfCoordinator already emits this event. However, it is easier to test.
    }
    // CEI: Checks, Effects, Interactions Pattern - one of the most important security patterns
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal virtual override {
        //Checks
        //1. Conditionals like (Require)
        //2. Important to do checks first to save gas if conditions not met

        //s_player = 10
        //rng = 12  - random number was 12
        //12 % 10 = 2<= index of winner
        //this random number is huge 123456789456453121321 %10 = 1

        //Effects (Internal Contract State changes)

        uint256 indexOfWinner = randomWords[0] % s_players.length; //randomword index 0 because we only requested 1 word
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner; //store recent winner as a state variable to know who won clearly
        s_raffleState = RaffleState.OPEN; //reset raffle state after winner is picked
        s_players = new address payable[](0); //reset all players to make a new lottery
        s_lastTimeStamp = block.timestamp; //reset last timestamp
        emit WinnerPicked(s_recentWinner); //This was actually below bool success but moved up for CEI pattern (because emit is an internal state change)

        //Interactions (External Contract Interactions)
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed(); //custom error gas efficient - at the top
        }
    }

    /** Getter Function */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
