// Run directly: node test/font-catalog-test.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'FontCatalog.js'), 'utf8');
const context = vm.createContext({});
vm.runInContext(source, context);
const catalog = context.FontCatalog;

const state = catalog.create();
catalog.append(state, '/fonts/LMN Yekan.ttf\tLMN Yekan\tRegular\t20-7e 600-6ff\n/fonts/Noto.otf\tNoto Sans,Noto Sans Regular\tRegular\t20-7e');
catalog.append(state, ' 600-6ff\n/fonts/Noto-copy.otf\tNoto Sans\tRegular\t20-7e\n');
catalog.append(state, '/fonts/bad.woff\tBad\tRegular\t20\n../bad.ttf\tBad\tRegular\t20\n');
const entries = catalog.finish(state);
assert.equal(entries.length, 2);
assert.equal(entries[0].family, 'LMN Yekan');
assert.equal(entries[1].path, '/fonts/Noto.otf');
assert.equal(entries[1].charset, '20-7e 600-6ff');
assert.equal(catalog.previewWithoutFallback('41 600-6ff', 'A ب Z'), 'A ب □');
assert.equal(catalog.previewWithoutFallback('1f600', '😀 B'), '😀 □');
assert.ok(entries[1].unicodePreview.includes('روباه'));
assert.ok(entries[0].compatibilityPreview.length > 0);
assert.equal(catalog.forMode(entries, 'compatibility', '/bundled.ttf', 'Vazirmatn', 'Bundled').length, 1);
const unicode = catalog.forMode(entries, 'unicode', '/bundled.ttf', 'Vazirmatn', 'Bundled');
assert.equal(unicode.length, 2);
assert.equal(unicode[0].path, '/bundled.ttf');
assert.equal(catalog.selectedEntry(unicode, '/fonts/Noto.otf').display, 'Noto Sans');
assert.equal(catalog.selectedEntry(unicode, '/custom/My Font.ttf').display, 'My Font.ttf');
assert.equal(catalog.selectedEntry(unicode, '/custom/My Font.ttf').custom, true);
assert.equal(catalog.selectedEntry(unicode, '/custom/My Font.ttf').unicodePreview, '');

const oversized = catalog.create();
assert.throws(() => catalog.append(oversized, 'x'.repeat(64 * 1024 + 1)), /record is too long/);
const excessive = catalog.create();
assert.throws(() => catalog.append(excessive, 'x\n'.repeat(20001)), /Too many font catalog records/);
const malformed = catalog.create();
catalog.append(malformed, '/fonts/C.ttf\tC\tRegular\t20-7e\n/fonts/bad.ttf\tBad\tRegular\tinvalid!\n');
assert.equal(catalog.finish(malformed).length, 1);

const qml = fs.readFileSync(path.join(root, 'InstalledFontCatalog.qml'), 'utf8');
const exportPage = fs.readFileSync(path.join(root, 'ExportSection.qml'), 'utf8');
assert.match(qml, /command: \["fc-list", "--format",/);
assert.match(qml, /splitMarker: ""/);
assert.match(qml, /onPageActiveChanged:[\s\S]*if \(!pageActive\) cancel\(\)/);
assert.match(exportPage, /id: fontCatalogLoader\s+active: false/);
assert.match(exportPage, /onVisibleChanged:[\s\S]*fontCatalogLoader\.active = true/);
assert.match(exportPage, /source: "InstalledFontCatalog\.qml"/);
console.log('font catalog tests passed');
