"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.filterPoolName = exports.filter = exports.filterOnlyObjectProperties = void 0;
const bad_words_1 = __importDefault(require("bad-words"));
function filterOnlyObjectProperties(obj) {
    return Object.fromEntries(Object.entries(obj).filter(([k]) => isNaN(k)));
}
exports.filterOnlyObjectProperties = filterOnlyObjectProperties;
exports.filter = new bad_words_1.default({ placeHolder: " " });
exports.filter.addWords(...["R1", "R2", "R3", "R4", "R5", "R6", "R7"]);
const filterPoolName = (name) => {
    return exports.filter.clean(name);
};
exports.filterPoolName = filterPoolName;
