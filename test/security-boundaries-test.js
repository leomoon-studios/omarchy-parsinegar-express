// Run directly: node test/security-boundaries-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const context = vm.createContext({ TextDecoder, TextEncoder });
for (const file of ['vendor/typr.js', 'vendor/js-parsi-reshaper.js', 'ResourceLimits.js', 'LocalPath.js', 'ReshaperSettings.js', 'SvgCurveExporter.js']) {
    vm.runInContext(read(file), context, { filename: file });
}
const limits = context.ResourceLimits;
const paths = context.LocalPath;
const exporter = context.SvgCurveExporter;
const fontBuffer = fs.readFileSync(path.join(root, 'assets/fonts/Vazirmatn[wght].ttf'));
const font = new Uint8Array(fontBuffer.buffer.slice(fontBuffer.byteOffset, fontBuffer.byteOffset + fontBuffer.byteLength));

assert.match(exporter.exportSvg('پ', font, undefined, context.Typr, limits), /<svg /);
for (const options of [null, false, true, 0, 1, 'options', [], new Date(), new String('options')]) {
    assert.throws(() => exporter.exportSvg('پ', font, options, context.Typr, limits), error => error.code === 'INVALID_OPTION');
}
for (const options of [
    { unknown: true }, { bounds: null }, { bounds: [] }, { bounds: { unknown: 1 } },
    { fontSize: null }, { fontSize: '48' }, { lineSpacing: null }, { alignment: null },
    { fill: null }, { precision: null }, { fontIndex: null }, { fontIndex: '0' },
    { axes: null }, { axes: {} }, { axes: [] }, { axes: ['400'] }, { axes: [Infinity] }, { axes: [400, 500] }
]) {
    assert.throws(() => exporter.exportSvg('پ', font, options, context.Typr, limits), error => error.code === 'INVALID_OPTION');
}
assert.match(exporter.exportSvg('پ', font, { axes: [400] }, context.Typr, limits), /<svg /);
const payload = '\"><script>alert(1)</script>&';
const escaped = exporter.exportSvg('پ', font, { fill: payload }, context.Typr, limits);
assert.doesNotMatch(escaped, /<script/i);
assert.ok(escaped.includes('&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;&amp;'));

for (const invalid of [null, undefined, '', 'relative.svg', 'https://example.com/a.svg', 'file://example.com/a.svg', 'file:///tmp/bad%ZZ.svg', 'file:///tmp/%00.svg', '/tmp/bad\0.svg', '/tmp/../outside.svg', 'file:///tmp/%2e%2e/outside.svg']) {
    assert.throws(() => paths.absolute(invalid), error => error.code === 'INVALID_PATH');
}
assert.equal(paths.absolute('/tmp/نام پرونده ; $(touch never).svg'), '/tmp/نام پرونده ; $(touch never).svg');
assert.equal(paths.absolute('file:///tmp/%D9%BE%D8%A7%D8%B1%D8%B3%DB%8C%20%D9%86%DA%AF%D8%A7%D8%B1.svg'), '/tmp/پارسی نگار.svg');
assert.equal(paths.absolute('file://localhost/tmp/test.svg'), '/tmp/test.svg');
assert.equal(paths.fromPickerOutput('/tmp/ leading and trailing .svg \n'), '/tmp/ leading and trailing .svg ');
assert.equal(paths.fileName('/tmp/نام پرونده.svg'), 'نام پرونده.svg');

assert.throws(() => limits.assertSettingsSize('x'.repeat(limits.values.maxSettingsBytes + 1)), error => error.code === 'SETTINGS_TOO_LARGE');
assert.equal(limits.assertSettingsSize('x'.repeat(limits.values.maxSettingsBytes)).length, limits.values.maxSettingsBytes);
const hostileSettings = '{"schemaVersion":1,"uiLanguage":"en","settings":{"__proto__":{"polluted":true},"ligatures":{"__proto__":{"polluted":true}}}}';
const parsedSettings = context.ReshaperSettings.parse(context.ReshaperSettings.metadata, hostileSettings);
assert.equal(parsedSettings.recovered, false);
assert.equal(Object.prototype.polluted, undefined);
assert.equal(parsedSettings.settings.polluted, undefined);
assert.equal(parsedSettings.settings.ligatures.polluted, undefined);

const exportSection = read('ExportSection.qml');
const menu = read('MenuContent.qml');
const controller = read('SvgCurveExportController.qml');
assert.doesNotMatch(exportSection, /--confirm-overwrite/);
assert.doesNotMatch(exportSection, /destinationCheck|overwriteConfirmation|zenity", "--question|\/usr\/bin\/test/);
assert.match(exportSection, /kind === "font"[\s\S]*else continueExport\(svgPath\(output\)\)/);
assert.match(exportSection, /function continueExport\(destination\)[\s\S]*controller\.setExportStatus\(uiText\("export\.processing"\)[\s\S]*Qt\.callLater/);
assert.ok(menu.indexOf('Limits.ResourceLimits.assertSettingsSize(raw)') < menu.indexOf('Settings.ReshaperSettings.parse(reshaperMetadata, raw)'));
assert.ok(controller.includes('outputPath = Paths.LocalPath.absolute(destinationPath)'));
assert.ok(controller.includes('outputFile.path = outputPath'));

for (const file of fs.readdirSync(root).filter(file => /\.(?:js|qml)$/.test(file))) {
    if (file === 'LocalPath.js') continue;
    assert.doesNotMatch(read(file), /\b(?:eval|XMLHttpRequest|WebSocket)\b|\bfetch\s*\(/, file);
}
assert.doesNotMatch(exportSection, /(?:bash|sh)\s+-c|Quickshell\.exec/);
assert.doesNotMatch(controller, /(?:bash|sh)\s+-c|Quickshell\.exec/);

console.log('Security boundary checks passed');
