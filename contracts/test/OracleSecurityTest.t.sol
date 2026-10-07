// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MiniOracle.sol";
import "../src/LendingProtocol.sol";

contract MockDEX is ISpotDEX {
    uint256 public price;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function getSpotPrice() external view override returns (uint256) {
        return price;
    }
}

contract OracleSecurityTest is Test {
    MiniOracle public oracle;
    LendingProtocol public lending;
    MockDEX public dex;

    uint256 internal signerPrivateKey = 0xA11CE;
    address internal signer;

    function setUp() public {
        signer = vm.addr(signerPrivateKey);
        oracle = new MiniOracle(signer);
        dex = new MockDEX();
        lending = new LendingProtocol(address(oracle), address(dex));

        dex.setPrice(3000 * 1e18);

        uint256 initialPrice = 3000 * 1e18;
        uint256 initialTimestamp = block.timestamp;
        bytes memory sig = signPrice(initialPrice, initialTimestamp, signerPrivateKey);
        oracle.updatePrice(initialPrice, initialTimestamp, sig);
    }

    function signPrice(
        uint256 price,
        uint256 timestamp,
        uint256 pk
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(price, timestamp, block.chainid, address(oracle))
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    function test_RevertOnUnauthorizedSignature() public {
        uint256 maliciousPk = 0xBAD;
        uint256 newPrice = 3100 * 1e18;
        uint256 newTimestamp = block.timestamp + 10;

        vm.warp(block.timestamp + 10);
        bytes memory maliciousSig = signPrice(newPrice, newTimestamp, maliciousPk);

        vm.expectRevert(MiniOracle.InvalidSignature.selector);
        oracle.updatePrice(newPrice, newTimestamp, maliciousSig);
    }

    function test_RevertOnStaleTimestamp() public {
        uint256 newPrice = 3100 * 1e18;
        uint256 staleTimestamp = block.timestamp - 1;
        bytes memory sig = signPrice(newPrice, staleTimestamp, signerPrivateKey);

        vm.expectRevert(MiniOracle.StaleData.selector);
        oracle.updatePrice(newPrice, staleTimestamp, sig);
    }

    function test_FlashLoanManipulationPoC() public {
        address borrower = address(0x200);
        vm.deal(borrower, 10 ether);

        vm.startPrank(borrower);
        lending.depositCollateral{value: 10 ether}();
        lending.borrowProtected(15000 * 1e18);
        vm.stopPrank();

        dex.setPrice(1000 * 1e18);

        vm.expectRevert(LendingProtocol.HealthyPosition.selector);
        lending.liquidateProtected(borrower);

        lending.liquidateVulnerable(borrower);
        assertEq(lending.userCollateral(borrower), 0);
    }

    function testFuzz_PriceAggregationRobustness(uint256[5] memory rawNodePrices) public view {
        uint256[5] memory sorted;
        for (uint256 i = 0; i < 5; i++) {
            sorted[i] = bound(rawNodePrices[i], 100 * 1e18, 10000 * 1e18);
        }

        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = i + 1; j < 5; j++) {
                if (sorted[i] > sorted[j]) {
                    uint256 temp = sorted[i];
                    sorted[i] = sorted[j];
                    sorted[j] = temp;
                }
            }
        }
        uint256 medianPrice = sorted[2];

        assertTrue(medianPrice >= sorted[0]);
        assertTrue(medianPrice <= sorted[4]);

        sorted[4] = sorted[4] * 100;
        uint256 recalculatedMedian = sorted[2];
        assertEq(recalculatedMedian, medianPrice);
    }
}
