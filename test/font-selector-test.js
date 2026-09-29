// Run directly: node test/font-selector-test.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const context = vm.createContext({});
vm.runInContext(read('FontSearch.js'), context);
const search = context.FontSearch;
const fonts = [
    { display: 'Noto Serif', key: 'serif' },
    { display: 'Noto Sans', key: 'sans' },
    { display: 'Vazirmatn', key: 'vazir' },
    { display: 'LMN Yekan', key: 'yekan' }
];
assert.equal(search.fuzzyScore('Noto Sans', 'noto sans'), -1000);
assert.equal(search.fuzzyScore('Noto Sans', 'xyz'), null);
assert.deepEqual(Array.from(search.filter(fonts, 'noto'), item => item.key), ['sans', 'serif']);
assert.deepEqual(Array.from(search.filter(fonts, 'vzr'), item => item.key), ['vazir']);
assert.deepEqual(Array.from(search.filter(fonts, 'no match')), []);

const selector = read('FontSelector.qml');
const exportSection = read('ExportSection.qml');
assert.match(selector, /Keys\.onDownPressed/);
assert.match(selector, /Keys\.onUpPressed/);
assert.match(selector, /Keys\.onEscapePressed/);
assert.match(selector, /Keys\.onReturnPressed/);
assert.match(selector, /LayoutMirroring\.enabled: false/);
assert.match(selector, /horizontalAlignment: Text\.AlignLeft/);
assert.match(selector, /layoutDirection: Qt\.LeftToRight/);
assert.match(selector, /horizontalAlignment: Text\.AlignRight/);
assert.match(selector, /font\.family: control\.uiFontFamily/);
assert.match(selector, /resultList\.gutter/);
assert.match(selector, /font\.family: fontDelegate\.modelData\.custom/);
assert.match(exportSection, /FontSelector\s*\{[\s\S]*selectedKey: root\.selectedFontPath/);
assert.match(exportSection, /onFontSelected: function\(entry\)/);
assert.match(exportSection, /root\.saveSettings\(\)/);
assert.doesNotMatch(exportSection, /export\.browseFont|openPicker\("font"\)/);
assert.match(exportSection, /FontSelector\s*\{[\s\S]*HeaderActionButton\s*\{\s*objectName: "refreshExportFontsButton"/);
assert.match(exportSection, /if \(selected && selected\.custom\) entries\.push\(selected\)/);
assert.match(exportSection, /enabled: !root\.exportBusy && fonts\.length > 0 &&/);
assert.match(exportSection, /objectName: "refreshExportFontsButton"[\s\S]*iconText: root\.typography\.iconRefresh/);
assert.match(exportSection, /uiFontFamily: root\.typography \? root\.typography\.family/);
assert.match(read('Typography.qml'), /iconRefresh: "\\ue5d5"/);
console.log('font selector tests passed');
