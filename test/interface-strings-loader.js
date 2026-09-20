const fs = require('fs');
const path = require('path');
const vm = require('vm');

function source(file) {
    return fs.readFileSync(file, 'utf8').replace(/^\s*\.(?:pragma|import)\b.*$/gm, '');
}

function loadInterfaceStrings(root, context) {
    for (const [namespace, relativePath] of [
        ['EnglishStrings', 'i18n/English.js'],
        ['PersianStrings', 'i18n/Persian.js'],
        ['ArabicStrings', 'i18n/Arabic.js']
    ]) {
        const moduleContext = vm.createContext({});
        vm.runInContext(source(path.join(root, relativePath)), moduleContext, { filename: relativePath });
        context[namespace] = { values: moduleContext.values };
    }
    vm.runInContext(source(path.join(root, 'InterfaceStrings.js')), context, { filename: 'InterfaceStrings.js' });
}

module.exports = { loadInterfaceStrings };
