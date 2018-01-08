pragma solidity ^0.4.11;

contract Channel {

    address public moneyProvider;
    address public worker;
    uint public startTime;
    uint public timeOut;
    mapping (bytes32 => address) signatures;

    function Channel(address to, uint t) payable {
        worker = to;
        moneyProvider = msg.sender;
        startTime = now;
        timeOut = t;
    }
    // this function can be both called by moneyProvider and worker
    // we use sha3 as hash function in this case
    function CloseChannel(bytes32 h, uint8 v, bytes32 r, bytes32 s, uint value){
        address signer;
        bytes32 proof;
        // get signer from signature
        signer = ecrecover(h, v, r, s);
        // signature is invalid, throw
        require (signer == moneyProvider || signer == worker);
        proof = sha3(this, value);
        // signature also needs to match the data provided
        require (proof == h);
        if (signatures[proof] == 0)
            signatures[proof] = signer;
        else if (signatures[proof] != signer){
            // channel completed, both signatures provided
            worker.transfer(value);
            selfdestruct(moneyProvider);
        }
    }
    // this function is called by moneyProvider, when woker is malicious
    function forcePay(){
        require (startTime + timeOut > now && msg.sender == moneyProvider);
        selfdestruct(moneyProvider);
    }
}