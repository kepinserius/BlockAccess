// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title AccessControl
 * @dev Smart contract for managing physical access control using blockchain
 */
contract AccessControl {
    address public owner;
    
    struct AccessRight {
        string userId;
        string doorId;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }
    
    struct AccessLog {
        string userId;
        string doorId;
        uint256 timestamp;
        bool wasSuccessful;
    }
    
    // Mapping from accessId to AccessRight
    mapping(string => AccessRight) public accessRights;
    
    // Array of all access logs
    AccessLog[] public accessLogs;
    
    // Events
    event AccessGranted(string accessId, string userId, string doorId, uint256 startTime, uint256 endTime);
    event AccessRevoked(string accessId);
    event AccessAttempted(string userId, string doorId, uint256 timestamp, bool wasSuccessful);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Grant access to a user for a specific door
     * @param userId The ID of the user
     * @param doorId The ID of the door
     * @param startTime The start time of the access period (unix timestamp)
     * @param endTime The end time of the access period (unix timestamp)
     */
    function grantAccess(
        string memory userId,
        string memory doorId,
        uint256 startTime,
        uint256 endTime
    ) public onlyOwner {
        require(startTime < endTime, "Start time must be before end time");
        
        // Generate a unique access ID
        string memory accessId = generateAccessId(userId, doorId);
        
        // Create and store the access right
        accessRights[accessId] = AccessRight({
            userId: userId,
            doorId: doorId,
            startTime: startTime,
            endTime: endTime,
            isActive: true
        });
        
        emit AccessGranted(accessId, userId, doorId, startTime, endTime);
    }
    
    /**
     * @dev Revoke access for a specific access ID
     * @param accessId The ID of the access right to revoke
     */
    function revokeAccess(string memory accessId) public onlyOwner {
        require(accessRights[accessId].startTime != 0, "Access right does not exist");
        
        accessRights[accessId].isActive = false;
        
        emit AccessRevoked(accessId);
    }
    
    /**
     * @dev Check if a user has access to a specific door
     * @param userId The ID of the user
     * @param doorId The ID of the door
     * @return bool Whether the user has access to the door
     */
    function checkAccess(string memory userId, string memory doorId) public view returns (bool) {
        string memory accessId = generateAccessId(userId, doorId);
        AccessRight memory right = accessRights[accessId];
        
        if (right.startTime == 0) {
            return false; // Access right doesn't exist
        }
        
        uint256 currentTime = block.timestamp;
        return (
            right.isActive &&
            currentTime >= right.startTime &&
            currentTime <= right.endTime
        );
    }
    
    /**
     * @dev Log an access attempt
     * @param userId The ID of the user
     * @param doorId The ID of the door
     * @param timestamp The timestamp of the access attempt
     * @param success Whether the access attempt was successful
     */
    function logAccess(
        string memory userId,
        string memory doorId,
        uint256 timestamp,
        bool success
    ) public {
        accessLogs.push(AccessLog({
            userId: userId,
            doorId: doorId,
            timestamp: timestamp,
            wasSuccessful: success
        }));
        
        emit AccessAttempted(userId, doorId, timestamp, success);
    }
    
    /**
     * @dev Generate a unique access ID from user ID and door ID
     * @param userId The ID of the user
     * @param doorId The ID of the door
     * @return string The generated access ID
     */
    function generateAccessId(string memory userId, string memory doorId) internal pure returns (string memory) {
        return string(abi.encodePacked(userId, "-", doorId));
    }
    
    /**
     * @dev Get the total number of access logs
     * @return uint256 The number of access logs
     */
    function getAccessLogsCount() public view returns (uint256) {
        return accessLogs.length;
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
    }
}
