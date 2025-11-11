// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {EthPandaNFT} from "../src/EthPandaNFT.sol";

/**
 * @title Deploy Script
 * @dev 部署 EthPandaNFT 合约的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --broadcast --verify
 */
contract DeployScript is Script {
    // 配置参数
    string constant NAME = "EthPanda NFT";
    string constant SYMBOL = "EPNFT";
    string constant BASE_URI = "https://api.ethpanda.io/metadata/";
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    
    function run() external {
        // 从环境变量读取私钥和默认管理员地址
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address defaultAdmin = vm.envOr("DEFAULT_ADMIN", vm.addr(deployerPrivateKey));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署合约
        EthPandaNFT nft = new EthPandaNFT(NAME, SYMBOL, BASE_URI, defaultAdmin);
        
        console.log("=== EthPandaNFT Deployed ===");
        console.log("Contract Address:", address(nft));
        console.log("Default Admin:", defaultAdmin);
        console.log("Is Admin:", nft.hasRole(ADMIN_ROLE, defaultAdmin));
        console.log("Name:", nft.name());
        console.log("Symbol:", nft.symbol());
        console.log("Max Supply:", nft.MAX_SUPPLY());
        console.log("Token ID:", nft.TOKEN_ID());
        
        vm.stopBroadcast();
    }
}

/**
 * @title Setup Whitelist Script
 * @dev 设置白名单 Merkle Root 的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:SetupWhitelistScript --rpc-url <RPC_URL> --broadcast
 * 
 * 注意: 需要提前生成 Merkle Root
 */
contract SetupWhitelistScript is Script {
    function run() external {
        // 从环境变量读取配置
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        // 设置 Merkle Root
        nft.setMerkleRoot(merkleRoot);
        
        console.log("=== Whitelist Setup ===");
        console.log("NFT Address:", address(nft));
        console.log("Merkle Root:", uint256(merkleRoot));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Start Whitelist Phase Script
 * @dev 开始白名单阶段的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:StartWhitelistPhaseScript --rpc-url <RPC_URL> --broadcast
 */
contract StartWhitelistPhaseScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        // 开始白名单阶段
        nft.startWhitelistPhase();
        
        console.log("=== Whitelist Phase Started ===");
        console.log("NFT Address:", address(nft));
        console.log("Start Time:", nft.whitelistStartTime());
        console.log("End Time:", nft.whitelistStartTime() + nft.PHASE_DURATION());
        console.log("Current Phase:", uint256(nft.getCurrentPhase()));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Start Public Phase Script
 * @dev 开始公开阶段的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:StartPublicPhaseScript --rpc-url <RPC_URL> --broadcast
 */
contract StartPublicPhaseScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        // 开始公开阶段
        nft.startPublicPhase();
        
        console.log("=== Public Phase Started ===");
        console.log("NFT Address:", address(nft));
        console.log("Start Time:", nft.publicStartTime());
        console.log("End Time:", nft.publicStartTime() + nft.PHASE_DURATION());
        console.log("Current Phase:", uint256(nft.getCurrentPhase()));
        
        vm.stopBroadcast();
    }
}

/**
 * @title End Mint Permanently Script
 * @dev 永久结束 mint 并销毁剩余 NFT 的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:EndMintPermanentlyScript --rpc-url <RPC_URL> --broadcast
 */
contract EndMintPermanentlyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        uint256 currentSupply = nft.totalSupply(nft.TOKEN_ID());
        uint256 remainingSupply = nft.remainingSupply();
        
        console.log("=== Before Ending Mint ===");
        console.log("Current Supply:", currentSupply);
        console.log("Remaining Supply:", remainingSupply);
        
        // 永久结束 mint
        nft.endMintPermanently();
        
        console.log("\n=== After Ending Mint ===");
        console.log("Mint Ended:", nft.mintEnded());
        console.log("Remaining Supply:", nft.remainingSupply());
        console.log("Final Supply:", nft.totalSupply(nft.TOKEN_ID()));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Add Admin Script
 * @dev 添加新管理员的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:AddAdminScript --rpc-url <RPC_URL> --broadcast
 */
contract AddAdminScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address newAdmin = vm.envAddress("NEW_ADMIN");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        console.log("=== Adding Admin ===");
        console.log("NFT Address:", address(nft));
        console.log("New Admin:", newAdmin);
        
        nft.addAdmin(newAdmin);
        
        console.log("Is Admin:", nft.isAdmin(newAdmin));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Remove Admin Script
 * @dev 移除管理员的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:RemoveAdminScript --rpc-url <RPC_URL> --broadcast
 */
contract RemoveAdminScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address adminToRemove = vm.envAddress("ADMIN_TO_REMOVE");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        console.log("=== Removing Admin ===");
        console.log("NFT Address:", address(nft));
        console.log("Admin to Remove:", adminToRemove);
        
        nft.removeAdmin(adminToRemove);
        
        console.log("Is Admin:", nft.isAdmin(adminToRemove));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Admin Mint Script
 * @dev 管理员铸造 NFT 的脚本（用于空投等）
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:AdminMintScript --rpc-url <RPC_URL> --broadcast
 */
contract AdminMintScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address recipient = vm.envAddress("RECIPIENT_ADDRESS");
        uint256 amount = vm.envUint("MINT_AMOUNT");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        console.log("=== Admin Mint ===");
        console.log("Recipient:", recipient);
        console.log("Amount:", amount);
        console.log("Current Supply:", nft.totalSupply(nft.TOKEN_ID()));
        
        nft.adminMint(recipient, amount);
        
        console.log("New Supply:", nft.totalSupply(nft.TOKEN_ID()));
        console.log("Recipient Balance:", nft.balanceOf(recipient, nft.TOKEN_ID()));
        
        vm.stopBroadcast();
    }
}

/**
 * @title Query Contract Status Script
 * @dev 查询合约当前状态的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:QueryStatusScript --rpc-url <RPC_URL>
 */
contract QueryStatusScript is Script {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    
    function run() external view {
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        console.log("=== Contract Status ===");
        console.log("Contract Address:", address(nft));
        console.log("Name:", nft.name());
        console.log("Symbol:", nft.symbol());
        console.log("");
        
        console.log("=== Admin Info ===");
        address checkAddress = vm.envOr("CHECK_ADDRESS", address(0));
        if (checkAddress != address(0)) {
            console.log("Checking Address:", checkAddress);
            console.log("Is Admin:", nft.isAdmin(checkAddress));
            console.log("Has DEFAULT_ADMIN_ROLE:", nft.hasRole(DEFAULT_ADMIN_ROLE, checkAddress));
        }
        console.log("");
        
        console.log("=== Supply Info ===");
        console.log("Max Supply:", nft.MAX_SUPPLY());
        console.log("Current Supply:", nft.totalSupply(nft.TOKEN_ID()));
        console.log("Remaining Supply:", nft.remainingSupply());
        console.log("Mint Ended:", nft.mintEnded());
        console.log("");
        
        console.log("=== Phase Info ===");
        console.log("Current Phase:", uint256(nft.getCurrentPhase()));
        console.log("Whitelist Start Time:", nft.whitelistStartTime());
        console.log("Public Start Time:", nft.publicStartTime());
        console.log("Phase Duration:", nft.PHASE_DURATION());
        console.log("");
        
        console.log("=== Mint Limits ===");
        console.log("Whitelist Max Per Address:", nft.WHITELIST_MAX_PER_ADDRESS());
        console.log("Public Max Per Address:", nft.PUBLIC_MAX_PER_ADDRESS());
    }
}

