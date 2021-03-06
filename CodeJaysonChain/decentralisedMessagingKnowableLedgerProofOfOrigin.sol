pragma solidity ^0.4.18;

//For terminology purposes, the user that creates the contract is called the owner and the users using the contract as a messaging system are called accounts.
contract DecentralisedMessagingKnowableLedgerProofOfOrigin {
    //DM Features (Decentralised Messaging):
    //Everyone that wants to use this contract must generate a private and public key according to some asymmetrical cryptograhy method, for example RSA.
    //Then he needs to call initAccount and publish his public key to the blockchain.
    //Using the blockchain we can now solve decentralised messaging as follows. Account A can send a message to account B using the following way:
    //1. Account A encrypts his message with a symmetric key, which is equal to the hash of the length of the messageTable.
    //This has to be a symmetric encryption scheme, where every possible hash can be used as a symmetric key.
    //For example: The length of the message table could be hashed using SHA-256. Then you use this 256 hash as a symmetric key for AES-256.
    //2. On top of that, account A then encrypts the message with the public key of account B.
    //3. Now account A writes to the messageTable, but this only works if the messageTable didn't in change in length. This can be achieved, by using the following method defined below:
    // function sendMessage(string _encryptedTo, string _encryptedMessage, uint256 _expectedLengthOfMessageTable);
    //If the length changed, the transaction will simply revert and account A has to retry (start at step 1 again).
    //4. Account B then decrypts every message he hasn't read yet with his private key. After this decryption he also decrypts the message with the hash of the messageTable index.
    //5. If the decrypted receiver address is equal to the address of account B, then B knows the message was intended for him. He also knows that the message is from A (proof of origin)
    //by checking MessageTableEntry.sender
    //6. He then only needs to decrypt the message with the same decryption scheme (first RSA, then AES-256 of the SHA-256 hash of the message index)

    //Additionally account B knows when the transaction of the message was mined. Therefore he has an upper bound to when the message was sent.
    //Also the blockchain hinders spamming to the messageTable, since every add costs gas. Reads don't cost anything, so having a large messageTable wouldn't even charge gas, but would only cost more local computational time.

    //DMK Features (Decentralised Messaging Knowable):
    //The decentralisedMessagingKnowable contract adds the additional functionality that we can tell the other party that we read the message.
    //This is done by adding a new information to AccountData, namely mostRecentlyReadIndex, which can be updated by the reader.
    //If the reader sets mostRecentlyReadIndex, then he not only shows that he has read that particular message, but also every message, which came before that message.
    //This system basically works the same way WhatsApps doubleflag system works, you can either tell everyone when you received the messages or nobody.
    //You cannot receive some messages and not receive some previous ones.
    //If you only want to notify certain people that you read their messages, you can always create a new account for these specific people. Then you can tell some people you read the message and don't tell others.
    //Additionally, this system also enables a way to remember, what the last message was, that you read from the messageTable.
    //This way, if you read the messageTable from latest to most recent, you can just continue reading messages where you left off.

    //DMKL Features (Decentralised Messaging Knowable Ledger):
    //This contract version adds one ledger to every account. Every account can add anything he wants to his own ledger (and nobody can add anything to somoene elses ledger).
    //Every ledger table entry should be encrypted with a symmetric key in the following way:
    //The symmetric key is generated by the following hash procedure:
    //hash(hash (the ledger table length) + hash(the private key)).
    //For example, you can use SHA-256 as a hashing function and then use AES-256 and use the calculated hash as the symmetric key.
    //Notice, that the ledger table length can change, if the the account adds multiple things to his own ledger at the same time.
    //Therefore we have to give the expected ledger table length to the addLedgerTableEntry function, similarily to how we added the message table length in the DM protocol. 
    //This system can now be used to  broadcast messages to multiple trusted people using the following broadcast protocol:
    //1. Write your message to your own ledger encrypted with the symmetric key of the ledger entry.
    //2. Send a message to everyone using the DM (decentralised messaging system) containing the symmetric key of the ledger entry and the ledger entry index.
    //3. Now everyone can read the ledger table entry that has the symmetric key. 
    //This system can work similairly to Email. It can either be used as a CC broadcast or BCC broadcast (blind).
    //For the CC system, you additionally have to do the following steps:
    //4. You simply add the address of each receiving account (which is in the CC) into the message.
    //5. The parties themselves can then send the symmetric keys to each other to make sure that all of them received the symmetric key (so you can't cheat and tell someone that you wrote this mail to someone who didn't actually receive).
    //You can of course choose, who you want to add to the CC and who you want to add to the BCC, similairly to Email.

    //Use DMKL for proof-of-path (DMKLPoP):
    //This new contract, is exactly the same as the DMKL, it only adds the concept of proof of origin as a new protocol, but it doesn't change in the contract.
    //DMKLPoO adds trustless forwardability of messages. 
    //Using this system account A can send a forwardable message to account B and now account B can show account C that he received this message from account A in a trustless way (Forwarding).
    //This is done by the following way:
    //1. Account A stores the message and the address of B on its own ledger encrypted with the symmetric key of the ledger entry index.
    //2. Account A then sends the symmetric key and the ledger entry index to account B using the DM system in a safe way.
    //3. Account B now reads the message from A by decrypting it with the received symmetric key.
    //4. Account B now stores this symmetric key (and its respective ledger entry index) in its own ledger and encrypts it with account B's symmetric key
    // (if he wants to make his message forwardable again, he simply would need to store the address of C in the ledger entry as well).
    //5. Account B then sends his symmetric key (and the ledger entry index of B's ledger) to account C.
    //6. Now account C can follow the chain of B's ledger entry to A's ledger entry and he knows, that A sent the message to B.

    //These forwardable messages can also be broadcasted to multiple accounts, simply write multiple receiver addresses to the ledger. 
    //Again similairly to how we implemented broadcasted messages in DMKL, we can have CC and BCC forwardable broadcast messages.

    modifier accountInitialized(address _address) {
        require(accountDatas[_address].account != 0);
        _;
    }

    struct LedgerTableEntry {
        string symmetricallyEncryptedMessage;
    }

    struct AccountData {
        address account;
        uint256 publicKey;
        uint256 mostRecentlyReadIndex;

        uint256 ledgerTableLength;
        mapping(uint256 => LedgerTableEntry) ledgerTable;
    }
    mapping(address => AccountData) accountDatas;


    function initAccount (uint256 _publicKey) public {
        require(accountDatas[msg.sender].account == 0); //checks if the account was never initialised before.
        AccountData memory accountData;
        accountData.account = msg.sender;
        accountData.publicKey = _publicKey;
        accountData.mostRecentlyReadIndex = messageTable.length - 1;
        accountData.ledgerTableLength = 0;
        accountDatas[msg.sender] = accountData;
    }

    //According to the protocol
    function addLedgerTableEntry(string _symmetricallyEncryptedMessage, uint256 _expectedLedgerTableLength) public accountInitialized(msg.sender) {
        require(accountDatas[msg.sender].ledgerTableLength == _expectedLedgerTableLength);
        LedgerTableEntry memory ledgerTableEntry;
        ledgerTableEntry.symmetricallyEncryptedMessage = _symmetricallyEncryptedMessage;
        accountDatas[msg.sender].ledgerTable[accountDatas[msg.sender].ledgerTableLength] = ledgerTableEntry;
        accountDatas[msg.sender].ledgerTableLength++;
    }

    //This is simply a function that allows you to view the ledger table entry of any account. Keep in mind its only read-able if you have the symmetric key.
    function getLedgerTableEntry(address _accountAddress, uint256 _ledgerTableEntryIndex) public view accountInitialized(msg.sender) accountInitialized(_accountAddress)
    returns (string symmetricallyEncryptedMessage) {
        require(accountDatas[_accountAddress].ledgerTableLength > _ledgerTableEntryIndex);
        LedgerTableEntry storage ledgerTableEntryPointer = accountDatas[_accountAddress].ledgerTable[_ledgerTableEntryIndex];
        return ledgerTableEntryPointer.symmetricallyEncryptedMessage;
    }

    struct MessageTableEntry {
        //This is public anyway, so we store it here.
        address sender;
        uint256 unixTime;

        string encryptedTo; //if decrypted, this is an address
        string encryptedMessage; //if decrypted, this is a string
    }
    MessageTableEntry[] public messageTable;

    function sendMessage(string _encryptedTo, string _encryptedMessage, uint256 _expectedLengthOfMessageTable) public accountInitialized(msg.sender) {
        require(_expectedLengthOfMessageTable == messageTable.length);
        MessageTableEntry memory messageTableEntry;
        messageTableEntry.sender = msg.sender;
        messageTableEntry.unixTime = now;

        messageTableEntry.encryptedTo = _encryptedTo; 
        messageTableEntry.encryptedMessage = _encryptedMessage;
        messageTable.push(messageTableEntry);
    }

    function updateMostRecentlyReadIndex (uint256 _newIndex) public accountInitialized(msg.sender) {
        require(_newIndex < messageTable.length && accountDatas[msg.sender].mostRecentlyReadIndex < _newIndex);
        accountDatas[msg.sender].mostRecentlyReadIndex = _newIndex;
    }

    //In order to read a message 
    function getMessage(uint256 _messageIndex) view public accountInitialized(msg.sender)
    returns (address sender, uint256 unixTime, string encryptedTo, string encryptedMessage) {
        return (messageTable[_messageIndex].sender, messageTable[_messageIndex].unixTime, messageTable[_messageIndex].encryptedTo, messageTable[_messageIndex].encryptedMessage);
    }

}