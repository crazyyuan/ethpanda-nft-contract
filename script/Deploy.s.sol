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
    
    function run() external {
        // 从环境变量读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署合约
        EthPandaNFT nft = new EthPandaNFT(NAME, SYMBOL, BASE_URI);
        
        console.log("EthPandaNFT deployed at:", address(nft));
        console.log("Owner:", nft.owner());
        console.log("Name:", nft.name());
        console.log("Symbol:", nft.symbol());
        
        vm.stopBroadcast();
    }
}

/**
 * @title Setup Script
 * @dev 设置初始 token 类型的脚本
 * 
 * 使用方法:
 * forge script script/Deploy.s.sol:SetupScript --rpc-url <RPC_URL> --broadcast
 */
contract SetupScript is Script {
    function run() external {
        // 从环境变量读取配置
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EthPandaNFT nft = EthPandaNFT(nftAddress);
        
        // 创建示例 token 类型
        // Token ID 1: 普通熊猫
        nft.createToken(1, 1000, 0.01 ether);
        console.log("Created Token ID 1: Common Panda");
        console.log("  Max Supply: 1000");
        console.log("  Mint Price: 0.01 ETH");
        
        // Token ID 2: 稀有熊猫
        nft.createToken(2, 500, 0.05 ether);
        console.log("Created Token ID 2: Rare Panda");
        console.log("  Max Supply: 500");
        console.log("  Mint Price: 0.05 ETH");
        
        // Token ID 3: 史诗熊猫
        nft.createToken(3, 100, 0.1 ether);
        console.log("Created Token ID 3: Epic Panda");
        console.log("  Max Supply: 100");
        console.log("  Mint Price: 0.1 ETH");
        
        // Token ID 4: 传奇熊猫
        nft.createToken(4, 10, 1 ether);
        console.log("Created Token ID 4: Legendary Panda");
        console.log("  Max Supply: 10");
        console.log("  Mint Price: 1 ETH");
        
        vm.stopBroadcast();
        
        console.log("\nSetup completed successfully!");
    }
}

