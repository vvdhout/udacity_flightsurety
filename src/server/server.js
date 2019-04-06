import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

const statusCodes = [0,10,20,30,40,50];
let oracles= {};
let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);


web3.eth.getAccounts().then((accounts) => { 
	console.log(accounts);
     flightSuretyApp.methods.REGISTRATION_FEE().call()
     .then((fee) => {
      for(let i = 1; i < 50 ; i++) {
        flightSuretyApp.methods.registerOracle().send({ from: accounts[i], value: fee, gas:5000000 })
        .then((result) => {
          flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]})
          .then((indexes) => {
            oracles[accounts[i]] = indexes;
            console.log("Oracle with address: " + accounts[i] + " and indexes:" + indexes + "has been registered.");
          })
        }) 
        .catch(error => {
          console.log("Error while registering oracles: " + accounts[i] +  " Error: " + error);
        });           
      }
     })  
});


flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, eventResult) {
    if (error) console.log(error)
    else {
      const index = eventResult.returnValues.index;
      const airline = eventResult.returnValues.airline;
      const flight = eventResult.returnValues.flight;
      const timestamp = eventResult.returnValues.timestamp;      
      //let randomstatusCode = STATUSCODES[Math.floor(Math.random()*STATUSCODES.length)];
      //console.log("statuscode is:" + randomstatusCode);
      for(let oracle in oracles)
      {
        let indexes = oracles[oracle];
        if(indexes.includes(index))
        {          
          let randomstatusCode = statusCodes[Math.floor(Math.random() * statusCodes.length)];;
          flightSuretyApp.methods.submitOracleResponse(index, airline, flight, timestamp, randomstatusCode)       
          .send({ from: oracle,gas:5000001})
          .then(result =>{
            console.log("Oracle [" + oracle + "] send statuscode: "  + randomstatusCode + " for "+ flight + " and index:"+ index);
          })
          .catch(error =>{
            console.log("Error sending Oracle response for "+ flight + " Error:" + error)
          });      
           
        }
      }
      //console.log(event);

    }
    
}); 

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})


export default app;
