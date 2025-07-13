// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract DepositGame  {

    string public name;
    string public description;
    address public owner;
    uint256 public goal;
    uint256 public deadLine;
    uint256 public ownerPercent;
    bool private locked;
    address leader;
    uint256 maxDeposit;
    uint256 countDeposits;
   
    // Enum
    enum GameStatus {INACTIVE, ACTIVE, PAUSED, COMPLETED, TERMINATED, FINISHED}
    GameStatus gameStatus; 

    constructor(
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays,
        uint256 _ownerPercent
    ) {
        require(msg.sender != address(0), "Invalid address.");
        require(bytes(_name).length > 0, "Name can not be empry.");
        require(bytes(_description).length > 0, "Description can not be empty.");
        require(_goal > 0, "Goal must be positive.");
        require(_durationInDays > 0, "Duration must be positive.");
        require(_ownerPercent <= 100 || _ownerPercent > 0, "Percent must be between 0 - 100.");
        
        owner = msg.sender;
        gameStatus = GameStatus.INACTIVE;
        name = _name;
        description = _description;
        goal = _goal;
        ownerPercent = _ownerPercent;
        maxDeposit = 0;
        deadLine = block.timestamp + (_durationInDays * 1 days);
    }

    //Events
    event OwnerChange(string _message, address _oldOwner, address _newOwner, uint256 _time);
    event WithDrawValue(string _message, address indexed _owner, uint256 _value, uint256 _time);
    event Deposited(string _message, address _sender, uint256 _time); 
    event MyDepositWithdrawn(string _message, address _sender, uint256 _value, uint256 _time);
    event GameStarted(string _message, uint256 _goal, uint256 _time);
    event GamePaused(string _message, uint256 _time);
    event GameUnpaused(string _message, uint256 _time);
    event GameCompleted(string _message, address indexed  _winnder, uint256 _winAmount, uint256 _numberOfDeposits, uint256 _time);
    event GameTerminated(string _message, uint256 _time);

    struct Deposit {
        uint256 amount;
        uint256 timeStamp;
    }

    // mapping deposits user => Deposit
    mapping(address => Deposit) public deposits;
    //Array of participant 
    address[] public participants;

    
    modifier onlyOwner() {
        require(owner == msg.sender, "Must be owner.");
        _;
    }

    modifier shouldBePositive() {
        require(address(this).balance > 0, "There is no ether to withdraw.");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrancy detected");
        locked = true;
        _;
        locked = false;
    }

    modifier gameShouldBeActive() {
        require(gameStatus == GameStatus.ACTIVE, "Game is not active.");
        _;
    }

    modifier gameShouldbeInactive() {
        require(gameStatus == GameStatus.INACTIVE || gameStatus == GameStatus.COMPLETED, "Game is active or paused.");
        _;
    }

    modifier gameBalanceShouldBeEmpty() {
        require(address(this).balance == 0, "Contract balance should be empty");
        _;
    }

    modifier gameTerminated() {
        require(gameStatus == GameStatus.TERMINATED, "Game is not terminated");
        _;
    }

    modifier gameShouldBePaused() {
        require(gameStatus == GameStatus.PAUSED, "Game is not paused.");
        _;
    }

    modifier goalShouldBeReached() {
        require(address(this).balance >= goal, "Goal is not reached yet.");
        _;
    }

    modifier deadlineReached() {
        require(deadLine < block.timestamp, "Deadline is not over.");
        _;
    }

    modifier deadlineIsNotReached() {
        require(deadLine > block.timestamp, "Deadline is over.");
        _;
    }

    modifier goalOrDeadLineReached() {
        require(deadLine > block.timestamp || address(this).balance >= goal, " ");
        _;
    }

    function checkUpdateGame() internal {
        if (gameStatus == GameStatus.ACTIVE) {
            if (block.timestamp >= deadLine) {
                gameStatus = GameStatus.COMPLETED;
                emit GameCompleted("Game has ended", leader, address(this).balance, countDeposits, block.timestamp);
            }
        }
    }

    
    function startGame() public onlyOwner gameShouldbeInactive gameBalanceShouldBeEmpty {
        gameStatus = GameStatus.ACTIVE;
        emit GameStarted("Game has started!", goal, block.timestamp);
    }

    function pauseGame() public onlyOwner gameShouldBeActive {
        gameStatus = GameStatus.PAUSED;
        emit GamePaused("Game is paused.", block.timestamp);
    }

    function unPauseGame() public onlyOwner gameShouldBePaused {
        gameStatus = GameStatus.ACTIVE;
        emit GameUnpaused("Game is unpaused", block.timestamp);
        checkUpdateGame();
    }

    function terminateGame() public onlyOwner gameShouldBeActive {
        checkUpdateGame();
        if (gameStatus != GameStatus.COMPLETED){
             gameStatus = GameStatus.TERMINATED;
             emit GameTerminated("Game is terminated", block.timestamp);
        }
    }

    function makeDepsit() external payable gameShouldBeActive deadlineIsNotReached {
        require(msg.value > 0, "Invalid amount. Must be positive.");
        deposits[msg.sender] = Deposit({
            amount: deposits[msg.sender].amount + msg.value,
            timeStamp: block.timestamp 
        });

        //add address in array
        if (deposits[msg.sender].amount == 0) {
            participants.push(msg.sender);
            countDeposits++;
        }
        //Check game status
        checkUpdateGame();

        //emit
        emit Deposited("Deposit is done", msg.sender, block.timestamp);

        //Check maybe a new leader
        if (deposits[msg.sender].amount > maxDeposit) {
            maxDeposit = msg.value;
            leader = msg.sender;
        }  
    }

    receive() external payable gameShouldBeActive deadlineIsNotReached {
        deposits[msg.sender] = Deposit (
           { amount: deposits[msg.sender].amount + msg.value,
            timeStamp: block.timestamp
        });

        //Check maybe a new leader
        if (msg.value > maxDeposit) {
            maxDeposit = msg.value;
            leader = msg.sender;
        }
        
        //emit
        emit Deposited("ETH received via fallback", msg.sender, block.timestamp);
    }
   
    function refund() public nonReentrant gameTerminated {
        require(deposits[msg.sender].amount > 0, "Your deposit is 0. Should be positive to withdraw.");
        uint256 balance = deposits[msg.sender].amount;
        deposits[msg.sender].amount = 0;
        (bool success, ) = msg.sender.call{value: balance, gas: 10000}("");
        if(!success) {
            deposits[msg.sender].amount = balance;
            revert("Transfer failed");
        }
        emit MyDepositWithdrawn("My deposit is withdrawed", msg.sender, balance, block.timestamp);
    }

    function completeGame() public onlyOwner gameShouldBeActive nonReentrant goalShouldBeReached {
        gameStatus = GameStatus.COMPLETED;
        //percentages count
        uint256 balance = address(this).balance;
        uint256 amountToOwner = (balance * ownerPercent) / 100;
        uint256 amountToWinner = balance - amountToOwner;
        //call to owner
        (bool successOwner, ) = owner.call{value: amountToOwner, gas: 10000}("");
        require(successOwner, "Transfer failed");
        //call to winer 
        (bool successLeader, ) = leader.call{value: amountToWinner, gas: 10000}("");
        require(successLeader, "Transfer failed");
        //emit
        emit GameCompleted("Game has finished!", leader, address(this).balance, countDeposits, block.timestamp);
        gameStatus = GameStatus.FINISHED;
    }
    

    function getMyDeposit() public view returns (uint256) {
        return deposits[msg.sender].amount;
    }

    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function getGameStatus() public view returns (GameStatus) {
        return gameStatus;
    }


    function changeOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
        emit OwnerChange("Owner has changed.", owner, _newOwner, block.timestamp); 
    }

}