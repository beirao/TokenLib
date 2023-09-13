// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Safe Native and ERC20 transfer library with native token abstraction
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
///
/// @dev Note:
/// - This library help you managing ERC20 and Native tokens using a standardized syntax
/// - This lib abstract native token (ETH, MATIC...) as the address(0)
/// @dev added comparing to SafeTransferLib:
/// - For ERC20s, this implementation new check that a token has code
/// - For ERC20s, now check for 0 amount approval/transfer without throwing an error (https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers, https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers)

library SafeTokenLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ETH transfer has failed.
    error ETHTransferFailed();

    /// @dev The ERC20 `transferFrom` has failed.
    error TransferFromFailed();

    /// @dev The ERC20 `transfer` has failed.
    error TransferFailed();

    /// @dev The ERC20 `approve` has failed.
    error ApproveFailed();

    /// @dev The native transfer amount doesn't match the receive value
    error InvalidNativeTransferAmount();

    /// @dev We can't perform a permit operation on native token
    error PermitOnNativeToken();

    /// @dev The token address is not valid
    error InvalidToken();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC20/Native OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` of ERC20 or native `token` from msg.sender to `to`.
    /// Reverts upon failure.
    ///
    /// The msg.sender account must have at least `amount` approved for
    /// the current contract to manage.
    function safeTransferFromSender(
        address token,
        address to,
        uint256 amount
    ) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Revert on Zero Value Transfer fix: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers
            if iszero(amount) {
                return(0, 0)
            }
            switch token
            // In the case of a native token, no transfer from is possible, so whe just check the sent amount
            case 0 {
                if iszero(eq(callvalue(), amount)) {
                    mstore(0x00, 0xefbc7cbf) // `InvalidNativeTransferAmount()`.
                    revert(0x1c, 0x04)
                }
            }
            default {
                if iszero(extcodesize(token)) {
                    mstore(0x00, 0xc1ab6dc1) // `InvalidToken()`.
                    revert(0x1c, 0x04)
                }
                let m := mload(0x40) // Cache the free memory pointer.
                mstore(0x60, amount) // Store the `amount` argument.
                mstore(0x40, to) // Store the `to` argument.
                mstore(0x2c, shl(96, caller())) // Store the `msg.sender` argument.
                mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
                // Perform the transfer, reverting upon failure.
                if iszero(
                    and(
                        // The arguments of `and` are evaluated from right to left.
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                    )
                ) {
                    mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x60, 0) // Restore the zero slot to zero.
                mstore(0x40, m) // Restore the free memory pointer.
            }
        }
    }

    /// @dev Sends `amount` of ERC20 or native `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransfer(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Revert on Zero Value Transfer fix: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers
            if iszero(amount) {
                return(0, 0)
            }
            switch token
            // if native token safeTransferETH
            case 0 {
                if iszero(call(gas(), to, amount, gas(), 0x00, gas(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            default {
                if iszero(extcodesize(token)) {
                    mstore(0x00, 0xc1ab6dc1) // `InvalidToken()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x14, to) // Store the `to` argument.
                mstore(0x34, amount) // Store the `amount` argument.
                mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
                // Perform the transfer, reverting upon failure.
                if iszero(
                    and(
                        // The arguments of `and` are evaluated from right to left.
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    )
                ) {
                    mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
            }
        }
    }

    /// @dev Sends all of ERC20 `token` or native token (address(0)) from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransferAll(
        address token,
        address to
    ) internal returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            switch token
            // if native token safeTransferAllETH
            case 0 {
                if iszero(
                    call(gas(), to, selfbalance(), gas(), 0x00, gas(), 0x00)
                ) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            default {
                if iszero(extcodesize(token)) {
                    mstore(0x00, 0xc1ab6dc1) // `InvalidToken()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x00, 0x70a08231) // Store the function selector of `balanceOf(address)`.
                mstore(0x20, address()) // Store the address of the current contract.
                // Read the balance, reverting upon failure.
                if iszero(
                    and(
                        // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), token, 0x1c, 0x24, 0x34, 0x20)
                    )
                ) {
                    mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x14, to) // Store the `to` argument.
                amount := mload(0x34) // The `amount` is already at 0x34. We'll need to return it.
                // Revert on Zero Value Transfer fix: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers
                if iszero(amount) {
                    mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
                    return(0, 0)
                }
                mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
                // Perform the transfer, reverting upon failure.
                if iszero(
                    and(
                        // The arguments of `and` are evaluated from right to left.
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    )
                ) {
                    mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
            }
        }
    }

    /// @dev Sets `amount` of ERC20 `token` or native token (address(0)) for `to` to manage on behalf of the current contract.
    /// Reverts upon failure.
    /// if token == address(0x0) (native token) skip
    function safeApprove(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            switch token
            // No need to approve if native token
            case 0 {
                return(0, 0)
            }
            default {
                // Revert on Zero Value Approvals fix: https://github.com/d-xo/weird-erc20#revert-on-zero-value-approvals
                if iszero(amount) {
                    return(0, 0)
                }
                mstore(0x14, to) // Store the `to` argument.
                mstore(0x34, amount) // Store the `amount` argument.
                mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
                // Perform the approval, reverting upon failure.
                if iszero(
                    and(
                        // The arguments of `and` are evaluated from right to left.
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    )
                ) {
                    mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
            }
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// If the initial attempt to approve fails, attempts to reset the approved amount to zero,
    /// then retries the approval again (some tokens, e.g. USDT, requires this).
    /// Reverts upon failure.
    /// if token == address(0x0) (native token) skip
    function safeApproveWithRetry(
        address token,
        address to,
        uint256 amount
    ) internal {
        /// @solidity memory-safe-assembly
        assembly {
            switch token
            // No need to approve if native token
            case 0 {
                return(0, 0)
            }
            default {
                // Revert on Zero Value Approvals fix: https://github.com/d-xo/weird-erc20#revert-on-zero-value-approvals
                if iszero(amount) {
                    return(0, 0)
                }
                mstore(0x14, to) // Store the `to` argument.
                mstore(0x34, amount) // Store the `amount` argument.
                mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
                // Perform the approval, retrying upon failure.
                if iszero(
                    and(
                        // The arguments of `and` are evaluated from right to left.
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    )
                ) {
                    mstore(0x34, 0) // Store 0 for the `amount`.
                    mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
                    pop(call(gas(), token, 0, 0x10, 0x44, 0x00, 0x00)) // Reset the approval.
                    mstore(0x34, amount) // Store back the original `amount`.
                    // Retry the approval, reverting upon failure.
                    if iszero(
                        and(
                            or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                            call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                        )
                    ) {
                        mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                        revert(0x1c, 0x04)
                    }
                }
                mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
            }
        }
    }

    /// @dev Returns the amount of ERC20 `token` owned by `account`.
    /// address(0x0) return native token balance
    /// Returns zero if the `token` does not exist.
    function balanceOf(
        address token,
        address owner
    ) internal view returns (uint256 amount) {
        assembly {
            switch token
            case 0 {
                // Get the native balance of the owner in case of native token
                amount := balance(owner)
            }
            default {
                // Otherwise, get balance from the token
                // From:
                // https://github.com/Vectorized/solady/blob/9ea395bd66b796c7f08afd18a565eea021c98127/src/utils/SafeTransferLib.sol#L366
                mstore(0x14, owner) // Store the `account` argument.
                mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
                amount := mul(
                    mload(0x20),
                    and(
                        // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                    )
                )
            }
        }
    }
}
