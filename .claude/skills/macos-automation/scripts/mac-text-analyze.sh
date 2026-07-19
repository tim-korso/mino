#!/bin/bash
# mac-text-analyze.sh — 本地 NLP (NaturalLanguage 框架, 零配置)
# NER实体识别 + 语言检测 + 词性标注 + 分词
# 用法: echo "文本" | bash mac-text-analyze.sh
#       bash mac-text-analyze.sh "文本内容"

TEXT="${1:-$(cat)}"
[ -z "$TEXT" ] && { echo "用法: bash mac-text-analyze.sh '文本'" ; exit 1; }

BIN="/tmp/_nlpanalyze"

if [ ! -f "$BIN" ]; then
  cat > /tmp/_nlpanalyze.swift << 'SWIFT'
import NaturalLanguage

let text = CommandLine.arguments.dropFirst().joined(separator: " ")
guard !text.isEmpty else { exit(1) }

// 语言检测
let lang = NLLanguageRecognizer.dominantLanguage(for: text) ?? NLLanguage.undetermined
print("语言: \(lang.rawValue)")

// 命名实体识别
print("")
print("─── 命名实体 ───")
let tagger = NLTagger(tagSchemes: [.nameType])
tagger.string = text
tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
    if let tag = tag, tag != .other {
        print("  \(text[range]) → \(tag.rawValue)")
    }
    return true
}

// 分词
print("")
print("─── 分词 ───")
let tokenizer = NLTokenizer(unit: .word)
tokenizer.string = text
let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex)
let words = tokens.map { String(text[$0]) }
print("  \(words.joined(separator: " | "))")

// 情感 (整体)
let sentiment = NLTagScheme("SentimentScore")
let sTagger = NLTagger(tagSchemes: [sentiment])
sTagger.string = text
let (sTag, _) = sTagger.tag(at: text.startIndex, unit: .document, scheme: sentiment)
print("")
print("情感: \(sTag?.rawValue ?? "neutral")")
SWIFT
  swiftc /tmp/_nlpanalyze.swift -o "$BIN" 2>/dev/null || { echo "编译失败"; exit 1; }
fi

echo "$TEXT" | xargs "$BIN" 2>/dev/null
