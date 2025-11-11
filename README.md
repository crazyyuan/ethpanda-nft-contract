# EthPanda NFT

以太熊猫 NFT 智能合约项目 - 基于 ERC-1155 标准的多代币 NFT 集合。

## 项目概述

EthPanda NFT 是一个基于以太坊的 NFT 项目，使用 ERC-1155 标准支持多种稀有度的 NFT 代币。项目使用 OpenZeppelin 合约库构建，并采用 Foundry 作为开发和测试框架。

## 技术栈

- **合约标准**: ERC-1155 (多代币标准)
- **合约库**: OpenZeppelin Contracts v5.1.0
- **开发框架**: Foundry
- **Solidity 版本**: ^0.8.24

## 主要特性

- ✅ **多代币支持**: 使用 ERC-1155 标准，支持多种稀有度的 NFT
- ✅ **供应量控制**: 每种 token 可设置最大供应量
- ✅ **灵活定价**: 每种 token 可独立设置铸造价格
- ✅ **批量操作**: 支持批量铸造和转账
- ✅ **销毁机制**: 支持 NFT 销毁
- ✅ **暂停功能**: 可暂停/恢复铸造
- ✅ **所有者权限**: 所有者可免费铸造和管理合约
- ✅ **资金提取**: 所有者可提取合约收益

## 项目结构

```
ethpanda-nft/
├── src/
│   └── EthPandaNFT.sol          # 主合约
├── test/
│   └── EthPandaNFT.t.sol        # 测试文件
├── script/
│   └── Deploy.s.sol             # 部署脚本
├── lib/
│   ├── forge-std/               # Foundry 标准库
│   └── openzeppelin-contracts/  # OpenZeppelin 合约库 v5.1.0
├── foundry.toml                 # Foundry 配置
├── remappings.txt               # 导入路径映射
└── README.md
```

## 安装和设置

### 前置要求

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)

### 安装依赖

```bash
# 克隆仓库
git clone <repository-url>
cd ethpanda-nft

# 初始化子模块
git submodule update --init --recursive
```

### 配置环境变量

复制环境变量模板并填写配置：

```bash
cp .env.example .env
```

编辑 `.env` 文件，填入你的配置：

```bash
PRIVATE_KEY=your_private_key_here
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
ETHERSCAN_API_KEY=your_etherscan_api_key_here
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
forge test --match-test testMint

# 查看测试覆盖率
forge coverage
```

### 本地测试

```bash
# 启动本地节点
anvil

# 在另一个终端部署到本地网络
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast
```

## 部署

### 部署到测试网

```bash
# 部署到 Sepolia 测试网
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# 设置初始 token 类型
forge script script/Deploy.s.sol:SetupScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

### 部署到主网

```bash
# 部署到以太坊主网 (谨慎操作!)
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify
```

## 合约功能

### 管理员功能

```solidity
// 创建新的 token 类型
createToken(uint256 tokenId, uint256 maxSupply, uint256 mintPrice)

// 所有者免费铸造
ownerMint(address to, uint256 tokenId, uint256 amount)
ownerMintBatch(address to, uint256[] tokenIds, uint256[] amounts)

// 更新配置
setBaseURI(string newBaseURI)
updateMaxSupply(uint256 tokenId, uint256 newMaxSupply)
updateMintPrice(uint256 tokenId, uint256 newPrice)
toggleMintPause()

// 提取资金
withdraw()
```

### 用户功能

```solidity
// 铸造 NFT
mint(address to, uint256 tokenId, uint256 amount) payable
mintBatch(address to, uint256[] tokenIds, uint256[] amounts) payable

// 销毁 NFT
burn(address account, uint256 tokenId, uint256 amount)
burnBatch(address account, uint256[] tokenIds, uint256[] amounts)

// 转账
safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data)
safeBatchTransferFrom(address from, address to, uint256[] ids, uint256[] amounts, bytes data)

// 查询
balanceOf(address account, uint256 id)
balanceOfBatch(address[] accounts, uint256[] ids)
uri(uint256 tokenId)
```

## 使用示例

### 创建 Token 类型

```solidity
// 创建普通熊猫 (Token ID: 1)
nft.createToken(1, 1000, 0.01 ether);

// 创建稀有熊猫 (Token ID: 2)
nft.createToken(2, 500, 0.05 ether);
```

### 铸造 NFT

```javascript
// 用户铸造
await nft.mint(userAddress, 1, 5, { value: ethers.parseEther("0.05") });

// 批量铸造
await nft.mintBatch(
  userAddress,
  [1, 2],
  [3, 2],
  { value: ethers.parseEther("0.13") } // 0.01*3 + 0.05*2
);
```

## 安全考虑

- ✅ 使用 OpenZeppelin 审计过的合约库
- ✅ 实现了访问控制 (Ownable)
- ✅ 防止重入攻击
- ✅ 供应量限制检查
- ✅ 支付金额验证
- ✅ 自动退还多余 ETH

## 测试覆盖

项目包含全面的测试套件：

- ✅ 合约初始化测试
- ✅ Token 创建测试
- ✅ 铸造功能测试
- ✅ 批量操作测试
- ✅ 销毁功能测试
- ✅ 权限控制测试
- ✅ 边界条件测试
- ✅ Fuzz 测试

运行测试以验证：

```bash
forge test -vvv
```

## Gas 优化

合约经过优化以降低 gas 消耗：

- 使用 `uint256` 避免额外的转换
- 批量操作减少交易次数
- 合理的存储布局
- Solidity 0.8.24 的优化器

查看 gas 报告：

```bash
forge test --gas-report
```

## 许可证

MIT License

## 联系方式

- GitHub: [项目仓库]
- 文档: [项目文档]
- Discord: [社区链接]

## 致谢

- [OpenZeppelin](https://www.openzeppelin.com/) - 安全的智能合约库
- [Foundry](https://github.com/foundry-rs/foundry) - 快速的以太坊开发工具链

---

**警告**: 这是一个示例项目。在主网部署前，请务必进行完整的安全审计。
