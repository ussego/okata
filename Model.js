var CASES = [
  { id: "camel", label: "camelCase" },
  { id: "capital", label: "Capital Case" },
  { id: "constant", label: "CONSTANT_CASE" },
  { id: "dot", label: "dot.case" },
  { id: "header", label: "Header-Case" },
  { id: "lower", label: "lower case" },
  { id: "lowerFirst", label: "lower First" },
  { id: "no", label: "no case" },
  { id: "kebab", label: "kebab-case" },
  { id: "kebabUpper", label: "KEBAB-UPPER-CASE" },
  { id: "pascal", label: "PascalCase" },
  { id: "pascalSnake", label: "Pascal_Snake_Case" },
  { id: "path", label: "path/case" },
  { id: "alternating", label: "AlTeRnAtInG cAsE" },
  { id: "random", label: "rAndOm cAsE" },
  { id: "sentence", label: "Sentence case" },
  { id: "snake", label: "snake_case" },
  { id: "swap", label: "sWAP cASE" },
  { id: "title", label: "Title Case" },
  { id: "upper", label: "UPPER CASE" },
  { id: "upperFirst", label: "Upper first" }
]

var MINOR_WORDS = {
  "a": 1, "an": 1, "and": 1, "as": 1, "at": 1, "but": 1, "by": 1,
  "en": 1, "for": 1, "if": 1, "in": 1, "nor": 1, "of": 1, "on": 1,
  "or": 1, "per": 1, "the": 1, "to": 1, "up": 1, "v": 1, "vs": 1, "via": 1
}

function charType(ch) {
  if (ch >= "A" && ch <= "Z") return "upper"
  if (ch >= "a" && ch <= "z") return "lower"
  if (ch >= "0" && ch <= "9") return "digit"
  var up = ch.toUpperCase()
  var lo = ch.toLowerCase()
  if (up !== lo) return ch === up ? "upper" : "lower"
  return "other"
}

function isLetter(ch) {
  var t = charType(ch)
  return t === "upper" || t === "lower"
}

function splitWords(text) {
  var words = []
  var current = ""
  var prevType = "other"

  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    var type = charType(ch)

    if (type === "other") {
      if (current) words.push(current)
      current = ""
      prevType = "other"
      continue
    }

    if (prevType === "lower" || prevType === "digit") {
      if (type === "upper") {
        if (current) words.push(current)
        current = ""
      }
    } else if (prevType === "upper" && type === "lower" && current.length > 1) {
      words.push(current.slice(0, current.length - 1))
      current = current.charAt(current.length - 1)
    }

    current += ch
    prevType = type
  }

  if (current) words.push(current)
  return words
}

function capitalize(word) {
  return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
}

function joinMapped(words, separator, mapFn) {
  var parts = []
  for (var i = 0; i < words.length; i++) parts.push(mapFn(words[i], i))
  return parts.join(separator)
}

function lower(word) {
  return word.toLowerCase()
}

function upper(word) {
  return word.toUpperCase()
}

function sentenceCase(words) {
  return joinMapped(words, " ", function(word, i) {
    return i === 0 ? capitalize(word) : lower(word)
  })
}

function titleCase(words) {
  return joinMapped(words, " ", function(word, i) {
    if (i !== 0 && i !== words.length - 1 && MINOR_WORDS[lower(word)]) return lower(word)
    return capitalize(word)
  })
}

function alternatingCase(text) {
  var out = ""
  var flip = false
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    if (isLetter(ch)) {
      out += flip ? ch.toUpperCase() : ch.toLowerCase()
      flip = !flip
    } else {
      out += ch
    }
  }
  return out
}

function randomCase(text) {
  var out = ""
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    if (isLetter(ch)) out += Math.random() < 0.5 ? ch.toLowerCase() : ch.toUpperCase()
    else out += ch
  }
  return out
}

function swapCase(text) {
  var out = ""
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    var up = ch.toUpperCase()
    var lo = ch.toLowerCase()
    if (ch === up && ch !== lo) out += lo
    else if (ch === lo && ch !== up) out += up
    else out += ch
  }
  return out
}

function transform(caseId, text) {
  var value = String(text || "")
  if (!value) return ""
  var words = splitWords(value)

  switch (caseId) {
  case "camel":
    return joinMapped(words, "", function(word, i) {
      return i === 0 ? lower(word) : capitalize(word)
    })
  case "capital": return joinMapped(words, " ", capitalize)
  case "constant": return joinMapped(words, "_", upper)
  case "dot": return joinMapped(words, ".", lower)
  case "header": return joinMapped(words, "-", capitalize)
  case "lower": return joinMapped(words, " ", lower)
  case "lowerFirst": return value.charAt(0).toLowerCase() + value.slice(1)
  case "no": return joinMapped(words, " ", lower)
  case "kebab": return joinMapped(words, "-", lower)
  case "kebabUpper": return joinMapped(words, "-", upper)
  case "pascal": return joinMapped(words, "", capitalize)
  case "pascalSnake": return joinMapped(words, "_", capitalize)
  case "path": return joinMapped(words, "/", lower)
  case "alternating": return alternatingCase(value)
  case "random": return randomCase(value)
  case "sentence": return sentenceCase(words)
  case "snake": return joinMapped(words, "_", lower)
  case "swap": return swapCase(value)
  case "title": return titleCase(words)
  case "upper": return joinMapped(words, " ", upper)
  case "upperFirst": return value.charAt(0).toUpperCase() + value.slice(1)
  }
  return value
}

function hasCase(caseId) {
  for (var i = 0; i < CASES.length; i++) {
    if (CASES[i].id === caseId) return true
  }
  return false
}

function orderedCases(pinned) {
  var pinnedSet = {}
  var i
  for (i = 0; i < pinned.length; i++) pinnedSet[pinned[i]] = true

  var out = []
  for (i = 0; i < CASES.length; i++) {
    if (pinnedSet[CASES[i].id]) out.push(CASES[i])
  }
  for (i = 0; i < CASES.length; i++) {
    if (!pinnedSet[CASES[i].id]) out.push(CASES[i])
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    CASES: CASES,
    charType: charType,
    splitWords: splitWords,
    transform: transform,
    hasCase: hasCase,
    orderedCases: orderedCases
  }
}
