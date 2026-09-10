// Run directly: node test/lifecycle-test.js
// Source guards and the actual UI handler with mocked host/clipboard APIs.
// Native Loader destruction and desktop idle measurements are checked separately.
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const panel = read('Panel.qml');
const menu = read('MenuContent.qml');
assert.match(panel, /active: root\.opened \|\| root\.filePickerActive\s+visible: active\s+enabled: active/);
assert.match(panel, /open: root\.opened && !root\.filePickerActive/);
assert.match(panel, /if \(root\.opened && !root\.filePickerActive && menuLoader\.item\)/);
assert.match(panel, /focusTarget: menuLoader\.item \? menuLoader\.item\.editorItem : null/);
assert.equal((menu.match(/Conversion\.convert\(/g) || []).length, 2);
assert.match(menu, /onClicked: root\.convertAndCopy\(\)/);
for (const file of ['Panel.qml', 'Typography.qml', 'LetterBadge.qml']) {
    assert.doesNotMatch(read(file), /LibraryAdapter|ParsiNegar\.js|vendor\//);
    assert.doesNotMatch(read(file), /SvgCurve|typr/i);
}
assert.doesNotMatch(read('MenuContent.qml'), /SvgCurve(?:Exporter|Adapter|ExportController)|vendor\/typr/i);
assert.doesNotMatch(read('SettingsContent.qml'), /SvgCurve|typr/i);
for (const file of ['Panel.qml', 'Typography.qml', 'LetterBadge.qml', 'LibraryAdapter.js', 'ParsiNegar.js', 'ReshaperSettings.js', 'InterfaceStrings.js', 'SettingsContent.qml']) {
    assert.doesNotMatch(read(file), /\b(?:Timer|Process|FileView|Connections|WorkerScript)\s*\{|\b(?:setInterval|setTimeout|fetch)\s*\(|Quickshell\.exec|XMLHttpRequest/);
}
assert.doesNotMatch(menu, /\b(?:Timer|Connections|WorkerScript)\s*\{|\b(?:setInterval|setTimeout|fetch)\s*\(|Quickshell\.exec|XMLHttpRequest/);
assert.match(menu, /if \(host && host\.reshaperSettingsLoaded\)[\s\S]*else settingsDirectoryCreator\.running = true/);
assert.doesNotMatch(read('LibraryAdapter.js'), /^\s*\.pragma library/m);
assert.doesNotMatch(read('SvgCurveExportController.qml'), /\b(?:Timer|Process|Connections|WorkerScript)\s*\{|Quickshell\.exec|setInterval|setTimeout|fetch\s*\(/);
assert.doesNotMatch(read('ExportSection.qml'), /SvgCurve(?:Exporter|Adapter)|vendor\/typr|\b(?:Timer|FileView|WorkerScript)\s*\{|Quickshell\.exec|setInterval|setTimeout|fetch\s*\(/);
assert.equal((read('ExportSection.qml').match(/\bProcess\s*\{/g) || []).length, 1);
assert.match(read('ExportSection.qml'), /Loader\s*\{[\s\S]*active: false[\s\S]*source: "SvgCurveExportController\.qml"/);
assert.match(read('ExportSection.qml'), /function cleanupExport\(\)[\s\S]*exportLoader\.active = false/);
const coreContext = vm.createContext({});
vm.runInContext('var tableBuilds = 0; var createObject = Object.create; Object.create = function(prototype) { tableBuilds++; return createObject(prototype); };', coreContext);
vm.runInContext(read('ParsiNegar.js'), coreContext);
assert.equal(coreContext.tableBuilds, 1);
const identity = { reshape: text => text, getDisplay: text => text };
for (let i = 0; i < 20; i++) coreContext.ParsiNegar.convert('پ', 'compatibility', undefined, identity, identity);
assert.equal(coreContext.tableBuilds, 1, 'Maryam table must not rebuild per conversion');
const exportFunctions = menu.slice(menu.indexOf('    function conversionOptions()'), menu.indexOf('    function convertAndCopy()'));
let exportCalls = 0;
const exportContext = vm.createContext({
    settingsReady: true,
    host: { opened: true, conversionMode: 'unicode', reverseWords: true, videoStudioPro: false },
    typography: { ready: true }, editor: { text: 'پارسی نگار' }, reshaperSettings: {},
    Quickshell: { clipboardText: 'unchanged' },
    Limits: { ResourceLimits: { values: { maxSvgTextLength: 50000 }, assertTextLength(text, maximum) {
        if (text.length > maximum) { const error = new Error('too large'); error.code = 'EXPORT_TEXT_TOO_LARGE'; throw error; }
        return text;
    } } },
    Conversion: { convert(text, mode) { exportCalls++; return mode + ':' + text; } }
});
vm.runInContext(exportFunctions, exportContext);
assert.equal(exportContext.convertForExport(), 'unicode:پارسی نگار');
assert.equal(exportCalls, 1);
assert.equal(exportContext.editor.text, 'پارسی نگار');
assert.equal(exportContext.Quickshell.clipboardText, 'unchanged');
exportContext.editor.text = 'پ'.repeat(50001);
assert.throws(() => exportContext.convertForExport(), error => error.code === 'EXPORT_TEXT_TOO_LARGE');
assert.equal(exportCalls, 1, 'oversized export text must be rejected before conversion');
assert.equal(exportContext.Quickshell.clipboardText, 'unchanged');
exportContext.editor.text = 'پارسی نگار';
exportContext.host.opened = false;
assert.throws(() => exportContext.convertForExport(), /Export is not ready/);
const handler = menu.slice(menu.indexOf('    function convertAndCopy()'), menu.indexOf('    Keys.onEscapePressed'));
let calls = 0;
const context = vm.createContext({
    busy: false, settingsReady: false, exportSection: { exportBusy: false }, host: { opened: true, conversionMode: 'unicode', reverseWords: true, videoStudioPro: false },
    typography: { ready: true }, editor: { text: 'سلام\nدنیا' }, reshaperSettings: {},
    statusError: false, statusText: '', uiText(key) {
        if (key === 'status.failure') return 'Conversion failed: ';
        if (key === 'status.textTooLarge') return 'Conversion is limited.';
        return 'Converted and copied.';
    }, focusEditor() {}, conversionOptions() { return {}; },
    Quickshell: { clipboardText: 'untouched' },
    Limits: { ResourceLimits: { values: { maxConversionTextLength: 250000 }, assertTextLength(text, maximum) {
        if (text.length > maximum) { const error = new Error('too large'); error.code = 'CONVERSION_TEXT_TOO_LARGE'; throw error; }
        return text;
    } } },
    Conversion: { convert(text) { calls++; return text + '\nconverted'; } }
});
vm.runInContext(handler, context);
assert.equal(calls, 0);
context.settingsReady = true;
context.host.opened = false;
context.convertAndCopy();
assert.equal(calls, 0);
assert.equal(context.Quickshell.clipboardText, 'untouched');
context.host.opened = true;
context.typography.ready = false;
context.convertAndCopy();
assert.equal(calls, 0);
context.typography.ready = true;
context.busy = true;
context.convertAndCopy();
assert.equal(calls, 0);
context.busy = false;
context.convertAndCopy();
assert.equal(calls, 1);
assert.equal(context.Quickshell.clipboardText, 'سلام\nدنیا\nconverted');
assert.equal(context.editor.text, 'سلام\nدنیا');
assert.equal(context.busy, false);
context.editor.text = 'پ'.repeat(250001);
context.convertAndCopy();
assert.equal(calls, 1, 'oversized text must be rejected before conversion');
assert.equal(context.Quickshell.clipboardText, 'سلام\nدنیا\nconverted');
assert.equal(context.statusText, 'Conversion is limited.');
context.editor.text = 'سلام\nدنیا';
context.Conversion.convert = () => { throw new Error('test failure'); };
context.convertAndCopy();
assert.equal(context.busy, false);
assert.equal(context.statusError, true);
assert.equal(context.Quickshell.clipboardText, 'سلام\nدنیا\nconverted');
context.host.opened = false;
assert.equal(context.Quickshell.clipboardText, 'سلام\nدنیا\nconverted');
console.log('Lifecycle source and action checks passed');
