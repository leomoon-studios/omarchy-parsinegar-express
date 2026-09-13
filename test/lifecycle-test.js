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
assert.equal((menu.match(/conversionWorker\.sendMessage\(/g) || []).length, 2);
assert.match(menu, /onClicked: root\.convertAndCopy\(\)/);
for (const file of ['Panel.qml', 'Typography.qml', 'LetterBadge.qml']) {
    assert.doesNotMatch(read(file), /LibraryAdapter|ParsiNegar\.js|vendor\//);
    assert.doesNotMatch(read(file), /SvgCurve|typr/i);
}
assert.doesNotMatch(read('MenuContent.qml'), /SvgCurve(?:Exporter|Adapter|ExportController)|vendor\/typr/i);
assert.doesNotMatch(read('SettingsContent.qml'), /SvgCurve|typr/i);
for (const file of ['Panel.qml', 'Typography.qml', 'LetterBadge.qml', 'LibraryAdapter.js', 'ParsiNegar.js', 'ReshaperSettings.js', 'InterfaceStrings.js', 'EditorDirection.js', 'SettingsContent.qml']) {
    assert.doesNotMatch(read(file), /\b(?:Timer|Process|FileView|Connections|WorkerScript)\s*\{|\b(?:setInterval|setTimeout|fetch)\s*\(|Quickshell\.exec|XMLHttpRequest/);
}
assert.doesNotMatch(menu, /\bTimer\s*\{|\b(?:setInterval|setTimeout|fetch)\s*\(|Quickshell\.exec|XMLHttpRequest/);
assert.equal((menu.match(/\bWorkerScript\s*\{/g) || []).length, 1);
assert.match(menu, /if \(host && host\.reshaperSettingsLoaded\)[\s\S]*else settingsDirectoryCreator\.running = true/);
assert.doesNotMatch(read('LibraryAdapter.js'), /^\s*\.pragma library/m);
assert.equal((read('SvgCurveExportController.qml').match(/\bWorkerScript\s*\{/g) || []).length, 1);
assert.doesNotMatch(read('SvgCurveExportController.qml'), /\b(?:Timer|Process|Connections)\s*\{|Quickshell\.exec|setInterval|setTimeout|fetch\s*\(/);
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
assert.match(menu, /function requestExportConversion\(\)[\s\S]*conversionWorker\.sendMessage/);
assert.match(menu, /function convertAndCopy\(\)[\s\S]*conversionWorker\.sendMessage/);
assert.match(menu, /function finishConversion\(message\)[\s\S]*Quickshell\.clipboardText = message\.output/);
assert.match(read('ConversionWorker.js'), /WorkerScript\.onMessage[\s\S]*ParsiNegar\.convert[\s\S]*WorkerScript\.sendMessage/);
assert.match(read('SvgCurveWorker.js'), /WorkerScript\.onMessage/);
assert.match(read('SvgCurveWorker.js'), /SvgCurveExporter\.exportSvg[\s\S]*WorkerScript\.sendMessage/);
console.log('Lifecycle source and action checks passed');
