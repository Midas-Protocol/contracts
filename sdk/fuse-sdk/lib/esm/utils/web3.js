import { BigNumber, constants, Contract } from "ethers";
export const createContract = (address, abi, provider) => new Contract(address, abi, provider.getSigner());
export const toBN = (input) => {
    if (input === 0 || input === "0")
        return constants.Zero;
    if (input === 1e18)
        return constants.WeiPerEther;
    else
        return BigNumber.from(input);
};
