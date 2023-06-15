// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

error Raffle__NotEnoughEthProvided();
error Raffle__RequestNotFound();
error Raffle_TransferFailed();

// https://docs.chain.link/vrf/v2/subscription

/**
 * @title A contract to create a Lottery game
 * @author Syed Rehan
 * @notice In the Lottery game, people will contribute money and a randowm winner will be picked
 */
contract Raffle is VRFConsumerBaseV2, ConfirmedOwner {
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
    // --- Structs and Mappings ---
    // ----------------------------
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    // -----------------------
    // --- State variables ---
    // -----------------------
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    address private s_recentWinner;

    // Past requests Id.
    uint256[] public s_requestIds;
    uint256 public s_lastRequestId;

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
        uint256 _entranceFee
    ) VRFConsumerBaseV2(VRF_COORDINATOR) ConfirmedOwner(msg.sender) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(VRF_COORDINATOR);
        i_entranceFee = _entranceFee;
    }

    // -----------------
    // --- Functions ---
    // -----------------
    /**
     * @notice Function to enter in Lottery game
     */
    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthProvided();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender, msg.value);
    }

    /**
     * @notice Function to pick a random winner
     */
    function requestRandomWinner() external payable onlyOwner {
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
     * @notice Receives random values and stores them with your contract.
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
            revert Raffle_TransferFailed();
        }

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
}
