// Run directly: node test/settings-test.js
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const context = vm.createContext({});
for (const file of ['../vendor/js-parsi-reshaper.js', '../ReshaperSettings.js', '../InterfaceStrings.js']) {
    vm.runInContext(fs.readFileSync(path.join(__dirname, file), 'utf8'), context, { filename: file });
}
const settings = context.ReshaperSettings;
const metadata = settings.metadata;
const strings = context.InterfaceStrings;
const plain = value => JSON.parse(JSON.stringify(value));
assert.deepEqual(plain(metadata.languages), ['Arabic', 'Kurdish']);
assert.deepEqual(plain(metadata.shapingProfiles), [
    { id: 'standardPersianArabic', language: 'Arabic' },
    { id: 'kurdishUrdu', language: 'Kurdish' },
    { id: 'hebrew', language: null }
]);
assert.deepEqual(plain(metadata.ligatureGroups.map(group => group.ligatures.length)), [3, 9, 274]);
assert.equal(metadata.ligatureGroups.flatMap(group => group.ligatures).length, 286);
assert.deepEqual(Array.from(strings.languages), ['en', 'fa']);
assert.equal(strings.text('en', 'settings.title'), 'Settings');
assert.equal(strings.text('fa', 'settings.title'), 'تنظیمات');
assert.equal(strings.text('en', 'settings.language'), 'SHAPING PROFILE');
assert.equal(strings.text('fa', 'settings.language'), 'نمایهٔ شکل‌دهی');
assert.equal(strings.text('en', 'settings.profileLabel.standardPersianArabic'), 'Persian/Arabic');
assert.equal(strings.text('fa', 'settings.profileLabel.standardPersianArabic'), 'پارسی/عربی');
assert.equal(strings.text('en', 'settings.profileLabel.kurdishUrdu'), 'Kurdish/Urdu');
assert.equal(strings.text('fa', 'settings.profileLabel.kurdishUrdu'), 'کردی/اردو');
assert.equal(strings.text('en', 'settings.profileLabel.hebrew'), 'Hebrew');
assert.equal(strings.text('fa', 'settings.profileLabel.hebrew'), 'عبری');
assert.equal(strings.text('en', 'settings.profileDescription.standardPersianArabic'), 'Uses standard Unicode letter forms for Persian and Arabic.');
assert.ok(strings.text('fa', 'settings.profileDescription.kurdishUrdu').includes('کردی و اردو'));
assert.ok(strings.text('en', 'settings.profileDescription.hebrew').includes('bidi visual ordering only'));
assert.ok(strings.text('fa', 'settings.profileDescription.hebrew').includes('عبری'));
assert.equal(strings.text('en', 'toggle.reverse'), 'Apply bidi visual ordering');
assert.equal(strings.text('fa', 'toggle.reverse'), 'اعمال ترتیب نمایشی دوجهته');
for (const key of ['settings.hebrewNoticeTitle', 'settings.hebrewNoticeDescription']) {
    assert.notEqual(strings.text('en', key), key, key + ' English');
    assert.notEqual(strings.text('fa', key), key, key + ' Persian');
}
assert.equal(strings.text('fa', 'settings.deleteHarakat'), 'حذف اعراب');
assert.equal(strings.text('fa', 'settings.shiftHarakat').startsWith('جابه‌جایی'), true);
assert.equal(strings.text('fa', 'settings.group.sentences'), 'لیگچرهای عبارتی');
assert.equal(strings.text('en', 'export.title'), 'Export SVG');
assert.equal(strings.text('fa', 'export.title'), 'خروجی SVG');
assert.equal(strings.text('en', 'export.fontRequired'), 'Choose a Maryam-compatible font');
assert.equal(strings.text('fa', 'export.save'), 'ذخیرهٔ SVG…');
for (const key of ['export.mode', 'export.font', 'export.chooseFont', 'export.fontSize', 'export.moreOptions', 'export.lineSpacing', 'export.alignment', 'export.alignLeft', 'export.alignCenter', 'export.alignRight', 'export.width', 'export.height', 'export.padding', 'export.auto', 'export.success', 'export.processing', 'export.warning.missingGlyphs', 'export.error.noText', 'export.error.fontRequired', 'export.error.invalidOption', 'export.error.invalidFont', 'export.error.missingGlyphs', 'export.error.bounds', 'export.error.unsupportedGlyph', 'export.error.save', 'export.error.generic', 'export.error.textTooLarge', 'export.error.fontTooLarge', 'export.error.svgTooLarge', 'export.error.dimensions', 'export.error.invalidPath', 'status.converting', 'status.textTooLarge']) {
    assert.notEqual(strings.text('en', key), key, key + ' English');
    assert.notEqual(strings.text('fa', key), key, key + ' Persian');
}
assert.equal(strings.normalize('unknown'), 'en');
const defaults = settings.defaults(metadata);
assert.deepEqual({
    language: defaults.language,
    deleteHarakat: defaults.deleteHarakat,
    shiftHarakatPosition: defaults.shiftHarakatPosition,
    deleteTatweel: defaults.deleteTatweel,
    supportZWJ: defaults.supportZWJ,
    useUnshapedInsteadOfIsolated: defaults.useUnshapedInsteadOfIsolated,
    supportLigatures: defaults.supportLigatures
}, {
    language: 'Arabic', deleteHarakat: false, shiftHarakatPosition: false,
    deleteTatweel: false, supportZWJ: true, useUnshapedInsteadOfIsolated: false,
    supportLigatures: true
});
assert.equal(metadata.defaults.ligatures['RIAL SIGN'], false);
assert.equal(defaults.ligatures['RIAL SIGN'], true);
assert.equal(defaults.ligatures['ARABIC LIGATURE ALLAH'], true);
assert.deepEqual(Object.keys(defaults.ligatures).filter(name => defaults.ligatures[name]), [
    'ARABIC LIGATURE ALLAH',
    'RIAL SIGN',
    'ARABIC LIGATURE LAM WITH ALEF',
    'ARABIC LIGATURE LAM WITH ALEF WITH HAMZA ABOVE',
    'ARABIC LIGATURE LAM WITH ALEF WITH HAMZA BELOW',
    'ARABIC LIGATURE LAM WITH ALEF WITH MADDA ABOVE'
]);
for (const language of metadata.languages) {
    const selected = settings.sanitize(metadata, { language });
    assert.equal(selected.language, language);
    assert.equal(typeof context.JsParsiReshaper.reshape('پ', selected), 'string');
}
assert.equal(settings.sanitize(metadata, { language: 'ArabicV2' }).language, 'Arabic');
for (const flag of settings.flags) {
    const selected = settings.sanitize(metadata, { [flag]: !defaults[flag] });
    assert.equal(selected[flag], !defaults[flag], flag);
}
const custom = settings.sanitize(metadata, {
    language: 'Kurdish', deleteHarakat: true, unknown: true,
    ligatures: { 'RIAL SIGN': true, 'UNKNOWN': true }
});
assert.equal(custom.language, 'Kurdish');
assert.equal(custom.deleteHarakat, true);
assert.equal(custom.ligatures['RIAL SIGN'], true);
assert.equal(custom.ligatures.UNKNOWN, undefined);
assert.equal(Object.keys(custom.ligatures).length, 286);
for (const raw of ['', '{', 'null', '[]', '{"schemaVersion":2,"settings":{}}']) {
    const recovered = settings.parse(metadata, raw);
    assert.equal(recovered.recovered, true);
    assert.deepEqual(plain(recovered.settings), plain(defaults));
}
const serialized = settings.serialize(metadata, custom);
assert.ok(!serialized.includes('draftText'));
const restored = settings.parse(metadata, serialized);
assert.equal(restored.recovered, false);
assert.equal(restored.uiLanguage, 'en');
assert.equal(restored.shapingProfile, 'kurdishUrdu');
assert.deepEqual(plain(restored.settings), plain(custom));
const persianSerialized = settings.serialize(metadata, custom, 'fa');
assert.equal(settings.parse(metadata, persianSerialized).uiLanguage, 'fa');
const legacyArabic = settings.parse(metadata, JSON.stringify({ schemaVersion: 1, settings: { language: 'Arabic' } }));
const legacyKurdish = settings.parse(metadata, JSON.stringify({ schemaVersion: 1, settings: { language: 'Kurdish' } }));
assert.equal(legacyArabic.shapingProfile, 'standardPersianArabic');
assert.equal(legacyKurdish.shapingProfile, 'kurdishUrdu');
assert.equal(legacyKurdish.settings.language, 'Kurdish');
const hebrewSettings = settings.parse(metadata, JSON.stringify({
    schemaVersion: 1, shapingProfile: 'hebrew', settings: { language: 'Kurdish', deleteHarakat: true }
}));
assert.equal(hebrewSettings.shapingProfile, 'hebrew');
assert.equal(hebrewSettings.settings.language, 'Kurdish', 'Hebrew must retain the last reshaper table for later reuse');
const invalidProfile = settings.parse(metadata, JSON.stringify({
    schemaVersion: 1, shapingProfile: 'unknown', settings: { language: 'Kurdish' }
}));
assert.equal(invalidProfile.shapingProfile, 'standardPersianArabic');
assert.equal(invalidProfile.settings.language, 'Arabic');
const serializedHebrew = settings.serialize(metadata, hebrewSettings.settings, 'en', 'hebrew');
assert.equal(JSON.parse(serializedHebrew).shapingProfile, 'hebrew');
assert.equal(settings.parse(metadata, serializedHebrew).settings.language, 'Kurdish');
assert.equal(context.JsParsiReshaper.reshape('ریال', { ligatures: { 'RIAL SIGN': true } }), '﷼');
assert.notEqual(context.JsParsiReshaper.reshape('ریال', { ligatures: { 'RIAL SIGN': false } }), '﷼');
assert.equal(context.JsParsiReshaper.reshape('الله', { ligatures: { 'ARABIC LIGATURE ALLAH': true } }), 'ﷲ');
assert.notEqual(context.JsParsiReshaper.reshape('الله', { ligatures: { 'ARABIC LIGATURE ALLAH': false } }), 'ﷲ');
assert.notEqual(context.JsParsiReshaper.reshape('بسم الله الرحمن الرحيم', {
    ligatures: { 'ARABIC LIGATURE BISMILLAH AR-RAHMAN AR-RAHEEM': true }
}), context.JsParsiReshaper.reshape('بسم الله الرحمن الرحيم', {
    ligatures: { 'ARABIC LIGATURE BISMILLAH AR-RAHMAN AR-RAHEEM': false }
}));
console.log('Reshaper settings checks passed');
