import { deployConfig as deployConfig56 } from "./56";
import { deployConfig as deployConfig1337 } from "./1337";
import { deployConfig as deployConfig97 } from "./97";
import { deploy as deploy56 } from "./56";
import { deploy as deploy97 } from "./97";
import { deploy as deploy1337 } from "./1337";

export const chainDeployConfig = {
  56: { config: deployConfig56, deployFunc: deploy56 },
  97: { config: deployConfig97, deployFunc: deploy97 },
  1337: { config: deployConfig1337, deployFunc: deploy1337 },
};
