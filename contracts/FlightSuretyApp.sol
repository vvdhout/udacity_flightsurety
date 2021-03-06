pragma solidity ^0.4.25;

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData dataContract;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    
    mapping(bytes32 => uint8[]) statusCodes;

 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
         // Modify to call data contract's status
        require(dataContract.isOperational(), "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier isAirlineRegistered() {
        require(dataContract.isAirlineRegistered(msg.sender) == true, "Airline is not registered yet.");
        _;
    }
    
    modifier isAirlineFunded() {
        require(dataContract.isAirlineFunded(msg.sender) == true, "Airline is not funded yet.");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address _dataContract) public {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(_dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() view public returns(bool) {
        dataContract.isOperational();
    }

    function setOperatingStatus(bool _mode) public requireContractOwner {
        dataContract.setOperatingStatus(_mode);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline (address _address, string _name) public isAirlineRegistered requireIsOperational() returns(bool success){
        require(dataContract.isAirlineRegistered(_address) == false, "Airline is already registered.");
        return dataContract.registerAirline(_address, _name, msg.sender);
    }

    function checkRegistrationStatus(address _address) view public returns(bool) {
        return dataContract.isAirlineRegistered(_address);
    }
    
    function fund() public payable isAirlineRegistered {
        require(msg.value >= 10 ether, "Payment is not 10 ether or heigher");
        dataContract.fund(msg.sender);
    }
    
    
    function buyInsurance(address airline, string flight, uint256 timestamp) public payable requireIsOperational() {
        bytes32 _flightID = getFlightKey(airline, flight, timestamp);
        require(flights[_flightID].isRegistered, "Flight does not exist.");
        require(msg.value <= 1 ether, "You can only insure up to 1 ETH of value.");
        dataContract.buy(msg.sender, _flightID, msg.value);
    }
    
    function checkFunds() view public requireIsOperational returns (uint) {
        return dataContract.checkFunds(msg.sender);
    }
    
    function withdrawFunds() public requireIsOperational {
        uint totalCredit = dataContract.checkFunds(msg.sender);
        dataContract.pay(msg.sender);
        msg.sender.transfer(totalCredit);
    }
    
    function createFlight(string memory flight, uint256 timestamp) public isAirlineRegistered isAirlineFunded requireIsOperational returns (bytes32) {
        bytes32 _flightID = getFlightKey(msg.sender, flight, timestamp);
        flights[_flightID].isRegistered = true; 
        flights[_flightID].updatedTimestamp = timestamp; 
        flights[_flightID].airline = msg.sender; 
        return _flightID;
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus (address airline, string memory flight, uint256 timestamp, uint8 statusCode) internal requireIsOperational() {
        bytes32 _flightID = getFlightKey(airline, flight, timestamp);
        flights[_flightID].statusCode = statusCode;
        flights[_flightID].updatedTimestamp = timestamp;
        if(statusCode == 20) {
            dataContract.creditInsurees(_flightID);
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus (address airline, string flight, uint256 timestamp) external requireIsOperational() {
        bytes32 _flightID = getFlightKey(airline, flight, timestamp);
        require(flights[_flightID].isRegistered, "Flight does not exist.");
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

contract FlightSuretyData {

/**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool);


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode) external;

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline (address, string, address) external returns (bool);


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy (address _address, bytes32 _flightID, uint _value) external payable;

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees (bytes32) external;
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay (address) external;

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address) public payable;

    function getFlightKey (address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32);

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable;
    
    function isAirlineRegistered(address _address) view external returns(bool);
    
    function isAirlineFunded(address _address) view external returns(bool);
    
    function checkFunds (address _address) view external returns (uint);
    
    function alreadyCalled(address _toRegister, address _caller) view external returns (bool);

}