import Foundation
import SwiftUI

struct MarkdownMessageView: View {
  let text: String
  var alignment: HorizontalAlignment = .leading

  private var nsTextAlignment: NSTextAlignment {
    alignment == .trailing ? .right : .left
  }

  var body: some View {
    VStack(alignment: alignment, spacing: 7) {
      ForEach(HermesMarkdownParser.blocks(in: text)) { block in
        blockView(block)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private func blockView(_ block: MarkdownMessageBlock) -> some View {
    switch block.kind {
    case .paragraph(let value):
      inlineText(value, font: .systemFont(ofSize: NSFont.systemFontSize))
    case .heading(let level, let value):
      inlineText(value, font: .systemFont(ofSize: headingSize(level), weight: .semibold))
        .padding(.top, level == 1 ? 2 : 0)
    case .bullet(let value):
      HStack(alignment: .top, spacing: 7) {
        Text("-")
          .font(.body.weight(.semibold))
        inlineText(value, font: .systemFont(ofSize: NSFont.systemFontSize))
      }
    case .numbered(let marker, let value):
      HStack(alignment: .top, spacing: 7) {
        Text(marker)
          .font(.body.monospacedDigit())
        inlineText(value, font: .systemFont(ofSize: NSFont.systemFontSize))
      }
    case .quote(let value):
      HStack(alignment: .top, spacing: 8) {
        Rectangle()
          .fill(Color.secondary.opacity(0.35))
          .frame(width: 2)
        inlineText(value, font: .systemFont(ofSize: NSFont.systemFontSize), color: .secondaryLabelColor)
      }
    case .code(let value):
      SelectableMarkdownText(
        text: value,
        font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
        alignment: nsTextAlignment,
        parseMarkdown: false
      )
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    case .table(let headers, let rows):
      table(headers: headers, rows: rows)
    }
  }

  private func inlineText(_ source: String, font: NSFont, color: NSColor = .labelColor) -> some View {
    SelectableMarkdownText(text: source, font: font, color: color, alignment: nsTextAlignment, parseMarkdown: true)
  }

  private func headingSize(_ level: Int) -> CGFloat {
    switch level {
    case 1: return 20
    case 2: return 17
    default: return 15
    }
  }

  private func table(headers: [String], rows: [[String]]) -> some View {
    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
      GridRow {
        ForEach(headers.indices, id: \.self) { index in
          tableCell(headers[index], isHeader: true)
        }
      }
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        GridRow {
          ForEach(headers.indices, id: \.self) { index in
            tableCell(index < row.count ? row[index] : "", isHeader: false)
          }
        }
      }
    }
    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator, lineWidth: 1))
  }

  private func tableCell(_ value: String, isHeader: Bool) -> some View {
    inlineText(
      value,
      font: isHeader ? .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold) : .systemFont(ofSize: NSFont.smallSystemFontSize)
    )
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isHeader ? Color.primary.opacity(0.06) : Color.clear)
      .overlay(Rectangle().stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5))
  }
}

private struct SelectableMarkdownText: View {
  let text: String
  let font: NSFont
  var color: NSColor = .labelColor
  var alignment: NSTextAlignment = .left
  var parseMarkdown = true
  @State private var height: CGFloat = 1

  var body: some View {
    SelectableTextView(
      attributedText: attributedText,
      alignment: alignment,
      height: $height
    )
    .frame(minHeight: height, idealHeight: height, maxHeight: height)
  }

  private var attributedText: NSAttributedString {
    let attributed: NSMutableAttributedString
    if parseMarkdown,
       let parsed = try? AttributedString(
        markdown: text,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
       ) {
      attributed = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
    } else {
      attributed = NSMutableAttributedString(string: text)
    }
    let range = NSRange(location: 0, length: attributed.length)
    attributed.addAttribute(.foregroundColor, value: color, range: range)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = alignment
    attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
    attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
      if value == nil {
        attributed.addAttribute(.font, value: font, range: subrange)
      }
    }
    if attributed.length == 0 {
      attributed.append(NSAttributedString(string: " ", attributes: [.font: font, .foregroundColor: color]))
    }
    return attributed
  }
}

private struct SelectableTextView: NSViewRepresentable {
  let attributedText: NSAttributedString
  let alignment: NSTextAlignment
  @Binding var height: CGFloat

  func makeNSView(context: Context) -> NSTextView {
    let textView = NSTextView()
    textView.delegate = context.coordinator
    textView.isEditable = false
    textView.isSelectable = true
    textView.isRichText = true
    textView.drawsBackground = false
    textView.alignment = alignment
    textView.textContainerInset = .zero
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.textContainer?.lineBreakMode = .byWordWrapping
    textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width]
    textView.allowsUndo = false
    return textView
  }

  func updateNSView(_ textView: NSTextView, context: Context) {
    if textView.attributedString() != attributedText {
      let selectedRange = textView.selectedRange()
      textView.textStorage?.setAttributedString(attributedText)
      textView.setSelectedRange(clampedRange(selectedRange, length: attributedText.length))
    }
    textView.alignment = alignment
    textView.textContainer?.containerSize = NSSize(width: max(textView.bounds.width, 1), height: CGFloat.greatestFiniteMagnitude)
    context.coordinator.updateHeight(for: textView)
    DispatchQueue.main.async {
      context.coordinator.updateHeight(for: textView)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(height: $height)
  }

  private func clampedRange(_ range: NSRange, length: Int) -> NSRange {
    let location = min(max(range.location, 0), length)
    return NSRange(location: location, length: min(range.length, max(0, length - location)))
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding var height: CGFloat

    init(height: Binding<CGFloat>) {
      _height = height
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      updateHeight(for: textView)
    }

    func updateHeight(for textView: NSTextView) {
      guard let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer else { return }
      layoutManager.ensureLayout(for: textContainer)
      let usedRect = layoutManager.usedRect(for: textContainer)
      let nextHeight = max(1, ceil(usedRect.height + textView.textContainerInset.height * 2))
      guard abs(height - nextHeight) > 0.5 else { return }
      DispatchQueue.main.async {
        self.height = nextHeight
      }
    }
  }
}

struct MarkdownMessageBlock: Identifiable, Equatable {
  let id: Int
  let kind: MarkdownMessageBlockKind
}

enum MarkdownMessageBlockKind: Equatable {
  case paragraph(String)
  case heading(level: Int, String)
  case bullet(String)
  case numbered(marker: String, String)
  case quote(String)
  case code(String)
  case table(headers: [String], rows: [[String]])
}

enum HermesMarkdownParser {
  static func blocks(in source: String) -> [MarkdownMessageBlock] {
    let lines = source
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
    var blocks: [MarkdownMessageBlock] = []
    var index = 0

    func append(_ kind: MarkdownMessageBlockKind) {
      blocks.append(MarkdownMessageBlock(id: blocks.count, kind: kind))
    }

    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmed
      if trimmed.isEmpty {
        index += 1
        continue
      }

      if trimmed.hasPrefix("```") {
        var codeLines: [String] = []
        index += 1
        while index < lines.count, !lines[index].trimmed.hasPrefix("```") {
          codeLines.append(lines[index])
          index += 1
        }
        if index < lines.count {
          index += 1
        }
        append(.code(codeLines.joined(separator: "\n")))
        continue
      }

      if index + 1 < lines.count,
         let headers = tableCells(lines[index]),
         let separators = tableCells(lines[index + 1]),
         isSeparatorRow(separators) {
        index += 2
        var rows: [[String]] = []
        while index < lines.count, let row = tableCells(lines[index]) {
          rows.append(row)
          index += 1
        }
        append(.table(headers: headers, rows: rows))
        continue
      }

      if let heading = heading(from: trimmed) {
        append(.heading(level: heading.level, heading.text))
        index += 1
        continue
      }

      if let bullet = bullet(from: trimmed) {
        append(.bullet(bullet))
        index += 1
        continue
      }

      if let numbered = numbered(from: trimmed) {
        append(.numbered(marker: numbered.marker, numbered.text))
        index += 1
        continue
      }

      if trimmed.hasPrefix(">") {
        append(.quote(String(trimmed.dropFirst()).trimmed))
        index += 1
        continue
      }

      var paragraph = [trimmed]
      index += 1
      while index < lines.count {
        let next = lines[index].trimmed
        if next.isEmpty || startsBlock(next, in: lines, at: index) {
          break
        }
        paragraph.append(next)
        index += 1
      }
      append(.paragraph(paragraph.joined(separator: "\n")))
    }

    return blocks.isEmpty ? [MarkdownMessageBlock(id: 0, kind: .paragraph(source))] : blocks
  }

  private static func startsBlock(_ line: String, in lines: [String], at index: Int) -> Bool {
    line.hasPrefix("```")
      || heading(from: line) != nil
      || bullet(from: line) != nil
      || numbered(from: line) != nil
      || line.hasPrefix(">")
      || (index + 1 < lines.count && tableCells(line) != nil && tableCells(lines[index + 1]).map { isSeparatorRow($0) } == true)
  }

  private static func heading(from line: String) -> (level: Int, text: String)? {
    let level = line.prefix { $0 == "#" }.count
    guard (1...6).contains(level) else { return nil }
    let rest = String(line.dropFirst(level))
    guard rest.hasPrefix(" ") else { return nil }
    return (level, rest.trimmed)
  }

  private static func bullet(from line: String) -> String? {
    if line.hasPrefix("- ") || line.hasPrefix("* ") {
      return String(line.dropFirst(2)).trimmed
    }
    return nil
  }

  private static func numbered(from line: String) -> (marker: String, text: String)? {
    let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
    guard parts.count == 2, let marker = parts.first, let last = marker.last else { return nil }
    guard last == "." || last == ")" else { return nil }
    let digits = marker.dropLast()
    guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
    return (marker, parts[1].trimmed)
  }

  private static func tableCells(_ line: String) -> [String]? {
    let trimmed = line.trimmed
    guard trimmed.contains("|") else { return nil }
    let cells = trimmed
      .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
      .components(separatedBy: "|")
      .map { $0.trimmed }
    return cells.count > 1 ? cells : nil
  }

  private static func isSeparatorRow(_ cells: [String]) -> Bool {
    cells.allSatisfy { cell in
      let stripped = cell
        .replacingOccurrences(of: ":", with: "")
        .trimmed
      return stripped.count >= 3 && stripped.allSatisfy { $0 == "-" }
    }
  }
}
