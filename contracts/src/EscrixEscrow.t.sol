// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "./EscrixEscrow.sol";

/**
 * Foundry test suite for EscrixEscrow
 * Run with: forge test -vv
 */

// Minimal USDC mock for testing
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount,            "insufficient balance");
        require(allowance[from][msg.sender] >= amount, "insufficient allowance");
        balanceOf[from]               -= amount;
        balanceOf[to]                 += amount;
        allowance[from][msg.sender]   -= amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to]         += amount;
        return true;
    }
}

contract EscrixEscrowTest is Test {
    EscrixEscrow public escrow;
    MockUSDC     public usdc;

    address poster   = address(0x1);
    address executor = address(0x2);
    address treasury = address(0x3);
    address verifier = address(this); // test contract is verifier

    uint256 constant REWARD = 10e6; // 10 USDC
    bytes32 constant SPEC_HASH   = keccak256("test_spec");
    bytes32 constant RESULT_HASH = keccak256("test_result");

    function setUp() public {
        usdc   = new MockUSDC();
        escrow = new EscrixEscrow(treasury);

        // Fund poster and executor
        usdc.mint(poster,   100e6);
        usdc.mint(executor, 100e6);

        // Mock the USDC address used by the contract
        // (In production, use Base USDC; here we use vm.etch)
        vm.etch(escrow.USDC(), address(usdc).code);
    }

    // ── Happy path: create → accept → submit → verify PASS ────────────────────
    function testHappyPath() public {
        // Poster creates task
        vm.startPrank(poster);
        MockUSDC(escrow.USDC()).approve(address(escrow), REWARD);
        bytes32 taskId = escrow.createTask(SPEC_HASH, REWARD);
        vm.stopPrank();

        // Verify task is OPEN
        EscrixEscrow.Task memory t = escrow.getTask(taskId);
        assertEq(uint(t.status), uint(EscrixEscrow.Status.OPEN));
        assertEq(t.rewardUsdc, REWARD);

        // Executor accepts
        uint256 bond = (REWARD * 500) / 10_000; // 5%
        vm.startPrank(executor);
        MockUSDC(escrow.USDC()).approve(address(escrow), bond);
        escrow.acceptTask(taskId);
        vm.stopPrank();

        t = escrow.getTask(taskId);
        assertEq(uint(t.status), uint(EscrixEscrow.Status.ACCEPTED));

        // Executor submits result
        vm.prank(executor);
        escrow.submitResult(taskId, RESULT_HASH);

        t = escrow.getTask(taskId);
        assertEq(uint(t.status), uint(EscrixEscrow.Status.SUBMITTED));

        // Verifier approves
        uint256 executorBalBefore = MockUSDC(escrow.USDC()).balanceOf(executor);
        escrow.verify(taskId, true, "All tests passed");

        t = escrow.getTask(taskId);
        assertEq(uint(t.status), uint(EscrixEscrow.Status.VERIFIED_PASS));

        // Executor received reward - fee + bond back
        uint256 fee             = (REWARD * 30) / 10_000;
        uint256 expectedPayout  = REWARD - fee + bond;
        uint256 executorBalAfter = MockUSDC(escrow.USDC()).balanceOf(executor);
        assertEq(executorBalAfter - executorBalBefore, expectedPayout);
    }

    // ── Fail path: verify FAIL → poster refunded, bond slashed ────────────────
    function testVerifyFail() public {
        vm.startPrank(poster);
        MockUSDC(escrow.USDC()).approve(address(escrow), REWARD);
        bytes32 taskId = escrow.createTask(SPEC_HASH, REWARD);
        vm.stopPrank();

        uint256 bond = (REWARD * 500) / 10_000;
        vm.startPrank(executor);
        MockUSDC(escrow.USDC()).approve(address(escrow), bond);
        escrow.acceptTask(taskId);
        escrow.submitResult(taskId, RESULT_HASH);
        vm.stopPrank();

        uint256 posterBalBefore = MockUSDC(escrow.USDC()).balanceOf(poster);
        escrow.verify(taskId, false, "Tests failed: assertion error");

        // Poster gets full refund
        uint256 posterBalAfter = MockUSDC(escrow.USDC()).balanceOf(poster);
        assertEq(posterBalAfter - posterBalBefore, REWARD);

        // Bond goes to protocol fees
        assertEq(escrow.protocolFeesAccrued(), bond);
    }

    // ── Cancel: poster cancels open task ──────────────────────────────────────
    function testCancelOpenTask() public {
        vm.startPrank(poster);
        MockUSDC(escrow.USDC()).approve(address(escrow), REWARD);
        bytes32 taskId = escrow.createTask(SPEC_HASH, REWARD);

        uint256 balBefore = MockUSDC(escrow.USDC()).balanceOf(poster);
        escrow.cancelTask(taskId);
        uint256 balAfter  = MockUSDC(escrow.USDC()).balanceOf(poster);

        assertEq(balAfter - balBefore, REWARD);
        vm.stopPrank();
    }

    // ── Access control: non-verifier cannot call verify ───────────────────────
    function testOnlyVerifierCanVerify() public {
        vm.startPrank(poster);
        MockUSDC(escrow.USDC()).approve(address(escrow), REWARD);
        bytes32 taskId = escrow.createTask(SPEC_HASH, REWARD);
        vm.stopPrank();

        uint256 bond = (REWARD * 500) / 10_000;
        vm.startPrank(executor);
        MockUSDC(escrow.USDC()).approve(address(escrow), bond);
        escrow.acceptTask(taskId);
        escrow.submitResult(taskId, RESULT_HASH);

        // executor is not a verifier
        vm.expectRevert("not verifier");
        escrow.verify(taskId, true, "attempt");
        vm.stopPrank();
    }
}
