// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title EthPandaNFT
 * @dev ERC-1155 NFT 合约，支持白名单和公开 mint 阶段
 * @notice 以太熊猫 NFT 集合，总供应量 10000，使用 AccessControl 实现多管理员
 */
contract EthPandaNFT is ERC1155, AccessControl, ERC1155Burnable, ERC1155Supply {
    using Strings for uint256;

    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // NFT 名称和符号
    string public name;
    string public symbol;
    
    // 基础 URI
    string private _baseTokenURI;
    
    // Token ID (固定为 1)
    uint256 public constant TOKEN_ID = 1;
    
    // 总供应量
    uint256 public constant MAX_SUPPLY = 10000;
    
    // 白名单阶段每地址最大 mint 数量
    uint256 public constant WHITELIST_MAX_PER_ADDRESS = 5;
    
    // 公开阶段每地址最大 mint 数量
    uint256 public constant PUBLIC_MAX_PER_ADDRESS = 1;
    
    // 阶段持续时间（2天）
    uint256 public constant PHASE_DURATION = 2 days;
    
    // Merkle root for whitelist
    bytes32 public merkleRoot;
    
    // 白名单阶段开始时间
    uint256 public whitelistStartTime;
    
    // 公开阶段开始时间
    uint256 public publicStartTime;
    
    // Mint 是否已结束（永久销毁后）
    bool public mintEnded;
    
    // 白名单阶段每个地址已 mint 数量
    mapping(address => uint256) public whitelistMinted;
    
    // 公开阶段每个地址已 mint 数量
    mapping(address => uint256) public publicMinted;

    // Mint 阶段枚举
enum MintPhase {
        NotStarted,
        Whitelist,
        Public,
        Ended
    }

    // 事件
    event MerkleRootUpdated(bytes32 newMerkleRoot);
    event WhitelistPhaseStarted(uint256 startTime);
    event PublicPhaseStarted(uint256 startTime);
    event MintPermanentlyEnded(uint256 remainingSupply, uint256 burned);
    event BaseURIUpdated(string newBaseURI);
    event WhitelistMint(address indexed minter, uint256 amount);
    event PublicMint(address indexed minter, uint256 amount);
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    /**
     * @dev 构造函数
     * @param _name NFT 名称
     * @param _symbol NFT 符号
     * @param baseURI 基础 URI
     * @param defaultAdmin 默认管理员地址
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI,
        address defaultAdmin
    ) ERC1155(baseURI) {
        name = _name;
        symbol = _symbol;
        _baseTokenURI = baseURI;
        
        // 设置角色管理
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
    }

    /**
     * @dev 获取当前 mint 阶段
     */
    function getCurrentPhase() public view returns (MintPhase) {
        if (mintEnded) {
            return MintPhase.Ended;
        }
        
        if (whitelistStartTime == 0) {
            return MintPhase.NotStarted;
        }
        
        if (block.timestamp < whitelistStartTime) {
            return MintPhase.NotStarted;
        }
        
        if (block.timestamp < whitelistStartTime + PHASE_DURATION) {
            return MintPhase.Whitelist;
        }
        
        if (publicStartTime == 0) {
            return MintPhase.Ended;
        }
        
        if (block.timestamp < publicStartTime) {
            return MintPhase.Ended;
        }
        
        if (block.timestamp < publicStartTime + PHASE_DURATION) {
            return MintPhase.Public;
        }
        
        return MintPhase.Ended;
    }

    /**
     * @dev 添加管理员
     * @param account 要添加的管理员地址
     */
    function addAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
        emit AdminAdded(account);
    }

    /**
     * @dev 移除管理员
     * @param account 要移除的管理员地址
     */
    function removeAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
        emit AdminRemoved(account);
    }

    /**
     * @dev 检查地址是否是管理员
     * @param account 要检查的地址
     * @return 是否是管理员
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @dev 设置 Merkle Root（白名单）
     * @param _merkleRoot 新的 Merkle Root
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyRole(ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /**
     * @dev 开始白名单阶段
     */
    function startWhitelistPhase() external onlyRole(ADMIN_ROLE) {
        require(whitelistStartTime == 0, "Whitelist phase already started");
        require(merkleRoot != bytes32(0), "Merkle root not set");
        
        whitelistStartTime = block.timestamp;
        emit WhitelistPhaseStarted(whitelistStartTime);
    }

    /**
     * @dev 开始公开阶段
     */
    function startPublicPhase() external onlyRole(ADMIN_ROLE) {
        require(whitelistStartTime > 0, "Whitelist phase not started");
        require(
            block.timestamp >= whitelistStartTime + PHASE_DURATION,
            "Whitelist phase not ended"
        );
        require(publicStartTime == 0, "Public phase already started");
        
        publicStartTime = block.timestamp;
        emit PublicPhaseStarted(publicStartTime);
    }

    /**
     * @dev 白名单 mint
     * @param amount mint 数量
     * @param merkleProof Merkle proof
     */
    function whitelistMint(uint256 amount, bytes32[] calldata merkleProof) external {
        require(!mintEnded, "Mint has permanently ended");
        require(getCurrentPhase() == MintPhase.Whitelist, "Not in whitelist phase");
        require(amount > 0, "Amount must be greater than 0");
        require(
            whitelistMinted[msg.sender] + amount <= WHITELIST_MAX_PER_ADDRESS,
            "Exceeds whitelist allocation"
        );
        require(
            totalSupply(TOKEN_ID) + amount <= MAX_SUPPLY,
            "Exceeds max supply"
        );
        
        // 验证白名单
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, leaf),
            "Invalid merkle proof"
        );
        
        // 更新已 mint 数量
        whitelistMinted[msg.sender] += amount;
        
        // Mint NFT
        _mint(msg.sender, TOKEN_ID, amount, "");
        
        emit WhitelistMint(msg.sender, amount);
    }

    /**
     * @dev 公开 mint
     * @param amount mint 数量
     */
    function publicMint(uint256 amount) external {
        require(!mintEnded, "Mint has permanently ended");
        require(getCurrentPhase() == MintPhase.Public, "Not in public phase");
        require(amount > 0, "Amount must be greater than 0");
        require(
            publicMinted[msg.sender] + amount <= PUBLIC_MAX_PER_ADDRESS,
            "Exceeds public allocation"
        );
        require(
            totalSupply(TOKEN_ID) + amount <= MAX_SUPPLY,
            "Exceeds max supply"
        );
        
        // 更新已 mint 数量
        publicMinted[msg.sender] += amount;
        
        // Mint NFT
        _mint(msg.sender, TOKEN_ID, amount, "");
        
        emit PublicMint(msg.sender, amount);
    }

    /**
     * @dev 管理员 mint（不受阶段和数量限制）
     * @param to 接收地址
     * @param amount 数量
     */
    function adminMint(address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(!mintEnded, "Mint has permanently ended");
        require(
            totalSupply(TOKEN_ID) + amount <= MAX_SUPPLY,
            "Exceeds max supply"
        );
        
        _mint(to, TOKEN_ID, amount, "");
    }

    /**
     * @dev 永久结束 mint 并销毁所有剩余 NFT
     * 只能在公开阶段结束后调用
     */
    function endMintPermanently() external onlyRole(ADMIN_ROLE) {
        require(!mintEnded, "Mint already ended");
        require(
            getCurrentPhase() == MintPhase.Ended,
            "Mint phases not completed"
        );
        
        uint256 currentSupply = totalSupply(TOKEN_ID);
        uint256 remaining = MAX_SUPPLY - currentSupply;
        
        // 标记 mint 已结束
        mintEnded = true;
        
        emit MintPermanentlyEnded(remaining, remaining);
    }

    /**
     * @dev 设置基础 URI
     * @param newBaseURI 新的基础 URI
     */
    function setBaseURI(string memory newBaseURI) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        _setURI(newBaseURI);
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev 获取 token URI
     * @param tokenId token ID
     * @return token 的完整 URI
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(tokenId == TOKEN_ID, "Invalid token ID");
        return string(abi.encodePacked(_baseTokenURI, tokenId.toString(), ".json"));
    }


    /**
     * @dev 获取剩余可 mint 数量
     */
    function remainingSupply() external view returns (uint256) {
        if (mintEnded) {
            return 0;
        }
        return MAX_SUPPLY - totalSupply(TOKEN_ID);
    }

    /**
     * @dev 获取地址在白名单阶段剩余可 mint 数量
     */
    function whitelistRemainingForAddress(address account)
        external
        view
        returns (uint256)
    {
        if (getCurrentPhase() != MintPhase.Whitelist) {
            return 0;
        }
        return WHITELIST_MAX_PER_ADDRESS - whitelistMinted[account];
    }

    /**
     * @dev 获取地址在公开阶段剩余可 mint 数量
     */
    function publicRemainingForAddress(address account)
        external
        view
        returns (uint256)
    {
        if (getCurrentPhase() != MintPhase.Public) {
            return 0;
        }
        return PUBLIC_MAX_PER_ADDRESS - publicMinted[account];
    }

    /**
     * @dev 批量检查地址是否在白名单中
     * @param accounts 地址数组
     * @param merkleProofs Merkle proofs 数组
     * @return 布尔数组，表示每个地址是否在白名单中
     */
    function verifyWhitelist(
        address[] calldata accounts,
        bytes32[][] calldata merkleProofs
    ) external view returns (bool[] memory) {
        require(accounts.length == merkleProofs.length, "Arrays length mismatch");
        
        bool[] memory results = new bool[](accounts.length);
        
        for (uint256 i = 0; i < accounts.length; i++) {
            bytes32 leaf = keccak256(abi.encodePacked(accounts[i]));
            results[i] = MerkleProof.verify(merkleProofs[i], merkleRoot, leaf);
        }
        
        return results;
    }

    // 必需的覆盖函数

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    /**
     * @dev 覆盖 supportsInterface 以支持 AccessControl 和 ERC1155
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
