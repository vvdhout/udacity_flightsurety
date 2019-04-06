# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding. MAKE SURE YOU HAVE GANACHE INSTALLED GLOBALLY (we will run on ganache-cli).

To install, download or clone the repo, then:

`npm install`

In a different cmd, run: 
`ganache-cli -a 50 -m "federal purchase shrimp arrest mouse carry aunt sail margin arrest popular vague"`

Go back to the first cmd in which the project folder is open and run:
`truffle compile --reset`

## Develop Client

To use the dapp:

`truffle migrate --reset`

Take the contract address of the deployed FlightSuretyApp contract, copy it, and paste it into the src/dapp/index.html file where we set the 'instance' variable below on the page in the script tag(replace the placeholder address with the newly deployed address).

`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

Before running dApp operations be sure to initiate the server which will simulate oracle behavior. You can do so by running the command below in a Git Bash prompt.

`npm run server`


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)