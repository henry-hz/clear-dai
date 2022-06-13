# Much Clearer DAI

> _'First the spot files the vat, which grabs the cat. The cat calls fess on the vow, which can kick the flap to move the vat. Couldn't be simpler.' - Nick Johnson_


### Changed filenames:

- ~pot.sol~ -> daiSavingsRate.sol
- ~end.sol~ -> globalSettlement.sol
- ~lib.sol~ -> commonFunctions.sol
- ~join.sol~ -> adapters.sol
- ~flip.sol~ -> collateralAuction.sol
- ~flap.sol~ -> surplusAuction.sol
- ~vat.sol~ -> CDPEngine.sol
- ~cat.sol~ -> liquidations.sol
- ~flop.sol~ -> debtAuction.sol
- ~jug.sol~ -> stabilityFees.sol
- ~spot.sol~ -> oracle.sol
- ~vow.sol~ -> settlement.sol

### Other remarkable changes

- Some uint variables that only used 0 or 1 values were transformed into bools (`uint256 ward`, which is a flag to check if an account is authorized is now `bool authorizedAccounts`, `uint256 live`, a flag to check if DSR is active is now `bool DSRisActive`)
- the library contract Note is now LogEmitter (because its purpose is to emit logs) and now was expanded to include the common `auth` pattern.
- Gems are renamed to Tokens wherever they are found. And so are derivatives: so `gemLike`, a contract pattern to have a very simple token is therefore called `SimpleToken` and so on.
- Flip and Flap both are auctions that exchange Collateral Tokens for DAI, in opposite directions. Assuming DAI takes the place of an usual currency, we can name these auctions the much more commonly used verb in english, "to buy" and "to sell".

You can see a much longer list of changes in [this link](https://github.com/makerdao/dss/compare/master...alexvansande:master)
This is a work in progress and we welcome your feedback!


## Sources


- [Maker Protocol 101](https://docs.makerdao.com/maker-protocol-101)
- [Glossary](https://docs.makerdao.com/other-documentation/system-glossary) (you know, because why make the code clearer in the first place?)
- [Smart contract annotations](https://docs.makerdao.com/other-documentation/smart-contract-annotations)

---

# Multi Collateral Dai

This repository contains the core smart contract code for Multi
Collateral Dai. This is a high level description of the system, assuming
familiarity with the basic economic mechanics as described in the
whitepaper.

## Additional Documentation

`dss` is also documented in the [wiki](https://github.com/makerdao/dss/wiki) and in [DEVELOPING.md](https://github.com/makerdao/dss/blob/master/DEVELOPING.md)

## Design Considerations

- Token agnostic

  - system doesn't care about the implementation of external tokens
  - can operate entirely independently of other systems, provided an authority assigns
    initial collateral to users in the system and provides price data.

- Verifiable

  - designed from the bottom up to be amenable to formal verification
  - the core cdp and balance database makes _no_ external calls and
    contains _no_ precision loss (i.e. no division)

- Modular
  - multi contract core system is made to be very adaptable to changing
    requirements.
  - allows for implementations of e.g. auctions, liquidation, CDP risk
    conditions, to be altered on a live system.
  - allows for the addition of novel collateral types (e.g. whitelisting)

## Collateral, Adapters and Wrappers

Collateral is the foundation of Dai and Dai creation is not possible
without it. There are many potential candidates for collateral, whether
native ether, ERC20 tokens, other fungible token standards like ERC777,
non-fungible tokens, or any number of other financial instruments.

Token wrappers are one solution to the need to standardise collateral
behaviour in Dai. Inconsistent decimals and transfer semantics are
reasons for wrapping. For example, the WETH token is an ERC20 wrapper
around native ether.

In MCD, we abstract all of these different token behaviours away behind
_Adapters_.

Adapters manipulate a single core system function: `slip`, which
modifies user collateral balances.

Adapters should be very small and well defined contracts. Adapters are
very powerful and should be carefully vetted by MKR holders. Some
examples are given in `join.sol`. Note that the adapter is the only
connection between a given collateral type and the concrete on-chain
token that it represents.

There can be a multitude of adapters for each collateral type, for
different requirements. For example, ETH collateral could have an
adapter for native ether and _also_ for WETH.

## The Dai Token

The fundamental state of a Dai balance is given by the balance in the
core (`vat.dai`, sometimes referred to as `D`).

Given this, there are a number of ways to implement the Dai that is used
outside of the system, with different trade offs.

_Fundamentally, "Dai" is any token that is directly fungible with the
core._

In the Kovan deployment, "Dai" is represented by an ERC20 DSToken.
After interacting with CDPs and auctions, users must `exit` from the
system to gain a balance of this token, which can then be used in Oasis
etc.

It is possible to have multiple fungible Dai tokens, allowing for the
adoption of new token standards. This needs careful consideration from a
UX perspective, with the notion of a canonical token address becoming
increasingly restrictive. In the future, cross-chain communication and
scalable sidechains will likely lead to a proliferation of multiple Dai
tokens. Users of the core could `exit` into a Plasma sidechain, an
Ethereum shard, or a different blockchain entirely via e.g. the Cosmos
Hub.

## Price Feeds

Price feeds are a crucial part of the Dai system. The code here assumes
that there are working price feeds and that their values are being
pushed to the contracts.

Specifically, the price that is required is the highest acceptable
quantity of CDP Dai debt per unit of collateral.

## Liquidation and Auctions

An important difference between SCD and MCD is the switch from fixed
price sell offs to auctions as the means of liquidating collateral.

The auctions implemented here are simple and expect liquidations to
occur in _fixed size lots_ (say 10,000 ETH).

## Settlement

Another important difference between SCD and MCD is in the handling of
System Debt. System Debt is debt that has been taken from risky CDPs.
In SCD this is covered by diluting the collateral pool via the PETH
mechanism. In MCD this is covered by dilution of an external token,
namely MKR.

As in collateral liquidation, this dilution occurs by an auction
(`flop`), using a fixed-size lot.

In order to reduce the collateral intensity of large CDP liquidations,
MKR dilution is delayed by a configurable period (e.g 1 week).

Similarly, System Surplus is handled by an auction (`flap`), which sells
off Dai surplus in return for the highest bidder in MKR.

## Authentication

The contracts here use a very simple multi-owner authentication system,
where a contract totally trusts multiple other contracts to call its
functions and configure it.

It is expected that modification of this state will be via an interface
that is used by the Governance layer.
