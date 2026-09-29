// Copyright (c) 2026 LeoMoon Studios
// Search ordering matches the desktop font selector.
var FontSearch = (function () {
    "use strict";

    function fuzzyScore(value, query) {
        var candidate = String(value).toLocaleLowerCase();
        var needle = String(query).trim().toLocaleLowerCase();
        if (needle === "") return 0;
        if (candidate === needle) return -1000;
        if (candidate.indexOf(needle) === 0)
            return -500 + candidate.length - needle.length;
        var substring = candidate.indexOf(needle);
        if (substring >= 0)
            return -250 + substring * 2 + candidate.length - needle.length;
        var position = -1;
        var score = 0;
        for (var index = 0; index < needle.length; index++) {
            var next = candidate.indexOf(needle[index], position + 1);
            if (next < 0) return null;
            score += next - position - 1;
            position = next;
        }
        return score + candidate.length;
    }

    function filter(fonts, query) {
        var matches = [];
        for (var index = 0; index < fonts.length; index++) {
            var score = fuzzyScore(fonts[index].display, query);
            if (score !== null) matches.push({ entry: fonts[index], score: score, order: index });
        }
        matches.sort(function (left, right) {
            return left.score === right.score ? left.order - right.order : left.score - right.score;
        });
        var result = [];
        for (var match = 0; match < matches.length; match++) result.push(matches[match].entry);
        return result;
    }

    return Object.freeze({ fuzzyScore: fuzzyScore, filter: filter });
}());
