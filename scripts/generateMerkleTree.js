#!/usr/bin/env node

/**
 * 生成白名单 Merkle Tree 和 Proofs
 * 
 * 安装依赖:
 * npm install merkletreejs keccak256
 * 
 * 运行:
 * node scripts/generateMerkleTree.js
 */

const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const fs = require('fs');

// 白名单地址列表
// 在实际使用中，这些地址应该从 CSV 文件或数据库读取
const whitelist = [
  '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
  '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
  '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
  '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65',
  '0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc',
];

console.log('🐼 Generating Merkle Tree for EthPanda NFT Whitelist\n');

// 生成叶子节点
const leaves = whitelist.map(address => keccak256(address));

// 创建 Merkle Tree
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });

// 获取 Merkle Root
const root = tree.getHexRoot();

console.log('📋 Whitelist Summary:');
console.log(`Total addresses: ${whitelist.length}`);
console.log(`\n🌳 Merkle Root:\n${root}\n`);

// 为每个地址生成 proof
console.log('🔑 Merkle Proofs:\n');
const proofs = {};

whitelist.forEach((address, index) => {
  const leaf = keccak256(address);
  const proof = tree.getHexProof(leaf);
  proofs[address] = proof;
  
  console.log(`Address ${index + 1}: ${address}`);
  console.log(`Proof: ${JSON.stringify(proof)}`);
  
  // 验证 proof
  const verified = tree.verify(proof, leaf, root);
  console.log(`Verified: ${verified ? '✅' : '❌'}\n`);
});

// 保存到文件
const output = {
  merkleRoot: root,
  totalAddresses: whitelist.length,
  whitelist: whitelist,
  proofs: proofs,
};

const outputPath = 'whitelist-merkle-data.json';
fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));

console.log(`\n💾 Merkle data saved to: ${outputPath}`);
console.log('\n✅ Done! Use the Merkle Root to set up the whitelist in your contract.');
console.log('\n📝 Next steps:');
console.log('1. Set MERKLE_ROOT in your .env file');
console.log('2. Run: forge script script/Deploy.s.sol:SetupWhitelistScript --rpc-url $SEPOLIA_RPC_URL --broadcast');
console.log('3. Share the proofs with whitelisted users for minting');

