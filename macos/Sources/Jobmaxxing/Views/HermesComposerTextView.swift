import AppKit
import SwiftUI

enum ComposerMetrics {
  static let minHeight: CGFloat = 36
  static let maxHeight: CGFloat = 110
}

struct TaggedComposerTextView: NSViewRepresentable {
  @Binding var text: String
  @Binding var height: CGFloat
  let onTab: (String) -> Void
  let onSend: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, height: $height)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true

    let textView = ComposerNSTextView()
    textView.delegate = context.coordinator
    textView.onTab = onTab
    textView.onSend = onSend
    textView.isRichText = false
    textView.isEditable = true
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.allowsUndo = true
    textView.font = .systemFont(ofSize: NSFont.systemFontSize)
    textView.textColor = .labelColor
    textView.insertionPointColor = .labelColor
    textView.textContainerInset = NSSize(width: 0, height: 8)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width]
    textView.minSize = NSSize(width: 0, height: ComposerMetrics.minHeight)
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? ComposerNSTextView else { return }
    textView.onTab = onTab
    textView.onSend = onSend
    if textView.string != text {
      textView.string = text
      let endRange = NSRange(location: (text as NSString).length, length: 0)
      textView.setSelectedRange(endRange)
      textView.scrollRangeToVisible(endRange)
    }
    textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
    context.coordinator.applyTagAttributes(to: textView)
    context.coordinator.updateHeight(for: textView)
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding var text: String
    @Binding var height: CGFloat
    private var isApplyingAttributes = false

    init(text: Binding<String>, height: Binding<CGFloat>) {
      _text = text
      _height = height
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      text = textView.string
      applyTagAttributes(to: textView)
      updateHeight(for: textView)
      textView.scrollRangeToVisible(textView.selectedRange())
    }

    func applyTagAttributes(to textView: NSTextView) {
      guard !isApplyingAttributes, let storage = textView.textStorage else { return }
      isApplyingAttributes = true
      let selectedRange = textView.selectedRange()
      let fullRange = NSRange(location: 0, length: storage.length)
      if storage.length > 0 {
        storage.setAttributes(Self.baseAttributes, range: fullRange)
      }
      for range in Self.tagRanges(in: textView.string) {
        storage.addAttributes(Self.tagAttributes, range: range)
      }
      textView.setSelectedRange(Self.clampedRange(selectedRange, length: storage.length))
      isApplyingAttributes = false
    }

    func updateHeight(for textView: NSTextView) {
      guard let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer else { return }
      layoutManager.ensureLayout(for: textContainer)
      let usedRect = layoutManager.usedRect(for: textContainer)
      let rawHeight = ceil(usedRect.height + (textView.textContainerInset.height * 2))
      let nextHeight = min(max(rawHeight, ComposerMetrics.minHeight), ComposerMetrics.maxHeight)
      textView.enclosingScrollView?.hasVerticalScroller = rawHeight > ComposerMetrics.maxHeight
      guard abs(height - nextHeight) > 0.5 else { return }
      DispatchQueue.main.async {
        self.height = nextHeight
      }
    }

    private static let baseAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
      .foregroundColor: NSColor.labelColor
    ]

    private static let tagAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
      .foregroundColor: NSColor.controlAccentColor
    ]

    private static func tagRanges(in text: String) -> [NSRange] {
      let nsText = text as NSString
      let fullRange = NSRange(location: 0, length: nsText.length)
      var ranges: [NSRange] = []
      if let rawTagRegex {
        ranges.append(contentsOf: rawTagRegex.matches(in: text, range: fullRange).map(\.range))
      }
      for regex in visibleTitleRegexes {
        ranges.append(contentsOf: regex.matches(in: text, range: fullRange).map(\.range))
      }
      return ranges
    }

    private static func clampedRange(_ range: NSRange, length: Int) -> NSRange {
      let location = min(max(range.location, 0), length)
      let maxLength = max(0, length - location)
      return NSRange(location: location, length: min(range.length, maxLength))
    }

    private static let rawTagRegex = try? NSRegularExpression(pattern: #"[/@$][A-Za-z][A-Za-z0-9_-]*"#)
    private static let visibleTitleRegexes: [NSRegularExpression] = InlineTagRenderer.visibleTitles.compactMap { title in
      let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: title))\b"#
      return try? NSRegularExpression(pattern: pattern)
    }
  }
}

private final class ComposerNSTextView: NSTextView {
  var onTab: ((String) -> Void)?
  var onSend: (() -> Void)?

  override func keyDown(with event: NSEvent) {
    let characters = event.charactersIgnoringModifiers
    if event.modifierFlags.contains(.command),
       characters == "\r" || characters == "\n" {
      onSend?()
      return
    }
    super.keyDown(with: event)
  }

  override func doCommand(by selector: Selector) {
    if selector == #selector(insertTab(_:)) {
      onTab?(string)
      return
    }
    if selector == #selector(insertNewline(_:)) {
      let modifiers = NSApp.currentEvent?.modifierFlags ?? []
      if modifiers.contains(.command) {
        onSend?()
      } else {
        super.doCommand(by: selector)
      }
      return
    }
    super.doCommand(by: selector)
  }
}
