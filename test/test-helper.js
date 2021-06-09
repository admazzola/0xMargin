

export default class TestHelper {


static async deployContract(contractData, from, web3, args){
    //let chainId = await web3.eth.net.getId()


   return await new web3.eth.Contract(contractData.abi)
    .deploy({data: "0x" + contractData.evm.bytecode.object, arguments: args})
    .send({from:  from, gas: 5000000});
   
   
}

static async getERC20Balance(contractInstance, from){
    return await contractInstance.methods.balanceOf(from).call()
}

}
