# Memory of Ethereum NFT

[English](./README.md) | 中文

Memory of Ethereum（以太坊记忆）- 纪念以太坊每次重大升级的 NFT 集合，基于 ERC-1155 标准，支持多 Token 系列管理。

## 🎯 项目概述

Memory of Ethereum 是一个创新的 NFT 项目，每次以太坊重大升级（如 Shapella, Dencun, Fusaka 等）都会发行一个独立的 NFT 系列。每个系列都是独立的 Token ID，拥有独立的配置、白名单和价格设置。

### 核心理念

- 🌟 **纪念意义**: 每个 NFT 代表一次以太坊的重大技术升级
- 🎨 **独立系列**: 每次升级对应独立的 Token ID 和配置
- 🔓 **灵活定价**: 支持免费或付费铸造，可针对不同阶段设置不同价格
- 🛡️ **安全可靠**: 基于 OpenZeppelin v5.1.0 和 Foundry 构建

## 🚀 主要特性

### 核心功能
- ✅ **多 Token 支持**: 每次以太坊升级创建新的 Token ID
- ✅ **数据隔离**: 每个 Token 拥有独立的配置、白名单和用户记录
- ✅ **灵活定价**: 支持免费/付费铸造，可针对白名单和公开阶段设置不同价格
- ✅ **自动退款**: 用户支付多余的 ETH 会自动退还
- ✅ **资金管理**: 管理员可提取合约收益

### 铸造机制
- 🎫 **白名单阶段**: 使用 Merkle Tree 验证，高效且 gas 优化
- 🌍 **公开阶段**: 向所有人开放
- 🎛️ **手动控制**: 管理员可随时开启/结束各阶段
- 🔒 **永久结束**: 可永久禁止某个 Token 继续铸造

### 权限管理
- 👥 **多管理员**: 基于 OpenZeppelin AccessControl
- 🔐 **角色分离**: DEFAULT_ADMIN_ROLE 和 ADMIN_ROLE 两级权限
- ⚡ **灵活操作**: 支持动态添加/移除管理员

## 📋 技术栈

- **合约标准**: ERC-1155 (多代币标准)
- **合约库**: OpenZeppelin Contracts v5.1.0
- **开发框架**: Foundry
- **Solidity 版本**: ^0.8.24
- **编译优化**: via-ir 模式
- **白名单机制**: Merkle Tree

## 🏗️ 项目结构

```
ethpanda-nft/
├── src/
│   └── EthereumOfMemoryNFT.sol         # 主合约 (521 行)
├── test/
│   └── EthereumOfMemoryNFT.t.sol       # 测试文件 (54 个测试)
├── script/
│   ├── Deploy.s.sol                    # 部署和管理脚本 (10+ 脚本)
│   └── GenerateMerkleRoot.s.sol        # Merkle Root 生成工具
├── scripts/
│   └── generateMerkleTree.js           # JavaScript Merkle Tree 生成
├── metadata/
│   └── 1.json                          # NFT metadata 示例
├── lib/
│   ├── forge-std/                      # Foundry 标准库
│   └── openzeppelin-contracts/         # OpenZeppelin v5.1.0
├── foundry.toml                        # Foundry 配置
└── package.json                        # Node.js 依赖
```

## 🛠️ 安装和设置

### 前置要求

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v16+)
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

复制 `.env.example` 并填写配置：

```bash
cp .env.example .env
```

编辑 `.env` 文件：

```bash
# 私钥（不含 0x 前缀）
PRIVATE_KEY=your_private_key_here

# RPC 节点
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID

# Etherscan API Key
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# 默认管理员（可选）
DEFAULT_ADMIN=0xYourAdminAddress

# Token 配置
TOKEN_ID=1
UPGRADE_NAME=Shapella
MAX_SUPPLY=10000
WHITELIST_MAX_PER_ADDRESS=5
PUBLIC_MAX_PER_ADDRESS=1
WHITELIST_PRICE=0
PUBLIC_PRICE=0

# 部署后填写
NFT_ADDRESS=0x...
MERKLE_ROOT=0x...
```

## 💻 开发

### 编译合约

```bash
npm run build
# 或
forge build
```

### 运行测试

```bash
npm run test
# 或
forge test --offline

# 查看 gas 报告
forge test --gas-report

# 查看覆盖率
forge coverage
```

**测试统计**: 54 个测试，100% 通过率 ✅

## 🚀 部署流程

### 1. 部署主合约

```bash
npm run deploy:sepolia
```

这会部署 `EthereumOfMemoryNFT` 合约并输出合约地址。

### 2. 创建第一个 Token

编辑 `.env` 配置：

```bash
NFT_ADDRESS=0xYourDeployedContractAddress
UPGRADE_NAME=Shapella
MAX_SUPPLY=10000
WHITELIST_MAX_PER_ADDRESS=5
PUBLIC_MAX_PER_ADDRESS=1
WHITELIST_PRICE=0                    # 免费
PUBLIC_PRICE=0                       # 免费
```

执行创建：

```bash
forge script script/Deploy.s.sol:CreateTokenScript \
  --rpc-url sepolia \
  --broadcast
```

### 3. 生成白名单 Merkle Tree

创建 `whitelist.txt` 文件，每行一个地址：

```
0x1234567890123456789012345678901234567890
0xabcdefabcdefabcdefabcdefabcdefabcdefabcd
```

生成 Merkle Root：

```bash
npm run generate-merkle
```

### 4. 设置白名单

```bash
export TOKEN_ID=1
export MERKLE_ROOT=0x...  # 从上一步获取

forge script script/Deploy.s.sol:SetupWhitelistScript \
  --rpc-url sepolia \
  --broadcast
```

### 5. 开始白名单阶段

```bash
export TOKEN_ID=1
export WHITELIST_PRICE=0  # 或设置价格，如 10000000000000000 (0.01 ETH)

forge script script/Deploy.s.sol:StartWhitelistPhaseScript \
  --rpc-url sepolia \
  --broadcast
```

### 6. 开始公开阶段

```bash
export TOKEN_ID=1
export PUBLIC_PRICE=0  # 或设置价格

forge script script/Deploy.s.sol:StartPublicPhaseScript \
  --rpc-url sepolia \
  --broadcast
```

### 7. 提取资金（如果是付费铸造）

```bash
export WITHDRAW_TO=0xYourTreasuryAddress

forge script script/Deploy.s.sol:WithdrawScript \
  --rpc-url sepolia \
  --broadcast
```

## 📖 合约功能详解

### Token 管理

#### 创建新 Token

每次以太坊升级时，创建新的 Token：

```solidity
function createToken(
    string memory upgradeName,      // "Shapella", "Dencun", "Fusaka"
    uint256 maxSupply,              // 10000
    uint256 whitelistMaxPerAddress, // 5
    uint256 publicMaxPerAddress,    // 1
    uint256 whitelistPrice,         // 0 (免费) 或 0.01 ether
    uint256 publicPrice             // 0 (免费) 或 0.02 ether
) external returns (uint256 tokenId);
```

#### 更新 Token 配置

```solidity
function updateTokenConfig(
    uint256 tokenId,
    uint256 maxSupply,
    uint256 whitelistMaxPerAddress,
    uint256 publicMaxPerAddress,
    uint256 whitelistPrice,
    uint256 publicPrice
) external;
```

#### 查询 Token 信息

```solidity
function getTokenInfo(uint256 tokenId) external view returns (
    string memory upgradeName,
    uint256 maxSupply,
    uint256 currentSupply,
    uint256 whitelistMaxPerAddress,
    uint256 publicMaxPerAddress,
    uint256 whitelistPrice,
    uint256 publicPrice,
    MintPhase phase,
    bool ended
);
```

### 用户铸造

#### 白名单铸造

```solidity
function whitelistMint(
    uint256 tokenId,
    uint256 amount,
    bytes32[] calldata merkleProof
) external payable;
```

使用示例：
```javascript
// 免费铸造
await nft.whitelistMint(1, 3, proof);

// 付费铸造 (0.01 ETH per NFT)
await nft.whitelistMint(1, 3, proof, { value: ethers.parseEther("0.03") });
```

#### 公开铸造

```solidity
function publicMint(uint256 tokenId, uint256 amount) external payable;
```

使用示例：
```javascript
// 免费铸造
await nft.publicMint(1, 1);

// 付费铸造
await nft.publicMint(1, 1, { value: ethers.parseEther("0.02") });
```

### 管理功能

#### 管理员铸造（免费）

```solidity
function adminMint(uint256 tokenId, address to, uint256 amount) external;
```

#### 结束铸造

```solidity
function endMintPermanently(uint256 tokenId) external;
```

#### 提取资金

```solidity
function withdraw(address payable to) external;
```

#### 管理员管理

```solidity
function addAdmin(address account) external;
function removeAdmin(address account) external;
function isAdmin(address account) external view returns (bool);
```

## 🎯 使用场景

### 场景 1: 免费铸造活动

```bash
# 创建免费 Token
export UPGRADE_NAME="Shapella"
export MAX_SUPPLY=10000
export WHITELIST_MAX_PER_ADDRESS=5
export PUBLIC_MAX_PER_ADDRESS=1
export WHITELIST_PRICE=0
export PUBLIC_PRICE=0

forge script script/Deploy.s.sol:CreateTokenScript --rpc-url sepolia --broadcast
```

### 场景 2: 付费铸造活动

```bash
# 创建付费 Token
export UPGRADE_NAME="Dencun"
export MAX_SUPPLY=8000
export WHITELIST_MAX_PER_ADDRESS=3
export PUBLIC_MAX_PER_ADDRESS=2
export WHITELIST_PRICE=10000000000000000   # 0.01 ETH
export PUBLIC_PRICE=20000000000000000      # 0.02 ETH

forge script script/Deploy.s.sol:CreateTokenScript --rpc-url sepolia --broadcast
```

### 场景 3: 白名单免费，公开付费

```bash
export WHITELIST_PRICE=0
export PUBLIC_PRICE=10000000000000000   # 0.01 ETH
```

### 场景 4: 多个系列并行管理

```solidity
// Token 1: Shapella（已完成）
nft.endMintPermanently(1);

// Token 2: Dencun（白名单中，免费）
nft.startWhitelistPhase(2, 0);

// Token 3: Fusaka（未开始，已配置为付费）
// 等待合适时机启动
```

## 📊 数据隔离

每个 Token 的以下数据完全独立：

| 数据项 | 说明 |
|--------|------|
| maxSupply | 最大供应量 |
| whitelistMaxPerAddress | 白名单每地址限额 |
| publicMaxPerAddress | 公开每地址限额 |
| whitelistPrice | 白名单价格 |
| publicPrice | 公开价格 |
| merkleRoot | 白名单 Merkle Root |
| phase | 当前阶段状态 |
| whitelistMinted | 用户白名单铸造记录 |
| publicMinted | 用户公开铸造记录 |

## 🔐 权限系统

### 角色定义

- **DEFAULT_ADMIN_ROLE** (最高权限)
  - 添加/移除 ADMIN_ROLE
  - 拥有所有 ADMIN_ROLE 权限

- **ADMIN_ROLE** (操作权限)
  - 创建 Token
  - 更新配置
  - 设置白名单
  - 开始/结束阶段
  - 管理员铸造
  - 提取资金

### 多管理员示例

```bash
# 添加管理员
export NEW_ADMIN=0x...
forge script script/Deploy.s.sol:AddAdminScript --rpc-url sepolia --broadcast

# 移除管理员
export ADMIN_TO_REMOVE=0x...
forge script script/Deploy.s.sol:RemoveAdminScript --rpc-url sepolia --broadcast
```

## 📦 脚本工具

项目提供了丰富的管理脚本：

| 脚本 | 功能 |
|------|------|
| `DeployScript` | 部署主合约 |
| `CreateTokenScript` | 创建新 Token |
| `SetupWhitelistScript` | 设置白名单 |
| `StartWhitelistPhaseScript` | 开始白名单阶段 |
| `StartPublicPhaseScript` | 开始公开阶段 |
| `EndMintPermanentlyScript` | 永久结束铸造 |
| `AdminMintScript` | 管理员铸造 |
| `WithdrawScript` | 提取资金 |
| `QueryTokenInfoScript` | 查询 Token 信息 |
| `AddAdminScript` | 添加管理员 |
| `RemoveAdminScript` | 移除管理员 |

## 🎨 Metadata

项目包含 NFT metadata 模板：

```json
{
  "name": "Memory of Ethereum #1",
  "description": "Memory of Ethereum 是一个限量收藏...",
  "image": "ipfs://YOUR_CID/image.png",
  "external_url": "https://ethereum.org",
  "attributes": [
    {
      "trait_type": "Collection",
      "value": "Memory of Ethereum"
    }
  ]
}
```

上传到 IPFS 后，更新 BASE_URI：

```bash
# 在部署脚本中设置
string constant BASE_URI = "ipfs://YOUR_CID/";
```

## ⚙️ 配置说明

### Foundry 配置 (foundry.toml)

```toml
[profile.default]
solc = "0.8.24"
optimizer = true
optimizer_runs = 200
via_ir = true  # 重要：解决 Stack too deep 问题

[rpc_endpoints]
sepolia = "${SEPOLIA_RPC_URL}"
mainnet = "${MAINNET_RPC_URL}"

[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}" }
mainnet = { key = "${ETHERSCAN_API_KEY}" }
```

### Gas 优化

- ✅ 使用 `via_ir` 编译模式
- ✅ Merkle Tree 白名单验证
- ✅ 优化的存储布局
- ✅ 批量操作支持

## 🔍 合约验证

### 自动验证

部署时自动验证：
```bash
npm run deploy:sepolia
```

### 手动验证

如果自动验证失败：
```bash
export CONTRACT_ADDRESS=0x...
export BASE_URI=ipfs://YOUR_CID/
export DEFAULT_ADMIN=0x...

npm run verify:sepolia
```

详细说明请参考 [VERIFY.md](./VERIFY.md)

## 📚 相关文档

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [ERC-1155 Standard](https://eips.ethereum.org/EIPS/eip-1155)
- [Merkle Tree 说明](https://en.wikipedia.org/wiki/Merkle_tree)

## 🛡️ 安全考虑

### 已实施的安全措施

- ✅ OpenZeppelin 标准合约库
- ✅ 完整的单元测试覆盖
- ✅ 权限控制和访问限制
- ✅ 重入攻击保护（使用 OpenZeppelin 的 ReentrancyGuard 模式）
- ✅ 整数溢出保护（Solidity 0.8+）
- ✅ 自动退款机制

### 审计建议

在主网部署前建议：
- 🔒 进行专业的安全审计
- 🔒 在测试网进行充分测试
- 🔒 使用多签钱包管理 DEFAULT_ADMIN_ROLE
- 🔒 设置合理的供应量和价格
- 🔒 准备应急暂停机制

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

**Built with ❤️ for the Ethereum Community**

