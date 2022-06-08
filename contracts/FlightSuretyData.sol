pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) private authorizedContracts;

    struct Airline {
        address airlineAddress;
        bool isRegistered;
        string name;
        bool funded;
        uint256 votes;
    }

    mapping(address => Airline) private airlines;
    address[] registeredAirlines = new address[](0);
    mapping(address => address[]) public registeredAirlineMultiCalls;


    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        string flight;
    }

    mapping(bytes32 => Flight) private flights;
    bytes32[] registeredFlights = new bytes32[](0);

    struct Insurance {
        address passenger;
        uint256 cost;
        uint256 payoutAmount;
        bool isCredited;
    }
    mapping (bytes32 => Insurance[]) insuredPassengersOnFlight;
    mapping (address => uint256) public creditedPassengers; //credits for insurance
    mapping (address => bool) private whitelistedAddresses;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(string name, address addr);
    event InsurancePurchased(address airline, string flight, uint256 timestamp, address passenger, uint256 amount);
    event PassengerCredited(address passenger, uint256 amount);
    event CreditsWithdrawn(uint256 amount, address passenger);
    event FlightRegistered(bytes32 flightKey, address airlineAddress, string flight, uint256 updatedTimestamp);
    event FlightStatusUpdated(address airline, string flight, uint256 timestamp, uint8 statusCode);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(string airlineName, address airlineAddress) public {
        contractOwner = msg.sender;
        airlines[airlineAddress] = Airline({
            airlineAddress: airlineAddress,
            isRegistered: true,
            name: airlineName,
            funded: false,
            votes: 0
        });
        registeredAirlines.push(airlineAddress);
    }

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

    modifier airlineNotRegistered(address airline) {
        require(!airlines[airline].isRegistered, "Airline already registered");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    modifier tooMuchInsurance() {
        require(msg.value < 5 ether, "Payment exceeds insurance limit");
        _;
    }

    modifier messageValueGreaterThanZero(){
        require(msg.value > 0);
        _;
    }

    modifier passengerHasCredits(address passenger){
        require(creditedPassengers[passenger] > 0);
        _;
    }

    modifier requireWhitelistedAddress(){
        require(whitelistedAddresses[msg.sender] = true || msg.sender == contractOwner, "Unauthorized action");
        _;
    }

    modifier hasntAlreadyVoted(address pendingAirline){
        address[] memory voters = registeredAirlineMultiCalls[pendingAirline];
        bool found = false;
        for(uint i; i<voters.length; i++) {
            if(msg.sender == voters[i]){
                found = true;
            }
        }
        require(found == false);
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns(bool){
        return operational;
    }

    function setOperatingStatus(bool mode) requireWhitelistedAddress public returns (bool) {
        operational = mode;
        return operational;
    }

    function addWhitelistAddress(address addressToAdd) requireContractOwner public {
        whitelistedAddresses[addressToAdd] = true;
    }

    function removeWhitelistAddress(address addressToRemove) requireContractOwner public {
        whitelistedAddresses[addressToRemove] = false;
    }

    function getRegisteredAirlines() requireIsOperational external view returns(address[]){
        return registeredAirlines;
    }

    function isAirlineRegistered(address airlineAddress) requireIsOperational external view returns(bool) {
        return airlines[airlineAddress].isRegistered;
    }

    function authorizeCaller (address appContract) public {
        authorizedContracts[appContract] = true;
    }

    function getRegisteredAirlineMultiCallsArray(address airline) public view returns(address[]){
        return registeredAirlineMultiCalls[airline];
    }

    function getPassengerCredit(address passenger) view returns(uint256) {
        return creditedPassengers[passenger];
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    */
    function registerAirline(string airlineName, address airlineAddress)
    requireIsOperational airlineNotRegistered(airlineAddress) validAddress(msg.sender) external returns (bool registered){
        airlines[airlineAddress] = Airline({
            airlineAddress: airlineAddress,
            isRegistered: true,
            name: airlineName,
            funded: true,
            votes: 0
        });
        registeredAirlines.push(airlineAddress);
        registeredAirlineMultiCalls[airlineAddress];

        emit AirlineRegistered(airlineName, airlineAddress);
        return true;
    }

    function registerFlight(address airlineAddress, uint256 updatedTimestamp, string flight) requireIsOperational public {
        require(airlineAddress == msg.sender, "Airlines can only register flights for themselves");
        bytes32 flightKey = getFlightKey(airlineAddress, flight, updatedTimestamp);
        require(!flights[flightKey].isRegistered, "Flight already registered");
        flights[flightKey] = Flight({
            isRegistered: true,
            statusCode: 0,
            updatedTimestamp: updatedTimestamp,
            airline: airlineAddress,
            flight: flight
        });
        registeredFlights.push(flightKey);

        emit FlightRegistered(flightKey, airlineAddress, flight, updatedTimestamp);
    }

    function processFlightStatus(address airline, string flight, uint256 timestamp, uint8 statusCode) external requireIsOperational {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        if (flights[flightKey].statusCode == 0) {
            flights[flightKey].statusCode = statusCode;
            if(statusCode == 20) {
                this.creditPassengers(airline, flight, timestamp);
            }
        }

        emit FlightStatusUpdated(airline, flight, timestamp, statusCode);
    }

    /**
     * @dev Buy insurance for a flight
    *
    */
    function buy(string flight, uint256 timestamp, address airline, address passenger, uint256 value)
    requireIsOperational messageValueGreaterThanZero tooMuchInsurance external payable {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        uint256 payoutAmount = value.mul(2); //payout is always 2x more

        insuredPassengersOnFlight[flightKey].push(Insurance({
            passenger: passenger,
            cost: value,
            payoutAmount: payoutAmount,
            isCredited: false
        }));

        emit InsurancePurchased(airline, flight, timestamp, passenger, payoutAmount);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditPassengers(address airlineAddress, string flight, uint256 timestamp) external {
        bytes32 flightKey = getFlightKey(airlineAddress, flight, timestamp);

        for(uint256 i; i<insuredPassengersOnFlight[flightKey].length; i++){
            Insurance storage insurance = insuredPassengersOnFlight[flightKey][i];
            if(!insurance.isCredited){
                insurance.isCredited = true;
                creditedPassengers[insurance.passenger] += insurance.payoutAmount;
            }
            emit PassengerCredited(insurance.passenger, insurance.payoutAmount);
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address passenger) requireIsOperational passengerHasCredits(passenger) external {
        uint256 credits = creditedPassengers[passenger];
        creditedPassengers[passenger] = 0;
        passenger.transfer(credits);
        emit CreditsWithdrawn(credits, passenger);
    }

    function vote(address airlineAddress) hasntAlreadyVoted(msg.sender) external {
        airlines[airlineAddress].votes++;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund() public requireIsOperational payable {

    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund();
    }


}

