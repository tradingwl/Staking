// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IGoldHunter {
    function ownerOf(uint id) external view returns (address);
//####################################################################################################isRes1 toevoegen
    function isTaxman(uint16 id) external view returns (bool);
    function isRes1(uint16 id) external view returns (bool);
    function isRes2(uint16 id) external view returns (bool);
    function isRes3(uint16 id) external view returns (bool);
    function isCom1(uint16 id) external view returns (bool);
    function isCom2(uint16 id) external view returns (bool);
    function isCom3(uint16 id) external view returns (bool);
    function isRec1(uint16 id) external view returns (bool);
    function isRec2(uint16 id) external view returns (bool);
    function isRec3(uint16 id) external view returns (bool);
    function transferFrom(address from, address to, uint tokenId) external;
    function safeTransferFrom(address from, address to, uint tokenId, bytes memory _data) external;
}

interface IGGold {
    function mint(address account, uint amount) external;
}

contract TreasureIsland is Ownable, IERC721Receiver {
    bool private _paused = false;

    uint16 private _randomIndex = 0;
    uint private _randomCalls = 0;
    mapping(uint => address) private _randomSource;

    struct Stake {
        uint16 tokenId;
        uint80 value;
        address owner;
    }

    event TokenStaked(address owner, uint16 tokenId, uint value);
//####################################################################################################Res1Claimed
    event TaxmanClaimed(uint16 tokenId, uint earned, bool unstaked);
    event Res1Claimed(uint16 tokenId, uint earned, bool unstaked);
    event Res2Claimed(uint16 tokenId, uint earned, bool unstaked);
    event Res3Claimed(uint16 tokenId, uint earned, bool unstaked);
    event Com1Claimed(uint16 tokenId, uint earned, bool unstaked);
    event Com2Claimed(uint16 tokenId, uint earned, bool unstaked);
    event Com3Claimed(uint16 tokenId, uint earned, bool unstaked);
    event Rec1Claimed(uint16 tokenId, uint earned, bool unstaked);
    event Rec2Claimed(uint16 tokenId, uint earned, bool unstaked);
    event Rec3Claimed(uint16 tokenId, uint earned, bool unstaked);

    IGoldHunter public goldHunter;
    IGGold public gold;

//####################################################################################################Res1
    mapping(uint256 => uint256) public res1Indices;
    mapping(address => Stake[]) public res1Stake;

    mapping(uint256 => uint256) public res2Indices;
    mapping(address => Stake[]) public res2Stake;

    mapping(uint256 => uint256) public res3Indices;
    mapping(address => Stake[]) public res3Stake;

    mapping(uint256 => uint256) public com1Indices;
    mapping(address => Stake[]) public com1Stake;

    mapping(uint256 => uint256) public com2Indices;
    mapping(address => Stake[]) public com2Stake;

    mapping(uint256 => uint256) public com3Indices;
    mapping(address => Stake[]) public com3Stake;

    mapping(uint256 => uint256) public rec1Indices;
    mapping(address => Stake[]) public rec1Stake;

    mapping(uint256 => uint256) public rec2Indices;
    mapping(address => Stake[]) public rec2Stake;

    mapping(uint256 => uint256) public rec3Indices;
    mapping(address => Stake[]) public rec3Stake;

    mapping(uint256 => uint256) public taxmanIndices;
    mapping(address => Stake[]) public taxmanStake;
    address[] public taxmanHolders;

    // Total staked tokens
    uint public totalGoldMinerStaked;
    //####################################################################################################res1staked
    uint public totalRes1Staked;
    uint public totalRes2Staked;
    uint public totalRes3Staked;
    uint public totalCom1Staked;
    uint public totalCom2Staked;
    uint public totalCom3Staked;
    uint public totalRec1Staked;
    uint public totalRec2Staked;
    uint public totalRec3Staked;
    uint public totalTaxmanStaked = 0;
    uint public unaccountedRewards = 0;

//####################################################################################################res1 toevoegen. daily gold vervangen voor Daily_miner en Daily_res1?
    // GoldMiner earn 10000 $GGOLD per day
    uint public constant DAILY_RES1_RATE = 10000 ether;
    uint public constant DAILY_RES2_RATE = 20000 ether;
    uint public constant DAILY_RES3_RATE = 30000 ether;
    uint public constant DAILY_COM1_RATE = 40000 ether;
    uint public constant DAILY_COM2_RATE = 50000 ether;
    uint public constant DAILY_COM3_RATE = 60000 ether;
    uint public constant DAILY_REC1_RATE = 70000 ether;
    uint public constant DAILY_REC2_RATE = 80000 ether;
    uint public constant DAILY_REC3_RATE = 90000 ether;
    uint public constant MINIMUM_TIME_TO_EXIT = 10 seconds;
    uint public constant TAX_PERCENTAGE = 15;
    uint public constant MAXIMUM_GLOBAL_GOLD = 2400000000 ether;

    uint public totalGoldEarned;

    uint public lastClaimTimestamp;
    uint public taxmanReward = 0;

    // emergency rescue to allow unstaking without any checks but without $GGOLD
    bool public rescueEnabled = false;

    constructor() {
        // Fill random source addresses
        _randomSource[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _randomSource[1] = 0x3cD751E6b0078Be393132286c442345e5DC49699;
        _randomSource[2] = 0xb5d85CBf7cB3EE0D56b3bB207D5Fc4B82f43F511;
        _randomSource[3] = 0xC098B2a3Aa256D2140208C3de6543aAEf5cd3A94;
        _randomSource[4] = 0x28C6c06298d514Db089934071355E5743bf21d60;
        _randomSource[5] = 0x2FAF487A4414Fe77e2327F0bf4AE2a264a776AD2;
        _randomSource[6] = 0x267be1C1D684F78cb4F6a176C4911b741E4Ffdc0;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function setGoldHunter(address _goldHunter) external onlyOwner {
        goldHunter = IGoldHunter(_goldHunter);
    }

    function setGold(address _gold) external onlyOwner {
        gold = IGGold(_gold);
    }

//####################################################################################################get account res1s
//ADDON    
    function getAccountRes1s(address user) external view returns (Stake[] memory) {
        return res1Stake[user];
    }

    function getAccountRes2s(address user) external view returns (Stake[] memory) {
        return res2Stake[user];
    }

    function getAccountRes3s(address user) external view returns (Stake[] memory) {
        return res3Stake[user];
    }

    function getAccountCom1s(address user) external view returns (Stake[] memory) {
        return com1Stake[user];
    }

    function getAccountCom2s(address user) external view returns (Stake[] memory) {
        return com2Stake[user];
    }

    function getAccountCom3s(address user) external view returns (Stake[] memory) {
        return com3Stake[user];
    }

    function getAccountRec1s(address user) external view returns (Stake[] memory) {
        return rec1Stake[user];
    }

    function getAccountRec2s(address user) external view returns (Stake[] memory) {
        return rec2Stake[user];
    }

    function getAccountRec3s(address user) external view returns (Stake[] memory) {
        return rec3Stake[user];
    }

//ADDON

    function getAccountTaxmans(address user) external view returns (Stake[] memory) {
        return taxmanStake[user];
    }

    function addTokensToStake(address account, uint16[] calldata tokenIds) external {
        require(account == msg.sender || msg.sender == address(goldHunter), "You do not have a permission to do that");

        for (uint i = 0; i < tokenIds.length; i++) {
            if (msg.sender != address(goldHunter)) {
                // dont do this step if its a mint + stake
                require(goldHunter.ownerOf(tokenIds[i]) == msg.sender, "This NTF does not belong to address");
                goldHunter.transferFrom(msg.sender, address(this), tokenIds[i]);
            } else if (tokenIds[i] == 0) {
                continue; // there may be gaps in the array for stolen tokens
            }

//####################################################################################################zelfde voor res1?
            if (goldHunter.isTaxman(tokenIds[i])) {
                _stakeTaxmans(account, tokenIds[i]);
            }
            else if (goldHunter.isRes1(tokenIds[i])) {
                _stakeRes1s(account, tokenIds[i]);
            }
            else if (goldHunter.isRes2(tokenIds[i])) {
                _stakeRes2s(account, tokenIds[i]);
            }
            else if (goldHunter.isRes3(tokenIds[i])) {
                _stakeRes3s(account, tokenIds[i]);
            }
            else if (goldHunter.isCom1(tokenIds[i])) {
                _stakeCom1s(account, tokenIds[i]);
            }
            else if (goldHunter.isCom2(tokenIds[i])) {
                _stakeCom2s(account, tokenIds[i]);
            }
            else if (goldHunter.isCom3(tokenIds[i])) {
                _stakeCom3s(account, tokenIds[i]);
            }
            else if (goldHunter.isRec1(tokenIds[i])) {
                _stakeRec1s(account, tokenIds[i]);
            }
            else if (goldHunter.isRec2(tokenIds[i])) {
                _stakeRec2s(account, tokenIds[i]);
            }
            else {
                _stakeRec3s(account, tokenIds[i]);
            }
        }
    }
//####################################################################################################stakeRes1 toevoegen
    function _stakeRes1s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalRes1Staked += 1;

        res1Indices[tokenId] = res1Stake[account].length;
        res1Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeRes2s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalRes2Staked += 1;

        res2Indices[tokenId] = res2Stake[account].length;
        res2Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeRes3s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalRes3Staked += 1;

        res3Indices[tokenId] = res3Stake[account].length;
        res3Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeCom1s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalCom1Staked += 1;

        com1Indices[tokenId] = com1Stake[account].length;
        com1Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeCom2s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalCom2Staked += 1;

        com2Indices[tokenId] = com2Stake[account].length;
        com2Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeCom3s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalCom3Staked += 1;

        com3Indices[tokenId] = com3Stake[account].length;
        com3Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeRec1s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalRec1Staked += 1;

        rec1Indices[tokenId] = rec1Stake[account].length;
        rec1Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeRec2s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalRec2Staked += 1;

        rec2Indices[tokenId] = res2Stake[account].length;
        rec2Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeRec3s(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalRec3Staked += 1;

        rec3Indices[tokenId] = rec3Stake[account].length;
        rec3Stake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeTaxmans(address account, uint16 tokenId) internal {
        totalTaxmanStaked += 1;

        // If account already has some taxmans no need to push it to the tracker
        if (taxmanStake[account].length == 0) {
            taxmanHolders.push(account);
        }

        taxmanIndices[tokenId] = taxmanStake[account].length;
        taxmanStake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(taxmanReward)
            }));

        emit TokenStaked(account, tokenId, taxmanReward);
    }

//####################################################################################################claimfromres1 toevoegen zoals miner?
    function claimFromStake(uint16[] calldata tokenIds, bool unstake) external whenNotPaused _updateEarnings {
        uint owed = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            if (goldHunter.isRes1(tokenIds[i])) {
                owed += _claimFromRes1(tokenIds[i], unstake);
            }
            else if (goldHunter.isRes2(tokenIds[i])) {
                owed += _claimFromRes2(tokenIds[i], unstake);
            }
            else if (goldHunter.isRes3(tokenIds[i])) {
                owed += _claimFromRes3(tokenIds[i], unstake);
            }
            else if (goldHunter.isCom1(tokenIds[i])) {
                owed += _claimFromCom1(tokenIds[i], unstake);
            }
            else if (goldHunter.isCom2(tokenIds[i])) {
                owed += _claimFromCom2(tokenIds[i], unstake);
            }
            else if (goldHunter.isCom3(tokenIds[i])) {
                owed += _claimFromCom3(tokenIds[i], unstake);
            }
            else if (goldHunter.isRec1(tokenIds[i])) {
                owed += _claimFromRec1(tokenIds[i], unstake);
            }
            else if (goldHunter.isRec2(tokenIds[i])) {
                owed += _claimFromRec2(tokenIds[i], unstake);
            }
            else {
                owed += _claimFromRec3(tokenIds[i], unstake);
            } 
            
        }
        if (owed == 0) return;
        gold.mint(msg.sender, owed);
    }

//####################################################################################################claimfromres1
    function _claimFromRes1(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = res1Stake[msg.sender][res1Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to address");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_RES1_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_RES1_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalRes1Staked -= 1;

            Stake memory lastStake = res1Stake[msg.sender][res1Stake[msg.sender].length - 1];
            res1Stake[msg.sender][res1Indices[tokenId]] = lastStake;
            res1Indices[lastStake.tokenId] = res1Indices[tokenId];
            res1Stake[msg.sender].pop();
            delete res1Indices[tokenId];

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            res1Stake[msg.sender][res1Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // reset stake
        }

        emit Res1Claimed(tokenId, owed, unstake);
    }    

    function _claimFromRes2(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = res2Stake[msg.sender][res2Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to address");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_RES2_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_RES2_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalRes2Staked -= 1;

            Stake memory lastStake = res2Stake[msg.sender][res2Stake[msg.sender].length - 1];
            res2Stake[msg.sender][res2Indices[tokenId]] = lastStake;
            res2Indices[lastStake.tokenId] = res2Indices[tokenId];
            res2Stake[msg.sender].pop();
            delete res2Indices[tokenId];

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            res2Stake[msg.sender][res2Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // reset stake
        }

        emit Res2Claimed(tokenId, owed, unstake);
    }  

    function _claimFromRes3(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = res3Stake[msg.sender][res3Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to address");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_RES3_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_RES3_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalRes3Staked -= 1;

            Stake memory lastStake = res3Stake[msg.sender][res3Stake[msg.sender].length - 1];
            res3Stake[msg.sender][res3Indices[tokenId]] = lastStake;
            res3Indices[lastStake.tokenId] = res3Indices[tokenId];
            res3Stake[msg.sender].pop();
            delete res3Indices[tokenId];

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            res3Stake[msg.sender][res3Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // reset stake
        }

        emit Res3Claimed(tokenId, owed, unstake);
    }  
    
    function _claimFromCom1(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = com1Stake[msg.sender][com1Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to addcoms");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_COM1_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_COM1_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalCom1Staked -= 1;

            Stake memory lastStake = com1Stake[msg.sender][com1Stake[msg.sender].length - 1];
            com1Stake[msg.sender][com1Indices[tokenId]] = lastStake;
            com1Indices[lastStake.tokenId] = com1Indices[tokenId];
            com1Stake[msg.sender].pop();
            delete com1Indices[tokenId];

             goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            com1Stake[msg.sender][com1Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // comet stake
        }

        emit Com1Claimed(tokenId, owed, unstake);
    }    

    function _claimFromCom2(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = com2Stake[msg.sender][com2Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to addcoms");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_COM2_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_COM2_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalCom2Staked -= 1;

            Stake memory lastStake = com2Stake[msg.sender][com2Stake[msg.sender].length - 1];
            com2Stake[msg.sender][com2Indices[tokenId]] = lastStake;
            com2Indices[lastStake.tokenId] = com2Indices[tokenId];
            com2Stake[msg.sender].pop();
            delete com2Indices[tokenId];

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            com2Stake[msg.sender][com2Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // comet stake
        }

        emit Com2Claimed(tokenId, owed, unstake);
    }  

    function _claimFromCom3(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = com3Stake[msg.sender][com3Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to addcoms");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_COM3_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_COM3_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalCom3Staked -= 1;

            Stake memory lastStake = com3Stake[msg.sender][com3Stake[msg.sender].length - 1];
            com3Stake[msg.sender][com3Indices[tokenId]] = lastStake;
            com3Indices[lastStake.tokenId] = com3Indices[tokenId];
            com3Stake[msg.sender].pop();
            delete com3Indices[tokenId];

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            com3Stake[msg.sender][com3Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // comet stake
        }

        emit Com3Claimed(tokenId, owed, unstake);
    }  

    function _claimFromRec1(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = rec1Stake[msg.sender][rec1Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to addrecs");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_REC1_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_REC1_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalRec1Staked -= 1;

            Stake memory lastStake = rec1Stake[msg.sender][rec1Stake[msg.sender].length - 1];
            rec1Stake[msg.sender][rec1Indices[tokenId]] = lastStake;
            rec1Indices[lastStake.tokenId] = rec1Indices[tokenId];
            rec1Stake[msg.sender].pop();
            delete rec1Indices[tokenId];

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            rec1Stake[msg.sender][rec1Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // recet stake
        }

        emit Rec1Claimed(tokenId, owed, unstake);
    }    

    function _claimFromRec2(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = rec2Stake[msg.sender][rec2Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to addrecs");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_REC2_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_REC2_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalRec2Staked -= 1;

            Stake memory lastStake = rec2Stake[msg.sender][rec2Stake[msg.sender].length - 1];
            rec2Stake[msg.sender][rec2Indices[tokenId]] = lastStake;
            rec2Indices[lastStake.tokenId] = rec2Indices[tokenId];
            rec2Stake[msg.sender].pop();
            delete rec2Indices[tokenId];

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            rec2Stake[msg.sender][rec2Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // recet stake
        }

        emit Rec2Claimed(tokenId, owed, unstake);
    }  

    function _claimFromRec3(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = rec3Stake[msg.sender][rec3Indices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to addrecs");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            owed = ((block.timestamp - stake.value) * DAILY_REC3_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $GGOLD production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_REC3_RATE) / 1 days; // stop earning additional $GGOLD if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalRec3Staked -= 1;

            Stake memory lastStake = rec3Stake[msg.sender][rec3Stake[msg.sender].length - 1];
            rec3Stake[msg.sender][rec3Indices[tokenId]] = lastStake;
            rec3Indices[lastStake.tokenId] = rec3Indices[tokenId];
            rec3Stake[msg.sender].pop();
            delete rec3Indices[tokenId];

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $GGOLD to taxmans!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;
            
            uint80 timestamp = uint80(block.timestamp);

            rec3Stake[msg.sender][rec3Indices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // recet stake
        }

        emit Rec3Claimed(tokenId, owed, unstake);
    }  
    

    function _claimFromTaxman(uint16 tokenId, bool unstake) internal returns (uint owed) {
        require(goldHunter.ownerOf(tokenId) == address(this), "This NTF does not belong to address");

        Stake memory stake = taxmanStake[msg.sender][taxmanIndices[tokenId]];

        require(stake.owner == msg.sender, "This NTF does not belong to address");
        owed = (taxmanReward - stake.value);

        if (unstake) {
            totalTaxmanStaked -= 1; // Remove Alpha from total staked

            Stake memory lastStake = taxmanStake[msg.sender][taxmanStake[msg.sender].length - 1];
            taxmanStake[msg.sender][taxmanIndices[tokenId]] = lastStake;
            taxmanIndices[lastStake.tokenId] = taxmanIndices[tokenId];
            taxmanStake[msg.sender].pop();
            delete taxmanIndices[tokenId];
            updateTaxmanOwnerAddressList(msg.sender);

            goldHunter.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            taxmanStake[msg.sender][taxmanIndices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: uint80(taxmanReward)
            }); // reset stake
        }
        emit TaxmanClaimed(tokenId, owed, unstake);
    }

    function updateTaxmanOwnerAddressList(address account) internal {
        if (taxmanStake[account].length != 0) {
            return; // No need to update holders
        }

        // Update the address list of holders, account unstaked all taxmans
        address lastOwner = taxmanHolders[taxmanHolders.length - 1];
        uint indexOfHolder = 0;
        for (uint i = 0; i < taxmanHolders.length; i++) {
            if (taxmanHolders[i] == account) {
                indexOfHolder = i;
                break;
            }
        }
        taxmanHolders[indexOfHolder] = lastOwner;
        taxmanHolders.pop();
    }

    

    function _payTax(uint _amount) internal {
        if (totalTaxmanStaked == 0) {
            unaccountedRewards += _amount;
            return;
        }

        taxmanReward += (_amount + unaccountedRewards) / totalTaxmanStaked;
        unaccountedRewards = 0;
    }

//####################################################################################################res1 toevoegen
    modifier _updateEarnings() {
        if (totalGoldEarned < MAXIMUM_GLOBAL_GOLD) {
            totalGoldEarned += ((block.timestamp - lastClaimTimestamp) 
            * (totalRes1Staked * DAILY_RES1_RATE) 
            * (totalRes2Staked * DAILY_RES2_RATE)
            * (totalRes3Staked * DAILY_RES3_RATE)
            * (totalRes1Staked * DAILY_COM1_RATE) 
            * (totalRes2Staked * DAILY_COM2_RATE)
            * (totalRes3Staked * DAILY_COM3_RATE)
            * (totalRes1Staked * DAILY_REC1_RATE) 
            * (totalRes2Staked * DAILY_REC2_RATE)
            * (totalRes3Staked * DAILY_REC3_RATE)
            ) / 1 days;
            lastClaimTimestamp = block.timestamp;
        }
        _;
    }


    function setRescueEnabled(bool _enabled) external onlyOwner {
        rescueEnabled = _enabled;
    }

    function setPaused(bool _state) external onlyOwner {
        _paused = _state;
    }


    function randomTaxmanOwner() external returns (address) {
        if (totalTaxmanStaked == 0) return address(0x0);

        uint holderIndex = getSomeRandomNumber(totalTaxmanStaked, taxmanHolders.length);
        updateRandomIndex();

        return taxmanHolders[holderIndex];
    }

    function updateRandomIndex() internal {
        _randomIndex += 1;
        _randomCalls += 1;
        if (_randomIndex > 6) _randomIndex = 0;
    }

    function getSomeRandomNumber(uint _seed, uint _limit) internal view returns (uint16) {
        uint extra = 0;
        for (uint16 i = 0; i < 7; i++) {
            extra += _randomSource[_randomIndex].balance;
        }

        uint random = uint(
            keccak256(
                abi.encodePacked(
                    _seed,
                    blockhash(block.number - 1),
                    block.coinbase,
                    block.difficulty,
                    msg.sender,
                    extra,
                    _randomCalls,
                    _randomIndex
                )
            )
        );

        return uint16(random % _limit);
    }

    function changeRandomSource(uint _id, address _address) external onlyOwner {
        _randomSource[_id] = _address;
    }

    function shuffleSeeds(uint _seed, uint _max) external onlyOwner {
        uint shuffleCount = getSomeRandomNumber(_seed, _max);
        _randomIndex = uint16(shuffleCount);
        for (uint i = 0; i < shuffleCount; i++) {
            updateRandomIndex();
        }
    }

    function onERC721Received(
        address,
        address from,
        uint,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send tokens to this contact directly");
        return IERC721Receiver.onERC721Received.selector;
    }
} 