# Duckee Contract

🧱 AI NFT &amp; Marketplace Contracts of Duckee.

## Getting Started

### Deploying Contract

### Emulator

The easiest way to try Duckee Art NFT contracts is to deploy it on the emulator first—
you can deploy it with preconfigured key.

```
 $ flow emulator &
 $ flow project deploy -n=emulator
```

### Testnet

You need to set up your private key in `testnet-account.key` and edit the account in `flow.json`.

```
 $ flow generate keys
 $ flow project deploy -n=testnet
```

## Setting Up

### 1. Set up ChildAccountCreator

```
 $ flow transactions send -n=testnet --authorizer testnet-account --proposer testnet-account --payer testnet-account ./transactions/setup-child-account-creator.cdc
```
