// Contributor-only benchmark: node test/performance-test.js
// Node measures the core, not QML rendering or desktop idle CPU.
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { performance } = require('perf_hooks');
const context = vm.createContext({});
const start = performance.now();
for (const file of ['vendor/js-bidi.js', 'vendor/js-parsi-reshaper.js', 'ParsiNegar.js']) {
    vm.runInContext(fs.readFileSync(path.join(__dirname, '..', file), 'utf8'), context, { filename: file });
}
console.log('Core cold load (ms):', (performance.now() - start).toFixed(2));
vm.runInContext(fs.readFileSync(path.join(__dirname, 'fixtures.js'), 'utf8'), context);
const corpus = context.ParsiNegarFixtures['editor-corpus'].text;
const points = Array.from(corpus);
function inputOfSize(size) {
    return Array.from({ length: size }, (_, i) => points[i % points.length]).join('');
}
console.log('Input | mode | reverse | median ms | max ms (5 runs)');
for (const [label, input] of [['corpus', corpus], ['10,000', inputOfSize(10000)], ['100,000', inputOfSize(100000)]]) {
    for (const mode of ['unicode', 'compatibility']) {
        for (const reverseWords of [false, true]) {
            const times = [];
            let expected;
            for (let i = 0; i < 5; i++) {
                const began = performance.now();
                const output = context.ParsiNegar.convert(input, mode, { reverseWords }, context.JsBidi, context.JsParsiReshaper);
                times.push(performance.now() - began);
                assert.ok(output.length > 0);
                if (i === 0) expected = output;
                else assert.equal(output, expected, 'repeated conversion must be deterministic');
            }
            times.sort((a, b) => a - b);
            console.log([label, mode, reverseWords, times[2].toFixed(2), times[4].toFixed(2)].join(' | '));
        }
    }
}
