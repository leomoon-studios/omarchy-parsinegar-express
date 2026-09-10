// Run directly: node test/svg-curve-export-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const context = vm.createContext({ TextDecoder, TextEncoder });
for (const file of ['vendor/js-bidi.js', 'vendor/js-parsi-reshaper.js', 'ParsiNegar.js', 'vendor/typr.js', 'ResourceLimits.js', 'SvgCurveExporter.js']) {
    vm.runInContext(read(file), context, { filename: file });
}

function bytes(file) {
    const buffer = fs.readFileSync(file);
    return new Uint8Array(buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength));
}

function convert(text, mode) {
    return context.ParsiNegar.convert(text, mode, {
        reverseWords: true,
        reshaperOptions: { ligatures: { 'RIAL SIGN': true } }
    }, context.JsBidi, context.JsParsiReshaper);
}

function exportWith(text, font, alignment = 'left') {
    return context.SvgCurveExporter.exportSvg(text, font, {
        fontSize: 48,
        lineSpacing: 1.5,
        alignment,
        bounds: { width: 600, height: 300, padding: 20 },
        fill: '#171717'
    }, context.Typr, context.ResourceLimits);
}

function transforms(svg) {
    return [...svg.matchAll(/transform="translate\(([-0-9.]+) ([-0-9.]+)\)/g)].map(match => ({ x: Number(match[1]), y: Number(match[2]) }));
}

function assertCurveOnly(svg) {
    assert.match(svg, /^<\?xml version="1\.0" encoding="UTF-8"\?>\n<svg /);
    assert.match(svg, /<path /);
    assert.doesNotMatch(svg, /<(?:text|tspan|image|foreignObject)\b/i);
    assert.doesNotMatch(svg, /(?:font-family|@font-face|data:font|\bhref\s*=)/i);
}

const vazirmatn = bytes(path.join(root, 'assets/fonts/Vazirmatn[wght].ttf'));
const limits = context.ResourceLimits;
const source = 'پارسی نگار ریال ۱۲۳\nمتن دوم';
const unicodeText = convert(source, 'unicode');
assert.ok(unicodeText.includes('\uFDFC'), 'Rial must be converted to its enabled ligature glyph');

const left = exportWith(unicodeText, vazirmatn, 'left');
const center = exportWith(unicodeText, vazirmatn, 'center');
const right = exportWith(unicodeText, vazirmatn, 'right');
for (const svg of [left, center, right]) assertCurveOnly(svg);
assert.equal((left.match(/<path /g) || []).length, 2, 'one curve path is emitted per non-empty line');
assert.equal(left, exportWith(unicodeText, vazirmatn, 'left'), 'curve output must be deterministic');

const leftPositions = transforms(left);
const centerPositions = transforms(center);
const rightPositions = transforms(right);
assert.equal(leftPositions.length, 2);
assert.equal(leftPositions[1].y - leftPositions[0].y, 72, 'lineSpacing must control baseline distance');
for (let i = 0; i < leftPositions.length; i++) {
    assert.ok(leftPositions[i].x < centerPositions[i].x);
    assert.ok(centerPositions[i].x < rightPositions[i].x);
}

const inspection = context.SvgCurveExporter.inspect(unicodeText, vazirmatn, {}, context.Typr, limits);
assert.equal(inspection.font.family, 'Vazirmatn');
assert.equal(inspection.font.style, 'Regular', 'a variable font must default to its declared default instance');
assert.equal(inspection.missingGlyphs.length, 0);
const explicitRegular = context.SvgCurveExporter.exportSvg(unicodeText, vazirmatn, {
    fontIndex: 3, fontSize: 48, lineSpacing: 1.5, alignment: 'left',
    bounds: { width: 600, height: 300, padding: 20 }, fill: '#171717'
}, context.Typr, limits);
const explicitThin = context.SvgCurveExporter.exportSvg(unicodeText, vazirmatn, {
    fontIndex: 0, fontSize: 48, lineSpacing: 1.5, alignment: 'left',
    bounds: { width: 600, height: 300, padding: 20 }, fill: '#171717'
}, context.Typr, limits);
assert.equal(left, explicitRegular, 'the implicit variable-font instance must match Vazirmatn Regular');
assert.notEqual(left, explicitThin, 'the implicit variable-font instance must not fall back to Vazirmatn Thin');
const missingCombinedMarks = context.SvgCurveExporter.inspect('\uFC5E\uFC5F\uFC60\uFC61\uFC62', vazirmatn, {}, context.Typr, limits);
assert.deepEqual(Array.from(missingCombinedMarks.missingGlyphs, item => item.label),
    ['U+FC5E', 'U+FC5F', 'U+FC60', 'U+FC61', 'U+FC62']);
assertCurveOnly(exportWith(unicodeText + '🧬', vazirmatn));
assert.deepEqual(Array.from(context.SvgCurveExporter.inspect(unicodeText + '🧬', vazirmatn, {}, context.Typr, limits).missingGlyphs,
    item => item.label), ['U+1F9EC']);
assert.throws(
    () => context.SvgCurveExporter.exportSvg(unicodeText, vazirmatn, { bounds: { width: 10, height: 10 } }, context.Typr, limits),
    error => error.code === 'BOUNDS_TOO_SMALL'
);

const alternateFontPath = '/usr/share/fonts/noto/NotoSansArabic-Regular.ttf';
if (fs.existsSync(alternateFontPath)) {
    const alternate = exportWith(unicodeText, bytes(alternateFontPath));
    assertCurveOnly(alternate);
    assert.notEqual(alternate, left, 'the exact selected font must determine the outlines');
}

const maryamFontPath = process.env.PARSINEGAR_MARYAM_TEST_FONT ||
    '/home/leomoon/Projects/python3_projects/parsinegar_codehub/src/_fonts/LMN Maryam.ttf';
if (fs.existsSync(maryamFontPath)) {
    const compatibilityText = convert(source, 'compatibility');
    const compatibility = exportWith(compatibilityText, bytes(maryamFontPath), 'right');
    assertCurveOnly(compatibility);
    assert.equal(context.SvgCurveExporter.inspect(compatibilityText, bytes(maryamFontPath), {}, context.Typr, limits).missingGlyphs.length, 0);
    assert.notEqual(compatibility, left);
} else {
    console.log('Compatibility outline fixture skipped; set PARSINEGAR_MARYAM_TEST_FONT to an LMN-compatible TTF/OTF file');
}

console.log('SVG curve export checks passed');
