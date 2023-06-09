// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

error Raffle__NotEnoughEthProvided();

/**
 * @title A contract to create a Lottery game
 * @author Syed Rehan
 * @notice In the Lottery game, people will contribute money and a randowm winner will be picked
 */
contract Raffle {
    // * State variable *
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    // * Events *
    event RaffleEnter (address indexed player)

    // * Constructor *
    constructor(uint256 _entranceFee) {
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
        emit RaffleEnter(msg.sender);
    }

    /**
     * @notice Function to pick a randowm winner
     */
    function pickRandomWinner() public payable {}

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
