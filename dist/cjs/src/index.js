"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ERC20Abi = exports.filterOnlyObjectProperties = exports.SupportedChains = exports.Fuse = void 0;
const Fuse_1 = __importDefault(require("./Fuse"));
exports.Fuse = Fuse_1.default;
const ERC20_json_1 = __importDefault(require("./Fuse/abi/ERC20.json"));
exports.ERC20Abi = ERC20_json_1.default;
var network_1 = require("./network");
Object.defineProperty(exports, "SupportedChains", { enumerable: true, get: function () { return network_1.SupportedChains; } });
var utils_1 = require("./Fuse/utils");
Object.defineProperty(exports, "filterOnlyObjectProperties", { enumerable: true, get: function () { return utils_1.filterOnlyObjectProperties; } });
