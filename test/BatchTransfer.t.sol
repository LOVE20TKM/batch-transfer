// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {BatchTransfer} from "../src/BatchTransfer.sol";
import {IBatchTransferErrors} from "../src/interface/IBatchTransfer.sol";

contract MockERC20 {
    string public constant name = "Mock Token";
    string public constant symbol = "MOCK";
    uint8 public constant decimals = 18;

    bool public returnFalse;
    bool public revertTransfer;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function setReturnFalse(bool returnFalse_) external {
        returnFalse = returnFalse_;
    }

    function setRevertTransfer(bool revertTransfer_) external {
        revertTransfer = revertTransfer_;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (revertTransfer) {
            revert("MOCK_REVERT");
        }
        if (returnFalse) {
            return false;
        }

        require(balanceOf[from] >= amount, "MOCK_BALANCE");
        require(allowance[from][msg.sender] >= amount, "MOCK_ALLOWANCE");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract NoReturnERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function approve(address spender, uint256 amount) external {
        allowance[msg.sender][spender] = amount;
    }

    function transferFrom(address from, address to, uint256 amount) external {
        require(balanceOf[from] >= amount, "NO_RETURN_BALANCE");
        require(allowance[from][msg.sender] >= amount, "NO_RETURN_ALLOWANCE");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract RejectNative {
    receive() external payable {
        revert("REJECT_NATIVE");
    }
}

contract BatchTransferTest is Test {
    BatchTransfer internal batchTransfer;
    MockERC20 internal token;

    address internal sender = address(0xA11CE);
    address internal recipient1 = address(0xB0B);
    address internal recipient2 = address(0xCAFE);
    address internal recipient3 = address(0xD00D);

    function setUp() public {
        batchTransfer = new BatchTransfer();
        token = new MockERC20();
    }

    function testBatchTransferNative() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(1 ether, 2 ether, 3 ether);

        vm.deal(sender, 10 ether);
        vm.prank(sender);
        uint256 totalAmount = batchTransfer.batchTransferNative{value: 6 ether}(recipients, amounts);

        assertEq(totalAmount, 6 ether);
        assertEq(recipient1.balance, 1 ether);
        assertEq(recipient2.balance, 2 ether);
        assertEq(recipient3.balance, 3 ether);
        assertEq(address(batchTransfer).balance, 0);
    }

    function testBatchTransferNativeRevertsOnValueMismatchBeforeTransfer() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(1 ether, 2 ether, 3 ether);

        vm.deal(sender, 10 ether);
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(IBatchTransferErrors.NativeValueMismatch.selector, 6 ether, 5 ether));
        batchTransfer.batchTransferNative{value: 5 ether}(recipients, amounts);

        assertEq(recipient1.balance, 0);
        assertEq(recipient2.balance, 0);
        assertEq(recipient3.balance, 0);
        assertEq(address(batchTransfer).balance, 0);
    }

    function testBatchTransferNativeRevertsOnRejectingRecipient() public {
        RejectNative rejectNative = new RejectNative();
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = address(rejectNative);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;

        vm.deal(sender, 2 ether);
        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBatchTransferErrors.NativeTransferFailed.selector, 1, address(rejectNative), 1 ether
            )
        );
        batchTransfer.batchTransferNative{value: 2 ether}(recipients, amounts);

        assertEq(recipient1.balance, 0);
        assertEq(address(rejectNative).balance, 0);
        assertEq(address(batchTransfer).balance, 0);
    }

    function testBatchTransferERC20() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(100, 200, 300);

        token.mint(sender, 1_000);
        vm.prank(sender);
        token.approve(address(batchTransfer), 600);

        vm.prank(sender);
        uint256 totalAmount = batchTransfer.batchTransferERC20(address(token), recipients, amounts);

        assertEq(totalAmount, 600);
        assertEq(token.balanceOf(sender), 400);
        assertEq(token.balanceOf(recipient1), 100);
        assertEq(token.balanceOf(recipient2), 200);
        assertEq(token.balanceOf(recipient3), 300);
        assertEq(token.balanceOf(address(batchTransfer)), 0);
        assertEq(token.allowance(sender, address(batchTransfer)), 0);
    }

    function testBatchTransferERC20SupportsTokensWithoutReturnValue() public {
        NoReturnERC20 noReturnToken = new NoReturnERC20();
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(100, 200, 300);

        noReturnToken.mint(sender, 1_000);
        vm.prank(sender);
        noReturnToken.approve(address(batchTransfer), 600);

        vm.prank(sender);
        uint256 totalAmount = batchTransfer.batchTransferERC20(address(noReturnToken), recipients, amounts);

        assertEq(totalAmount, 600);
        assertEq(noReturnToken.balanceOf(sender), 400);
        assertEq(noReturnToken.balanceOf(recipient1), 100);
        assertEq(noReturnToken.balanceOf(recipient2), 200);
        assertEq(noReturnToken.balanceOf(recipient3), 300);
    }

    function testBatchTransferERC20RevertsBeforeTransferOnInsufficientBalance() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(100, 200, 300);

        token.mint(sender, 599);
        vm.prank(sender);
        token.approve(address(batchTransfer), 600);

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBatchTransferErrors.ERC20InsufficientBalance.selector, address(token), sender, 599, 600
            )
        );
        batchTransfer.batchTransferERC20(address(token), recipients, amounts);

        assertEq(token.balanceOf(sender), 599);
        assertEq(token.balanceOf(recipient1), 0);
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token.balanceOf(recipient3), 0);
    }

    function testBatchTransferERC20RevertsBeforeTransferOnInsufficientAllowance() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(100, 200, 300);

        token.mint(sender, 1_000);
        vm.prank(sender);
        token.approve(address(batchTransfer), 599);

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBatchTransferErrors.ERC20InsufficientAllowance.selector,
                address(token),
                sender,
                address(batchTransfer),
                599,
                600
            )
        );
        batchTransfer.batchTransferERC20(address(token), recipients, amounts);

        assertEq(token.balanceOf(sender), 1_000);
        assertEq(token.balanceOf(recipient1), 0);
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token.balanceOf(recipient3), 0);
    }

    function testBatchTransferERC20RevertsOnFalseReturn() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(100, 200, 300);

        token.mint(sender, 1_000);
        vm.prank(sender);
        token.approve(address(batchTransfer), 600);
        token.setReturnFalse(true);

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBatchTransferErrors.ERC20TransferFailed.selector, address(token), 0, recipient1, 100
            )
        );
        batchTransfer.batchTransferERC20(address(token), recipients, amounts);

        assertEq(token.balanceOf(sender), 1_000);
        assertEq(token.balanceOf(recipient1), 0);
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token.balanceOf(recipient3), 0);
    }

    function testNativeBalances() public {
        vm.deal(recipient1, 1 ether);
        vm.deal(recipient2, 2 ether);
        vm.deal(recipient3, 3 ether);

        uint256[] memory balances = batchTransfer.nativeBalances(_recipients3());

        assertEq(balances.length, 3);
        assertEq(balances[0], 1 ether);
        assertEq(balances[1], 2 ether);
        assertEq(balances[2], 3 ether);
    }

    function testERC20Balances() public {
        token.mint(recipient1, 100);
        token.mint(recipient2, 200);
        token.mint(recipient3, 300);

        uint256[] memory balances = batchTransfer.erc20Balances(address(token), _recipients3());

        assertEq(balances.length, 3);
        assertEq(balances[0], 100);
        assertEq(balances[1], 200);
        assertEq(balances[2], 300);
    }

    function testAllowsEmptyBalanceQueries() public view {
        address[] memory accounts = new address[](0);

        uint256[] memory nativeBalanceValues = batchTransfer.nativeBalances(accounts);
        uint256[] memory erc20BalanceValues = batchTransfer.erc20Balances(address(token), accounts);

        assertEq(nativeBalanceValues.length, 0);
        assertEq(erc20BalanceValues.length, 0);
    }

    function testRevertsOnLengthMismatch() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.expectRevert(abi.encodeWithSelector(IBatchTransferErrors.ArrayLengthMismatch.selector, 3, 2));
        batchTransfer.batchTransferERC20(address(token), recipients, amounts);
    }

    function testRevertsOnZeroRecipient() public {
        address[] memory recipients = _recipients3();
        recipients[1] = address(0);
        uint256[] memory amounts = _amounts3(100, 200, 300);

        vm.expectRevert(abi.encodeWithSelector(IBatchTransferErrors.ZeroRecipient.selector, 1));
        batchTransfer.batchTransferERC20(address(token), recipients, amounts);
    }

    function testRevertsOnZeroAmount() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(100, 0, 300);

        vm.expectRevert(abi.encodeWithSelector(IBatchTransferErrors.ZeroAmount.selector, 1));
        batchTransfer.batchTransferERC20(address(token), recipients, amounts);
    }

    function testRevertsOnTooManyTransferRecipients() public {
        address[] memory recipients = new address[](batchTransfer.MAX_TRANSFER_RECIPIENTS() + 1);
        uint256[] memory amounts = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            recipients[i] = address(uint160(i + 1));
            amounts[i] = 1;
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                IBatchTransferErrors.BatchTooLarge.selector, recipients.length, batchTransfer.MAX_TRANSFER_RECIPIENTS()
            )
        );
        batchTransfer.batchTransferERC20(address(token), recipients, amounts);
    }

    function testRevertsOnTooManyBalanceAccounts() public {
        address[] memory accounts = new address[](batchTransfer.MAX_BALANCE_ACCOUNTS() + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IBatchTransferErrors.BatchTooLarge.selector, accounts.length, batchTransfer.MAX_BALANCE_ACCOUNTS()
            )
        );
        batchTransfer.nativeBalances(accounts);
    }

    function testRevertsOnInvalidToken() public {
        address[] memory recipients = _recipients3();
        uint256[] memory amounts = _amounts3(100, 200, 300);

        vm.expectRevert(abi.encodeWithSelector(IBatchTransferErrors.InvalidToken.selector, address(0)));
        batchTransfer.batchTransferERC20(address(0), recipients, amounts);

        vm.expectRevert(abi.encodeWithSelector(IBatchTransferErrors.InvalidToken.selector, recipient1));
        batchTransfer.erc20Balances(recipient1, recipients);
    }

    function _recipients3() internal view returns (address[] memory recipients) {
        recipients = new address[](3);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;
    }

    function _amounts3(uint256 amount1, uint256 amount2, uint256 amount3)
        internal
        pure
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](3);
        amounts[0] = amount1;
        amounts[1] = amount2;
        amounts[2] = amount3;
    }
}
