import { task, types } from "hardhat/config";

export default task("swap-wtoken-for-token", "Swap WNATIVE for token")
  .addParam("token", "token address", undefined, types.string)
  .addOptionalParam("amount", "Amount to trade", "100", types.string)
  .addOptionalParam("account", "Account with which to trade", "bob", types.string)
  .setAction(async ({ token: _token, amount: _amount, account: _account }, { ethers }) => {
    // @ts-ignore
    const sdkModule = await import("../dist/esm/src");
    const sdk = new sdkModule.Fuse(ethers.provider, (await ethers.provider.getNetwork()).chainId);
    const account = await ethers.getNamedSigner(_account);

    const tokenContract = new ethers.Contract(_token, sdkModule.ERC20Abi, account);
    await tokenContract.approve(
      sdk.chainSpecificAddresses.UNISWAP_V2_ROUTER,
      ethers.BigNumber.from(2).pow(ethers.BigNumber.from(256)).sub(ethers.constants.One),
      {
        gasLimit: 100000,
        gasPrice: 5e9,
      }
    );

    console.log(`Token balance before: ${ethers.utils.formatEther(await tokenContract.balanceOf(account.address))}`);
    const uniRouter = new ethers.Contract(
      sdk.chainSpecificAddresses.UNISWAP_V2_ROUTER,
      [
        "function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts)",
      ],
      account
    );

    const path = [sdk.chainSpecificAddresses.W_TOKEN, _token];
    const ethAmount = ethers.utils.parseEther(_amount);

    const nowInSeconds = Math.floor(Date.now() / 1000);
    const expiryDate = nowInSeconds + 900;

    const txn = await uniRouter.swapExactETHForTokens(0, path, account.address, expiryDate, {
      gasLimit: 1000000,
      gasPrice: ethers.utils.parseUnits("10", "gwei"),
      value: ethAmount,
    });
    await txn.wait();
    console.log(`Token balance after: ${ethers.utils.formatEther(await tokenContract.balanceOf(account.address))}`);
  });
