
import solc from 'solc'
import path from 'path'
import fs from 'fs-extra'
 

const buildPath = path.resolve('generated', 'built');

const createBuildFolder = () => {
	fs.emptyDirSync(buildPath);
}

const contractFolderPath = path.resolve( 'generated','contracts');

const buildSources = () => {
  const sources = {};
  const contractsFiles = fs.readdirSync(contractFolderPath);
  
  contractsFiles.forEach(file => {
	console.log('file',file )

    const contractFullPath = path.resolve(contractFolderPath, file);
    sources[file] = {
      content: fs.readFileSync(contractFullPath, 'utf8')
    };
  });
  
  return sources;
}
 


const input = {
	language: 'Solidity',
	sources: buildSources(),
	settings: {
		outputSelection: {
			'*': {
				'*': [ 'abi', 'evm.bytecode' ]
			}
		}
	}
}


var compileOutput = JSON.parse(solc.compile(JSON.stringify(input)))

if(compileOutput. errors){
	console.log('input',  compileOutput.errors )

}


const compileContracts = () => {
	const compiledContracts = compileOutput.contracts;

    console.log('compiledContracts:',compiledContracts)
	for (let contract in compiledContracts) {
		for(let contractName in compiledContracts[contract]) {
			fs.outputJsonSync(
				path.resolve(buildPath, `${contractName}.json`),
				compiledContracts[contract][contractName],
				{
					spaces: 2
				}
			)
		}
	}
}

compileContracts()