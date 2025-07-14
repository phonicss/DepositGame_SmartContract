// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// importing DepositGame
import "./DepositGame.sol"; 


contract DepositGameFacctory {

    //Array to keep game addresses
    address[] public games;

    //Map to keep games to owners
    mapping(address => address) public gameToOwner; 

    //Map to keep owner to array of games
    mapping(address => address[]) public ownerToGame;

    //Event for new game creatin
    event NewGameCreated(string _message, address _gameAddress, address _owner, uint256 _creationTime);

    //Function to create a game
    function createGame(
        string memory _name,
        string memory _description,
        uint256 _durationInDays,
        uint256 _ownerPercent,
        uint256 _depositLimit
    ) public returns(address) {
        DepositGame newGame = new DepositGame(
            _name,
            _description,
            _durationInDays,
            _ownerPercent,
            _depositLimit
        );

        //add game address to array
        games.push(address(newGame));

        //add owner address to map
        gameToOwner[address(newGame)] = msg.sender;

        //add game addres to owner's games array
        ownerToGame[msg.sender].push(address(newGame));

        //Emit game creatin event
        emit NewGameCreated("New game has been vreated.", address(newGame), msg.sender, block.timestamp);

        return address(newGame);
    }

    //get amount of games in array
    function getGamesCount() public view returns (uint256) {
        return games.length;
    }

    //get all games in array
    function getAllGames() public view returns (address[] memory) {
        return games;
    }

    //get all games of owner
    function getAllGamesOfOwner(address _owner) public view returns (address[] memory) {
        return ownerToGame[_owner];
    }

    //check if the address is the owner of game
    function checkIfOwner(address _gameAddress, address _owner) public view returns(bool) {
        return gameToOwner[_gameAddress] == _owner;
    }



}