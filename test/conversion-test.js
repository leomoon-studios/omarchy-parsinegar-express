// Run directly: node test/conversion-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');

// Load the ordinary classic scripts unchanged; no package/build configuration.
const context = vm.createContext({});
for (const file of ['../vendor/js-bidi.js', '../vendor/js-parsi-reshaper.js', '../ParsiNegar.js', 'fixtures.js']) {
  vm.runInContext(fs.readFileSync(path.join(__dirname, file), 'utf8'), context, {filename: file});
}
const core = context.ParsiNegar;
const bidi = context.JsBidi;
const reshaper = context.JsParsiReshaper;
const fixtureData = context.ParsiNegarFixtures;
const fixtures = fixtureData.conversion;
const table = fixtureData.maryam;
let passed = 0;
function test(name, callback) {
  try { callback(); passed++; }
  catch (error) { error.message = name + ': ' + error.message; throw error; }
}
(function () {
  const identity = { reshape: text => text, getDisplay: text => text };

  test('core namespace is frozen and exposes its public API', () => {
    assert.ok(Object.isFrozen(core));
    for (const name of ['convert', 'normalize', 'applyCustomLigatures', 'normalizeCompatibility', 'mapMaryam']) assert.equal(typeof core[name], 'function');
  });

  test('pipeline order, explicit shaping flags, and complete-input bidi call', () => {
    const calls = [];
    const shaper = { reshape(text, options) {
      calls.push('reshape');
      assert.equal(text, 'ی اً\nپ');
      assert.deepEqual(JSON.parse(JSON.stringify(options)), {
        language: 'Arabic', deleteHarakat: false, shiftHarakatPosition: false,
        deleteTatweel: false, supportZWJ: true, useUnshapedInsteadOfIsolated: false, supportLigatures: true
      });
      assert.ok(Object.isFrozen(options));
      return '\ufeea\u0654\n\u064e\u0651';
    }};
    const bidi = { getDisplay(text, options) {
      calls.push('bidi');
      assert.equal(text, '\ufba5\n\ufc60');
      assert.equal(options, undefined);
      return '\ufc60\n\ufba5';
    }};
    assert.equal(core.convert('ى ا"\nپ', 'compatibility', undefined, bidi, shaper), '\u00da\n\u00e1\u00be');
    assert.deepEqual(calls, ['reshape', 'bidi']);
  });

  test('reverse off skips only bidi and does not require a bidi API', () => {
    let calls = 0;
    const shaper = { reshape(text) { calls++; assert.equal(text, 'ی'); return '\ufeea\u0654'; } };
    assert.equal(core.convert('ى', 'unicode', { reverseWords: false }, null, shaper), '\ufba5');
    assert.equal(calls, 1);
  });

  test('automatic paragraph direction keeps mixed-script paragraphs independent', () => {
    assert.equal(
      core.convert('سلام.\nsalam.\nچطوری؟', 'unicode', {
        reverseWords: true,
        autoParagraphDirection: true
      }, bidi, reshaper),
      '.ﻡﻼﺳ\nsalam.\n؟ﯼﺭﻮﻄﭼ'
    );
  });

  test('automatic paragraph direction preserves hard separators', () => {
    const calls = [];
    const ordering = {
      getDisplay(text) {
        calls.push(text);
        return '[' + text + ']';
      }
    };
    const shaper = { reshape(text) { return text; } };
    assert.equal(
      core.convert('one\r\ntwo\rthree\u2029four', 'unicode', {
        reverseWords: true,
        autoParagraphDirection: true
      }, ordering, shaper),
      '[one]\r\n[two]\r[three]\u2029[four]'
    );
    assert.deepEqual(calls, ['one', 'two', 'three', 'four']);
  });

  test('automatic paragraph direction skips empty paragraphs', () => {
    const calls = [];
    const ordering = {
      getDisplay(text) {
        calls.push(text);
        return '[' + text + ']';
      }
    };
    const shaper = { reshape(text) { return text; } };
    assert.equal(
      core.convert('one\n\nthree\n', 'unicode', {
        reverseWords: true,
        autoParagraphDirection: true
      }, ordering, shaper),
      '[one]\n\n[three]\n'
    );
    assert.deepEqual(calls, ['one', 'three']);
  });

  test('custom reshaper settings are copied and passed only during conversion', () => {
    const ligatures = Object.freeze({ 'RIAL SIGN': true, 'ARABIC LIGATURE ALLAH': false });
    const reshaperOptions = Object.freeze({
      language: 'Kurdish', deleteHarakat: true, shiftHarakatPosition: true,
      deleteTatweel: true, supportZWJ: false, useUnshapedInsteadOfIsolated: true,
      supportLigatures: true, ligatures
    });
    const shaper = { reshape(text, actual) {
      assert.equal(text, 'ریال');
      assert.notEqual(actual, reshaperOptions);
      assert.notEqual(actual.ligatures, ligatures);
      assert.ok(Object.isFrozen(actual));
      assert.ok(Object.isFrozen(actual.ligatures));
      assert.deepEqual(JSON.parse(JSON.stringify(actual)), JSON.parse(JSON.stringify(reshaperOptions)));
      return text;
    }};
    assert.equal(core.convert('ریال', 'unicode', { reverseWords: false, reshaperOptions }, null, shaper), 'ریال');
  });

  test('RIAL SIGN follows the named ligature setting in the real conversion pipeline', () => {
    const base = { reverseWords: false, reshaperOptions: { ligatures: { 'RIAL SIGN': false } } };
    assert.notEqual(core.convert('ریال', 'unicode', base, null, reshaper), '﷼');
    base.reshaperOptions.ligatures['RIAL SIGN'] = true;
    assert.equal(core.convert('ریال', 'unicode', base, null, reshaper), '﷼');
  });

  test('shaping profiles map only Arabic-script profiles to reshaper languages', () => {
    const languages = [];
    const shaper = { reshape(text, options) { languages.push(options.language); return text; } };
    core.convert('پ', 'unicode', {
      reverseWords: false, shapingProfile: 'standardPersianArabic', reshaperOptions: { language: 'Kurdish' }
    }, null, shaper);
    core.convert('پ', 'unicode', {
      reverseWords: false, shapingProfile: 'kurdishUrdu', reshaperOptions: { language: 'Arabic' }
    }, null, shaper);
    assert.deepEqual(languages, ['Arabic', 'Kurdish']);
  });

  test('Hebrew profile bypasses shaping and applies only optional bidi ordering', () => {
    const forbiddenShaper = { reshape() { throw new Error('Hebrew must not enter the reshaper'); } };
    const cases = [
      ['שלום', 'םולש'],
      ['שלום 123!', '!123 םולש'],
      ['abc שלום 123', 'abc 123 םולש'],
      ['שלום\nעולם', 'םולש\nםלוע'],
      ['שלום (123) test', 'test (123) םולש']
    ];
    for (const [input, expected] of cases) {
      assert.equal(core.convert(input, 'unicode', { shapingProfile: 'hebrew' }, bidi, forbiddenShaper), expected);
      assert.equal(core.convert(input, 'unicode', { shapingProfile: 'hebrew', reverseWords: false }, null, forbiddenShaper), input);
    }
    assert.equal(core.convert('שלום ى ا"', 'unicode', {
      shapingProfile: 'hebrew', reverseWords: false
    }, null, null), 'שלום ى ا"', 'Hebrew profile must also bypass Arabic-specific normalization');
  });

  test('Hebrew profile rejects Compatibility mode before shaping or Maryam mapping', () => {
    assert.throws(() => core.convert('שלום', 'compatibility', {
      shapingProfile: 'hebrew', reverseWords: false
    }, null, null), { name: 'RangeError', code: 'HEBREW_COMPATIBILITY_UNSUPPORTED' });
  });

  test('Hebrew SVG-export preparation uses the same bidi-only Unicode result', () => {
    const source = 'מחיר 123 ש״ח';
    const preparedForExport = core.convert(source, 'unicode', { shapingProfile: 'hebrew' }, bidi, null);
    assert.equal(preparedForExport, 'ח״ש 123 ריחמ');
  });

  test('explicit Arabic-script profiles preserve legacy Persian and Kurdish output', () => {
    const persian = 'این یک متن فارسی است';
    const kurdish = 'کوردی و ئوردوو';
    assert.equal(
      core.convert(persian, 'unicode', { reverseWords: true, shapingProfile: 'standardPersianArabic' }, bidi, reshaper),
      core.convert(persian, 'unicode', { reverseWords: true }, bidi, reshaper)
    );
    assert.equal(
      core.convert(kurdish, 'unicode', {
        reverseWords: true, shapingProfile: 'kurdishUrdu', reshaperOptions: { language: 'Kurdish' }
      }, bidi, reshaper),
      core.convert(kurdish, 'unicode', { reverseWords: true, reshaperOptions: { language: 'Kurdish' } }, bidi, reshaper)
    );
  });

  test('VideoStudio applies only after Maryam mapping and never modifies Unicode output', () => {
    assert.equal(core.convert('\u0153', 'unicode', { videoStudioPro: true }, identity, identity), '\u0153');
    assert.equal(core.convert('\ufed2', 'compatibility', { videoStudioPro: true }, identity, identity), '\u00fe');
    assert.equal(core.convert('\u0153', 'compatibility', { videoStudioPro: true }, identity, identity), '');
  });

  test('text and helper argument validation rejects coercion', () => {
    for (const text of [null, undefined, 1, true, [], {}, new String('پ')]) {
      assert.throws(() => core.convert(text, 'unicode', undefined, identity, identity), { name: 'TypeError' });
      for (const name of ['normalize', 'applyCustomLigatures', 'normalizeCompatibility', 'mapMaryam']) assert.throws(() => core[name](text), { name: 'TypeError' });
    }
    for (const value of [null, 0, 'true', {}]) assert.throws(() => core.mapMaryam('', value), { name: 'TypeError' });
  });

  test('modes and options are strict even for empty text', () => {
    for (const mode of [undefined, null, 'Unicode', 'Maryam', '', 0]) assert.throws(() => core.convert('', mode, {}, identity, identity), { name: 'RangeError' });
    for (const options of [null, [], true, 1, '', new Date(), { unknown: true }, { reverseWords: 1 }, { videoStudioPro: 'false' }, { autoParagraphDirection: 1 }, { [Symbol('x')]: true }]) {
      assert.throws(() => core.convert('', 'unicode', options, identity, identity), { name: 'TypeError' });
    }
    for (const shapingProfile of ['unknown', null, false, 1]) {
      assert.throws(() => core.convert('', 'unicode', { shapingProfile }, identity, identity), { name: 'RangeError' });
    }
    for (const reshaperOptions of [null, [], true, new Date(), { unknown: true }, { ligatures: [] }, { [Symbol('x')]: true }]) {
      assert.throws(() => core.convert('', 'unicode', { reshaperOptions }, identity, reshaper), { name: 'TypeError' });
    }
    assert.throws(() => core.convert('', 'unicode', { reshaperOptions: { ligatures: { UNKNOWN: true } } }, identity, reshaper), { name: 'TypeError' });
  });

  test('options are read from own properties and frozen inputs are never changed', () => {
    const options = Object.freeze({ reverseWords: false, videoStudioPro: true });
    assert.equal(core.convert('\ufed2', 'compatibility', options, null, identity), '\u00fe');
    assert.deepEqual(options, { reverseWords: false, videoStudioPro: true });
    let called = 0;
    core.convert('', 'unicode', Object.create({ reverseWords: false }), { getDisplay(text) { called++; return text; } }, identity);
    assert.equal(called, 1);
    core.convert('', 'unicode', { reverseWords: undefined, videoStudioPro: undefined }, identity, identity);
  });

  test('invalid dependency interfaces or return values fail clearly', () => {
    assert.throws(() => core.convert('', 'unicode', {}, identity, {}), { name: 'TypeError' });
    assert.throws(() => core.convert('', 'unicode', {}, {}, identity), { name: 'TypeError' });
    assert.throws(() => core.convert('', 'unicode', {}, identity, { reshape: () => null }), { name: 'TypeError' });
    assert.throws(() => core.convert('', 'unicode', {}, { getDisplay: () => 0 }, identity), { name: 'TypeError' });
    const error = new Error('deliberate failure');
    assert.throws(() => core.convert('', 'unicode', {}, identity, { reshape() { throw error; } }), value => value === error);
  });

}());
(function () {

  for (const fixture of fixtures.cases) {
    for (const mode of ['unicode', 'compatibility']) {
      for (const reverseWords of [false, true]) {
        for (const videoStudioPro of [false, true]) {
          test(fixture.id + ': ' + mode + ' reverse=' + reverseWords + ' video=' + videoStudioPro, () => {
            const name = (reverseWords ? 'visual' : 'logical') + (mode === 'compatibility' && videoStudioPro ? 'VideoStudio' : '');
            const expected = fixture.expected[mode][name];
            const actual = core.convert(fixture.input, mode, { reverseWords, videoStudioPro }, bidi, reshaper);
            assert.equal(actual, expected);
            assert.deepEqual(Array.from(actual, ch => ch.codePointAt(0)), Array.from(expected, ch => ch.codePointAt(0)));
          });
        }
      }
    }
  }

  test('default flags match reverse on / VideoStudio off', () => {
    for (const mode of ['unicode', 'compatibility']) {
      for (const fixture of fixtures.cases) assert.equal(core.convert(fixture.input, mode, undefined, bidi, reshaper), fixture.expected[mode].visual);
    }
  });

  test('the original editor corpus completes in every configuration (smoke check, not a golden oracle)', () => {
    const input = fixtureData['editor-corpus'].text;
    assert.equal(input.split('\n').length, 69);
    for (const mode of ['unicode', 'compatibility']) {
      for (const reverseWords of [false, true]) {
        for (const videoStudioPro of [false, true]) {
          const output = core.convert(input, mode, { reverseWords, videoStudioPro }, bidi, reshaper);
          assert.ok(output.length > 0);
          assert.equal(output.split('\n').length, input.split('\n').length);
          assert.ok(!output.includes('\ufffd'));
        }
      }
    }
  });

  test('unsupported isolates propagate only when bidi ordering is requested', () => {
    assert.throws(() => core.convert('\u2066x\u2069', 'unicode', undefined, bidi, reshaper), { code: 'ERR_BIDI_UNSUPPORTED_ISOLATE' });
    assert.equal(core.convert('\u2066x\u2069', 'unicode', { reverseWords: false }, null, reshaper), '\u2066x\u2069');
  });

  test('repeated calls and large text do not share mutable output or lose boundaries', () => {
    const input = 'پ '.repeat(10000);
    assert.equal(core.convert(input, 'compatibility', { reverseWords: false }, null, reshaper), 'N '.repeat(10000));
    assert.equal(core.convert('فف', 'compatibility', { videoStudioPro: true }, bidi, reshaper), '\u00fe\u00ce');
    assert.equal(core.convert('فف', 'compatibility', undefined, bidi, reshaper), '\u0153\u00ce');
  });

}());
(function () {
  for (const [i, [key]] of table.pairs.entries()) {
    test('ordered Maryam entry ' + i + ' uses the first source match', () => {
      const expected = table.pairs.find(([candidate]) => candidate === key)[1];
      assert.equal(core.mapMaryam(key), expected);
      assert.equal(core.mapMaryam(key, true), expected.replace(/\u0153/g, '\u00fe'));
    });
  }

  for (const [stage, entries] of Object.entries(fixtures.stages)) {
    const method = { normalize: 'normalize', customLigatures: 'applyCustomLigatures', compatibilityNormalization: 'normalizeCompatibility' }[stage];
    for (const [i, fixture] of entries.entries()) test(stage + ' frozen rule ' + i, () => assert.equal(core[method](fixture.input), fixture.expected));
  }

  test('spaces and LF handling match the original loop without general whitespace trimming', () => {
    assert.equal(core.mapMaryam('\n\n \n\ufe8f\n\n \n'), ' \nJ\n\n ');
    assert.equal(core.mapMaryam('\t\r😀abc\u0000'), '');
    assert.equal(core.mapMaryam('\ufe8f\r\n\ufe8f'), 'J\nJ');
    assert.equal(core.mapMaryam('\u2003\ufe8f\u2003'), 'J');
    assert.equal(core.mapMaryam(' \n '), ' \n ');
  });

  test('golden corpus has complete static outputs and documented expectations', () => {
    const ids = new Set();
    for (const fixture of fixtures.cases) {
      assert.ok(!ids.has(fixture.id)); ids.add(fixture.id);
      assert.equal(fixture.source.kind, 'hand-derived');
      assert.ok(fixture.source.rationale.length > 10);
      assert.equal(typeof fixture.input, 'string');
      for (const mode of ['unicode', 'compatibility']) for (const value of Object.values(fixture.expected[mode])) assert.equal(typeof value, 'string');
      assert.equal(Object.keys(fixture.expected.unicode).length, 2);
      assert.equal(Object.keys(fixture.expected.compatibility).length, 4);
    }
    assert.equal(ids.size, 42);
  });

}());

console.log(passed + ' tests passed');
