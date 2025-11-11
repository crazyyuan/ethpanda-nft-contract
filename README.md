# EthPanda NFT

以太熊猫 NFT 智能合约项目 - 基于 ERC-1155 标准的 NFT 集合，支持白名单和公开铸造阶段。

## 项目概述

EthPanda NFT 是一个基于以太坊的 NFT 项目，使用 ERC-1155 标准，总供应量 10,000。项目采用两阶段铸造机制：白名单阶段（2天）和公开阶段（2天），**免费铸造**（只需支付 gas 费）。使用 Merkle Tree 实现 gas 优化的白名单验证，使用 OpenZeppelin AccessControl 实现**多管理员权限控制**。项目使用 OpenZeppelin 合约库构建，并采用 Foundry 作为开发和测试框架。

## 技术栈

- **合约标准**: ERC-1155 (多代币标准)
- **合约库**: OpenZeppelin Contracts v5.1.0
- **开发框架**: Foundry
- **Solidity 版本**: ^0.8.24
- **白名单机制**: Merkle Tree

## 主要特性

- ✅ **固定供应量**: 总供应量 10,000 NFT
- ✅ **免费铸造**: 用户只需支付 gas 费即可铸造
- ✅ **两阶段铸造**: 白名单阶段和公开阶段，各持续 2 天
- ✅ **白名单机制**: 使用 Merkle Tree 进行高效的白名单验证
- ✅ **限量铸造**: 白名单每地址最多 5 个，公开阶段每地址最多 1 个
- ✅ **永久销毁**: mint 结束后可永久销毁剩余 NFT，禁止再次铸造
- ✅ **多管理员**: 使用 AccessControl 支持多个管理员
- ✅ **批量操作**: 支持批量转账
- ✅ **销毁机制**: 支持 NFT 销毁

## 项目结构

```
ethpanda-nft/
├── src/
│   └── EthPandaNFT.sol              # 主合约
├── test/
│   └── EthPandaNFT.t.sol            # 测试文件
├── script/
│   ├── Deploy.s.sol                 # 部署和管理脚本
│   └── GenerateMerkleRoot.s.sol    # Merkle Root 生成工具
├── scripts/
│   └── generateMerkleTree.js        # JavaScript Merkle Tree 生成脚本
├── lib/
│   ├── forge-std/                   # Foundry 标准库
│   └── openzeppelin-contracts/      # OpenZeppelin 合约库 v5.1.0
├── foundry.toml                     # Foundry 配置
├── remappings.txt                   # 导入路径映射
├── package.json                     # Node.js 依赖
└── README.md
```

## 安装和设置

### 前置要求

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (用于生成 Merkle Tree)
- [Git](https://git-scm.com/downloads)

### 安装依赖

```bash
# 克隆仓库
git clone <repository-url>
cd ethpanda-nft

# 初始化 git 子模块
git submodule update --init --recursive

# 安装 Node.js 依赖
npm install
```

### 配置环境变量

创建 `.env` 文件并填写配置：

```bash
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# 部署后填写
NFT_ADDRESS=0x...
MERKLE_ROOT=0x...
```

## 开发

### 编译合约

```bash
forge build
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行测试并显示详细信息
forge test -vvv

# 运行特定测试
forge test --match-test testWhitelistMint

# 查看测试覆盖率
forge coverage

# 查看 gas 报告
forge test --gas-report
```

### 本地测试

```bash
# 启动本地节点
anvil

# 在另一个终端部署到本地网络
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast
```

## Mint 阶段和流程

### 阶段说明

1. **未开始阶段 (NotStarted)**
   - 合约部署后的初始状态
   - 只有所有者可以 mint

2. **白名单阶段 (Whitelist) - 2 天**
   - 白名单用户可以 mint
   - 每个地址最多 mint 5 个
   - 需要提供 Merkle Proof

3. **公开阶段 (Public) - 2 天**
   - 任何人都可以 mint
   - 每个地址最多 mint 1 个

4. **结束阶段 (Ended)**
   - 两个阶段结束后自动进入
   - 可以调用 `endMintPermanently()` 永久销毁剩余 NFT

### 完整部署和运行流程

#### 1. 部署合约

```bash
# 部署合约（默认使用部署者作为管理员）
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# 或指定其他地址作为默认管理员
DEFAULT_ADMIN=0x... forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

记录下合约地址，并更新 `.env` 文件中的 `NFT_ADDRESS`。

#### 1.5. （可选）添加额外管理员

如果需要多个管理员来管理合约：

```bash
# 添加新管理员
NEW_ADMIN=0x... forge script script/Deploy.s.sol:AddAdminScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

#### 2. 生成白名单 Merkle Tree

编辑 `scripts/generateMerkleTree.js`，添加白名单地址：

```javascript
const whitelist = [
  '0x1234...',
  '0x5678...',
  // 更多地址
];
```

运行脚本生成 Merkle Root：

```bash
npm run generate-merkle
```

这将生成 `whitelist-merkle-data.json` 文件，包含：
- Merkle Root
- 每个地址的 Proof
- 白名单地址列表

将 Merkle Root 更新到 `.env` 文件。

#### 3. 设置白名单

```bash
forge script script/Deploy.s.sol:SetupWhitelistScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

#### 4. 开始白名单阶段

```bash
forge script script/Deploy.s.sol:StartWhitelistPhaseScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

白名单阶段将持续 2 天。

#### 5. 白名单用户 Mint

白名单用户需要使用他们的 Merkle Proof 进行免费 mint：

```javascript
// 从 whitelist-merkle-data.json 获取 proof
const proof = merkleData.proofs[userAddress];

// Mint (免费，只需 gas)
await nft.whitelistMint(amount, proof);
```

#### 6. 开始公开阶段

2 天后，开始公开阶段：

```bash
forge script script/Deploy.s.sol:StartPublicPhaseScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

#### 7. 公开 Mint

任何人都可以免费 mint（每地址限 1 个）：

```javascript
await nft.publicMint(1);
```

#### 8. 永久结束 Mint

公开阶段结束后（2 天），可以永久销毁剩余 NFT：

```bash
forge script script/Deploy.s.sol:EndMintPermanentlyScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

此后将无法再 mint 任何 NFT。

#### 9. （可选）管理员管理

```bash
# 添加新管理员
NEW_ADMIN=0x... forge script script/Deploy.s.sol:AddAdminScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# 移除管理员
ADMIN_TO_REMOVE=0x... forge script script/Deploy.s.sol:RemoveAdminScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# 管理员 mint（空投等）
RECIPIENT_ADDRESS=0x... MINT_AMOUNT=100 forge script script/Deploy.s.sol:AdminMintScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# 查询管理员状态
CHECK_ADDRESS=0x... forge script script/Deploy.s.sol:QueryStatusScript \
  --rpc-url $SEPOLIA_RPC_URL
```

## 合约功能

### 管理员功能

#### DEFAULT_ADMIN_ROLE（超级管理员）

```solidity
// 添加管理员
addAdmin(address account)

// 移除管理员
removeAdmin(address account)
```

#### ADMIN_ROLE（普通管理员）

```solidity
// 设置白名单 Merkle Root
setMerkleRoot(bytes32 merkleRoot)

// 开始白名单阶段
startWhitelistPhase()

// 开始公开阶段
startPublicPhase()

// 永久结束 mint
endMintPermanently()

// 管理员铸造（不受阶段和数量限制）
adminMint(address to, uint256 amount)

// 更新配置
setBaseURI(string newBaseURI)
```

#### 查询功能

```solidity
// 检查是否是管理员
isAdmin(address account) → bool

// 检查是否拥有特定角色
hasRole(bytes32 role, address account) → bool
```

### 用户功能

```solidity
// 白名单 mint
whitelistMint(uint256 amount, bytes32[] calldata merkleProof) payable

// 公开 mint
publicMint(uint256 amount) payable

// 销毁 NFT
burn(address account, uint256 tokenId, uint256 amount)

// 转账
safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data)

// 查询
balanceOf(address account, uint256 id)
remainingSupply()
whitelistRemainingForAddress(address account)
publicRemainingForAddress(address account)
getCurrentPhase()
```

### 查询功能

```solidity
// 获取当前阶段
getCurrentPhase() → MintPhase

// 获取剩余供应量
remainingSupply() → uint256

// 获取地址在白名单阶段剩余可 mint 数量
whitelistRemainingForAddress(address) → uint256

// 获取地址在公开阶段剩余可 mint 数量
publicRemainingForAddress(address) → uint256

// 批量验证白名单
verifyWhitelist(address[] accounts, bytes32[][] proofs) → bool[]
```

## 使用示例

### 前端集成示例

```javascript
import { ethers } from 'ethers';
import merkleData from './whitelist-merkle-data.json';

// 连接钱包
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const nft = new ethers.Contract(NFT_ADDRESS, ABI, signer);

// 检查当前阶段
const phase = await nft.getCurrentPhase();
// 0: NotStarted, 1: Whitelist, 2: Public, 3: Ended

// 白名单 mint（免费）
async function whitelistMint(amount) {
  const userAddress = await signer.getAddress();
  const proof = merkleData.proofs[userAddress];
  
  if (!proof) {
    throw new Error('Address not in whitelist');
  }
  
  const tx = await nft.whitelistMint(amount, proof);
  
  await tx.wait();
  console.log('Minted successfully!');
}

// 公开 mint（免费）
async function publicMint(amount) {
  const tx = await nft.publicMint(amount);
  
  await tx.wait();
  console.log('Minted successfully!');
}

// 查询用户余额
const balance = await nft.balanceOf(userAddress, 1);
console.log('User balance:', balance.toString());

// 查询剩余可 mint 数量
const remaining = await nft.remainingSupply();
console.log('Remaining supply:', remaining.toString());
```

## 权限系统

项目使用 OpenZeppelin AccessControl 实现灵活的权限管理：

### 角色说明

- **DEFAULT_ADMIN_ROLE（超级管理员）**
  - 可以添加和移除 ADMIN_ROLE
  - 拥有所有 ADMIN_ROLE 的权限
  - 通常由项目方持有

- **ADMIN_ROLE（普通管理员）**
  - 可以管理 mint 阶段（开始白名单/公开阶段）
  - 可以设置白名单 Merkle Root
  - 可以进行管理员 mint（空投等）
  - 可以永久结束 mint
  - 可以更新 baseURI

### 多管理员优势

- ✅ 分散风险：避免单点故障
- ✅ 团队协作：多人可以管理合约
- ✅ 灵活管理：可以随时添加/移除管理员
- ✅ 权限分离：超级管理员和普通管理员分离

## 安全考虑

- ✅ 使用 OpenZeppelin 审计过的合约库
- ✅ 实现了多层访问控制 (AccessControl)
- ✅ 防止重入攻击
- ✅ 供应量限制检查
- ✅ 阶段时间验证
- ✅ Merkle Tree 白名单验证（gas 优化）
- ✅ 永久销毁机制防止意外增发
- ✅ 免费铸造降低用户门槛
- ✅ 多管理员机制分散风险

## 测试覆盖

项目包含全面的测试套件（30+ 测试用例）：

- ✅ 合约初始化测试
- ✅ Merkle Root 设置和验证
- ✅ 阶段转换测试
- ✅ 白名单 mint（含 Merkle Proof 验证）
- ✅ 公开 mint
- ✅ 数量限制测试
- ✅ 永久结束 mint 测试
- ✅ 销毁功能测试
- ✅ 权限控制测试
- ✅ 边界条件测试
- ✅ Fuzz 测试
- ✅ 完整流程测试

运行测试：

```bash
forge test -vvv
```

## Gas 优化

合约经过优化以降低 gas 消耗：

- 使用 Merkle Tree 而非映射存储白名单（节省大量存储成本）
- 使用 `uint256` 避免额外的转换
- 合理的存储布局
- 批量操作支持
- Solidity 0.8.24 的优化器

查看 gas 报告：

```bash
forge test --gas-report
```

## 常见问题

**Q: Mint 需要支付费用吗？**
A: 不需要。本项目的 mint 是完全免费的，用户只需支付以太坊网络的 gas 费用。

**Q: 如何添加白名单地址？**
A: 编辑 `scripts/generateMerkleTree.js` 中的 whitelist 数组，然后运行 `npm run generate-merkle`。

**Q: 可以更改阶段持续时间吗？**
A: 阶段持续时间（2天）是合约中的常量。如需更改，需要在部署前修改合约代码。

**Q: 白名单用户可以在公开阶段继续 mint 吗？**
A: 可以，但只能 mint 1 个（公开阶段限制）。白名单和公开阶段的 mint 数量是分别计算的。

**Q: 如果没有调用 `endMintPermanently()`，还能 mint 吗？**
A: 不能。两个阶段结束后，合约会自动进入 Ended 状态，阻止普通 mint。但管理员仍可以调用 `adminMint()`，除非调用了 `endMintPermanently()`。

**Q: `endMintPermanently()` 会实际销毁代币吗？**
A: 不会实际销毁已 mint 的代币，只是将 `mintEnded` 标志设为 true，永久禁止所有 mint 操作（包括 `adminMint()`）。

**Q: 多管理员模式安全吗？**
A: 是的。使用 OpenZeppelin AccessControl 实现，经过广泛审计。超级管理员（DEFAULT_ADMIN_ROLE）可以管理普通管理员（ADMIN_ROLE），确保权限可控。

**Q: 如何添加或移除管理员？**
A: 只有超级管理员可以通过 `addAdmin()` 和 `removeAdmin()` 函数添加或移除普通管理员。也可以使用提供的部署脚本 `AddAdminScript` 和 `RemoveAdminScript`。

**Q: 管理员和超级管理员有什么区别？**
A: 超级管理员（DEFAULT_ADMIN_ROLE）可以管理管理员角色，而普通管理员（ADMIN_ROLE）只能执行合约管理操作（如开始 mint 阶段、设置白名单等），不能添加或移除其他管理员。

## 许可证

MIT License

## 致谢

- [OpenZeppelin](https://www.openzeppelin.com/) - 安全的智能合约库
- [Foundry](https://github.com/foundry-rs/foundry) - 快速的以太坊开发工具链
- [merkletreejs](https://github.com/miguelmota/merkletreejs) - Merkle Tree 实现

---

**警告**: 在主网部署前，请务必进行完整的安全审计。
