import { deployConfig as deployConfig56, deploy as deploy56 } from "./bsc";
import { deployConfig as deployConfig97, deploy as deploy97 } from "./chapel";
import { deployConfig as deployConfig1337, deploy as deploy1337 } from "./local";

export { assets as bscAssets } from "./bsc";

export const chainDeployConfig = {
  56: { config: deployConfig56, deployFunc: deploy56 },
  97: { config: deployConfig97, deployFunc: deploy97 },
  1337: { config: deployConfig1337, deployFunc: deploy1337 },
};
