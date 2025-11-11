// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title Generate Merkle Root Script
 * @dev 生成白名单 Merkle Root 和 Proof 的辅助脚本
 * 
 * 注意: 这是一个简化的示例脚本
 * 在生产环境中，建议使用 JavaScript/TypeScript 脚本来处理大型白名单
 * 可以使用 merkletreejs 库: https://github.com/miguelmota/merkletreejs
 * 
 * 示例 JavaScript 代码:
 * 
 * const { MerkleTree } = require('merkletreejs');
 * const keccak256 = require('keccak256');
 * 
 * // 白名单地址
 * const whitelist = [
 *   '0x1234...',
 *   '0x5678...',
 *   // ... more addresses
 * ];
 * 
 * // 生成叶子节点
 * const leaves = whitelist.map(addr => keccak256(addr));
 * 
 * // 创建 Merkle Tree
 * const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
 * 
 * // 获取 Merkle Root
 * const root = tree.getHexRoot();
 * console.log('Merkle Root:', root);
 * 
 * // 为特定地址生成 proof
 * const address = '0x1234...';
 * const leaf = keccak256(address);
 * const proof = tree.getHexProof(leaf);
 * console.log('Proof for', address, ':', proof);
 * 
 * // 验证 proof
 * const verified = tree.verify(proof, leaf, root);
 * console.log('Verified:', verified);
 */
contract GenerateMerkleRootScript is Script {
    
    /**
     * @dev 为小型白名单生成 Merkle Root 的示例
     * 实际使用时应该使用链外脚本处理
     */
    function run() external pure {
        // 示例白名单地址
        address[] memory whitelist = new address[](5);
        whitelist[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        whitelist[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        whitelist[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        whitelist[3] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        whitelist[4] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        
        console.log("=== Whitelist Addresses ===");
        for (uint256 i = 0; i < whitelist.length; i++) {
            console.log("Address", i, ":", whitelist[i]);
        }
        
        console.log("\n=== Leaf Hashes ===");
        bytes32[] memory leaves = new bytes32[](whitelist.length);
        for (uint256 i = 0; i < whitelist.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelist[i]));
            console.log("Leaf", i, ":");
            console.logBytes32(leaves[i]);
        }
        
        console.log("\n=== Instructions ===");
        console.log("Use the leaf hashes above to generate Merkle Root using:");
        console.log("1. merkletreejs library (recommended)");
        console.log("2. OpenZeppelin Merkle Tree library");
        console.log("3. Online Merkle Tree generator");
        console.log("\nExample command:");
        console.log("node scripts/generateMerkleTree.js");
    }
    
    /**
     * @dev 验证 Merkle Proof
     * 用于测试生成的 proof 是否正确
     */
    function verifyProof(
        bytes32[] memory proof,
        bytes32 root,
        address account
    ) external pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, root, leaf);
    }
}

