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
 * @title MemoryOfEthereumNFT
 * @dev ERC1155 collection with one tokenId per Ethereum upgrade.
 * @notice Memory of Ethereum NFT: each upgrade is a separate series.
 */
contract MemoryOfEthereumNFT is
    ERC1155,
    AccessControl,
    ERC1155Burnable,
    ERC1155Supply
{
    using Strings for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    address public owner;
    string public name;
    string public symbol;

    string private _baseTokenURI;
    mapping(uint256 => string) private _tokenURIs;

    uint256 public currentTokenId;

    enum MintPhase {
        NotStarted,
        Whitelist,
        Public,
        Ended
    }

    struct TokenConfig {
        uint256 maxSupply;
        uint256 whitelistMaxPerAddress;
        uint256 publicMaxPerAddress;
        uint256 whitelistPrice;
        uint256 publicPrice;
        bytes32 merkleRoot;
        uint256 whitelistStartTime;
        uint256 publicStartTime;
        bool mintEnded;
        uint256 mintEndTime;
        bool transferable;
        string upgradeName; // e.g. "Shapella", "Dencun"
    }

    mapping(uint256 => TokenConfig) public tokenConfigs;

    mapping(uint256 => mapping(address => uint256)) public whitelistMinted;

    mapping(uint256 => mapping(address => uint256)) public publicMinted;

    event TokenCreated(
        uint256 indexed tokenId,
        string upgradeName,
        uint256 maxSupply
    );
    event TokenConfigUpdated(uint256 indexed tokenId);
    event MerkleRootUpdated(uint256 indexed tokenId, bytes32 newMerkleRoot);
    event MintPermanentlyEnded(
        uint256 indexed tokenId,
        uint256 remainingSupply
    );
    event PhaseTimesUpdated(
        uint256 indexed tokenId,
        uint256 whitelistStartTime,
        uint256 publicStartTime
    );
    event BaseURIUpdated(string newBaseURI);
    event TokenURIUpdated(uint256 indexed tokenId, string newURI);
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
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);
    event FundsWithdrawn(address indexed to, uint256 amount);

    /**
     * @dev Constructor
     * @param _name NFT name
     * @param _symbol NFT symbol
     * @param baseURI base metadata URI
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI
    ) ERC1155(baseURI) {
        name = _name;
        symbol = _symbol;
        _baseTokenURI = baseURI;
        owner = msg.sender;

        _grantRole(ADMIN_ROLE, owner);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    /**
     * @dev Create a new token (one Ethereum upgrade).
     * @param upgradeName name of the upgrade
     * @param maxSupply max supply for this tokenId
     * @param whitelistMaxPerAddress per-address limit in whitelist phase
     * @param publicMaxPerAddress per-address limit in public phase
     * @param whitelistPrice price per token in whitelist phase
     * @param publicPrice price per token in public phase
     * @param whitelistStartTime timestamp when whitelist opens (0 to skip whitelist)
     * @param publicStartTime timestamp when public opens (must be > whitelistStartTime if whitelist set, or > 0 if skipping whitelist)
     * @param transferable whether the token can be transferred (false -> SBT-like)
     */
    function createToken(
        string memory upgradeName,
        uint256 maxSupply,
        uint256 whitelistMaxPerAddress,
        uint256 publicMaxPerAddress,
        uint256 whitelistPrice,
        uint256 publicPrice,
        uint256 whitelistStartTime,
        uint256 publicStartTime,
        bool transferable
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        require(maxSupply > 0, "Max supply must be greater than 0");
        require(
            whitelistMaxPerAddress > 0,
            "Whitelist max must be greater than 0"
        );
        require(publicMaxPerAddress > 0, "Public max must be greater than 0");
        _validatePhaseTimes(whitelistStartTime, publicStartTime);

        currentTokenId++;
        uint256 newTokenId = currentTokenId;

        tokenConfigs[newTokenId] = TokenConfig({
            maxSupply: maxSupply,
            whitelistMaxPerAddress: whitelistMaxPerAddress,
            publicMaxPerAddress: publicMaxPerAddress,
            whitelistPrice: whitelistPrice,
            publicPrice: publicPrice,
            merkleRoot: bytes32(0),
            whitelistStartTime: whitelistStartTime,
            publicStartTime: publicStartTime,
            mintEnded: false,
            mintEndTime: 0,
            transferable: transferable,
            upgradeName: upgradeName
        });

        emit TokenCreated(newTokenId, upgradeName, maxSupply);
        return newTokenId;
    }

    /**
     * @dev Update token configuration
     */
    function updateTokenConfig(
        uint256 tokenId,
        uint256 maxSupply,
        uint256 whitelistMaxPerAddress,
        uint256 publicMaxPerAddress,
        uint256 whitelistPrice,
        uint256 publicPrice,
        uint256 whitelistStartTime,
        uint256 publicStartTime
    ) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];
        require(!config.mintEnded, "Token mint has ended");
        require(
            maxSupply >= totalSupply(tokenId),
            "Max supply less than current supply"
        );
        _validatePhaseTimes(whitelistStartTime, publicStartTime);

        config.maxSupply = maxSupply;
        config.whitelistMaxPerAddress = whitelistMaxPerAddress;
        config.publicMaxPerAddress = publicMaxPerAddress;
        config.whitelistPrice = whitelistPrice;
        config.publicPrice = publicPrice;
        config.whitelistStartTime = whitelistStartTime;
        config.publicStartTime = publicStartTime;
        // mintEndTime stays unchanged; endMintPermanently sets it.

        emit TokenConfigUpdated(tokenId);
    }

    /**
     * @dev Get current mint phase
     */
    function getCurrentPhase(uint256 tokenId) public view returns (MintPhase) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];

        if (config.mintEnded) {
            return MintPhase.Ended;
        }

        uint256 wlStart = config.whitelistStartTime;
        uint256 pubStart = config.publicStartTime;

        if (wlStart == 0 && pubStart == 0) {
            return MintPhase.NotStarted;
        }

        if (wlStart == 0) {
            return
                block.timestamp < pubStart
                    ? MintPhase.NotStarted
                    : MintPhase.Public;
        }

        if (block.timestamp < wlStart) {
            return MintPhase.NotStarted;
        }

        if (pubStart == 0 || block.timestamp < pubStart) {
            return MintPhase.Whitelist;
        }

        return MintPhase.Public;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _isAdminManager(address account) internal view returns (bool) {
        return account == owner || hasRole(ADMIN_ROLE, account);
    }

    /**
     * @dev Add a new admin
     */
    function addAdmin(address account) external {
        require(_isAdminManager(msg.sender), "Not authorized to manage admins");
        _grantRole(ADMIN_ROLE, account);
        emit AdminAdded(account);
    }

    /**
     * @dev Remove an admin
     */
    function removeAdmin(address account) external {
        require(_isAdminManager(msg.sender), "Not authorized to manage admins");
        _revokeRole(ADMIN_ROLE, account);
        emit AdminRemoved(account);
    }

    /**
     * @dev Check if address has admin role
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @dev Set whitelist Merkle root
     */
    function setMerkleRoot(
        uint256 tokenId,
        bytes32 _merkleRoot
    ) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];
        require(
            block.timestamp < config.whitelistStartTime ||
                config.whitelistStartTime == 0,
            "Whitelist started"
        );
        tokenConfigs[tokenId].merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(tokenId, _merkleRoot);
    }

    function _validatePhaseTimes(
        uint256 whitelistStartTime,
        uint256 publicStartTime
    ) internal pure {
        if (whitelistStartTime == 0) {
            require(
                publicStartTime > 0,
                "Public start required when skipping whitelist"
            );
        }
        if (whitelistStartTime != 0 && publicStartTime != 0) {
            require(
                publicStartTime > whitelistStartTime,
                "Public must be after whitelist"
            );
        }
    }

    /**
     * @dev Whitelist mint
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
        require(config.whitelistStartTime > 0, "Whitelist not scheduled");
        require(
            block.timestamp >= config.whitelistStartTime,
            "Whitelist not started"
        );
        if (config.publicStartTime != 0) {
            require(
                block.timestamp < config.publicStartTime,
                "Whitelist phase ended"
            );
        }
        require(
            whitelistMinted[tokenId][msg.sender] + amount <=
                config.whitelistMaxPerAddress,
            "Exceeds whitelist allocation"
        );
        require(
            totalSupply(tokenId) + amount <= config.maxSupply,
            "Exceeds max supply"
        );

        uint256 totalPrice = config.whitelistPrice * amount;
        require(msg.value >= totalPrice, "Insufficient payment");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, config.merkleRoot, leaf),
            "Invalid merkle proof"
        );

        whitelistMinted[tokenId][msg.sender] += amount;

        _mint(msg.sender, tokenId, amount, "");

        if (msg.value > totalPrice) {
            (bool refundOk, ) = payable(msg.sender).call{
                value: msg.value - totalPrice
            }("");
            require(refundOk, "Refund failed");
        }

        emit WhitelistMint(tokenId, msg.sender, amount, totalPrice);
    }

    /**
     * @dev Public mint
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
        require(config.publicStartTime > 0, "Public not scheduled");
        require(
            block.timestamp >= config.publicStartTime,
            "Public not started"
        );
        require(
            publicMinted[tokenId][msg.sender] + amount <=
                config.publicMaxPerAddress,
            "Exceeds public allocation"
        );
        require(
            totalSupply(tokenId) + amount <= config.maxSupply,
            "Exceeds max supply"
        );

        uint256 totalPrice = config.publicPrice * amount;
        require(msg.value >= totalPrice, "Insufficient payment");

        publicMinted[tokenId][msg.sender] += amount;

        _mint(msg.sender, tokenId, amount, "");

        if (msg.value > totalPrice) {
            (bool refundOk, ) = payable(msg.sender).call{
                value: msg.value - totalPrice
            }("");
            require(refundOk, "Refund failed");
        }

        emit PublicMint(tokenId, msg.sender, amount, totalPrice);
    }

    /**
     * @dev Permanently end minting for a tokenId
     */
    function endMintPermanently(uint256 tokenId) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];
        require(!config.mintEnded, "Mint already ended");

        uint256 currentSupply = totalSupply(tokenId);
        uint256 remaining = config.maxSupply - currentSupply;

        config.mintEnded = true;
        config.mintEndTime = block.timestamp;
        config.maxSupply = currentSupply; // lock maxSupply to minted amount (burn unminted quota)

        emit MintPermanentlyEnded(tokenId, remaining);
    }

    /**
     * @dev Withdraw contract ETH
     */
    function withdraw(address payable to) external onlyRole(ADMIN_ROLE) {
        require(to != address(0), "Invalid recipient");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = to.call{value: balance}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(to, balance);
    }

    /**
     * @dev Set base URI
     */
    function setBaseURI(
        string memory newBaseURI
    ) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        _setURI(newBaseURI);
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Set per-token URI override
     */
    function setTokenURI(
        uint256 tokenId,
        string memory newURI
    ) external onlyRole(ADMIN_ROLE) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        _tokenURIs[tokenId] = newURI;
        emit TokenURIUpdated(tokenId, newURI);
    }

    /**
     * @dev token URI
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        string memory overrideURI = _tokenURIs[tokenId];
        if (bytes(overrideURI).length > 0) {
            return overrideURI;
        }
        return
            string(
                abi.encodePacked(_baseTokenURI, tokenId.toString(), ".json")
            );
    }

    /**
     * @dev Remaining mintable supply
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
     * @dev Remaining whitelist allocation for an address
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
     * @dev Remaining public allocation for an address
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
     * @dev Batch whitelist verification
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
     * @dev Token detail view
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
            bool ended,
            uint256 mintEndTime,
            bool transferable
        )
    {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];

        return (
            config.upgradeName,
            config.maxSupply,
            totalSupply(tokenId),
            config.whitelistMaxPerAddress,
            config.publicMaxPerAddress,
            config.whitelistPrice,
            config.publicPrice,
            getCurrentPhase(tokenId),
            config.mintEnded,
            config.mintEndTime,
            config.transferable
        );
    }

    function getPhaseTimes(
        uint256 tokenId
    )
        external
        view
        returns (uint256 whitelistStartTime, uint256 publicStartTime)
    {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        TokenConfig storage config = tokenConfigs[tokenId];
        return (config.whitelistStartTime, config.publicStartTime);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                require(
                    tokenConfigs[ids[i]].transferable,
                    "Transfers disabled"
                );
            }
        }

        super._update(from, to, ids, values);
    }

    /**
     * @dev supportsInterface for AccessControl and ERC1155
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {}
}
