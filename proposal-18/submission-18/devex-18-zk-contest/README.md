# Submission for Free-TON DevEx Contest 18 "Groth16 Use Cases"

By Thomas Sibut-Pinote and Fabrice Le Fessant at OCamlPro.

A detailed description of this submission is available in the
"submission" sub-directory ([PDF](submission/submission.pdf)).

## Introduction

This submission is composed of 3 use cases. As such, the jury can
consider it as one submission or as several submissions:

* Use case "01_sudoku" shows how the general problem of Sudoku can be
  encoded in Zksnarks. It's mostly Thomas' work.

* Use case "02_euler" shows how Zksnarks can be used for running the
  Euler contests. It's a joint work between Thomas and Fabrice.

* Use case "03_pincode" shows how Zksnarks can be used to provide a
  "backup" solution if a user lose his secret key. It's mostly Fabrice's work.

In general, all these use cases show how a first user can prepare a
challenge, and then another user can show that he can solve the
challenge, without providing the solution on the network. As a
consequence, other users cannot know the solution. The solution is
also attached to the user, in the sense that another user cannot
replay the solution for himself, as the solution is attached to the
user's pubkey.

## Preliminaries

Before you run our code, you need to be able to compile the contest
repository
(https://github.com/NilFoundation/ton-proof-verification-contest). On
Ubuntu 21.04, it should be enough to have installed the following
packages: `git make cmake g++ libboost-all-dev` (make sure that
libboost has version at least 1.74). Pulling and compiling the
repository will be done automatically by our test scripts, but it will
fail if there are missing packages.

You also very likely will want to install our in-house Freeton Wallet
`ft`. The easiest way to install it is through docker
(https://hub.docker.com/r/ocamlpro/ft), or alternatively with opam
(https://ocamlpro.github.io/freeton_wallet/sphinx/install.html#build-and-install). The
scripts assume the `ft` executable lives somewhere in your path.

## Architecture

Each use-case contains:

* The directory "cpp/" contains the C++ client. The client is used in
  two steps: (1) the user creating the challenge calls the client to
  create a proving key (used to generate proofs for submissions to the
  challenge) and a verification key (used to verify the proofs in the
  smart contracts); (2) a user can then use the client with his
  submission arguments to create a "proof" that his solution solves
  the challenge. This proof can be submitted to the smart contract
  (with his pubkey) to verify that he actually solved the challenge.

* The directory "contracts/" contains the Solidity smart contracts.
  Usually, they mimic the two steps of the C++ client: in the first
  step, a contract is deployed with the verification key of the
  challenge; in the second step, a user can submit a proof together
  with his pubkey, and the contracts verifies that the proof matches
  the verification key AND the pubkey of the user. In case of success,
  it triggers some business logic specific to the use case.

  Note that for use cases 2 and 3, the proving key is also published
  in the contract, because it is important to make it available, but
  it is not used by the contract itself. Usually, proving keys are big
  (about 96 kB), but they can be compressed efficiently (about 3 kB)
  in our use cases, so we expect users to publish this
  zipped-version. The proving key for Sudoku is too big to be
  published on the blockchain, however.

* The directory "tests/" contains a set of scripts to deploy the
  contracts either on a sandbox (local network with patched TONOS SE)
  or on the test network provided by Nil Foundation. The scripts test
  a full scenario from the challenge creation to a successful user
  submission.

We heavily use the 'ft' tool to build the Solidity smart contract and
test them. The easiest way to get 'ft' is through its Docker image on
https://hub.docker.com/r/ocamlpro/ft , that has been updated with
NilFoundation tooling for this contest. Using the source code version
from https://github.com/ocamlpro/freeton_wallet is more challenging as
it requires to build the NilFoundation tools (solc, tvm_linker,
tonos-cli) yourself and copy them in $HOME/.ft/bin/ .
