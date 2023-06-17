// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

error Raffle__NotEnoughEthProvided();
error Raffle__RequestNotFound();
error Raffle__TransferFailed();
error Raffle__LotteryIsNotOpen();
error Raffle__UpkeepNotNeeded(
    uint256 raffleState,
    uint256 playersLength,
    uint256 balance
);

// https://docs.chain.link/vrf/v2/subscription

/**
 * @title A contract to create a Lottery game
 * @author Syed Rehan
 * @notice In the Lottery game, people will contribute money and a randowm winner will be picked based on interval set.
 */
contract Raffle is
    AutomationCompatibleInterface,
    VRFConsumerBaseV2,
    ConfirmedOwner
{
    // -----------------
    // --- Constants ---
    // -----------------
    uint32 private constant CALLBACK_GAS_LIMIT = 2500000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    address private constant VRF_LINK_ADDRESS =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address private constant VRF_WRAPPER_ADDRESS =
        0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    address private constant VRF_COORDINATOR =
        0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    uint64 private constant SUB_ID = 2837;
    bytes32 private constant KEY_HASH =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // ----------------------------
    // --- Structs, Mappings, Enum ---
    // ----------------------------
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests;

    // -----------------------
    // --- State variables ---
    // -----------------------
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    address private s_recentWinner;

    // Past requests Id.
    uint256[] public s_requestIds;
    uint256 public s_lastRequestId;

    // Chainlink automation/keepers variables
    uint256 public immutable i_interval;
    uint256 private s_lastTimeStamp;

    // Raffle state
    RaffleState private s_raffleState;

    // --------------
    // --- Events ---
    // --------------
    event RaffleEnter(address indexed player, uint256 amountFunded);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RequestSent(uint256 indexed requestId, uint32 numWords);
    event RequestFulfilled(uint256 indexed requestId, uint256[] randomWords);
    event WinnerPicked(address indexed winner);

    // -------------------
    // --- Constructor ---
    // -------------------
    constructor(
        uint256 _entranceFee,
        uint256 _updateInterval
    ) VRFConsumerBaseV2(VRF_COORDINATOR) ConfirmedOwner(msg.sender) {
        // VRF
        i_vrfCoordinator = VRFCoordinatorV2Interface(VRF_COORDINATOR);
        i_entranceFee = _entranceFee;

        // Chainlink automation/keepers
        i_interval = _updateInterval;
        s_lastTimeStamp = block.timestamp;

        // Lottery or Raffle state
        s_raffleState = RaffleState.OPEN;
    }

    // -----------------
    // --- Functions ---
    // -----------------
    /**
    @dev Chailink automation calls this function off-chain to check for conditions and return True
    */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (isOpen && hasTimePassed && hasPlayers && hasBalance);
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    /**
     * @notice Function to enter in Lottery game
     */
    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthProvided();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__LotteryIsNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender, msg.value);
    }

    /**
     * @notice Function to pick a random winner
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        // Check if Upkeep is needed
        (bool upkeepNeeded, ) = this.checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                uint256(s_raffleState),
                s_players.length,
                address(this).balance
            );
        }

        // If Upkeep needed, execute steps to do so.
        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            KEY_HASH,
            SUB_ID,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        s_requestIds.push(requestId);
        s_lastRequestId = requestId;
        emit RequestSent(requestId, NUM_WORDS);
    }

    /**
     * @notice Receives random values from VRF service and stores them with your contract automatically.
               Since this function call is executed automatically, winner is also picked.
     * @param _requestId Request ID
     * @param _randomWords Random words from Chainlink VRF
     */
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        if (!s_requests[_requestId].exists) {
            revert Raffle__RequestNotFound();
        }
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        (bool success, ) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__TransferFailed();
        }

        s_players = new address payable[](0);

        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(winner);
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        if (!s_requests[_requestId].exists) {
            revert Raffle__RequestNotFound();
        }
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    // ---------------
    // --- Getters ---
    // ---------------
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 _index) public view returns (address) {
        return s_players[_index];
    }

    function getAllPlayers() public view returns (address payable[] memory) {
        return s_players;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLotteryStartTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
}
