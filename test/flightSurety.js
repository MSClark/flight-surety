
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
const web3 = require("web3");
const {re} = require("@babel/core/lib/vendor/import-meta-resolve");

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(` (multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(` (multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

  });

  it(` (multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try {
          await config.flightSuretyData.setOperatingStatus(false);
      } catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

    // ARRANGE
    let newAirline = accounts[2];
    let insufficientFundingError;
    // ACT
    try {
        await config.flightSuretyApp.registerAirline("testName", newAirline, {from: config.firstAirline});
    }
    catch(e) {
        console.log(e)
        insufficientFundingError = e
    }
    // ASSERT
    assert.equal(insufficientFundingError, "Error: VM Exception while processing transaction: revert 10 eth required to register airline", "Airline should not be able to register if it has not funded enough");

  });

  it('(multiparty) fifth and subsequent airline registration requires 50% votes', async () => {
      const cost = web3.utils.toWei('10', "ether");
      try {
          await config.flightSuretyApp.registerAirline("2nd airline", config.testAddresses[1], { from: config.owner, value: cost });
          await config.flightSuretyApp.registerAirline("3rd airline", config.testAddresses[2], { from: config.owner, value: cost });
          await config.flightSuretyApp.registerAirline("4th airline", config.testAddresses[3], { from: config.owner, value: cost });
          await config.flightSuretyApp.registerAirline("5th airline", config.testAddresses[4], { from: config.owner, value: cost });
      }
      catch (e) {
          console.log(e);
      }
      let result = await config.flightSuretyApp.isAirlineRegistered(config.testAddresses[4]);
      assert.equal(result, false, "5th airline requires sufficient votes")
  })

});
