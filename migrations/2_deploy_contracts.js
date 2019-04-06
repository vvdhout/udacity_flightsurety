const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {

    let firstAirline = '0x9693c1720f3c8b76006495670f238ac078205011';
    deployer.deploy(FlightSuretyData,firstAirline, "#1 Airline")
    .then(() => {
        return deployer.deploy(FlightSuretyApp,FlightSuretyData.address)
                .then( async () => {
                    let instance = await FlightSuretyData.deployed();
                    await instance.authorizeContract(FlightSuretyApp.address);
                    let config = {
                        localhost: {
                            url: 'http://localhost:7545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    }
                    fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                });
    });
}