// Plugin-local QML bridge. Import only from the lazily loaded menu content.
// No .pragma library: conversion state belongs to the importing component.
.import "vendor/js-bidi.js" as BidiLibrary
.import "vendor/js-parsi-reshaper.js" as ReshaperLibrary
.import "ParsiNegar.js" as ConversionCore

function convert(text, mode, options) {
    return ConversionCore.ParsiNegar.convert(
        text, mode, options, BidiLibrary.JsBidi, ReshaperLibrary.JsParsiReshaper
    );
}
