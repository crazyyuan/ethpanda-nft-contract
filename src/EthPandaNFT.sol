// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title EthPandaNFT
 * @dev ERC-1155 NFT 合约，支持多种 token 类型
 * @notice 以太熊猫 NFT 集合
 */
contract EthPandaNFT is ERC1155, Ownable, ERC1155Burnable, ERC1155Supply {
    using Strings for uint256;

    // NFT 名称
    string public name;
    // NFT 符号
    string public symbol;
    
    // 基础 URI
    string private _baseTokenURI;
    
    // 每个 token ID 的最大供应量
    mapping(uint256 => uint256) private _maxSupply;
    
    // 每个 token ID 的铸造价格
    mapping(uint256 => uint256) private _mintPrice;
    
    // 是否暂停铸造
    bool public mintPaused;

    // 事件
    event TokenCreated(uint256 indexed tokenId, uint256 maxSupply, uint256 mintPrice);
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event MintPausedToggled(bool paused);
    event BaseURIUpdated(string newBaseURI);
    event MaxSupplyUpdated(uint256 indexed tokenId, uint256 newMaxSupply);
    event MintPriceUpdated(uint256 indexed tokenId, uint256 newPrice);

    /**
     * @dev 构造函数
     * @param _name NFT 名称
     * @param _symbol NFT 符号
     * @param baseURI 基础 URI
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI
    ) ERC1155(baseURI) Ownable(msg.sender) {
        name = _name;
        symbol = _symbol;
        _baseTokenURI = baseURI;
        mintPaused = false;
    }

    /**
     * @dev 创建新的 token 类型
     * @param tokenId token ID
     * @param maxSupply 最大供应量 (0 表示无限制)
     * @param mintPrice 铸造价格
     */
    function createToken(
        uint256 tokenId,
        uint256 maxSupply,
        uint256 mintPrice
    ) external onlyOwner {
        require(_maxSupply[tokenId] == 0, "Token already exists");
        
        _maxSupply[tokenId] = maxSupply;
        _mintPrice[tokenId] = mintPrice;
        
        emit TokenCreated(tokenId, maxSupply, mintPrice);
    }

    /**
     * @dev 铸造 NFT
     * @param to 接收地址
     * @param tokenId token ID
     * @param amount 数量
     */
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external payable {
        require(!mintPaused, "Minting is paused");
        require(_maxSupply[tokenId] > 0, "Token does not exist");
        
        // 检查供应量限制
        if (_maxSupply[tokenId] > 0) {
            require(
                totalSupply(tokenId) + amount <= _maxSupply[tokenId],
                "Exceeds max supply"
            );
        }
        
        // 检查支付金额
        uint256 totalPrice = _mintPrice[tokenId] * amount;
        require(msg.value >= totalPrice, "Insufficient payment");
        
        _mint(to, tokenId, amount, "");
        
        // 退还多余的 ETH
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        
        emit TokenMinted(to, tokenId, amount);
    }

    /**
     * @dev 批量铸造 NFT
     * @param to 接收地址
     * @param tokenIds token ID 数组
     * @param amounts 数量数组
     */
    function mintBatch(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) external payable {
        require(!mintPaused, "Minting is paused");
        require(tokenIds.length == amounts.length, "Arrays length mismatch");
        
        uint256 totalPrice = 0;
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];
            
            require(_maxSupply[tokenId] > 0, "Token does not exist");
            
            if (_maxSupply[tokenId] > 0) {
                require(
                    totalSupply(tokenId) + amount <= _maxSupply[tokenId],
                    "Exceeds max supply"
                );
            }
            
            totalPrice += _mintPrice[tokenId] * amount;
        }
        
        require(msg.value >= totalPrice, "Insufficient payment");
        
        _mintBatch(to, tokenIds, amounts, "");
        
        // 退还多余的 ETH
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    /**
     * @dev 所有者铸造（免费）
     * @param to 接收地址
     * @param tokenId token ID
     * @param amount 数量
     */
    function ownerMint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlyOwner {
        require(_maxSupply[tokenId] > 0, "Token does not exist");
        
        if (_maxSupply[tokenId] > 0) {
            require(
                totalSupply(tokenId) + amount <= _maxSupply[tokenId],
                "Exceeds max supply"
            );
        }
        
        _mint(to, tokenId, amount, "");
        emit TokenMinted(to, tokenId, amount);
    }

    /**
     * @dev 批量所有者铸造
     * @param to 接收地址
     * @param tokenIds token ID 数组
     * @param amounts 数量数组
     */
    function ownerMintBatch(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) external onlyOwner {
        require(tokenIds.length == amounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(_maxSupply[tokenIds[i]] > 0, "Token does not exist");
            
            if (_maxSupply[tokenIds[i]] > 0) {
                require(
                    totalSupply(tokenIds[i]) + amounts[i] <= _maxSupply[tokenIds[i]],
                    "Exceeds max supply"
                );
            }
        }
        
        _mintBatch(to, tokenIds, amounts, "");
    }

    /**
     * @dev 设置基础 URI
     * @param newBaseURI 新的基础 URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
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
        return string(abi.encodePacked(_baseTokenURI, tokenId.toString(), ".json"));
    }

    /**
     * @dev 切换铸造暂停状态
     */
    function toggleMintPause() external onlyOwner {
        mintPaused = !mintPaused;
        emit MintPausedToggled(mintPaused);
    }

    /**
     * @dev 更新最大供应量
     * @param tokenId token ID
     * @param newMaxSupply 新的最大供应量
     */
    function updateMaxSupply(uint256 tokenId, uint256 newMaxSupply) external onlyOwner {
        require(_maxSupply[tokenId] > 0, "Token does not exist");
        require(newMaxSupply >= totalSupply(tokenId), "New max supply too low");
        
        _maxSupply[tokenId] = newMaxSupply;
        emit MaxSupplyUpdated(tokenId, newMaxSupply);
    }

    /**
     * @dev 更新铸造价格
     * @param tokenId token ID
     * @param newPrice 新价格
     */
    function updateMintPrice(uint256 tokenId, uint256 newPrice) external onlyOwner {
        require(_maxSupply[tokenId] > 0, "Token does not exist");
        
        _mintPrice[tokenId] = newPrice;
        emit MintPriceUpdated(tokenId, newPrice);
    }

    /**
     * @dev 提取合约余额
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        payable(owner()).transfer(balance);
    }

    /**
     * @dev 获取 token 的最大供应量
     * @param tokenId token ID
     * @return 最大供应量
     */
    function maxSupply(uint256 tokenId) external view returns (uint256) {
        return _maxSupply[tokenId];
    }

    /**
     * @dev 获取 token 的铸造价格
     * @param tokenId token ID
     * @return 铸造价格
     */
    function mintPrice(uint256 tokenId) external view returns (uint256) {
        return _mintPrice[tokenId];
    }

    // 以下函数是必需的覆盖

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }
}

