pragma solidity ^0.4.25;

contract FlightSuretyData {

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    struct Airline {
        string name;
        bool registered;
        bool funded;
    }

    mapping (address => Airline) airlines;
    
    struct Passenger {
        // Mapping a flightId to an insurance amount
        mapping(bytes32 => uint) flightsInsured;
        bytes32[] historyInsuredFlights;
        uint credit;
    }
    
    mapping (address => Passenger) passengers;
    
    
    mapping (bytes32 => address[]) insurees;

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor (address _address, string _name) public {
        contractOwner = msg.sender;
        airlines[_address].name = _name;
        airlines[_address].registered = true;
    }

    // Tracking authorized contracts
    mapping (address => bool) authorizedContracts;


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
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier isCallerAuthorized() {
        require(authorizedContracts[msg.sender] == true, "This caller is not authorized.");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    // Manage authorized contracts by contract owner 
    function authorizeContract(address _address) public requireContractOwner requireIsOperational {
        authorizedContracts[_address] = true;
    }

    function deauthorizeContract(address _address) public requireContractOwner requireIsOperational {
        authorizedContracts[_address] = false;
    }


    // Get airline info
    function isAirlineRegistered(address _address) view external returns (bool) {
        return airlines[_address].registered;
    }
    
    function isAirlineFunded(address _address) view external returns (bool) {
        return airlines[_address].funded;
    }

    /*
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool) {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
    
    // AIRLINE FUNCTIONALITY +++++++++++++++++++++++++++++
    
    function registerAirline (address _address, string _name) external isCallerAuthorized requireIsOperational returns(bool) {
        airlines[_address].name = _name;
        airlines[_address].registered = true;
        return (airlines[_address].registered);
    }
    
    function fund(address _address) external isCallerAuthorized {
        airlines[_address].funded = true;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy (address _address, bytes32 _flightID, uint _value) external payable isCallerAuthorized requireIsOperational {
        passengers[_address].flightsInsured[_flightID] = _value;
        passengers[_address].historyInsuredFlights.push(_flightID);
        insurees[_flightID].push(_address);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees (bytes32 _flightID) external isCallerAuthorized requireIsOperational {
        for(uint i = 0; i < insurees[_flightID].length; i++) {
            address pAddress = insurees[_flightID][i];
            uint payout = (3 * passengers[pAddress].flightsInsured[_flightID]) / 2;
            passengers[pAddress].flightsInsured[_flightID] = 0;
            passengers[pAddress].credit += payout;
        }
        delete insurees[_flightID];
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay (address _address) external  isCallerAuthorized requireIsOperational {
        passengers[_address].credit = 0;
    }
    
    function checkFunds (address _address) view external isCallerAuthorized requireIsOperational returns (uint) {
        return passengers[_address].credit;
    }
    

    function getFlightKey (address airline, string memory flight, uint256 timestamp) view internal isCallerAuthorized requireIsOperational returns(bytes32)  {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        
    }


}

