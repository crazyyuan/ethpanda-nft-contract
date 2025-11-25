// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EthereumOfMemoryNFT} from "../src/EthereumOfMemoryNFT.sol";

contract EthereumOfMemoryNFTTest is Test {
    EthereumOfMemoryNFT public nft;

    address public admin;
    address public admin2;
    address public user1;
    address public user2;
    address public user3;

    string constant NAME = "Memory of Ethereum";
    string constant SYMBOL = "MoE";
    string constant BASE_URI = "https://api.example.com/metadata/";

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    uint256 public tokenId1;
    uint256 public tokenId2;

    bytes32 public merkleRoot;
    bytes32[] public merkleProof1;
    bytes32[] public merkleProof2;

    event TokenCreated(
        uint256 indexed tokenId,
        string upgradeName,
        uint256 maxSupply
    );
    event TokenConfigUpdated(uint256 indexed tokenId);
    event WhitelistPhaseStarted(
        uint256 indexed tokenId,
        uint256 startTime,
        uint256 price
    );
    event PublicPhaseStarted(
        uint256 indexed tokenId,
        uint256 startTime,
        uint256 price
    );
    event MintPermanentlyEnded(
        uint256 indexed tokenId,
        uint256 remainingSupply
    );
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

    function setUp() public {
        admin = address(this);
        admin2 = makeAddr("admin2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        nft = new EthereumOfMemoryNFT(NAME, SYMBOL, BASE_URI, admin);

        // 为测试用户提供 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        // 创建两个 Token（默认价格为 0）
        tokenId1 = nft.createToken("Shapella", 10000, 5, 1, 0, 0);
        tokenId2 = nft.createToken("Dencun", 8000, 3, 2, 0, 0);

        // 设置 Merkle Tree (user1 和 user2 在白名单中)
        bytes32 leaf1 = keccak256(abi.encodePacked(user1));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2));

        // 正确的 Merkle root 计算：排序后再 hash
        bytes32 node;
        if (leaf1 < leaf2) {
            node = keccak256(abi.encodePacked(leaf1, leaf2));
        } else {
            node = keccak256(abi.encodePacked(leaf2, leaf1));
        }
        merkleRoot = node;

        merkleProof1 = new bytes32[](1);
        merkleProof1[0] = leaf2;

        merkleProof2 = new bytes32[](1);
        merkleProof2[0] = leaf1;

        // 设置白名单
        nft.setMerkleRoot(tokenId1, merkleRoot);
        nft.setMerkleRoot(tokenId2, merkleRoot);
    }

    // ========== 基础功能测试 ==========

    function testInitialState() public view {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.currentTokenId(), 2);
        assertTrue(nft.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(nft.hasRole(ADMIN_ROLE, admin));
    }

    function testCreateToken() public {
        vm.expectEmit(true, false, false, true);
        emit TokenCreated(3, "Fusaka", 5000);

        uint256 newTokenId = nft.createToken("Fusaka", 5000, 2, 1, 0, 0);

        assertEq(newTokenId, 3);
        assertEq(nft.currentTokenId(), 3);

        (
            string memory upgradeName,
            uint256 maxSupply,
            ,
            uint256 whitelistMax,
            uint256 publicMax,
            uint256 whitelistPrice,
            uint256 publicPrice,
            ,

        ) = nft.getTokenInfo(newTokenId);

        assertEq(upgradeName, "Fusaka");
        assertEq(maxSupply, 5000);
        assertEq(whitelistMax, 2);
        assertEq(publicMax, 1);
        assertEq(whitelistPrice, 0);
        assertEq(publicPrice, 0);
    }

    function testCreateTokenWithPrice() public {
        uint256 newTokenId = nft.createToken(
            "Fusaka",
            5000,
            2,
            1,
            0.01 ether,
            0.02 ether
        );

        (, , , , , uint256 whitelistPrice, uint256 publicPrice, , ) = nft
            .getTokenInfo(newTokenId);

        assertEq(whitelistPrice, 0.01 ether);
        assertEq(publicPrice, 0.02 ether);
    }

    function testCreateTokenDefaultPriceZero() public {
        // 明确测试默认价格为 0
        uint256 newTokenId = nft.createToken("Fusaka", 5000, 2, 1, 0, 0);

        (, , , , , uint256 whitelistPrice, uint256 publicPrice, , ) = nft
            .getTokenInfo(newTokenId);

        assertEq(whitelistPrice, 0);
        assertEq(publicPrice, 0);
    }

    function testGetTokenInfo() public view {
        (
            string memory upgradeName,
            uint256 maxSupply,
            uint256 currentSupply,
            uint256 whitelistMax,
            uint256 publicMax,
            uint256 whitelistPrice,
            uint256 publicPrice,
            EthereumOfMemoryNFT.MintPhase phase,
            bool ended
        ) = nft.getTokenInfo(tokenId1);

        assertEq(upgradeName, "Shapella");
        assertEq(maxSupply, 10000);
        assertEq(currentSupply, 0);
        assertEq(whitelistMax, 5);
        assertEq(publicMax, 1);
        assertEq(whitelistPrice, 0);
        assertEq(publicPrice, 0);
        assertEq(
            uint256(phase),
            uint256(EthereumOfMemoryNFT.MintPhase.NotStarted)
        );
        assertEq(ended, false);
    }

    function testUpdateTokenConfig() public {
        // 更新 token 配置
        vm.expectEmit(true, false, false, false);
        emit TokenConfigUpdated(tokenId1);

        nft.updateTokenConfig(
            tokenId1,
            12000, // 新的 maxSupply
            10, // 新的 whitelistMax
            3, // 新的 publicMax
            0.01 ether, // whitelistPrice
            0.02 ether // publicPrice
        );

        (
            ,
            uint256 maxSupply,
            ,
            uint256 whitelistMax,
            uint256 publicMax,
            uint256 whitelistPrice,
            uint256 publicPrice,
            ,

        ) = nft.getTokenInfo(tokenId1);

        assertEq(maxSupply, 12000);
        assertEq(whitelistMax, 10);
        assertEq(publicMax, 3);
        assertEq(whitelistPrice, 0.01 ether);
        assertEq(publicPrice, 0.02 ether);
    }

    function testUpdateTokenConfigOnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.updateTokenConfig(tokenId1, 12000, 10, 3, 0.01 ether, 0.02 ether);
    }

    function testUpdateTokenConfigCannotReduceSupplyBelowCurrent() public {
        // 先 mint 一些
        nft.adminMint(tokenId1, user1, 5000);

        // 尝试将 maxSupply 设置为低于当前供应量
        vm.expectRevert("Max supply less than current supply");
        nft.updateTokenConfig(tokenId1, 4000, 5, 1, 0, 0);
    }

    function testUpdateTokenConfigAfterMintEnded() public {
        nft.startWhitelistPhase(tokenId1, 0);
        nft.startPublicPhase(tokenId1, 0);
        nft.endMintPermanently(tokenId1);

        vm.expectRevert("Token mint has ended");
        nft.updateTokenConfig(tokenId1, 12000, 10, 3, 0, 0);
    }

    function testUpdateTokenConfigInvalidTokenId() public {
        vm.expectRevert("Invalid token ID");
        nft.updateTokenConfig(999, 10000, 5, 1, 0, 0);
    }

    // ========== 管理员功能测试 ==========

    function testAddAdmin() public {
        vm.expectEmit(true, false, false, false);
        emit AdminAdded(admin2);

        nft.addAdmin(admin2);

        assertTrue(nft.hasRole(ADMIN_ROLE, admin2));
        assertTrue(nft.isAdmin(admin2));
    }

    function testRemoveAdmin() public {
        nft.addAdmin(admin2);

        vm.expectEmit(true, false, false, false);
        emit AdminRemoved(admin2);

        nft.removeAdmin(admin2);

        assertFalse(nft.hasRole(ADMIN_ROLE, admin2));
        assertFalse(nft.isAdmin(admin2));
    }

    // ========== Phase 管理测试 ==========

    function testStartWhitelistPhase() public {
        vm.expectEmit(true, false, false, true);
        emit WhitelistPhaseStarted(tokenId1, block.timestamp, 0);

        nft.startWhitelistPhase(tokenId1, 0);

        assertEq(
            uint256(nft.getCurrentPhase(tokenId1)),
            uint256(EthereumOfMemoryNFT.MintPhase.Whitelist)
        );
    }

    function testStartWhitelistPhaseWithPrice() public {
        uint256 price = 0.01 ether;
        nft.startWhitelistPhase(tokenId1, price);

        (, , , , , uint256 whitelistPrice, , , ) = nft.getTokenInfo(tokenId1);
        assertEq(whitelistPrice, price);
    }

    function testStartPublicPhase() public {
        nft.startWhitelistPhase(tokenId1, 0);

        vm.expectEmit(true, false, false, true);
        emit PublicPhaseStarted(tokenId1, block.timestamp, 0);

        nft.startPublicPhase(tokenId1, 0);

        assertEq(
            uint256(nft.getCurrentPhase(tokenId1)),
            uint256(EthereumOfMemoryNFT.MintPhase.Public)
        );
    }

    function testStartPublicPhaseWithPrice() public {
        nft.startWhitelistPhase(tokenId1, 0);

        uint256 price = 0.02 ether;
        nft.startPublicPhase(tokenId1, price);

        (, , , , , , uint256 publicPrice, , ) = nft.getTokenInfo(tokenId1);
        assertEq(publicPrice, price);
    }

    // ========== 默认价格测试 ==========

    function testDefaultPriceIsZero() public view {
        // 验证新创建的 token 默认价格为 0
        (, , , , , uint256 whitelistPrice, uint256 publicPrice, , ) = nft
            .getTokenInfo(tokenId1);
        assertEq(whitelistPrice, 0);
        assertEq(publicPrice, 0);
    }

    function testMintWithZeroPrice() public {
        // 价格为 0 时，不需要发送 ETH
        nft.startWhitelistPhase(tokenId1, 0);

        vm.prank(user1);
        nft.whitelistMint(tokenId1, 1, merkleProof1);

        assertEq(nft.balanceOf(user1, tokenId1), 1);
        assertEq(address(nft).balance, 0);
    }

    function testMintWithZeroPriceCanSendETH() public {
        // 即使价格为 0，也可以发送 ETH（会被退回）
        nft.startWhitelistPhase(tokenId1, 0);

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        nft.whitelistMint{value: 1 ether}(tokenId1, 1, merkleProof1);

        uint256 balanceAfter = user1.balance;

        // ETH 应该被全部退回
        assertEq(balanceBefore, balanceAfter);
        assertEq(address(nft).balance, 0);
    }

    function testCanSetPriceViaUpdateConfig() public {
        // 通过 updateTokenConfig 设置价格
        nft.updateTokenConfig(tokenId1, 10000, 5, 1, 0.01 ether, 0.02 ether);

        (, , , , , uint256 whitelistPrice, uint256 publicPrice, , ) = nft
            .getTokenInfo(tokenId1);
        assertEq(whitelistPrice, 0.01 ether);
        assertEq(publicPrice, 0.02 ether);

        // 然后启动阶段
        nft.startWhitelistPhase(tokenId1, 0.015 ether); // 可以在启动时覆盖价格

        (, , , , , uint256 updatedWhitelistPrice, , , ) = nft.getTokenInfo(
            tokenId1
        );
        assertEq(updatedWhitelistPrice, 0.015 ether);
    }

    function testPriceCanBeChangedBeforePhaseStarts() public {
        // 在阶段开始前可以多次更新价格
        nft.updateTokenConfig(tokenId1, 10000, 5, 1, 0.01 ether, 0.02 ether);
        nft.updateTokenConfig(tokenId1, 10000, 5, 1, 0.02 ether, 0.03 ether);

        (, , , , , uint256 whitelistPrice, uint256 publicPrice, , ) = nft
            .getTokenInfo(tokenId1);
        assertEq(whitelistPrice, 0.02 ether);
        assertEq(publicPrice, 0.03 ether);
    }

    // ========== Whitelist Mint 测试 ==========

    function testWhitelistMintFree() public {
        nft.startWhitelistPhase(tokenId1, 0);

        uint256 amount = 3;

        vm.expectEmit(true, true, false, true);
        emit WhitelistMint(tokenId1, user1, amount, 0);

        vm.prank(user1);
        nft.whitelistMint(tokenId1, amount, merkleProof1);

        assertEq(nft.balanceOf(user1, tokenId1), amount);
        assertEq(nft.whitelistMinted(tokenId1, user1), amount);
    }

    function testWhitelistMintWithPrice() public {
        uint256 price = 0.01 ether;
        nft.startWhitelistPhase(tokenId1, price);

        uint256 amount = 2;
        uint256 totalPrice = price * amount;

        vm.prank(user1);
        nft.whitelistMint{value: totalPrice}(tokenId1, amount, merkleProof1);

        assertEq(nft.balanceOf(user1, tokenId1), amount);
        assertEq(address(nft).balance, totalPrice);
    }

    function testWhitelistMintRefundsExcess() public {
        uint256 price = 0.01 ether;
        nft.startWhitelistPhase(tokenId1, price);

        uint256 amount = 1;
        uint256 totalPrice = price * amount;
        uint256 sentValue = totalPrice + 0.05 ether;

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        nft.whitelistMint{value: sentValue}(tokenId1, amount, merkleProof1);

        uint256 balanceAfter = user1.balance;
        assertEq(balanceBefore - balanceAfter, totalPrice);
        assertEq(address(nft).balance, totalPrice);
    }

    function testWhitelistMintInsufficientPayment() public {
        uint256 price = 0.01 ether;
        nft.startWhitelistPhase(tokenId1, price);

        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        nft.whitelistMint{value: 0.005 ether}(tokenId1, 1, merkleProof1);
    }

    function testWhitelistMintExceedsAllocation() public {
        nft.startWhitelistPhase(tokenId1, 0);

        vm.startPrank(user1);
        nft.whitelistMint(tokenId1, 3, merkleProof1);

        vm.expectRevert("Exceeds whitelist allocation");
        nft.whitelistMint(tokenId1, 3, merkleProof1);
        vm.stopPrank();
    }

    function testWhitelistMintInvalidProof() public {
        nft.startWhitelistPhase(tokenId1, 0);

        vm.prank(user3);
        vm.expectRevert("Invalid merkle proof");
        nft.whitelistMint(tokenId1, 1, merkleProof1);
    }

    // ========== Public Mint 测试 ==========

    function testPublicMintFree() public {
        nft.startWhitelistPhase(tokenId1, 0);
        nft.startPublicPhase(tokenId1, 0);

        vm.prank(user3);
        vm.expectEmit(true, true, false, true);
        emit PublicMint(tokenId1, user3, 1, 0);

        nft.publicMint(tokenId1, 1);

        assertEq(nft.balanceOf(user3, tokenId1), 1);
        assertEq(nft.publicMinted(tokenId1, user3), 1);
    }

    function testPublicMintWithPrice() public {
        nft.startWhitelistPhase(tokenId1, 0);

        uint256 price = 0.02 ether;
        nft.startPublicPhase(tokenId1, price);

        uint256 amount = 1;
        uint256 totalPrice = price * amount;

        vm.prank(user3);
        nft.publicMint{value: totalPrice}(tokenId1, amount);

        assertEq(nft.balanceOf(user3, tokenId1), amount);
        assertEq(address(nft).balance, totalPrice);
    }

    function testPublicMintExceedsAllocation() public {
        nft.startWhitelistPhase(tokenId1, 0);
        nft.startPublicPhase(tokenId1, 0);

        vm.startPrank(user3);
        nft.publicMint(tokenId1, 1);

        vm.expectRevert("Exceeds public allocation");
        nft.publicMint(tokenId1, 1);
        vm.stopPrank();
    }

    function testPublicMintInsufficientPayment() public {
        nft.startWhitelistPhase(tokenId1, 0);

        uint256 price = 0.02 ether;
        nft.startPublicPhase(tokenId1, price);

        vm.prank(user3);
        vm.expectRevert("Insufficient payment");
        nft.publicMint{value: 0.01 ether}(tokenId1, 1);
    }

    function testPublicMintRefundsExcess() public {
        nft.startWhitelistPhase(tokenId1, 0);

        uint256 price = 0.02 ether;
        nft.startPublicPhase(tokenId1, price);

        uint256 balanceBefore = user3.balance;

        vm.prank(user3);
        nft.publicMint{value: 0.1 ether}(tokenId1, 1);

        uint256 balanceAfter = user3.balance;
        assertEq(balanceBefore - balanceAfter, price);
        assertEq(address(nft).balance, price);
    }

    // ========== Admin Mint 测试 ==========

    function testAdminMint() public {
        uint256 amount = 100;

        nft.adminMint(tokenId1, user1, amount);

        assertEq(nft.balanceOf(user1, tokenId1), amount);
        assertEq(nft.totalSupply(tokenId1), amount);
    }

    function testAdminMintMultipleTokens() public {
        nft.adminMint(tokenId1, user1, 50);
        nft.adminMint(tokenId2, user1, 30);

        assertEq(nft.balanceOf(user1, tokenId1), 50);
        assertEq(nft.balanceOf(user1, tokenId2), 30);
    }

    // ========== 数据隔离测试 ==========

    function testTokenIsolation() public {
        // 为 token1 启动白名单
        nft.startWhitelistPhase(tokenId1, 0.01 ether);

        // 为 token2 启动白名单，价格不同
        nft.startWhitelistPhase(tokenId2, 0.02 ether);

        // token1 的 mint 不影响 token2
        vm.prank(user1);
        nft.whitelistMint{value: 0.03 ether}(tokenId1, 3, merkleProof1);

        assertEq(nft.balanceOf(user1, tokenId1), 3);
        assertEq(nft.balanceOf(user1, tokenId2), 0);
        assertEq(nft.whitelistMinted(tokenId1, user1), 3);
        assertEq(nft.whitelistMinted(tokenId2, user1), 0);

        // user1 还可以 mint token2
        vm.prank(user1);
        nft.whitelistMint{value: 0.06 ether}(tokenId2, 3, merkleProof1);

        assertEq(nft.balanceOf(user1, tokenId2), 3);
        assertEq(nft.whitelistMinted(tokenId2, user1), 3);
    }

    function testDifferentSupplyLimits() public {
        // token1 max supply: 10000
        // token2 max supply: 8000

        nft.adminMint(tokenId1, user1, 10000);
        assertEq(nft.totalSupply(tokenId1), 10000);

        vm.expectRevert("Exceeds max supply");
        nft.adminMint(tokenId1, user2, 1);

        // token2 仍然可以 mint
        nft.adminMint(tokenId2, user1, 8000);
        assertEq(nft.totalSupply(tokenId2), 8000);
    }

    function testDifferentMintLimits() public {
        // token1: whitelist 5, public 1
        // token2: whitelist 3, public 2

        nft.startWhitelistPhase(tokenId1, 0);
        nft.startWhitelistPhase(tokenId2, 0);

        // token1 可以 mint 5
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 5, merkleProof1);
        assertEq(nft.balanceOf(user1, tokenId1), 5);

        // token2 只能 mint 3
        vm.prank(user1);
        nft.whitelistMint(tokenId2, 3, merkleProof1);
        assertEq(nft.balanceOf(user1, tokenId2), 3);

        vm.prank(user1);
        vm.expectRevert("Exceeds whitelist allocation");
        nft.whitelistMint(tokenId2, 1, merkleProof1);
    }

    // ========== 价格组合测试 ==========

    function testDifferentPricesForDifferentTokens() public {
        // token1: 免费
        // token2: 付费
        nft.startWhitelistPhase(tokenId1, 0);
        nft.startWhitelistPhase(tokenId2, 0.01 ether);

        // token1 免费 mint
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 1, merkleProof1);
        assertEq(address(nft).balance, 0);

        // token2 付费 mint
        vm.prank(user1);
        nft.whitelistMint{value: 0.03 ether}(tokenId2, 3, merkleProof1);
        assertEq(address(nft).balance, 0.03 ether);
    }

    function testDifferentPricesForWhitelistAndPublic() public {
        // 白名单便宜，公开贵
        nft.startWhitelistPhase(tokenId1, 0.01 ether);
        nft.startPublicPhase(tokenId1, 0.05 ether);

        // 检查价格设置
        (, , , , , uint256 whitelistPrice, uint256 publicPrice, , ) = nft
            .getTokenInfo(tokenId1);
        assertEq(whitelistPrice, 0.01 ether);
        assertEq(publicPrice, 0.05 ether);

        // 公开 mint 应该使用公开价格
        vm.prank(user3);
        nft.publicMint{value: 0.05 ether}(tokenId1, 1);
        assertEq(address(nft).balance, 0.05 ether);
    }

    function testWhitelistFreePublicPaid() public {
        // 白名单免费，公开付费
        nft.startWhitelistPhase(tokenId1, 0);

        // 白名单免费 mint（在公开阶段开始前）
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 1, merkleProof1);
        assertEq(address(nft).balance, 0);

        // 开始公开阶段
        nft.startPublicPhase(tokenId1, 0.02 ether);

        // 公开付费 mint
        vm.prank(user3);
        nft.publicMint{value: 0.02 ether}(tokenId1, 1);
        assertEq(address(nft).balance, 0.02 ether);
    }

    function testWhitelistPaidPublicFree() public {
        // 白名单付费，公开免费（不常见但应该支持）
        nft.startWhitelistPhase(tokenId1, 0.01 ether);
        nft.startPublicPhase(tokenId1, 0);

        // 公开免费 mint
        vm.prank(user3);
        nft.publicMint(tokenId1, 1);
        assertEq(address(nft).balance, 0);
    }

    function testMultipleMintsDifferentPrices() public {
        // 多次 mint，累计金额
        nft.startWhitelistPhase(tokenId1, 0.01 ether);

        vm.startPrank(user1);
        nft.whitelistMint{value: 0.01 ether}(tokenId1, 1, merkleProof1);
        nft.whitelistMint{value: 0.02 ether}(tokenId1, 2, merkleProof1);
        nft.whitelistMint{value: 0.02 ether}(tokenId1, 2, merkleProof1);
        vm.stopPrank();

        assertEq(nft.balanceOf(user1, tokenId1), 5);
        assertEq(address(nft).balance, 0.05 ether);
    }

    function testExactPayment() public {
        // 测试精确支付（不多不少）
        nft.startWhitelistPhase(tokenId1, 0.01 ether);

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        nft.whitelistMint{value: 0.03 ether}(tokenId1, 3, merkleProof1);

        uint256 balanceAfter = user1.balance;
        assertEq(balanceBefore - balanceAfter, 0.03 ether);
        assertEq(address(nft).balance, 0.03 ether);
    }

    // ========== 提现测试 ==========

    function testWithdraw() public {
        // 先收集一些 ETH
        nft.startWhitelistPhase(tokenId1, 0.01 ether);

        vm.prank(user1);
        nft.whitelistMint{value: 0.05 ether}(tokenId1, 5, merkleProof1);

        uint256 contractBalance = address(nft).balance;
        uint256 recipientBalanceBefore = admin2.balance;

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(admin2, contractBalance);

        nft.withdraw(payable(admin2));

        assertEq(address(nft).balance, 0);
        assertEq(admin2.balance, recipientBalanceBefore + contractBalance);
    }

    function testWithdrawMultipleSources() public {
        // 从多个 token 和阶段收集资金
        nft.startWhitelistPhase(tokenId1, 0.01 ether);
        nft.startWhitelistPhase(tokenId2, 0.015 ether);

        // token1 白名单
        vm.prank(user1);
        nft.whitelistMint{value: 0.05 ether}(tokenId1, 5, merkleProof1);

        // 开始 token1 公开阶段
        nft.startPublicPhase(tokenId1, 0.02 ether);

        // token1 公开
        vm.prank(user3);
        nft.publicMint{value: 0.02 ether}(tokenId1, 1);

        // token2 白名单
        vm.prank(user2);
        nft.whitelistMint{value: 0.045 ether}(tokenId2, 3, merkleProof2);

        uint256 totalCollected = 0.05 ether + 0.02 ether + 0.045 ether;
        assertEq(address(nft).balance, totalCollected);

        // 提现
        nft.withdraw(payable(admin));
        assertEq(address(nft).balance, 0);
    }

    function testWithdrawOnlyAdmin() public {
        nft.startWhitelistPhase(tokenId1, 0.01 ether);

        vm.prank(user1);
        nft.whitelistMint{value: 0.01 ether}(tokenId1, 1, merkleProof1);

        vm.prank(user2);
        vm.expectRevert();
        nft.withdraw(payable(user2));
    }

    function testWithdrawNoFunds() public {
        vm.expectRevert("No funds to withdraw");
        nft.withdraw(payable(admin));
    }

    // ========== End Mint 测试 ==========

    function testEndMintPermanently() public {
        nft.startWhitelistPhase(tokenId1, 0);
        nft.startPublicPhase(tokenId1, 0);

        nft.adminMint(tokenId1, user1, 100);
        uint256 remaining = nft.remainingSupply(tokenId1);

        vm.expectEmit(true, false, false, true);
        emit MintPermanentlyEnded(tokenId1, remaining);

        nft.endMintPermanently(tokenId1);

        assertEq(
            uint256(nft.getCurrentPhase(tokenId1)),
            uint256(EthereumOfMemoryNFT.MintPhase.Ended)
        );
        assertEq(nft.remainingSupply(tokenId1), 0);

        // tokenId2 不受影响
        assertEq(
            uint256(nft.getCurrentPhase(tokenId2)),
            uint256(EthereumOfMemoryNFT.MintPhase.NotStarted)
        );
    }

    function testCannotMintAfterEnded() public {
        nft.startWhitelistPhase(tokenId1, 0);
        nft.startPublicPhase(tokenId1, 0);
        nft.endMintPermanently(tokenId1);

        vm.prank(user1);
        vm.expectRevert("Mint has permanently ended");
        nft.whitelistMint(tokenId1, 1, merkleProof1);

        vm.prank(user3);
        vm.expectRevert("Mint has permanently ended");
        nft.publicMint(tokenId1, 1);

        vm.expectRevert("Mint has permanently ended");
        nft.adminMint(tokenId1, user1, 1);
    }

    // ========== URI 测试 ==========

    function testURI() public view {
        string memory expectedURI = string(
            abi.encodePacked(BASE_URI, "1.json")
        );
        assertEq(nft.uri(tokenId1), expectedURI);

        expectedURI = string(abi.encodePacked(BASE_URI, "2.json"));
        assertEq(nft.uri(tokenId2), expectedURI);
    }

    function testInvalidTokenId() public {
        vm.expectRevert("Invalid token ID");
        nft.uri(999);
    }

    // ========== 其他测试 ==========

    function testBurn() public {
        nft.adminMint(tokenId1, user1, 10);

        vm.prank(user1);
        nft.burn(user1, tokenId1, 3);

        assertEq(nft.balanceOf(user1, tokenId1), 7);
        assertEq(nft.totalSupply(tokenId1), 7);
    }

    function testTransfer() public {
        nft.adminMint(tokenId1, user1, 10);

        vm.prank(user1);
        nft.safeTransferFrom(user1, user2, tokenId1, 3, "");

        assertEq(nft.balanceOf(user1, tokenId1), 7);
        assertEq(nft.balanceOf(user2, tokenId1), 3);
    }

    function testCompleteFlow() public {
        // 创建新 token（带价格）
        uint256 newTokenId = nft.createToken(
            "Fusaka",
            5000,
            2,
            1,
            0.01 ether,
            0.02 ether
        );
        nft.setMerkleRoot(newTokenId, merkleRoot);

        // 白名单阶段（使用创建时设置的价格，或者覆盖）
        nft.startWhitelistPhase(newTokenId, 0.01 ether);

        vm.prank(user1);
        nft.whitelistMint{value: 0.02 ether}(newTokenId, 2, merkleProof1);

        // 公开阶段
        nft.startPublicPhase(newTokenId, 0.02 ether);

        vm.prank(user3);
        nft.publicMint{value: 0.02 ether}(newTokenId, 1);

        // 验证
        assertEq(nft.balanceOf(user1, newTokenId), 2);
        assertEq(nft.balanceOf(user3, newTokenId), 1);
        assertEq(nft.totalSupply(newTokenId), 3);

        // 提现
        uint256 expectedBalance = 0.04 ether;
        assertEq(address(nft).balance, expectedBalance);

        nft.withdraw(payable(admin));
        assertEq(address(nft).balance, 0);
    }

    receive() external payable {}
}
