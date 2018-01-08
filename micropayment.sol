pragma solidity ^0.4.11;

contract Micropayment{
    uint public value;
    uint public feePerMinute; // the fee is counted by wei
    uint public startTime;
    uint public endTime;
    address public serviceProvider;
    address public user;

    function Micropayment(uint fee) public {
        require(fee > 0);
        serviceProvider = msg.sender;
        feePerMinute = fee;
    }
    
    modifier condition(bool _condition) {
        require(_condition);
        _;
    }

    modifier onlyProvider() {
        require(msg.sender == serviceProvider);
        _;
    }

    modifier onlyUser() {
        require(msg.sender == user);
        _;
    }

    event ServiceStarted();
    event ServiceEnded();
    event ForceEnd();

    /// Force end the Micropayment (the service provider),
    /// and get paid,
    /// when user has run out his time.
    function forcePay()
        public
        onlyProvider
    {
        require(now >= endTime);
        ForceEnd();
        serviceProvider.transfer(this.balance);
    }

    /// Start service as user.
    /// Give a expected service time.
    function startService(uint eT) // minutes
        public
        condition(msg.value >= feePerMinute * eT)
        payable
    {
        ServiceStarted();
        user = msg.sender;
        startTime = now;
        endTime = now + eT * 1 minutes;
        value = msg.value;
    }

    /// End the service (the user).
    /// Pay bill to service provider according to using time.
    function endService()
        public
        onlyUser
    {
        require(now < endTime);
        uint usingTime = (now - startTime) / 60 + 1;
        uint bill = usingTime * feePerMinute;
        user.transfer(value - bill);
        serviceProvider.transfer(this.balance);
        ServiceEnded();
    }
}