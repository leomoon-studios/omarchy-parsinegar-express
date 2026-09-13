// Run directly: node test/editor-direction-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const context = vm.createContext({});
vm.runInContext(
  fs.readFileSync(path.join(__dirname, '..', 'EditorDirection.js'), 'utf8'),
  context,
  { filename: 'EditorDirection.js' }
);

const direction = context.EditorDirection;

assert.equal(direction.paragraphAlignment('سلام.'), 'right');
assert.equal(direction.paragraphAlignment('salam.'), 'left');
assert.equal(direction.paragraphAlignment('123؟'), '');

const emptyAfterPersian = direction.paragraphLayout('سلام.\n');
assert.deepEqual(Array.from(emptyAfterPersian.directions), ['right', 'right']);
assert.equal(emptyAfterPersian.signature, 'strong:right|inherited:right');

const persianAfterPersian = direction.paragraphLayout('سلام.\nس');
assert.deepEqual(Array.from(persianAfterPersian.directions), ['right', 'right']);
assert.equal(persianAfterPersian.signature, 'strong:right|strong:right');
assert.notEqual(persianAfterPersian.signature, emptyAfterPersian.signature);

const persianAfterEnglish = direction.paragraphLayout('salam.\nس');
assert.deepEqual(Array.from(persianAfterEnglish.directions), ['left', 'right']);

console.log('Editor direction checks passed');
