// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {MemoryOfEthereumNFT} from "../src/MemoryOfEthereumNFT.sol";

contract RefundReverter is IERC1155Receiver {
    function buyPublic(address payable nftAddr, uint256 tokenId) external payable {
        MemoryOfEthereumNFT(nftAddr).publicMint{value: msg.value}(tokenId, 1);
    }

    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}

contract MemoryOfEthereumNFTTest is Test {
    MemoryOfEthereumNFT public nft;

    address public admin;
    address public admin2;
    address public user1;
    address public user2;
    address public user3;

    string constant NAME = "Memory of Ethereum";
    string constant SYMBOL = "MoE";
    string constant BASE_URI = "https://api.example.com/metadata/";

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

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
    event MintPermanentlyEnded(uint256 indexed tokenId, uint256 mintEndTime);
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
    event TokenURIUpdated(uint256 indexed tokenId, string newURI);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function _setConfig(
        uint256 tokenId,
        uint256 whitelistPrice,
        uint256 publicPrice,
        uint256 whitelistStartTime,
        uint256 publicStartTime
    ) internal {
        (
            ,
            uint256 maxSupply,
            ,
            uint256 whitelistMaxPerAddress,
            uint256 publicMaxPerAddress,
            uint256 curWhitelistPrice,
            uint256 curPublicPrice,
            ,
            ,
            ,

        ) = nft.getTokenInfo(tokenId);
        (uint256 curWhitelistStart, uint256 curPublicStart) = nft.getPhaseTimes(
            tokenId
        );

        uint256 wlPrice = whitelistPrice == type(uint256).max
            ? curWhitelistPrice
            : whitelistPrice;
        uint256 pubPrice = publicPrice == type(uint256).max
            ? curPublicPrice
            : publicPrice;
        uint256 wlStart = whitelistStartTime == type(uint256).max
            ? curWhitelistStart
            : whitelistStartTime;
        uint256 pubStart = publicStartTime == type(uint256).max
            ? curPublicStart
            : publicStartTime;

        nft.updateTokenConfig(
            tokenId,
            maxSupply,
            whitelistMaxPerAddress,
            publicMaxPerAddress,
            wlPrice,
            pubPrice,
            wlStart,
            pubStart
        );
    }

    function _startWhitelist(uint256 tokenId, uint256 price) internal {
        _startWhitelist(tokenId, price, 1 hours);
    }

    function _startWhitelist(
        uint256 tokenId,
        uint256 price,
        uint256 delayToPublic
    ) internal {
        uint256 start = block.timestamp;
        uint256 publicStart = delayToPublic == 0
            ? start
            : start + delayToPublic;
        _setConfig(tokenId, price, type(uint256).max, start, publicStart);
        vm.warp(start);
    }

    function _startPublic(uint256 tokenId, uint256 price) internal {
        uint256 start = block.timestamp;
        _setConfig(
            tokenId,
            type(uint256).max,
            price,
            start > 0 ? start - 1 : 0,
            start
        );
        vm.warp(start);
    }

    function setUp() public {
        admin = address(this);
        admin2 = makeAddr("admin2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        nft = new MemoryOfEthereumNFT(NAME, SYMBOL, BASE_URI);

        // 为测试用户提供 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        uint256 nowTs = block.timestamp;
        // 创建两个 Token（默认价格为 0），设置默认时间：白名单 now+1 天，公开 now+2 天
        tokenId1 = nft.createToken(
            "Shapella",
            10000,
            5,
            1,
            0,
            0,
            nowTs + 1 days,
            nowTs + 2 days,
            true
        );
        tokenId2 = nft.createToken(
            "Dencun",
            8000,
            3,
            2,
            0,
            0,
            nowTs + 1 days,
            nowTs + 2 days,
            true
        );

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
        assertEq(nft.owner(), admin);
        assertTrue(nft.hasRole(ADMIN_ROLE, admin));
    }

    function testCreateToken() public {
        vm.expectEmit(true, false, false, true);
        emit TokenCreated(3, "Fusaka", 5000);

        uint256 newTokenId = nft.createToken(
            "Fusaka",
            5000,
            2,
            1,
            0,
            0,
            block.timestamp,
            block.timestamp + 1 days,
            true
        );

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
            MemoryOfEthereumNFT.MintPhase phase,
            bool ended,
            uint256 mintEndTime,
            bool transferable
        ) = nft.getTokenInfo(newTokenId);

        assertEq(upgradeName, "Fusaka");
        assertEq(maxSupply, 5000);
        assertEq(whitelistMax, 2);
        assertEq(publicMax, 1);
        assertEq(whitelistPrice, 0);
        assertEq(publicPrice, 0);
        assertFalse(ended);
        assertEq(mintEndTime, 0);
        assertTrue(transferable);
    }

    function testCreateTokenWithPrice() public {
        uint256 newTokenId = nft.createToken(
            "Fusaka",
            5000,
            2,
            1,
            0.01 ether,
            0.02 ether,
            block.timestamp,
            block.timestamp + 1 days,
            true
        );

        (, , , , , uint256 whitelistPrice, uint256 publicPrice, , , , ) = nft
            .getTokenInfo(newTokenId);

        assertEq(whitelistPrice, 0.01 ether);
        assertEq(publicPrice, 0.02 ether);
    }

    function testEnforceSBT() public {
        uint256 badgeId = nft.createToken(
            "Badge",
            100,
            1,
            1,
            0,
            0,
            block.timestamp,
            block.timestamp + 1 days,
            false
        );
        uint256 nowTs = block.timestamp;
        nft.updateTokenConfig(badgeId, 100, 1, 1, 0, 0, 0, nowTs + 1);
        vm.warp(nowTs + 1);

        vm.prank(user1);
        nft.publicMint(badgeId, 1);

        vm.prank(user1);
        vm.expectRevert("Transfers disabled");
        nft.safeTransferFrom(user1, user2, badgeId, 1, "");
    }

    function testCreateTokenDefaultPriceZero() public {
        // 明确测试默认价格为 0
        uint256 newTokenId = nft.createToken(
            "Fusaka",
            5000,
            2,
            1,
            0,
            0,
            block.timestamp,
            block.timestamp + 1 days,
            true
        );

        (, , , , , uint256 whitelistPrice, uint256 publicPrice, , , , ) = nft
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
            MemoryOfEthereumNFT.MintPhase phase,
            bool ended,
            uint256 mintEndTime,
            bool transferable
        ) = nft.getTokenInfo(tokenId1);

        assertEq(upgradeName, "Shapella");
        assertEq(maxSupply, 10000);
        assertEq(currentSupply, 0);
        assertEq(whitelistMax, 5);
        assertEq(publicMax, 1);
        assertEq(whitelistPrice, 0);
        assertEq(publicPrice, 0);
        assertTrue(transferable);
        assertEq(
            uint256(phase),
            uint256(MemoryOfEthereumNFT.MintPhase.NotStarted)
        );
        assertEq(ended, false);
    }

    function testUpdateTokenConfig() public {
        // 更新 token 配置
        vm.expectEmit(true, false, false, false);
        emit TokenConfigUpdated(tokenId1);

        (uint256 wlStart, uint256 pubStart) = nft.getPhaseTimes(tokenId1);

        nft.updateTokenConfig(
            tokenId1,
            12000, // 新的 maxSupply
            10, // 新的 whitelistMax
            3, // 新的 publicMax
            0.01 ether, // whitelistPrice
            0.02 ether, // publicPrice
            wlStart,
            pubStart
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
            ,
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
        nft.updateTokenConfig(
            tokenId1,
            12000,
            10,
            3,
            0.01 ether,
            0.02 ether,
            type(uint256).max,
            type(uint256).max
        );
    }

    function testUpdateTokenConfigCannotReduceSupplyBelowCurrent() public {
        // 提高配额并 mint 一些
        (uint256 wlStart, uint256 pubStart) = nft.getPhaseTimes(tokenId1);
        nft.updateTokenConfig(
            tokenId1,
            10000,
            6000,
            6000,
            0,
            0,
            wlStart,
            pubStart
        );
        _startWhitelist(tokenId1, 0);
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 5000, merkleProof1);

        // 尝试将 maxSupply 设置为低于当前供应量
        vm.expectRevert("Max supply less than current supply");
        nft.updateTokenConfig(
            tokenId1,
            4000,
            5,
            1,
            0,
            0,
            type(uint256).max,
            type(uint256).max
        );
    }

    function testUpdateTokenConfigAfterMintEnded() public {
        _startWhitelist(tokenId1, 0);
        _startPublic(tokenId1, 0);
        nft.endMintPermanently(tokenId1);

        vm.expectRevert("Token mint has ended");
        nft.updateTokenConfig(
            tokenId1,
            12000,
            10,
            3,
            0,
            0,
            type(uint256).max,
            type(uint256).max
        );
    }

    function testUpdateTokenConfigInvalidTokenId() public {
        vm.expectRevert("Invalid token ID");
        nft.updateTokenConfig(999, 10000, 5, 1, 0, 0, 0, 0);
    }

    function testPhaseTimeValidationOrdering() public {
        uint256 nowTs = block.timestamp;
        vm.expectRevert("Public must be after whitelist");
        nft.createToken("BadOrder", 100, 1, 1, 0, 0, nowTs + 2 days, nowTs + 1 days, true);
    }

    function testPhaseTimeValidationSkipWhitelistRequiresPublic() public {
        vm.expectRevert("Public start required when skipping whitelist");
        nft.createToken("MissingPublic", 100, 1, 1, 0, 0, 0, 0, true);
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

    function testAdminCanManageAdmins() public {
        nft.addAdmin(admin2);
        assertTrue(nft.hasRole(ADMIN_ROLE, admin2));

        vm.prank(admin2);
        vm.expectRevert("Not owner");
        nft.addAdmin(user1);

        vm.prank(admin2);
        vm.expectRevert("Not owner");
        nft.removeAdmin(admin2);
    }

    function testOwnerCanTransferAndManageAdmins() public {
        address newOwner = admin2;

        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(admin, newOwner);
        nft.transferOwnership(newOwner);
        assertEq(nft.owner(), newOwner);

        // new owner (no roles) can still manage admins
        vm.prank(newOwner);
        nft.addAdmin(user1);
        assertTrue(nft.hasRole(ADMIN_ROLE, user1));

        vm.prank(newOwner);
        nft.removeAdmin(user1);
        assertFalse(nft.hasRole(ADMIN_ROLE, user1));
    }

    // ========== Phase 管理测试 ==========

    function testStartWhitelistPhase() public {
        _startWhitelist(tokenId1, 0);

        assertEq(
            uint256(nft.getCurrentPhase(tokenId1)),
            uint256(MemoryOfEthereumNFT.MintPhase.Whitelist)
        );
    }

    function testStartWhitelistPhaseWithPrice() public {
        uint256 price = 0.01 ether;
        _startWhitelist(tokenId1, price);

        (, , , , , uint256 whitelistPrice, , , , , ) = nft.getTokenInfo(
            tokenId1
        );
        assertEq(whitelistPrice, price);
    }

    function testSetMerkleRootBlockedAfterWhitelistStart() public {
        uint256 nowTs = block.timestamp;
        uint256 wlStart = nowTs + 10;
        uint256 pubStart = wlStart + 10;
        uint256 newId = nft.createToken("Timelock", 100, 1, 1, 0, 0, wlStart, pubStart, true);
        vm.warp(wlStart + 1);
        vm.expectRevert("Whitelist started");
        nft.setMerkleRoot(newId, bytes32(uint256(123)));
    }

    function testStartPublicPhase() public {
        _startWhitelist(tokenId1, 0);

        _startPublic(tokenId1, 0);

        assertEq(
            uint256(nft.getCurrentPhase(tokenId1)),
            uint256(MemoryOfEthereumNFT.MintPhase.Public)
        );
    }

    function testStartPublicPhaseWithPrice() public {
        _startWhitelist(tokenId1, 0);

        uint256 price = 0.02 ether;
        _startPublic(tokenId1, price);

        (, , , , , , uint256 publicPrice, , , , ) = nft.getTokenInfo(tokenId1);
        assertEq(publicPrice, price);
    }

    // ========== 默认价格测试 ==========

    function testDefaultPriceIsZero() public view {
        // 验证新创建的 token 默认价格为 0
        (
            ,
            ,
            ,
            ,
            ,
            uint256 whitelistPrice,
            uint256 publicPrice,
            MemoryOfEthereumNFT.MintPhase _phase,
            bool _ended,
            uint256 _mintEndTime,
            bool _transferable
        ) = nft.getTokenInfo(tokenId1);
        assertEq(whitelistPrice, 0);
        assertEq(publicPrice, 0);
    }

    function testMintWithZeroPrice() public {
        // 价格为 0 时，不需要发送 ETH
        _startWhitelist(tokenId1, 0);

        vm.prank(user1);
        nft.whitelistMint(tokenId1, 1, merkleProof1);

        assertEq(nft.balanceOf(user1, tokenId1), 1);
        assertEq(address(nft).balance, 0);
    }

    function testMintWithZeroPriceCanSendETH() public {
        // 即使价格为 0，也可以发送 ETH（会被退回）
        _startWhitelist(tokenId1, 0);

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
        (uint256 wlStart, uint256 pubStart) = nft.getPhaseTimes(tokenId1);
        nft.updateTokenConfig(
            tokenId1,
            10000,
            5,
            1,
            0.01 ether,
            0.02 ether,
            wlStart,
            pubStart
        );

        (
            ,
            ,
            ,
            ,
            ,
            uint256 whitelistPrice,
            uint256 publicPrice,
            MemoryOfEthereumNFT.MintPhase phase,
            bool ended,
            uint256 mintEndTime,
            bool transferable
        ) = nft.getTokenInfo(tokenId1);
        assertEq(whitelistPrice, 0.01 ether);
        assertEq(publicPrice, 0.02 ether);

        // 然后启动阶段
        _startWhitelist(tokenId1, 0.015 ether); // 可以在启动时覆盖价格

        (, , , , , uint256 updatedWhitelistPrice, , , , , ) = nft.getTokenInfo(
            tokenId1
        );
        assertEq(updatedWhitelistPrice, 0.015 ether);
    }

    function testPriceCanBeChangedBeforePhaseStarts() public {
        // 在阶段开始前可以多次更新价格
        (uint256 wlStart, uint256 pubStart) = nft.getPhaseTimes(tokenId1);
        nft.updateTokenConfig(
            tokenId1,
            10000,
            5,
            1,
            0.01 ether,
            0.02 ether,
            wlStart,
            pubStart
        );
        nft.updateTokenConfig(
            tokenId1,
            10000,
            5,
            1,
            0.02 ether,
            0.03 ether,
            wlStart,
            pubStart
        );

        (
            ,
            ,
            ,
            ,
            ,
            uint256 whitelistPrice,
            uint256 publicPrice,
            MemoryOfEthereumNFT.MintPhase _phase,
            bool _ended,
            uint256 _mintEndTime,
            bool _transferable
        ) = nft.getTokenInfo(tokenId1);
        assertEq(whitelistPrice, 0.02 ether);
        assertEq(publicPrice, 0.03 ether);
    }

    // ========== Whitelist Mint 测试 ==========

    function testWhitelistMintFree() public {
        _startWhitelist(tokenId1, 0);

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
        _startWhitelist(tokenId1, price);

        uint256 amount = 2;
        uint256 totalPrice = price * amount;

        vm.prank(user1);
        nft.whitelistMint{value: totalPrice}(tokenId1, amount, merkleProof1);

        assertEq(nft.balanceOf(user1, tokenId1), amount);
        assertEq(address(nft).balance, totalPrice);
    }

    function testWhitelistMintRefundsExcess() public {
        uint256 price = 0.01 ether;
        _startWhitelist(tokenId1, price);

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

    function testRefundFailsWhenReceiverReverts() public {
        uint256 nowTs = block.timestamp;
        uint256 tokenId = nft.createToken("RefundTest", 100, 1, 1, 0, 0, 0, nowTs + 1, true);
        _setConfig(tokenId, type(uint256).max, type(uint256).max, 0, nowTs + 1);
        vm.warp(nowTs + 2);

        RefundReverter buyer = new RefundReverter();
        vm.expectRevert("Refund failed");
        buyer.buyPublic{value: 1 ether}(payable(address(nft)), tokenId);
    }

    function testWhitelistMintInsufficientPayment() public {
        uint256 price = 0.01 ether;
        _startWhitelist(tokenId1, price);

        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        nft.whitelistMint{value: 0.005 ether}(tokenId1, 1, merkleProof1);
    }

    function testWhitelistMintExceedsAllocation() public {
        _startWhitelist(tokenId1, 0);

        vm.startPrank(user1);
        nft.whitelistMint(tokenId1, 3, merkleProof1);

        vm.expectRevert("Exceeds whitelist allocation");
        nft.whitelistMint(tokenId1, 3, merkleProof1);
        vm.stopPrank();
    }

    function testWhitelistMintInvalidProof() public {
        _startWhitelist(tokenId1, 0);

        vm.prank(user3);
        vm.expectRevert("Invalid merkle proof");
        nft.whitelistMint(tokenId1, 1, merkleProof1);
    }

    // ========== Public Mint 测试 ==========

    function testPublicMintFree() public {
        _startWhitelist(tokenId1, 0);
        _startPublic(tokenId1, 0);

        vm.prank(user3);
        vm.expectEmit(true, true, false, true);
        emit PublicMint(tokenId1, user3, 1, 0);

        nft.publicMint(tokenId1, 1);

        assertEq(nft.balanceOf(user3, tokenId1), 1);
        assertEq(nft.publicMinted(tokenId1, user3), 1);
    }

    function testPublicMintWithPrice() public {
        _startWhitelist(tokenId1, 0);

        uint256 price = 0.02 ether;
        _startPublic(tokenId1, price);

        uint256 amount = 1;
        uint256 totalPrice = price * amount;

        vm.prank(user3);
        nft.publicMint{value: totalPrice}(tokenId1, amount);

        assertEq(nft.balanceOf(user3, tokenId1), amount);
        assertEq(address(nft).balance, totalPrice);
    }

    function testPublicMintExceedsAllocation() public {
        _startWhitelist(tokenId1, 0);
        _startPublic(tokenId1, 0);

        vm.startPrank(user3);
        nft.publicMint(tokenId1, 1);

        vm.expectRevert("Exceeds public allocation");
        nft.publicMint(tokenId1, 1);
        vm.stopPrank();
    }

    function testPublicMintInsufficientPayment() public {
        _startWhitelist(tokenId1, 0);

        uint256 price = 0.02 ether;
        _startPublic(tokenId1, price);

        vm.prank(user3);
        vm.expectRevert("Insufficient payment");
        nft.publicMint{value: 0.01 ether}(tokenId1, 1);
    }

    function testPublicMintRefundsExcess() public {
        _startWhitelist(tokenId1, 0);

        uint256 price = 0.02 ether;
        _startPublic(tokenId1, price);

        uint256 balanceBefore = user3.balance;

        vm.prank(user3);
        nft.publicMint{value: 0.1 ether}(tokenId1, 1);

        uint256 balanceAfter = user3.balance;
        assertEq(balanceBefore - balanceAfter, price);
        assertEq(address(nft).balance, price);
    }

    // ========== 数据隔离测试 ==========

    function testTokenIsolation() public {
        // 为 token1 启动白名单
        _startWhitelist(tokenId1, 0.01 ether);

        // 为 token2 启动白名单，价格不同
        _startWhitelist(tokenId2, 0.02 ether);

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

        (uint256 wlStart1, uint256 pubStart1) = nft.getPhaseTimes(tokenId1);
        nft.updateTokenConfig(
            tokenId1,
            10000,
            10000,
            10000,
            0,
            0,
            wlStart1,
            pubStart1
        );
        _startWhitelist(tokenId1, 0);
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 10000, merkleProof1);
        assertEq(nft.totalSupply(tokenId1), 10000);

        vm.prank(user2);
        vm.expectRevert("Exceeds max supply");
        nft.whitelistMint(tokenId1, 1, merkleProof2);

        // token2 仍然可以 mint
        (uint256 wlStart2, uint256 pubStart2) = nft.getPhaseTimes(tokenId2);
        nft.updateTokenConfig(
            tokenId2,
            8000,
            8000,
            8000,
            0,
            0,
            wlStart2,
            pubStart2
        );
        _startWhitelist(tokenId2, 0);
        vm.prank(user1);
        nft.whitelistMint(tokenId2, 8000, merkleProof1);
        assertEq(nft.totalSupply(tokenId2), 8000);
    }

    function testDifferentMintLimits() public {
        // token1: whitelist 5, public 1
        // token2: whitelist 3, public 2

        _startWhitelist(tokenId1, 0);
        _startWhitelist(tokenId2, 0);

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
        _startWhitelist(tokenId1, 0);
        _startWhitelist(tokenId2, 0.01 ether);

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
        _startWhitelist(tokenId1, 0.01 ether);
        _startPublic(tokenId1, 0.05 ether);

        // 检查价格设置
        (
            ,
            ,
            ,
            ,
            ,
            uint256 whitelistPrice,
            uint256 publicPrice,
            MemoryOfEthereumNFT.MintPhase _phase,
            bool _ended,
            uint256 _mintEndTime,
            bool _transferable
        ) = nft.getTokenInfo(tokenId1);
        assertEq(whitelistPrice, 0.01 ether);
        assertEq(publicPrice, 0.05 ether);

        // 公开 mint 应该使用公开价格
        vm.prank(user3);
        nft.publicMint{value: 0.05 ether}(tokenId1, 1);
        assertEq(address(nft).balance, 0.05 ether);
    }

    function testWhitelistFreePublicPaid() public {
        // 白名单免费，公开付费
        _startWhitelist(tokenId1, 0);

        // 白名单免费 mint（在公开阶段开始前）
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 1, merkleProof1);
        assertEq(address(nft).balance, 0);

        // 开始公开阶段
        _startPublic(tokenId1, 0.02 ether);

        // 公开付费 mint
        vm.prank(user3);
        nft.publicMint{value: 0.02 ether}(tokenId1, 1);
        assertEq(address(nft).balance, 0.02 ether);
    }

    function testWhitelistPaidPublicFree() public {
        // 白名单付费，公开免费（不常见但应该支持）
        _startWhitelist(tokenId1, 0.01 ether);
        _startPublic(tokenId1, 0);

        // 公开免费 mint
        vm.prank(user3);
        nft.publicMint(tokenId1, 1);
        assertEq(address(nft).balance, 0);
    }

    function testMultipleMintsDifferentPrices() public {
        // 多次 mint，累计金额
        _startWhitelist(tokenId1, 0.01 ether);

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
        _startWhitelist(tokenId1, 0.01 ether);

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
        _startWhitelist(tokenId1, 0.01 ether);

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
        _startWhitelist(tokenId1, 0.01 ether);
        _startWhitelist(tokenId2, 0.015 ether);

        // token1 白名单
        vm.prank(user1);
        nft.whitelistMint{value: 0.05 ether}(tokenId1, 5, merkleProof1);

        // 开始 token1 公开阶段
        _startPublic(tokenId1, 0.02 ether);

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
        _startWhitelist(tokenId1, 0.01 ether);

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

    function testWithdrawZeroAddressReverts() public {
        _startWhitelist(tokenId1, 0.01 ether);
        vm.prank(user1);
        nft.whitelistMint{value: 0.01 ether}(tokenId1, 1, merkleProof1);

        vm.expectRevert("Invalid recipient");
        nft.withdraw(payable(address(0)));
    }

    // ========== End Mint 测试 ==========

    function testEndMintPermanently() public {
        (uint256 wlStart, uint256 pubStart) = nft.getPhaseTimes(tokenId1);
        nft.updateTokenConfig(
            tokenId1,
            10000,
            200,
            200,
            0,
            0,
            wlStart,
            pubStart
        );
        _startWhitelist(tokenId1, 0);

        vm.prank(user1);
        nft.whitelistMint(tokenId1, 100, merkleProof1);

        vm.expectEmit(true, false, false, true);
        emit MintPermanentlyEnded(tokenId1, block.timestamp);

        nft.endMintPermanently(tokenId1);

        assertEq(
            uint256(nft.getCurrentPhase(tokenId1)),
            uint256(MemoryOfEthereumNFT.MintPhase.Ended)
        );
        assertEq(nft.remainingSupply(tokenId1), 0);
        (, uint256 maxSupplyAfter, , , , , , , , uint256 mintEndTime, ) = nft
            .getTokenInfo(tokenId1);
        assertEq(maxSupplyAfter, nft.totalSupply(tokenId1));

        // tokenId2 不受影响
        assertEq(
            uint256(nft.getCurrentPhase(tokenId2)),
            uint256(MemoryOfEthereumNFT.MintPhase.NotStarted)
        );
    }

    function testCannotMintAfterEnded() public {
        _startWhitelist(tokenId1, 0);
        _startPublic(tokenId1, 0);
        nft.endMintPermanently(tokenId1);

        vm.prank(user1);
        vm.expectRevert("Mint has permanently ended");
        nft.whitelistMint(tokenId1, 1, merkleProof1);

        vm.prank(user3);
        vm.expectRevert("Mint has permanently ended");
        nft.publicMint(tokenId1, 1);
    }

    function testSkipWhitelistMode() public {
        uint256 nowTs = block.timestamp;
        uint256 publicStart = nowTs + 100;

        // configure public-only token
        _setConfig(
            tokenId1,
            type(uint256).max,
            type(uint256).max,
            0,
            publicStart
        );

        // before public start: NotStarted, whitelist mint blocked, public mint blocked
        assertEq(
            uint256(nft.getCurrentPhase(tokenId1)),
            uint256(MemoryOfEthereumNFT.MintPhase.NotStarted)
        );
        vm.prank(user1);
        vm.expectRevert("Not in whitelist phase");
        nft.whitelistMint(tokenId1, 1, merkleProof1);

        vm.prank(user3);
        vm.expectRevert("Not in public phase");
        nft.publicMint{value: 0}(tokenId1, 1);

        // after public start: phase is Public, whitelist still blocked
        vm.warp(publicStart + 1);
        assertEq(
            uint256(nft.getCurrentPhase(tokenId1)),
            uint256(MemoryOfEthereumNFT.MintPhase.Public)
        );
        vm.prank(user1);
        vm.expectRevert("Not in whitelist phase");
        nft.whitelistMint(tokenId1, 1, merkleProof1);

        // public mint works
        vm.prank(user3);
        nft.publicMint{value: 0}(tokenId1, 1);
        assertEq(nft.balanceOf(user3, tokenId1), 1);
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

    function testTokenURIOverride() public {
        string memory customURI = "https://example.com/custom/1.json";

        vm.expectEmit(true, false, false, true);
        emit TokenURIUpdated(tokenId1, customURI);
        nft.setTokenURI(tokenId1, customURI);

        assertEq(nft.uri(tokenId1), customURI);
    }

    function testSetBaseURIAppliesWhenNoOverride() public {
        string memory newBase = "https://new.example.com/meta/";
        nft.setBaseURI(newBase);
        string memory expectedURI = string(abi.encodePacked(newBase, "1.json"));
        assertEq(nft.uri(tokenId1), expectedURI);
    }

    // ========== 其他测试 ==========

    function testBurn() public {
        (uint256 wlStart, uint256 pubStart) = nft.getPhaseTimes(tokenId1);
        nft.updateTokenConfig(tokenId1, 10000, 20, 20, 0, 0, wlStart, pubStart);
        _startWhitelist(tokenId1, 0);
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 10, merkleProof1);

        vm.prank(user1);
        nft.burn(user1, tokenId1, 3);

        assertEq(nft.balanceOf(user1, tokenId1), 7);
        assertEq(nft.totalSupply(tokenId1), 7);
    }

    function testTransfer() public {
        (uint256 wlStart, uint256 pubStart) = nft.getPhaseTimes(tokenId1);
        nft.updateTokenConfig(tokenId1, 10000, 20, 20, 0, 0, wlStart, pubStart);
        _startWhitelist(tokenId1, 0);
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 10, merkleProof1);

        vm.prank(user1);
        nft.safeTransferFrom(user1, user2, tokenId1, 3, "");

        assertEq(nft.balanceOf(user1, tokenId1), 7);
        assertEq(nft.balanceOf(user2, tokenId1), 3);
    }

    function testBatchTransferBlocksNonTransferable() public {
        uint256 nowTs = block.timestamp;
        uint256 transferableId = tokenId1;
        uint256 soulId = nft.createToken("Soul", 10, 5, 5, 0, 0, 0, nowTs + 1, false);
        _setConfig(soulId, type(uint256).max, type(uint256).max, 0, nowTs + 1);
        _startWhitelist(transferableId, 0);
        vm.warp(nowTs + 2);
        vm.startPrank(user1);
        nft.whitelistMint(transferableId, 1, merkleProof1);
        nft.publicMint(soulId, 1);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        ids[0] = transferableId;
        ids[1] = soulId;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        vm.prank(user1);
        vm.expectRevert("Transfers disabled");
        nft.safeBatchTransferFrom(user1, user2, ids, amounts, "");
    }

    function testCompleteFlow() public {
        // 创建新 token（带价格）
        uint256 nowTs = block.timestamp + 1 hours;
        uint256 newTokenId = nft.createToken(
            "Fusaka",
            5000,
            2,
            1,
            0.01 ether,
            0.02 ether,
            nowTs,
            nowTs + 1 days,
            true
        );
        nft.setMerkleRoot(newTokenId, merkleRoot);

        // 白名单阶段（使用创建时设置的价格）
        vm.warp(nowTs);

        vm.prank(user1);
        nft.whitelistMint{value: 0.02 ether}(newTokenId, 2, merkleProof1);

        // 公开阶段
        vm.warp(nowTs + 1 days + 1);

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

    function testRemainingSupplyZeroAfterEndMint() public {
        _startWhitelist(tokenId1, 0);
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 1, merkleProof1);
        nft.endMintPermanently(tokenId1);
        assertEq(nft.remainingSupply(tokenId1), 0);
    }

    function testWhitelistAndPublicRemainingHelpers() public {
        // not in phase returns 0
        assertEq(nft.whitelistRemainingForAddress(tokenId1, user1), 0);
        assertEq(nft.publicRemainingForAddress(tokenId1, user1), 0);

        _startWhitelist(tokenId1, 0);
        assertEq(nft.whitelistRemainingForAddress(tokenId1, user1), 5);
        vm.prank(user1);
        nft.whitelistMint(tokenId1, 2, merkleProof1);
        assertEq(nft.whitelistRemainingForAddress(tokenId1, user1), 3);

        _startPublic(tokenId1, 0);
        assertEq(nft.publicRemainingForAddress(tokenId1, user1), 1);
        vm.prank(user1);
        nft.publicMint(tokenId1, 1);
        assertEq(nft.publicRemainingForAddress(tokenId1, user1), 0);
    }

    function testVerifyWhitelistArrayLengthMismatch() public {
        address[] memory accounts = new address[](1);
        accounts[0] = user1;
        bytes32[][] memory proofs = new bytes32[][](2);
        vm.expectRevert("Arrays length mismatch");
        nft.verifyWhitelist(tokenId1, accounts, proofs);
    }

    function testVerifyWhitelistBatch() public view {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user3;
        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = merkleProof1;
        proofs[1] = new bytes32[](1);
        proofs[1][0] = merkleProof1[0];
        bool[] memory res = nft.verifyWhitelist(tokenId1, accounts, proofs);
        assertTrue(res[0]);
        assertFalse(res[1]);
    }

    function testGetPhaseTimesGetter() public view {
        (uint256 wlStart, uint256 pubStart) = nft.getPhaseTimes(tokenId1);
        uint256 nowTs = block.timestamp;
        assertEq(wlStart, nowTs + 1 days);
        assertEq(pubStart, nowTs + 2 days);
    }

    receive() external payable {}
}
