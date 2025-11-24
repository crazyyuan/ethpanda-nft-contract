// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

/**
 * @title Verify Script
 * @dev 独立验证已部署的合约
 * 
 * 使用方法:
 *forge script script/Verify.s.sol:VerifyScript --rpc-url sepolia --verify -vvvv
 * 
 * 或者使用 forge verify-contract 命令:
 * forge verify-contract <CONTRACT_ADDRESS> EthereumOfMemoryNFT \
 *   --constructor-args $(cast abi-encode "constructor(string,string,string,address)" "Memory of Ethereum" "Fusaka" "YOUR_BASE_URI" "YOUR_ADMIN_ADDRESS") \
 *   --etherscan-api-key $ETHERSCAN_API_KEY \
 *   --chain sepolia
 */
contract VerifyScript is Script {
    function run() external view {
        // 从环境变量读取配置
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        string memory name = vm.envOr("NFT_NAME", string("Memory of Ethereum"));
        string memory symbol = vm.envOr("NFT_SYMBOL", string("Fusaka"));
        string memory baseURI = vm.envString("BASE_URI");
        address defaultAdmin = vm.envAddress("DEFAULT_ADMIN");
        
        console.log("=== Contract Verification Info ===");
        console.log("Contract Address:", contractAddress);
        console.log("Contract Name: EthereumOfMemoryNFT");
        console.log("");
        console.log("Constructor Arguments:");
        console.log("  name:", name);
        console.log("  symbol:", symbol);
        console.log("  baseURI:", baseURI);
        console.log("  defaultAdmin:", defaultAdmin);
        console.log("");
        console.log("=== Verification Command ===");
        console.log("Run the following command to verify:");
        console.log("");
        
        // 构造验证命令
        string memory verifyCommand = string(abi.encodePacked(
            "forge verify-contract ",
            vm.toString(contractAddress),
            " EthereumOfMemoryNFT ",
            "--constructor-args $(cast abi-encode \"constructor(string,string,string,address)\" \"",
            name,
            "\" \"",
            symbol,
            "\" \"",
            baseURI,
            "\" ",
            vm.toString(defaultAdmin),
            ") ",
            "--etherscan-api-key $ETHERSCAN_API_KEY ",
            "--chain sepolia ",
            "--watch"
        ));
        
        console.log(verifyCommand);
    }
}

