// Authoritative server engine, retained from the retired Web client.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const CLIENT_JS = path.join(__dirname, 'engine');

const files = [
  'tiles-data.js',
  'traditional/tiles.js',
  'traditional/hand-eval.js',
  'traditional/scoring.js',
  'traditional/yaku.js',
  'traditional/engine.js',
  'traditional/bot.js',
  'traditional/local-match.js',
];

const code = files.map((f) => fs.readFileSync(path.join(CLIENT_JS, f), 'utf8')).join('\n;\n');

const sandbox = { console, setTimeout, clearTimeout, setInterval, clearInterval, Date };
vm.createContext(sandbox);
// `class` declarations (unlike `function` declarations) don't attach to the
// vm context's global object on their own — export them explicitly.
const exposeTail = `
;
this.RiichiEngine = RiichiEngine;
this.LocalMatch = LocalMatch;
this.chooseBotReaction = chooseBotReaction;
this.chooseBotRiichi = chooseBotRiichi;
this.chooseBotAnkan = chooseBotAnkan;
this.TILE_TYPES_BY_ID = TILE_TYPES_BY_ID;
this.STANDARD_TYPE_IDS = STANDARD_TYPE_IDS;
`;
vm.runInContext(code + exposeTail, sandbox, { filename: 'shared-client-engine.js' });

module.exports = {
  RiichiEngine: sandbox.RiichiEngine,
  LocalMatch: sandbox.LocalMatch,
  chooseBotReaction: sandbox.chooseBotReaction,
  chooseBotRiichi: sandbox.chooseBotRiichi,
  chooseBotAnkan: sandbox.chooseBotAnkan,
  TILE_TYPES_BY_ID: sandbox.TILE_TYPES_BY_ID,
  STANDARD_TYPE_IDS: sandbox.STANDARD_TYPE_IDS,
};
