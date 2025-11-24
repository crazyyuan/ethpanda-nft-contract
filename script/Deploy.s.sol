// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {EthereumOfMemoryNFT} from "../src/EthereumOfMemoryNFT.sol";

/**
 * @title Deploy Script
 * @dev 部署 EthereumOfMemoryNFT 合约的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --broadcast --verify
 */
contract DeployScript is Script {
    // 配置参数
    string constant NAME = "Memory of Ethereum";
    string constant SYMBOL = "MoE";
    string constant BASE_URI = "https://apricot-embarrassed-locust-895.mypinata.cloud/ipfs/bafybeibbwkzoznk24jn3ulqm6xkn2iq5mjubphgmtwydidpdgmdtmm76ma/";
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    
    function run() external {
        // 从环境变量读取私钥和默认管理员地址
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address defaultAdmin = vm.envOr("DEFAULT_ADMIN", vm.addr(deployerPrivateKey));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署合约
        EthereumOfMemoryNFT nft = new EthereumOfMemoryNFT(NAME, SYMBOL, BASE_URI, defaultAdmin);
        
        console.log("=== EthereumOfMemoryNFT Deployed ===");
        console.log("Contract Address:", address(nft));
        console.log("Default Admin:", defaultAdmin);
        console.log("Is Admin:", nft.hasRole(ADMIN_ROLE, defaultAdmin));
        console.log("Name:", nft.name());
        console.log("Symbol:", nft.symbol());
        console.log("Current Token ID:", nft.currentTokenId());
        
        vm.stopBroadcast();
    }
}

/**
 * @title Create Token Script
 * @dev 创建新的 Token（代表新的以太坊升级）
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:CreateTokenScript --rpc-url <RPC_URL> --broadcast
 */
contract CreateTokenScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        string memory upgradeName = vm.envString("UPGRADE_NAME");
        uint256 maxSupply = vm.envUint("MAX_SUPPLY");
        uint256 whitelistMax = vm.envUint("WHITELIST_MAX_PER_ADDRESS");
        uint256 publicMax = vm.envUint("PUBLIC_MAX_PER_ADDRESS");
        uint256 whitelistPrice = vm.envOr("WHITELIST_PRICE", uint256(0));
        uint256 publicPrice = vm.envOr("PUBLIC_PRICE", uint256(0));
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        
        uint256 tokenId = nft.createToken(
            upgradeName,
            maxSupply,
            whitelistMax,
            publicMax,
            whitelistPrice,
            publicPrice
        );
        
        console.log("=== Token Created ===");
        console.log("Token ID:", tokenId);
        console.log("Upgrade Name:", upgradeName);
        console.log("Max Supply:", maxSupply);
        console.log("Whitelist Max Per Address:", whitelistMax);
        console.log("Public Max Per Address:", publicMax);
        console.log("Whitelist Price:", whitelistPrice);
        console.log("Public Price:", publicPrice);
        
        vm.stopBroadcast();
    }
}

/**
 * @title Setup Whitelist Script
 * @dev 设置白名单 Merkle Root 的脚本
 */
contract SetupWhitelistScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        nft.setMerkleRoot(tokenId, merkleRoot);
        
        console.log("=== Whitelist Setup ===");
        console.log("Token ID:", tokenId);
        console.log("Merkle Root:", uint256(merkleRoot));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Start Whitelist Phase Script
 * @dev 开始白名单阶段的脚本
 */
contract StartWhitelistPhaseScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        uint256 price = vm.envOr("WHITELIST_PRICE", uint256(0));
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        nft.startWhitelistPhase(tokenId, price);
        
        console.log("=== Whitelist Phase Started ===");
        console.log("Token ID:", tokenId);
        console.log("Price:", price);
        console.log("Current Phase:", uint256(nft.getCurrentPhase(tokenId)));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Start Public Phase Script
 * @dev 开始公开阶段的脚本
 */
contract StartPublicPhaseScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        uint256 price = vm.envOr("PUBLIC_PRICE", uint256(0));
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        nft.startPublicPhase(tokenId, price);
        
        console.log("=== Public Phase Started ===");
        console.log("Token ID:", tokenId);
        console.log("Price:", price);
        console.log("Current Phase:", uint256(nft.getCurrentPhase(tokenId)));
        
        vm.stopBroadcast();
    }
}

/**
 * @title End Mint Permanently Script
 * @dev 永久结束 mint 的脚本
 */
contract EndMintPermanentlyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        
        uint256 remainingSupply = nft.remainingSupply(tokenId);
        
        console.log("=== Before Ending Mint ===");
        console.log("Token ID:", tokenId);
        console.log("Remaining Supply:", remainingSupply);
        
        nft.endMintPermanently(tokenId);
        
        console.log("\n=== After Ending Mint ===");
        console.log("Remaining Supply:", nft.remainingSupply(tokenId));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Admin Mint Script
 * @dev 管理员铸造 NFT 的脚本
 */
contract AdminMintScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        address recipient = vm.envAddress("RECIPIENT_ADDRESS");
        uint256 amount = vm.envUint("MINT_AMOUNT");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        
        console.log("=== Admin Mint ===");
        console.log("Token ID:", tokenId);
        console.log("Recipient:", recipient);
        console.log("Amount:", amount);
        
        nft.adminMint(tokenId, recipient, amount);
        
        console.log("Recipient Balance:", nft.balanceOf(recipient, tokenId));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Withdraw Funds Script
 * @dev 提取合约中的资金
 */
contract WithdrawScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address payable recipient = payable(vm.envAddress("WITHDRAW_TO"));
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        
        uint256 balance = address(nft).balance;
        console.log("=== Withdraw Funds ===");
        console.log("Contract Balance:", balance);
        console.log("Withdraw To:", recipient);
        
        nft.withdraw(recipient);
        
        console.log("Withdrawn Successfully");
        
        vm.stopBroadcast();
    }
}

/**
 * @title Query Token Info Script
 * @dev 查询 Token 信息的脚本
 */
contract QueryTokenInfoScript is Script {
    function run() external view {
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        
        (
            string memory upgradeName,
            uint256 maxSupply,
            uint256 currentSupply,
            uint256 whitelistMaxPerAddress,
            uint256 publicMaxPerAddress,
            uint256 whitelistPrice,
            uint256 publicPrice,
            EthereumOfMemoryNFT.MintPhase phase,
            bool ended
        ) = nft.getTokenInfo(tokenId);
        
        console.log("=== Token Info ===");
        console.log("Token ID:", tokenId);
        console.log("Upgrade Name:", upgradeName);
        console.log("Max Supply:", maxSupply);
        console.log("Current Supply:", currentSupply);
        console.log("Remaining Supply:", nft.remainingSupply(tokenId));
        console.log("");
        
        console.log("=== Mint Limits ===");
        console.log("Whitelist Max Per Address:", whitelistMaxPerAddress);
        console.log("Public Max Per Address:", publicMaxPerAddress);
        console.log("");
        
        console.log("=== Prices ===");
        console.log("Whitelist Price:", whitelistPrice);
        console.log("Public Price:", publicPrice);
        console.log("");
        
        console.log("=== Status ===");
        console.log("Current Phase:", uint256(phase));
        console.log("Mint Ended:", ended);
    }
}

/**
 * @title Add Admin Script
 * @dev 添加新管理员的脚本
 */
contract AddAdminScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address newAdmin = vm.envAddress("NEW_ADMIN");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        
        console.log("=== Adding Admin ===");
        console.log("New Admin:", newAdmin);
        
        nft.addAdmin(newAdmin);
        
        console.log("Is Admin:", nft.isAdmin(newAdmin));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Remove Admin Script
 * @dev 移除管理员的脚本
 */
contract RemoveAdminScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address adminToRemove = vm.envAddress("ADMIN_TO_REMOVE");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthereumOfMemoryNFT nft = EthereumOfMemoryNFT(payable(nftAddress));
        
        console.log("=== Removing Admin ===");
        console.log("Admin to Remove:", adminToRemove);
        
        nft.removeAdmin(adminToRemove);
        
        console.log("Is Admin:", nft.isAdmin(adminToRemove));
        
        vm.stopBroadcast();
    }
}
