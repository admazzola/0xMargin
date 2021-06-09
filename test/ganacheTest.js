 
import fs from 'fs'
import path from 'path'

import ganache from 'ganache-cli' 
import  Web3 from 'web3' 
import { expect } from 'chai';

import TestHelper from './test-helper.js'

let testAccountA = {
  publicAddress: '0x95eDA452256C1190947f9ba1fD19422f0120858a',
  secretKey: "0x31c354f57fc542eba2c56699286723e94f7bd02a4891a0a7f68566c2a2df6795",
  balance: "1000000000000000000000000000000000"

}

let testAccountB = {
  publicAddress: '0x4df25e870fC979ff3FE46F5329021A074504698a',
  secretKey: "0x35e642e9de5a47e3ccb2a118a2b37fdd418037df6aea453b9f9f40790878b5a5",
  balance: "1000000000000000000000000000000000"

}


const ganacheOptions = { gasLimit: 8000000, accounts:[testAccountA,testAccountB] };

const provider = ganache.provider( ganacheOptions )
const OPTIONS = {
  defaultBlock: "latest",
  transactionConfirmationBlocks: 1,
  transactionBlockTimeout: 5 
};

 
 
const web3 = new Web3(provider, null, OPTIONS);
 

let tokenContractJSON = fs.readFileSync(path.join('generated/built/MintableToken.json'));
let tokenContractData = JSON.parse(tokenContractJSON)

let hackytokenContractJSON = fs.readFileSync(path.join('generated/built/HackyToken.json'));
let hackytokenContractData = JSON.parse(hackytokenContractJSON)


let guildContractJSON = fs.readFileSync(path.join('generated/built/MinersGuild.json'));
let guildContractData = JSON.parse(guildContractJSON)
 
let primaryAccountAddress = testAccountA.publicAddress
 
let secondaryAccountAddress = testAccountB.publicAddress


var contractInstances  = {} 

describe("EIP712 Contract Testing", function() {
    it("deploys contract", async function() {
 
     
     // let primaryAccountAddress = testAccount.publicAddress
      
     
     contractInstances['stakeabletoken'] = await TestHelper.deployContract(tokenContractData ,primaryAccountAddress, web3, [8])
     contractInstances['reservetoken'] = await TestHelper.deployContract(tokenContractData ,primaryAccountAddress, web3, [8])

     contractInstances['guild'] = await TestHelper.deployContract(guildContractData ,primaryAccountAddress, web3, [contractInstances['stakeabletoken'].options.address, contractInstances['reservetoken'].options.address])



     contractInstances['auxiliarytoken'] = await TestHelper.deployContract(tokenContractData ,primaryAccountAddress, web3, [8])
     contractInstances['hackytoken'] = await TestHelper.deployContract(hackytokenContractData ,primaryAccountAddress, web3, [8])
    
   
      //console.log("deployed contract at ", contractInstances['guild'].options.address)
      expect( contractInstances['guild'].options.address ).to.exist;
    });

    it("calls methods ", async function() {



      await contractInstances['reservetoken'].methods.transferOwnership(contractInstances['guild'].options.address).send({from: primaryAccountAddress})
      
      let newOwner = await contractInstances['reservetoken'].methods.owner().call()
      expect( newOwner ).to.equal( contractInstances['guild'].options.address );
 
      await contractInstances['stakeabletoken'].methods.mint(primaryAccountAddress, 9000).send({from: primaryAccountAddress})
      await contractInstances['stakeabletoken'].methods.mint(secondaryAccountAddress, 9000).send({from: primaryAccountAddress})

      await contractInstances['auxiliarytoken'].methods.mint(secondaryAccountAddress, 9000).send({from: primaryAccountAddress})

     
      let myBalance = await TestHelper.getERC20Balance( contractInstances['stakeabletoken'] , primaryAccountAddress   )
      expect( parseInt(myBalance) ).to.equal( 9000 );


      //secondary account stakes 1000 
      await contractInstances['stakeabletoken'].methods.approveAndCall(contractInstances['guild'].options.address, 1000, '0x0').send({from: secondaryAccountAddress,  gasLimit: 8000000 })



     
       //primary account stakes 1000 
      await contractInstances['stakeabletoken'].methods.approveAndCall(contractInstances['guild'].options.address, 1000, '0x0').send({from: primaryAccountAddress,  gasLimit: 8000000 })

      myBalance = await TestHelper.getERC20Balance( contractInstances['stakeabletoken'] , primaryAccountAddress   )
       expect( parseInt(myBalance) ).to.equal( 8000 );


      let myReserve = await TestHelper.getERC20Balance( contractInstances['reservetoken'] , primaryAccountAddress   )
       expect( parseInt(myReserve) ).to.equal( 1000 );

 
 
       await contractInstances['stakeabletoken'].methods.approveAndCall(contractInstances['guild'].options.address, 1000, '0x0').send({from: primaryAccountAddress,  gasLimit: 8000000 })
       myReserve = await TestHelper.getERC20Balance( contractInstances['reservetoken'] , primaryAccountAddress   )
       expect( parseInt(myReserve) ).to.equal( 2000 );
 
  
       
      let reserveMinted =  await contractInstances['guild'].methods._reserveTokensMinted(500).call()
      expect( parseInt( reserveMinted ) ).to.equal(  499 );

      let outputAmount =  await contractInstances['guild'].methods._vaultOutputAmount(499, contractInstances['stakeabletoken'].options.address ).call()
      expect( parseInt( outputAmount ) ).to.equal(  498 );

 

       myBalance = await TestHelper.getERC20Balance( contractInstances['stakeabletoken'] , primaryAccountAddress   )
       expect( parseInt(myBalance) ).to.equal( 7000 );


        // primary account unstakes 100 shares  , has 900 shares left 
       await contractInstances['guild'].methods.unstakeCurrency(100, contractInstances['stakeabletoken'].options.address).send({from: primaryAccountAddress,  gasLimit: 8000000 })
       myBalance = await TestHelper.getERC20Balance( contractInstances['stakeabletoken'] , primaryAccountAddress   )
       expect( parseInt(myBalance) ).to.equal( 7099 );

        //1000 tokens are donated 
       await contractInstances['stakeabletoken'].methods.transfer(contractInstances['guild'].options.address, 1000).send({from: secondaryAccountAddress})
     
       outputAmount =  await contractInstances['guild'].methods._vaultOutputAmount(499, contractInstances['stakeabletoken'].options.address).call()
       expect( parseInt( outputAmount ) ).to.equal(  671  );


       
         // primary account stakes 1000 shares  
       await contractInstances['stakeabletoken'].methods.approveAndCall(contractInstances['guild'].options.address, 1000, '0x0').send({from: primaryAccountAddress,  gasLimit: 8000000 })
       myReserve = await TestHelper.getERC20Balance( contractInstances['reservetoken'] , primaryAccountAddress   )
       expect( parseInt(myReserve) ).to.equal( 2643 );

        // primary account can unstake the shares they just added and will get out approximately the 0xBTC they put in 
         outputAmount =  await contractInstances['guild'].methods._vaultOutputAmount(743, contractInstances['stakeabletoken'].options.address).call()
       expect( parseInt( outputAmount ) ).to.equal(  999 );
 
     

      
     
    });

    it("approve call secondary token fails ", async function() {

      let myBalance = await TestHelper.getERC20Balance( contractInstances['auxiliarytoken'] , secondaryAccountAddress   )
      expect( parseInt(myBalance) ).to.equal( 9000 );

      let failed; 
      try{
        await contractInstances['auxiliarytoken'].methods.approveAndCall(contractInstances['guild'].options.address, 1000, '0x0').send({from: secondaryAccountAddress,  gasLimit: 8000000 })
      }catch(e){
        failed = true;
      }

      expect(failed).to.equal(true)
     
    });


     it("transfer secondary token succeeds ", async function() {

      let myBalance = await TestHelper.getERC20Balance( contractInstances['auxiliarytoken'] , secondaryAccountAddress   )
      expect( parseInt(myBalance) ).to.equal( 9000 );

      await contractInstances['auxiliarytoken'].methods.transfer(contractInstances['guild'].options.address, 1000 ).send({from: secondaryAccountAddress,  gasLimit: 8000000 })
      myBalance = await TestHelper.getERC20Balance( contractInstances['auxiliarytoken'] , secondaryAccountAddress   )
      expect( parseInt(myBalance) ).to.equal( 8000 );
      

      let outputAmount =  await contractInstances['guild'].methods._vaultOutputAmount(100, contractInstances['auxiliarytoken'].options.address).call()
      expect( parseInt( outputAmount ) ).to.equal(  27 );


      outputAmount =  await contractInstances['guild'].methods._vaultOutputAmount(2543, contractInstances['stakeabletoken'].options.address ).call()
      expect( parseInt( outputAmount ) ).to.equal(  3421 );


      let myReserve = await TestHelper.getERC20Balance( contractInstances['reservetoken'] , primaryAccountAddress   )
      expect( parseInt(myReserve) ).to.equal( 2643 );

      await contractInstances['guild'].methods.unstakeCurrency(100, contractInstances['auxiliarytoken'].options.address).send({from: primaryAccountAddress,  gasLimit: 8000000 })
       
      outputAmount =  await contractInstances['guild'].methods._vaultOutputAmount(100, contractInstances['auxiliarytoken'].options.address).call()
      expect( parseInt( outputAmount ) ).to.equal(  27 ); 

      myReserve = await TestHelper.getERC20Balance( contractInstances['reservetoken'] , primaryAccountAddress   )
      expect( parseInt(myReserve) ).to.equal( 2543 );

      myBalance = await TestHelper.getERC20Balance( contractInstances['auxiliarytoken'] , primaryAccountAddress   )
      expect( parseInt(myBalance) ).to.equal( 27 );



      outputAmount =  await contractInstances['guild'].methods._vaultOutputAmount(2543, contractInstances['stakeabletoken'].options.address ).call()
      expect( parseInt( outputAmount ) ).to.equal(  3517 );

      outputAmount =  await contractInstances['guild'].methods._vaultOutputAmount(2543, contractInstances['auxiliarytoken'].options.address).call()
      expect( parseInt( outputAmount ) ).to.equal(  698 );

    });




 
  });