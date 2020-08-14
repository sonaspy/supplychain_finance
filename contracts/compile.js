const fs = require("fs-extra");
const path = require("path");
const solc = require("solc");
const contractPath = path.resolve(__dirname, "./", "Finance.sol");
const contractSource = fs.readFileSync(contractPath, "utf8");
const result = solc.compile(contractSource, 1);
if (Array.isArray(result.errors) && result.errors.length) {
  throw new Error(result.errors[0]);
}
Object.keys(result.contracts).forEach((name) => {
  const contractName = name.replace(/^:/, "");
  const filePath = path.resolve(compiledDir, `${contractName}.json`);
  fs.outputJsonSync(filePath, result.contracts[name]);
  console.log(`save compiled contract ${contractName} to ${filePath}`);
});
