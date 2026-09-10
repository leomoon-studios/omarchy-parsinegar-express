// Run directly: node test/resource-limits-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.join(__dirname, '..');
const context = vm.createContext({ TextDecoder, TextEncoder });
for (const file of ['vendor/typr.js', 'ResourceLimits.js', 'SvgCurveExporter.js']) {
    vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context, { filename: file });
}

const limits = context.ResourceLimits;
const values = limits.values;
const fontBuffer = fs.readFileSync(path.join(root, 'assets/fonts/Vazirmatn[wght].ttf'));
const font = new Uint8Array(fontBuffer.buffer.slice(fontBuffer.byteOffset, fontBuffer.byteOffset + fontBuffer.byteLength));
const exporter = context.SvgCurveExporter;

assert.equal(limits.assertTextLength('پ'.repeat(values.maxConversionTextLength), values.maxConversionTextLength, 'CONVERSION_TEXT_TOO_LARGE').length,
    values.maxConversionTextLength);
assert.throws(() => limits.assertTextLength('پ'.repeat(values.maxConversionTextLength + 1), values.maxConversionTextLength, 'CONVERSION_TEXT_TOO_LARGE'),
    error => error.code === 'CONVERSION_TEXT_TOO_LARGE');
const million = 'پ'.repeat(1000000);
const began = Date.now();
assert.throws(() => limits.assertTextLength(million, values.maxConversionTextLength, 'CONVERSION_TEXT_TOO_LARGE'),
    error => error.code === 'CONVERSION_TEXT_TOO_LARGE');
assert.ok(Date.now() - began < 100, 'oversized text must be rejected before conversion work');

assert.equal(limits.assertTextLength('پ'.repeat(values.maxSvgTextLength), values.maxSvgTextLength, 'EXPORT_TEXT_TOO_LARGE').length,
    values.maxSvgTextLength);
assert.throws(() => exporter.inspect('پ'.repeat(values.maxSvgTextLength + 1), font, {}, context.Typr, limits),
    error => error.code === 'EXPORT_TEXT_TOO_LARGE');
assert.throws(() => limits.assertFontBytes({ byteLength: values.maxFontBytes + 1 }), error => error.code === 'FONT_TOO_LARGE');
for (const malformed of [new Uint8Array(0), new Uint8Array([0, 1, 2, 3])]) {
    assert.throws(() => exporter.inspect('پ', malformed, {}, context.Typr, limits), error => error.code === 'INVALID_FONT');
}

const validMaximums = {
    fontSize: values.maxFontSize,
    lineSpacing: values.maxLineSpacing,
    bounds: { width: values.maxDimension, height: values.maxDimension, padding: values.maxPadding }
};
assert.match(exporter.exportSvg('پ\nپ', font, validMaximums, context.Typr, limits), /<svg /);
for (const options of [
    { fontSize: values.maxFontSize + 1 },
    { lineSpacing: values.maxLineSpacing + 1 },
    { bounds: { width: values.maxDimension + 1 } },
    { bounds: { height: values.maxDimension + 1 } },
    { bounds: { padding: values.maxPadding + 1 } },
    { fontSize: Number.MAX_VALUE }
]) {
    assert.throws(() => exporter.exportSvg('پ', font, options, context.Typr, limits), error => error.code === 'INVALID_OPTION');
}

const tallText = Array(1001).fill('پ').join('\n');
const tallSvg = exporter.exportSvg(tallText, font, {}, context.Typr, limits);
assert.equal((tallSvg.match(/<path /g) || []).length, 1001, 'large multiline input below the limit must export');

const tinyOutputLimits = {
    values: Object.assign({}, values, { maxSvgBytes: 200 }),
    assertTextLength: limits.assertTextLength,
    assertFontBytes: limits.assertFontBytes,
    assertSvgSize(svg) {
        if (Buffer.byteLength(svg, 'utf8') > this.values.maxSvgBytes) {
            const error = new Error('too large');
            error.code = 'SVG_TOO_LARGE';
            throw error;
        }
        return svg;
    }
};
assert.throws(() => exporter.exportSvg('پارسی نگار', font, {}, context.Typr, tinyOutputLimits),
    error => error.code === 'SVG_TOO_LARGE');
assert.equal(limits.utf8ByteLength('ASCII پارسی 🧬'), Buffer.byteLength('ASCII پارسی 🧬', 'utf8'));

console.log('Resource limit checks passed');
