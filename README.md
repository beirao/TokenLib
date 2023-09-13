# ERC20SafeTransferLibs

The goal of this library is to make you forget about [weird ERC20](https://github.com/d-xo/weird-erc20) by providing the best gas optimized version on `SafeTransferLib()` for your needs:

KiloSafeTransferLib => Classical safe transfer lib

MegaSafeTransferLib => Native token abstraction

GigaSafeTransferLib => Fee on Transfer token support

TeraSafeTransferLib => Rebasing token support

PetaSafeTransferLib => Decimal standardization (18 dec)

## Classification

Here are all usecases we may want to support (inspired by "[weird](https://github.com/d-xo/weird-erc20)"):

    1.  Missing Return Values
    2.  No Revert on Failure
    3.  Native token support (abstracted on `address(0x0)`)
    4.  Fee on Transfer
    5.  Transfer of less than amount
    6.  Balance Modifications Outside of Transfers (rebasing/airdrops)
    7.  Upgradable Tokens (become FoT)
    8.  Approval Race Protections
    9.  Revert on Large Approvals & Transfers
    10. Non string metadata
    11. DAI like permit function ([token ref](https://github.com/yashnaman/tokensWithPermitFunctionList/blob/master/hasDAILikePermitFunctionTokenList.json))
    12. Low/High Decimals
    13. Weird reverts:
        - Revert on Zero Value Approvals
        - Revert on Zero Value Transfers

These weird cases depend on your implementation:

-   Reentrant Calls (use `noReentrant` modifier or repect the Check-Effect-Interaction)
-   Flash Mintable Tokens (care when using `totalSupply()`)
-   Multiple Token Addresses (care with mappings)
-   `transferFrom()` with `src == msg.sender` (care if you rely on allowance value for accounting)

These weird cases that can't be mitigated:

-   Tokens with Blocklists
-   Pausable Tokens
-   Unexpected upgrade

## Developement rules when using these libraries

Never rely on `selfBalance()` => rely on an internal accounting.

The `address(0x0)` become the native token abstraction address:

-   Approvals to zero address will just skip the `approve()` method
-   Transfer to the zero address will just make a `.call{value}()`

Remember that now this is generic behaviors:

    - Revert on Zero Value Approvals
    - Revert on Zero Value Transfers
