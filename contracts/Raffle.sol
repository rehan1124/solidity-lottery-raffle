// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

error Raffle__NotEnoughEthProvided();

/**
 * @title A contract to create a Lottery game
 * @author Syed Rehan
 * @notice In the Lottery game, people will contribute money and a randowm winner will be picked
 */
contract Raffle is VRFV2WrapperConsumerBase {
    // * State variable *
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    // * Events *
    event RaffleEnter(address indexed player, uint256 amountFunded);

    // * Constructor *
    constructor(
        address linkAddress,
        address wrapperAddress,
        uint256 _entranceFee
    ) VRFV2WrapperConsumerBase(linkAddress, wrapperAddress) {
        i_entranceFee = _entranceFee;
    }

    // * Functions *
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
     * @notice Function to pick a randowm winner
     */
    function requestRandomWinner() external payable {}

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {}

    // * Getters *
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
