// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

error Raffle__NotEnoughEthProvided();

contract Raffle {
    // State variable
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    constructor(uint256 _entranceFee) {
        i_entranceFee = _entranceFee;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthProvided();
        }
        s_players.push(payable(msg.sender));
    }

    function pickRandomWinner() public payable {}

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 _index) public view returns (address) {
        return s_players[_index];
    }
}
