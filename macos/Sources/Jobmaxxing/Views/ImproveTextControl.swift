import AppKit
import SwiftUI

/// Small chat icon that opens a feedback popover (type or dictate) and rewrites the linked text.
struct ImproveTextControl: View {
  @EnvironmentObject private var store: JobmaxxingStore

  let currentText: String
  var context: String = ""
  var kind: String = "text"
  let onApply: (String) -> Void

  @StateObject private var dictation = DictationController()
  @State private var isOpen = false
  @State private var feedback = ""
  @State private var status = ""
  @State private var isRewriting = false
  @State private var editorHeight: CGFloat = 72

  var body: some View {
    Image(systemName: "bubble.left.and.bubble.right")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(width: 22, height: 22)
      .contentShape(Rectangle())
      .onTapGesture {
        isOpen.toggle()
      }
    .help("Improve with feedback")
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("Improve with feedback")
    .popover(isPresented: $isOpen, arrowEdge: .bottom) {
      popoverBody
        .frame(width: 300)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
  }

  private var popoverBody: some View {
    VStack(alignment: .leading, spacing: 6) {
      ImproveFeedbackEditor(
        text: $feedback,
        height: $editorHeight,
        placeholder: "What should change?",
        onSend: { applyRewrite() }
      )
      .frame(height: editorHeight)

      HStack(spacing: 4) {
        Spacer(minLength: 0)

        if isRewriting || dictation.isTranscribing {
          ProgressView()
            .controlSize(.small)
            .frame(width: 28, height: 28)
        }

        Button {
          toggleDictation()
        } label: {
          Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(dictation.isRecording ? Color.red : Color.secondary)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(dictation.isTranscribing || isRewriting)
        .help(dictation.isRecording ? "Stop and transcribe" : "Dictate feedback")
        .accessibilityLabel(dictation.isRecording ? "Stop recording" : "Record feedback")

        Button {
          applyRewrite()
        } label: {
          Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(canSend ? Color.accentColor : Color.secondary.opacity(0.45))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!canSend)
        .help("Rewrite (⌘⏎)")
        .accessibilityLabel("Rewrite with feedback")
      }

      if !status.trimmed.isEmpty {
        Text(status)
          .font(.caption2)
          .foregroundStyle(statusIsError ? .red : .secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var canSend: Bool {
    !feedback.trimmed.isEmpty
      && !isRewriting
      && !dictation.isRecording
      && !dictation.isTranscribing
  }

  private var statusIsError: Bool {
    if case .error = dictation.phase { return true }
    let lower = status.lowercased()
    return lower.hasPrefix("error") || lower.contains("could not") || lower.contains("failed")
  }

  private func toggleDictation() {
    Task {
      if dictation.isRecording {
        let result = await dictation.stopAndTranscribe()
        if result.hasPrefix("ERROR:") {
          status = String(result.dropFirst("ERROR:".count)).trimmed
          return
        }
        let text = result.trimmed
        if !text.isEmpty {
          feedback = [feedback.trimmed, text].filter { !$0.isEmpty }.joined(separator: " ")
        }
        status = text.isEmpty ? "No speech detected." : ""
      } else {
        status = ""
        if let error = await dictation.start() {
          status = error
        }
      }
    }
  }

  private func applyRewrite() {
    let userFeedback = feedback.trimmed
    guard !userFeedback.isEmpty else { return }
    isRewriting = true
    status = ""
    Task {
      let result = await store.rewriteTextWithFeedback(
        currentText: currentText,
        feedback: userFeedback,
        context: context,
        kind: kind
      )
      await MainActor.run {
        isRewriting = false
        if result.hasPrefix("ERROR:") {
          status = String(result.dropFirst("ERROR:".count)).trimmed
          return
        }
        let next = result.trimmed
        guard !next.isEmpty else {
          status = "Rewrite returned empty text."
          return
        }
        onApply(next)
        feedback = ""
        status = ""
        isOpen = false
      }
    }
  }
}

/// Header row with optional title and improve control top-right.
struct ImproveSectionHeader: View {
  let title: String
  let currentText: String
  var context: String = ""
  var kind: String = "text"
  let onApply: (String) -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      Spacer(minLength: 8)
      ImproveTextControl(
        currentText: currentText,
        context: context,
        kind: kind,
        onApply: onApply
      )
    }
  }
}

// MARK: - Feedback editor (Enter = newline, ⌘Enter = send)

private enum ImproveEditorMetrics {
  static let minHeight: CGFloat = 72
  static let maxHeight: CGFloat = 140
}

private struct ImproveFeedbackEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var height: CGFloat
  let placeholder: String
  let onSend: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, height: $height, onSend: onSend)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true

    let textView = ImproveFeedbackNSTextView()
    textView.delegate = context.coordinator
    textView.onSend = onSend
    textView.placeholderString = placeholder
    textView.isRichText = false
    textView.isEditable = true
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.allowsUndo = true
    textView.font = .systemFont(ofSize: NSFont.systemFontSize)
    textView.textColor = .labelColor
    textView.insertionPointColor = .labelColor
    textView.textContainerInset = NSSize(width: 0, height: 4)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width]
    textView.minSize = NSSize(width: 0, height: ImproveEditorMetrics.minHeight)
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.string = text

    scrollView.documentView = textView
    DispatchQueue.main.async {
      context.coordinator.focus(textView)
      context.coordinator.updateHeight(for: textView)
    }
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? ImproveFeedbackNSTextView else { return }
    textView.onSend = onSend
    textView.placeholderString = placeholder
    context.coordinator.onSend = onSend
    if textView.string != text {
      let selected = textView.selectedRange()
      textView.string = text
      let end = min(selected.location, (text as NSString).length)
      textView.setSelectedRange(NSRange(location: end, length: 0))
    }
    let width = scrollView.contentView.bounds.width
    if width > 0 {
      textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    }
    context.coordinator.updateHeight(for: textView)
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding var text: String
    @Binding var height: CGFloat
    var onSend: () -> Void

    init(text: Binding<String>, height: Binding<CGFloat>, onSend: @escaping () -> Void) {
      _text = text
      _height = height
      self.onSend = onSend
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      text = textView.string
      updateHeight(for: textView)
      textView.needsDisplay = true
    }

    func textDidBeginEditing(_ notification: Notification) {
      (notification.object as? NSView)?.needsDisplay = true
    }

    func textDidEndEditing(_ notification: Notification) {
      (notification.object as? NSView)?.needsDisplay = true
    }

    func focus(_ textView: NSTextView) {
      textView.window?.makeFirstResponder(textView)
    }

    func updateHeight(for textView: NSTextView) {
      guard let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer else { return }
      layoutManager.ensureLayout(for: textContainer)
      let usedRect = layoutManager.usedRect(for: textContainer)
      let rawHeight = ceil(usedRect.height + (textView.textContainerInset.height * 2) + 2)
      let nextHeight = min(max(rawHeight, ImproveEditorMetrics.minHeight), ImproveEditorMetrics.maxHeight)
      textView.enclosingScrollView?.hasVerticalScroller = rawHeight > ImproveEditorMetrics.maxHeight
      guard abs(height - nextHeight) > 0.5 else { return }
      DispatchQueue.main.async {
        self.height = nextHeight
      }
    }
  }
}

private final class ImproveFeedbackNSTextView: NSTextView {
  var onSend: (() -> Void)?
  var placeholderString: String = ""

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    // Placeholder only when empty and not first responder — avoids caret sitting inside "W".
    guard string.isEmpty, window?.firstResponder != self, !placeholderString.isEmpty else { return }
    let inset = textContainerInset
    let padding = textContainer?.lineFragmentPadding ?? 0
    let rect = bounds.insetBy(dx: inset.width + padding, dy: inset.height)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
      .foregroundColor: NSColor.tertiaryLabelColor
    ]
    (placeholderString as NSString).draw(in: rect, withAttributes: attrs)
  }

  override func becomeFirstResponder() -> Bool {
    let ok = super.becomeFirstResponder()
    needsDisplay = true
    return ok
  }

  override func resignFirstResponder() -> Bool {
    let ok = super.resignFirstResponder()
    needsDisplay = true
    return ok
  }

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
