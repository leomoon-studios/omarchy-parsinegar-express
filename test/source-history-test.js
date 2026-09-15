// Run directly: node test/source-history-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'SourceHistory.js'), 'utf8'), context, {
    filename: 'SourceHistory.js'
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'TextTools.js'), 'utf8'), context, {
    filename: 'TextTools.js'
});
const historyApi = context.SourceHistory;
const plain = value => JSON.parse(JSON.stringify(value));

let history = historyApi.create({ text: '', cursor: 0, anchor: 0 }, 3);
assert.equal(historyApi.canUndo(history), false);
assert.equal(historyApi.canRedo(history), false);

history = historyApi.record(history, { text: 'a', cursor: 1, anchor: 1 });
history = historyApi.record(history, { text: 'a\n', cursor: 2, anchor: 2 });
history = historyApi.record(history, { text: 'a\n\n', cursor: 3, anchor: 3 });
history = historyApi.record(history, { text: 'a\n\nb', cursor: 4, anchor: 4 });
assert.equal(history.undo.length, 3, 'history must remain bounded');

let result = historyApi.undo(history);
assert.deepEqual(plain(result.state), { text: 'a\n\n', cursor: 3, anchor: 3 });
history = result.history;
result = historyApi.undo(history);
assert.deepEqual(plain(result.state), { text: 'a\n', cursor: 2, anchor: 2 });
history = result.history;
result = historyApi.redo(history);
assert.deepEqual(plain(result.state), { text: 'a\n\n', cursor: 3, anchor: 3 });
history = result.history;

history = historyApi.updateSelection(history, 1, 0);
assert.deepEqual(plain(history.current), { text: 'a\n\n', cursor: 1, anchor: 0 });
assert.equal(history.undo.length, 2, 'selection changes must not create entries');

history = historyApi.record(history, { text: 'divergent', cursor: 9, anchor: 9 });
assert.equal(historyApi.canRedo(history), false, 'a divergent edit must clear redo');
assert.deepEqual(plain(historyApi.undo(history).state), { text: 'a\n\n', cursor: 1, anchor: 0 });

const source = 'می روم\n\nمیدان 12%';
const transformed = context.TextTools.applyEnabled(source, { repairZwnj: true, persianDigits: true });
history = historyApi.create({ text: source, cursor: source.length, anchor: source.length }, 100);
history = historyApi.record(history, {
    text: transformed.text,
    cursor: transformed.text.length,
    anchor: transformed.text.length
});
assert.equal(history.undo.length, 1, 'all enabled Text Tools must form one transaction');
assert.equal(historyApi.undo(history).state.text, source);

console.log('Source history checks passed');
