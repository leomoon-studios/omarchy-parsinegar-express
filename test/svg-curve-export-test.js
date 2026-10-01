// Run directly: node test/svg-curve-export-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const context = vm.createContext({ TextDecoder, TextEncoder });
for (const file of ['vendor/js-bidi.js', 'vendor/js-parsi-reshaper.js', 'ParsiNegar.js', 'vendor/typr.js', 'SafeTypr.js', 'ResourceLimits.js', 'SvgCurveExporter.js']) {
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
    }, context.Typr, context.ResourceLimits, context.SafeTypr);
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

const inspection = context.SvgCurveExporter.inspect(unicodeText, vazirmatn, {}, context.Typr, limits, context.SafeTypr);
assert.equal(inspection.font.family, 'Vazirmatn');
assert.equal(inspection.font.style, 'Regular', 'a variable font must default to its declared default instance');
assert.equal(inspection.missingGlyphs.length, 0);
const explicitRegular = context.SvgCurveExporter.exportSvg(unicodeText, vazirmatn, {
    fontIndex: 3, fontSize: 48, lineSpacing: 1.5, alignment: 'left',
    bounds: { width: 600, height: 300, padding: 20 }, fill: '#171717'
}, context.Typr, limits, context.SafeTypr);
const explicitThin = context.SvgCurveExporter.exportSvg(unicodeText, vazirmatn, {
    fontIndex: 0, fontSize: 48, lineSpacing: 1.5, alignment: 'left',
    bounds: { width: 600, height: 300, padding: 20 }, fill: '#171717'
}, context.Typr, limits, context.SafeTypr);
assert.equal(left, explicitRegular, 'the implicit variable-font instance must match Vazirmatn Regular');
assert.notEqual(left, explicitThin, 'the implicit variable-font instance must not fall back to Vazirmatn Thin');
const missingCombinedMarks = context.SvgCurveExporter.inspect('\uFC5E\uFC5F\uFC60\uFC61\uFC62', vazirmatn, {}, context.Typr, limits, context.SafeTypr);
assert.deepEqual(Array.from(missingCombinedMarks.missingGlyphs, item => item.label),
    ['U+FC5E', 'U+FC5F', 'U+FC60', 'U+FC61', 'U+FC62']);

const hebrewSource = 'שלום 123';
const hebrewText = context.ParsiNegar.convert(hebrewSource, 'unicode', {
    shapingProfile: 'hebrew', reverseWords: true
}, context.JsBidi, context.JsParsiReshaper);
assert.equal(hebrewText, '123 םולש');
assertCurveOnly(exportWith(hebrewText, vazirmatn));
assert.ok(context.SvgCurveExporter.inspect(hebrewText, vazirmatn, {}, context.Typr, limits, context.SafeTypr).missingGlyphs.length > 0,
    'bundled Vazirmatn must report its missing Hebrew glyphs without blocking export');
const hebrewFontPath = '/usr/share/fonts/TTF/OpenSans-Regular.ttf';
if (fs.existsSync(hebrewFontPath)) {
    const hebrewFont = bytes(hebrewFontPath);
    assertCurveOnly(exportWith(hebrewText, hebrewFont));
    assert.equal(context.SvgCurveExporter.inspect(hebrewText, hebrewFont, {}, context.Typr, limits, context.SafeTypr).missingGlyphs.length, 0);
}

assertCurveOnly(exportWith(unicodeText + '🧬', vazirmatn));
assert.deepEqual(Array.from(context.SvgCurveExporter.inspect(unicodeText + '🧬', vazirmatn, {}, context.Typr, limits, context.SafeTypr).missingGlyphs,
    item => item.label), ['U+1F9EC']);
assert.throws(
    () => context.SvgCurveExporter.exportSvg(unicodeText, vazirmatn, { bounds: { width: 10, height: 10 } }, context.Typr, limits, context.SafeTypr),
    error => error.code === 'BOUNDS_TOO_SMALL'
);
assert.throws(
    () => context.SvgCurveExporter.inspect('پ', vazirmatn, {}, context.Typr, limits),
    error => error.code === 'MISSING_ENGINE',
    'SVG inspection must not parse fonts without SafeTypr'
);
function ottoWithCff(cff) {
    const font = Buffer.alloc(28 + cff.length);
    font.write('OTTO', 0, 'ascii');
    font.writeUInt16BE(1, 4);
    font.write('CFF ', 12, 'ascii');
    font.writeUInt32BE(28, 20);
    font.writeUInt32BE(cff.length, 24);
    cff.copy(font, 28);
    return font;
}

const cffHeader = Buffer.from([1, 0, 4, 1]);
const validName = Buffer.from([0, 1, 1, 1, 2, 65]);
const validTopDict = Buffer.from([0, 1, 1, 1, 2, 139]);
const emptyIndex = Buffer.from([0, 0]);
const cffIndexes = [validName, validTopDict, emptyIndex, emptyIndex];
const malformedIndexes = [
    ['zero first offset', Buffer.from([0, 1, 1, 0, 1, 65])],
    ['reversed offsets', Buffer.from([0, 1, 1, 2, 1, 65])],
    ['truncated offset array', Buffer.from([0, 1, 4, 0, 0, 0, 1])],
    ['out-of-table offset', Buffer.from([0, 1, 1, 1, 32, 65])],
    ['maximum 32-bit offset', Buffer.from([0, 1, 4, 0, 0, 0, 1, 255, 255, 255, 255])]
];
const malformedFonts = [['zero-length CFF table', ottoWithCff(Buffer.alloc(0))]];
for (const position of [0, 1]) {
    const indexes = cffIndexes.slice();
    indexes[position] = emptyIndex;
    malformedFonts.push([`${position === 0 ? 'Name' : 'Top DICT'} INDEX: zero entries`,
        ottoWithCff(Buffer.concat([cffHeader, ...indexes]))]);
}
for (let position = 0; position < cffIndexes.length; position++) {
    for (const [label, malformed] of malformedIndexes) {
        const indexes = cffIndexes.slice();
        indexes[position] = malformed;
        malformedFonts.push([`${['Name', 'Top DICT', 'String', 'Global Subr'][position]} INDEX: ${label}`,
            ottoWithCff(Buffer.concat([cffHeader, ...indexes]))]);
    }
}
for (const [label, font] of malformedFonts) {
    for (const action of ['inspect', 'exportSvg']) {
        assert.throws(
            () => context.SvgCurveExporter[action]('پ', font, {}, context.Typr, limits, context.SafeTypr),
            error => error.code === 'INVALID_FONT',
            `${label} must fail before Typr parses it during ${action}`
        );
    }
}

const otfFixture = process.env.SAFE_TYPR_OTF_FIXTURE || '/usr/share/fonts/gsfonts/NimbusSans-Regular.otf';
if (fs.existsSync(otfFixture)) {
    const otf = bytes(otfFixture);
    assert.equal(context.SvgCurveExporter.inspect('A', otf, {}, context.Typr, limits, context.SafeTypr).missingGlyphs.length, 0);
    assertCurveOnly(exportWith('A', otf));
} else {
    console.log('OpenType/CFF outline fixture skipped; set SAFE_TYPR_OTF_FIXTURE to an OTF font');
}

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
    assert.equal(context.SvgCurveExporter.inspect(compatibilityText, bytes(maryamFontPath), {}, context.Typr, limits, context.SafeTypr).missingGlyphs.length, 0);
    assert.notEqual(compatibility, left);
} else {
    console.log('Compatibility outline fixture skipped; set PARSINEGAR_MARYAM_TEST_FONT to an LMN-compatible TTF/OTF file');
}

console.log('SVG curve export checks passed');
