var EditorDirection = (function () {
  "use strict";

  function isRtlStrong(code) {
    return (code >= 0x05d0 && code <= 0x05ea) ||
      (code >= 0x0621 && code <= 0x064a) ||
      (code >= 0x066e && code <= 0x06d3) ||
      (code >= 0x06fa && code <= 0x06ff) ||
      (code >= 0x0700 && code <= 0x074f) ||
      (code >= 0x0750 && code <= 0x077f) ||
      (code >= 0x08a0 && code <= 0x08ff) ||
      (code >= 0xfb1d && code <= 0xfdff) ||
      (code >= 0xfe70 && code <= 0xfeff);
  }

  function isLtrStrong(code) {
    return (code >= 0x0041 && code <= 0x005a) ||
      (code >= 0x0061 && code <= 0x007a) ||
      (code >= 0x00c0 && code <= 0x02af);
  }

  function paragraphAlignment(value) {
    var text = String(value || "");
    for (var index = 0; index < text.length; index++) {
      var code = text.charCodeAt(index);
      if (isRtlStrong(code)) return "right";
      if (isLtrStrong(code)) return "left";
    }
    return "";
  }

  function paragraphLayout(value) {
    var paragraphs = String(value || "").split(/\r\n|[\r\n\u2029]/);
    var inheritedAlignment = "right";
    var directions = [];
    var states = [];
    for (var index = 0; index < paragraphs.length; index++) {
      var detectedAlignment = paragraphAlignment(paragraphs[index]);
      if (detectedAlignment !== "") inheritedAlignment = detectedAlignment;
      directions.push(inheritedAlignment);
      states.push((detectedAlignment === "" ? "inherited:" : "strong:") + inheritedAlignment);
    }
    return {
      paragraphs: paragraphs,
      directions: directions,
      signature: states.join("|")
    };
  }

  function normalizeParagraphBreaks(value) {
    return String(value || "").replace(/\r\n|[\r\u2029]/g, "\n");
  }

  function isParagraphBreakInsertion(previousValue, currentValue) {
    var previous = normalizeParagraphBreaks(previousValue);
    var current = normalizeParagraphBreaks(currentValue);
    if (current.length !== previous.length + 1) return false;

    var index = 0;
    while (index < previous.length && previous.charAt(index) === current.charAt(index)) index++;
    return current.charAt(index) === "\n" &&
      current.slice(0, index) + current.slice(index + 1) === previous;
  }

  function logicalPosition(value, documentPosition) {
    var text = String(value || "");
    var end = Math.max(0, Math.min(Number(documentPosition) || 0, text.length));
    var position = 0;
    for (var index = 0; index < end; index++) {
      if (text.charAt(index) !== "\u200b") position++;
    }
    return position;
  }

  function documentPosition(value, logicalPosition) {
    var text = String(value || "");
    var target = Math.max(0, Number(logicalPosition) || 0);
    var logical = 0;
    var index = 0;
    while (index < text.length && logical < target) {
      if (text.charAt(index) !== "\u200b") logical++;
      index++;
    }
    while (index < text.length && text.charAt(index) === "\u200b") index++;
    return index;
  }

  return Object.freeze({
    paragraphAlignment: paragraphAlignment,
    paragraphLayout: paragraphLayout,
    isParagraphBreakInsertion: isParagraphBreakInsertion,
    logicalPosition: logicalPosition,
    documentPosition: documentPosition
  });
}());
