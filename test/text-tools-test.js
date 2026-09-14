// Run directly: node test/text-tools-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'TextTools.js'), 'utf8'), context, { filename: 'TextTools.js' });
const tools = context.TextTools;

assert.equal(tools.operations.length, 15);
for (const item of tools.operations) {
    for (const conflict of item.conflicts) {
        let state = tools.withToggled({}, conflict);
        state = tools.withToggled(state, item.id);
        assert.equal(state[item.id], true, item.id + ' enabled');
        assert.equal(state[conflict], false, item.id + ' disables ' + conflict);
    }
}

assert.equal(tools.copyState({ persianDigits: true, englishDigits: true }).persianDigits, true);
assert.equal(tools.copyState({ persianDigits: true, englishDigits: true }).englishDigits, false);

assert.equal(tools.applyEnabled('۱۲۳', {}).text, '۱۲۳');
assert.equal(tools.applyEnabled('ي ك ة "سلام" 12%', {
    arabicYehToPersian: true, arabicKafToPersian: true, tehMarbutaToHeh: true,
    persianQuotes: true, persianDigits: true
}).text, 'ی ک ه «سلام» ۱۲٪');
assert.equal(tools.applyEnabled('سَلاـم', { removeDiacritics: true, removeTatweel: true }).text, 'سلام');
assert.equal(tools.applyEnabled('می روم خانه ها', { repairZwnj: true }).text, 'می‌روم خانه‌ها');
assert.equal(tools.applyEnabled('می\nروم', { repairZwnj: true }).text, 'می\nروم');
assert.equal(tools.applyEnabled('۱۲٫۳٬۴٪', { englishDigits: true }).text, '12.3,4%');

console.log('Text tool transformation checks passed');
