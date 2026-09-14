// Run directly: node test/text-tools-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'TextTools.js'), 'utf8'), context, { filename: 'TextTools.js' });
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'InterfaceStrings.js'), 'utf8'), context, { filename: 'InterfaceStrings.js' });
vm.runInContext(fs.readFileSync(path.join(__dirname, 'text-tools-fixtures.js'), 'utf8'), context, { filename: 'text-tools-fixtures.js' });
const tools = context.TextTools;
const strings = context.InterfaceStrings;
const fixtures = context.TextToolsFixtures;
const plain = value => JSON.parse(JSON.stringify(value));

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
assert.equal(tools.applyEnabled('میخواهم نمیخواستند میدان', { repairZwnj: true }).text, 'می‌خواهم نمی‌خواستند میدان');
assert.equal(tools.applyEnabled('در میدان بزرگ راه می روم', { repairZwnj: true }).text, 'در میدان بزرگ راه می‌روم');
assert.equal(tools.applyEnabled('۱۲٫۳٬۴٪', { englishDigits: true }).text, '12.3,4%');

assert.equal(fixtures.schemaVersion, 1);
assert.equal(fixtures.source.kind, 'hand-reviewed');
assert.equal(fixtures.cases.length, tools.operations.length);
const seen = new Set();
for (const fixture of fixtures.cases) {
    assert.ok(fixture.rationale.length > 20, fixture.id + ' rationale');
    assert.ok(!seen.has(fixture.operation), 'duplicate fixture for ' + fixture.operation);
    seen.add(fixture.operation);
    const actual = tools.applyOne(fixture.input, fixture.operation);
    assert.equal(actual, fixture.expected, fixture.id);
    assert.equal(tools.applyOne(actual, fixture.operation), actual, fixture.id + ' must be idempotent');
}
for (const operation of tools.operations) {
    assert.ok(seen.has(operation.id), 'missing fixture for ' + operation.id);
    for (const language of ['en', 'fa']) {
        assert.notEqual(strings.text(language, operation.labelKey), operation.labelKey, language + ' label ' + operation.id);
        assert.notEqual(strings.text(language, operation.descriptionKey), operation.descriptionKey, language + ' description ' + operation.id);
    }
}

const ordered = tools.applyEnabled(fixtures.orderedEnabled.input, fixtures.orderedEnabled.enabled);
assert.equal(ordered.text, fixtures.orderedEnabled.expected);
assert.deepEqual(plain(ordered.applied), plain(fixtures.orderedEnabled.applied));

console.log('Text tool transformation checks passed');
