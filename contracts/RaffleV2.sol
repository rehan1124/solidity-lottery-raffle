// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

error Raffle__NotEnoughEthProvided();
error Raffle__RequestNotFound();

/**
 * @title A contract to create a Lottery game
 * @author Syed Rehan
 * @notice In the Lottery game, people will contribute money and a randowm winner will be picked
 */
contract Raffle is VRFV2WrapperConsumerBase, ConfirmedOwner {
    // --- Constants ---
    uint32 private constant CALLBACK_GAS_LIMIT = 100000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    address private constant VRF_LINK_ADDRESS =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address private constant VRF_WRAPPER_ADDRESS =
        0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

    // --- Structs and Mappings ---
    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests;

    // --- State variables ---
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    // Past requests Id.
    uint256[] public s_requestIds;
    uint256 public s_lastRequestId;

    // --- Events ---
    event RaffleEnter(address indexed player, uint256 amountFunded);
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    // --- Constructor ---
    constructor(
        uint256 _entranceFee
    )
        VRFV2WrapperConsumerBase(VRF_LINK_ADDRESS, VRF_WRAPPER_ADDRESS)
        ConfirmedOwner(msg.sender)
    {
        i_entranceFee = _entranceFee;
    }

    // --- Functions ---
    /**
     * @notice Takes your specified parameters and submits the request to the VRF v2 Wrapper contract.
     */
    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        requestId = requestRandomness(
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            NUM_WORDS
        );
        s_requests[requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(CALLBACK_GAS_LIMIT),
            fulfilled: false,
            randomWords: new uint256[](0)
        });

        s_requestIds.push(requestId);
        s_lastRequestId = requestId;
        emit RequestSent(requestId, NUM_WORDS);
        return requestId;
    }

    /**
     * @notice Retrive request details for a given _requestId.
     * @param _requestId Request ID
     * @return paid How much paid in LINK tokens
     * @return fulfilled Whether request has been fulfilled
     * @return randomWords Randowm number received
     */
    function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
    {
        if (s_requests[_requestId].paid < 0) {
            revert Raffle__RequestNotFound();
        }
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }

    /**
     * @notice Function to pick a randowm winner
     */
    function requestRandomWinner() external payable {}

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
     * @notice Receives random values and stores them with your contract.
     * @param _requestId Request ID
     * @param _randomWords Random words from Chainlink VRF
     */
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        if (s_requests[_requestId].paid < 0) {
            revert Raffle__RequestNotFound();
        }
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].paid
        );
    }

    // --- Getters ---
    /**
     * @notice Getter function to retrieve entrance fee
     * @return Returns entrance fee for Lottery game
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    /**
     * @notice Getter function to retrieve player at given index
     * @param _index A uint256 parameter for player index
     * @return Returns player located at given _index parameter
     */
    function getPlayers(uint256 _index) public view returns (address) {
        return s_players[_index];
    }
}
