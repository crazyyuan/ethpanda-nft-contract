// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {
    ERC1155Burnable
} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {
    ERC1155Supply
} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title EthereumOfMemoryNFT
 * @dev ERC-1155 NFT 合约，支持多个 Token ID，每个代表一次以太坊升级
 * @notice Memory of Ethereum NFT 集合，每个升级对应一个独立的 NFT 系列
 */
contract EthereumOfMemoryNFT is
    ERC1155,
    AccessControl,
    ERC1155Burnable,
    ERC1155Supply
{
    using Strings for uint256;

    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // NFT 名称和符号
    string public name;
    string public symbol;

    // 基础 URI
    string private _baseTokenURI;

    // 当前最新的 Token ID（每次升级加 1）
    uint256 public currentTokenId;

    // Mint 阶段枚举
    enum MintPhase {
        NotStarted,
        Whitelist,
        Public,
        Ended
    }

    // Token 配置结构体
    struct TokenConfig {
        uint256 maxSupply; // 最大供应量
        uint256 whitelistMaxPerAddress; // 白名单每地址最大 mint 数量
        uint256 publicMaxPerAddress; // 公开阶段每地址最大 mint 数量
        uint256 whitelistPrice; // 白名单阶段价格
        uint256 publicPrice; // 公开阶段价格
        bytes32 merkleRoot; // 白名单 Merkle Root
        uint256 whitelistStartTime; // 白名单开始时间
        uint256 publicStartTime; // 公开开始时间
        bool mintEnded; // Mint 是否已结束
        string upgradeName; // 升级名称（如 "Shapella", "Dencun"）
    }

    // Token ID => Token 配置
    mapping(uint256 => TokenConfig) public tokenConfigs;

    // Token ID => 用户地址 => 白名单阶段已 mint 数量
    mapping(uint256 => mapping(address => uint256)) public whitelistMinted;

    // Token ID => 用户地址 => 公开阶段已 mint 数量
    mapping(uint256 => mapping(address => uint256)) public publicMinted;

    // 事件
    event TokenCreated(
        uint256 indexed tokenId,
        string upgradeName,
        uint256 maxSupply
    );
    event TokenConfigUpdated(uint256 indexed tokenId);
    event MerkleRootUpdated(uint256 indexed tokenId, bytes32 newMerkleRoot);
    event WhitelistPhaseStarted(
        uint256 indexed tokenId,
        uint256 startTime,
        uint256 price
    );
    event PublicPhaseStarted(
        uint256 indexed tokenId,
        uint256 startTime,
        uint256 price
    );
    event MintPermanentlyEnded(
        uint256 indexed tokenId,
        uint256 remainingSupply
    );
    event BaseURIUpdated(string newBaseURI);
    event WhitelistMint(
        uint256 indexed tokenId,
        address indexed minter,
        uint256 amount,
        uint256 totalPaid
    );
    event PublicMint(
        uint256 indexed tokenId,
        address indexed minter,
        uint256 amount,
        uint256 totalPaid
    );
    event AdminMint(
        uint256 indexed tokenId,
        address indexed to,
        uint256 amount
    );
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);
    event FundsWithdrawn(address indexed to, uint256 amount);

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
     * @dev 创建新的 Token（新的以太坊升级）
     * @param upgradeName 升级名称
     * @param maxSupply 最大供应量
     * @param whitelistMaxPerAddress 白名单每地址最大 mint 数量
     * @param publicMaxPerAddress 公开阶段每地址最大 mint 数量
     * @param whitelistPrice 白名单价格（可选，默认 0）
     * @param publicPrice 公开价格（可选，默认 0）
     */
    function createToken(
        string memory upgradeName,
        uint256 maxSupply,
        uint256 whitelistMaxPerAddress,
        uint256 publicMaxPerAddress,
        uint256 whitelistPrice,
        uint256 publicPrice
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        require(maxSupply > 0, "Max supply must be greater than 0");
        require(
            whitelistMaxPerAddress > 0,
            "Whitelist max must be greater than 0"
        );
        require(publicMaxPerAddress > 0, "Public max must be greater than 0");

        currentTokenId++;
        uint256 newTokenId = currentTokenId;

        tokenConfigs[newTokenId] = TokenConfig({
            maxSupply: maxSupply,
            whitelistMaxPerAddress: whitelistMaxPerAddress,
            publicMaxPerAddress: publicMaxPerAddress,
            whitelistPrice: whitelistPrice,
            publicPrice: publicPrice,
            merkleRoot: bytes32(0),
            whitelistStartTime: 0,
            publicStartTime: 0,
            mintEnded: false,
            upgradeName: upgradeName
        });

        emit TokenCreated(newTokenId, upgradeName, maxSupply);
        return newTokenId;
    }

    /**
     * @dev 更新 Token 配置
     */
    function updateTokenConfig(
        uint256 tokenId,
        uint256 maxSupply,
        uint256 whitelistMaxPerAddress,
        uint256 publicMaxPerAddress,
        uint256 whitelistPrice,
        uint256 publicPrice
    ) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];
        require(!config.mintEnded, "Token mint has ended");
        require(
            maxSupply >= totalSupply(tokenId),
            "Max supply less than current supply"
        );

        config.maxSupply = maxSupply;
        config.whitelistMaxPerAddress = whitelistMaxPerAddress;
        config.publicMaxPerAddress = publicMaxPerAddress;
        config.whitelistPrice = whitelistPrice;
        config.publicPrice = publicPrice;

        emit TokenConfigUpdated(tokenId);
    }

    /**
     * @dev 获取当前 Token 的 mint 阶段
     */
    function getCurrentPhase(uint256 tokenId) public view returns (MintPhase) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];

        if (config.mintEnded) {
            return MintPhase.Ended;
        }

        if (config.whitelistStartTime == 0) {
            return MintPhase.NotStarted;
        }

        // 白名单阶段已开启但公开阶段未开启
        if (config.publicStartTime == 0) {
            return MintPhase.Whitelist;
        }

        // 公开阶段已开启
        return MintPhase.Public;
    }

    /**
     * @dev 添加管理员
     */
    function addAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
        emit AdminAdded(account);
    }

    /**
     * @dev 移除管理员
     */
    function removeAdmin(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
        emit AdminRemoved(account);
    }

    /**
     * @dev 检查地址是否是管理员
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @dev 设置 Merkle Root（白名单）
     */
    function setMerkleRoot(
        uint256 tokenId,
        bytes32 _merkleRoot
    ) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        tokenConfigs[tokenId].merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(tokenId, _merkleRoot);
    }

    /**
     * @dev 开始白名单阶段
     */
    function startWhitelistPhase(
        uint256 tokenId,
        uint256 price
    ) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];
        require(
            config.whitelistStartTime == 0,
            "Whitelist phase already started"
        );
        require(config.merkleRoot != bytes32(0), "Merkle root not set");

        config.whitelistStartTime = block.timestamp;
        config.whitelistPrice = price;
        emit WhitelistPhaseStarted(tokenId, block.timestamp, price);
    }

    /**
     * @dev 开始公开阶段
     */
    function startPublicPhase(
        uint256 tokenId,
        uint256 price
    ) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];
        require(config.whitelistStartTime > 0, "Whitelist phase not started");
        require(config.publicStartTime == 0, "Public phase already started");

        config.publicStartTime = block.timestamp;
        config.publicPrice = price;
        emit PublicPhaseStarted(tokenId, block.timestamp, price);
    }

    /**
     * @dev 白名单 mint
     */
    function whitelistMint(
        uint256 tokenId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external payable {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];

        require(!config.mintEnded, "Mint has permanently ended");
        require(
            getCurrentPhase(tokenId) == MintPhase.Whitelist,
            "Not in whitelist phase"
        );
        require(amount > 0, "Amount must be greater than 0");
        require(
            whitelistMinted[tokenId][msg.sender] + amount <=
                config.whitelistMaxPerAddress,
            "Exceeds whitelist allocation"
        );
        require(
            totalSupply(tokenId) + amount <= config.maxSupply,
            "Exceeds max supply"
        );

        // 检查支付金额
        uint256 totalPrice = config.whitelistPrice * amount;
        require(msg.value >= totalPrice, "Insufficient payment");

        // 验证白名单
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, config.merkleRoot, leaf),
            "Invalid merkle proof"
        );

        // 更新已 mint 数量
        whitelistMinted[tokenId][msg.sender] += amount;

        // Mint NFT
        _mint(msg.sender, tokenId, amount, "");

        // 退还多余的 ETH
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit WhitelistMint(tokenId, msg.sender, amount, totalPrice);
    }

    /**
     * @dev 公开 mint
     */
    function publicMint(uint256 tokenId, uint256 amount) external payable {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];

        require(!config.mintEnded, "Mint has permanently ended");
        require(
            getCurrentPhase(tokenId) == MintPhase.Public,
            "Not in public phase"
        );
        require(amount > 0, "Amount must be greater than 0");
        require(
            publicMinted[tokenId][msg.sender] + amount <=
                config.publicMaxPerAddress,
            "Exceeds public allocation"
        );
        require(
            totalSupply(tokenId) + amount <= config.maxSupply,
            "Exceeds max supply"
        );

        // 检查支付金额
        uint256 totalPrice = config.publicPrice * amount;
        require(msg.value >= totalPrice, "Insufficient payment");

        // 更新已 mint 数量
        publicMinted[tokenId][msg.sender] += amount;

        // Mint NFT
        _mint(msg.sender, tokenId, amount, "");

        // 退还多余的 ETH
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit PublicMint(tokenId, msg.sender, amount, totalPrice);
    }

    /**
     * @dev 管理员 mint（不受阶段和数量限制，免费）
     */
    function adminMint(
        uint256 tokenId,
        address to,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];

        require(!config.mintEnded, "Mint has permanently ended");
        require(
            totalSupply(tokenId) + amount <= config.maxSupply,
            "Exceeds max supply"
        );

        _mint(to, tokenId, amount, "");
        emit AdminMint(tokenId, to, amount);
    }

    /**
     * @dev 永久结束某个 Token 的 mint
     */
    function endMintPermanently(uint256 tokenId) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];
        require(!config.mintEnded, "Mint already ended");

        uint256 currentSupply = totalSupply(tokenId);
        uint256 remaining = config.maxSupply - currentSupply;

        // 标记 mint 已结束
        config.mintEnded = true;

        emit MintPermanentlyEnded(tokenId, remaining);
    }

    /**
     * @dev 提取合约中的 ETH
     */
    function withdraw(address payable to) external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = to.call{value: balance}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(to, balance);
    }

    /**
     * @dev 设置基础 URI
     */
    function setBaseURI(
        string memory newBaseURI
    ) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        _setURI(newBaseURI);
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev 获取 token URI
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        return
            string(
                abi.encodePacked(_baseTokenURI, tokenId.toString(), ".json")
            );
    }

    /**
     * @dev 获取剩余可 mint 数量
     */
    function remainingSupply(uint256 tokenId) external view returns (uint256) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];

        if (config.mintEnded) {
            return 0;
        }
        return config.maxSupply - totalSupply(tokenId);
    }

    /**
     * @dev 获取地址在白名单阶段剩余可 mint 数量
     */
    function whitelistRemainingForAddress(
        uint256 tokenId,
        address account
    ) external view returns (uint256) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        if (getCurrentPhase(tokenId) != MintPhase.Whitelist) {
            return 0;
        }
        TokenConfig storage config = tokenConfigs[tokenId];
        return
            config.whitelistMaxPerAddress - whitelistMinted[tokenId][account];
    }

    /**
     * @dev 获取地址在公开阶段剩余可 mint 数量
     */
    function publicRemainingForAddress(
        uint256 tokenId,
        address account
    ) external view returns (uint256) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        if (getCurrentPhase(tokenId) != MintPhase.Public) {
            return 0;
        }
        TokenConfig storage config = tokenConfigs[tokenId];
        return config.publicMaxPerAddress - publicMinted[tokenId][account];
    }

    /**
     * @dev 批量检查地址是否在白名单中
     */
    function verifyWhitelist(
        uint256 tokenId,
        address[] calldata accounts,
        bytes32[][] calldata merkleProofs
    ) external view returns (bool[] memory) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        require(
            accounts.length == merkleProofs.length,
            "Arrays length mismatch"
        );

        TokenConfig storage config = tokenConfigs[tokenId];
        bool[] memory results = new bool[](accounts.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            bytes32 leaf = keccak256(abi.encodePacked(accounts[i]));
            results[i] = MerkleProof.verify(
                merkleProofs[i],
                config.merkleRoot,
                leaf
            );
        }

        return results;
    }

    /**
     * @dev 获取 Token 的详细信息
     */
    function getTokenInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            string memory upgradeName,
            uint256 maxSupply,
            uint256 currentSupply,
            uint256 whitelistMaxPerAddress,
            uint256 publicMaxPerAddress,
            uint256 whitelistPrice,
            uint256 publicPrice,
            MintPhase phase,
            bool ended
        )
    {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];

        // Inline phase calculation to avoid stack too deep error
        MintPhase currentPhase;
        if (config.mintEnded) {
            currentPhase = MintPhase.Ended;
        } else if (config.whitelistStartTime == 0) {
            currentPhase = MintPhase.NotStarted;
        } else if (config.publicStartTime == 0) {
            currentPhase = MintPhase.Whitelist;
        } else {
            currentPhase = MintPhase.Public;
        }

        return (
            config.upgradeName,
            config.maxSupply,
            totalSupply(tokenId),
            config.whitelistMaxPerAddress,
            config.publicMaxPerAddress,
            config.whitelistPrice,
            config.publicPrice,
            currentPhase,
            config.mintEnded
        );
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
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // 接收 ETH
    receive() external payable {}
}
