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

  return Object.freeze({
    paragraphAlignment: paragraphAlignment,
    paragraphLayout: paragraphLayout
  });
}());
