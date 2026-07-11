import AppKit
import SwiftUI

struct SetupSettingsPage: View {
  let openConnections: () -> Void
  let openModels: () -> Void
  let openRuntime: () -> Void
  let openProfile: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SetupStepRow(
        number: "1",
        title: "Connect AI providers"
      ) {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Text("Open")
          SetupActionButton(title: "Connections", systemImage: "link", action: openConnections)
          Text("and complete setup for every provider you plan to use. Use the provider's sign-in or named API-key variable, then select Check setup to confirm that it is available.")
        }
      }

      SetupStepRow(
        number: "2",
        title: "Choose models"
      ) {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Text("Open")
          SetupActionButton(title: "Models", systemImage: "cpu", action: openModels)
          Text("and choose a provider and model for Light, Medium, and High. Each route uses one of the providers you connected in the first step.")
        }
      }

      SetupStepRow(
        number: "3",
        title: "Install Hermes"
      ) {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Text("Open")
          SetupActionButton(title: "Runtime", systemImage: "point.3.connected.trianglepath.dotted", action: openRuntime)
          Text("and install the Hermes layer if it is missing. Then run Check setup. This enables Hermes-backed features in the app.")
        }
      }

      SetupStepRow(
        number: "4",
        title: "Create your profile"
      ) {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Text("Open")
          SetupActionButton(title: "Profile", systemImage: "person.text.rectangle", action: openProfile)
          Text("and write one brief about your experience, target roles, constraints, and proof. Jobmaxxing uses it to keep writing and research specific to you.")
        }
      }
    }
    .frame(maxWidth: 880, alignment: .topLeading)
  }
}

private struct SetupStepRow<Content: View>: View {
  let number: String
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 16) {
        Text(number)
          .font(.system(.body, design: .monospaced).weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 22, alignment: .leading)
          .padding(.top, 1)

        VStack(alignment: .leading, spacing: 8) {
          Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
          content
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.vertical, 18)

      Divider()
    }
  }
}

private struct SetupActionButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 5))
    }
    .buttonStyle(LiquidPressButtonStyle())
    .background(AppTheme.hoverFill)
    .clipShape(RoundedRectangle(cornerRadius: 5))
    .overlay(
      RoundedRectangle(cornerRadius: 5)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    )
  }
}

struct CodeHelpSettingsPage: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @StateObject private var chat = CodeHelpChatStore()
  @State private var draft = ""
  @State private var composerHeight = ComposerMetrics.minHeight
  @State private var replyID: String?
  @State private var copyStatus = ""

  private var route: ModelRoute? {
    store.state.modelRoutes.first(where: { $0.id == "standard-writing" })
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      transcript
      composer
    }
    .background(Color.clear)
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Code Help")
          .font(.headline.weight(.semibold))
        Text(headerDetail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 12)
      if chat.isRunning {
        ProgressView()
          .scaleEffect(0.55)
          .frame(width: 14, height: 14)
      }
      Text(chat.isRunning ? "Working" : routeAvailability.message)
        .font(.caption.weight(.semibold))
        .foregroundStyle(chat.isRunning || routeAvailability.isReady ? Color.accentColor : Color.secondary)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 10)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color(nsColor: .separatorColor).opacity(0.7))
        .frame(height: 1)
    }
    .background(.bar)
  }

  private var headerDetail: String {
    let status = copyStatus.trimmed
    if !status.isEmpty {
      return status
    }
    return "Uses the Medium route. Reply adds one message as context."
  }

  private var routeAvailability: CodeHelpRouteAvailability {
    guard let route else { return .notConfigured }
    return CodeHelpAgentRunner.availability(for: route)
  }

  private var transcript: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          if chat.messages.isEmpty {
            CodeHelpEmptyState()
          } else {
            ForEach(chat.messages) { message in
              ChatMessageRow(
                message: message,
                usesHermesPresentation: false,
                onReply: { replyID = message.id },
                onCopy: { copy(message) }
              )
              .id(message.id)
            }
          }
          Color.clear
            .frame(height: 12)
            .id(Self.transcriptBottomID)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      .onAppear {
        scrollToBottom(with: proxy)
      }
      .onChange(of: chat.messages.last?.id) { _, _ in
        scrollToBottom(with: proxy)
      }
      .onChange(of: (chat.messages.last?.text.count ?? 0) / 160) { _, _ in
        scrollToBottom(with: proxy)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let reply = chat.replyTarget(id: replyID) {
        CodeHelpReplyPreview(text: reply.preview) {
          replyID = nil
        }
      }

      HStack(alignment: .bottom, spacing: 6) {
        ZStack(alignment: .leading) {
          if draft.isEmpty {
            Text("Ask one code question")
              .font(.body)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          TaggedComposerTextView(text: $draft, height: $composerHeight) { _ in
          } onSend: {
            send()
          }
          .frame(height: composerHeight)
        }
        .padding(.horizontal, 10)
        .frame(height: composerHeight)
        .liquidGlassSurface(.strong, cornerRadius: AppTheme.radiusMedium, isInteractive: true)

        CodeHelpSendButton(isEnabled: canSend) {
          send()
        }
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .padding(.bottom, 14)
    .background(.bar)
  }

  private var canSend: Bool {
    !draft.trimmed.isEmpty && !chat.isRunning && routeAvailability.isReady
  }

  private func send() {
    guard canSend, let route else { return }
    chat.send(question: draft, replyID: replyID, route: route)
    draft = ""
    replyID = nil
    copyStatus = ""
    composerHeight = ComposerMetrics.minHeight
  }

  private func copy(_ message: HermesChatMessage) {
    guard !message.text.trimmed.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(message.text.trimmed, forType: .string)
    copyStatus = "Copied."
  }

  private func scrollToBottom(with proxy: ScrollViewProxy) {
    DispatchQueue.main.async {
      proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
    }
  }

  private static let transcriptBottomID = "code-help-transcript-bottom"
}

private struct CodeHelpEmptyState: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Ask about this codebase.")
        .font(.body.weight(.semibold))
      Text("It searches local files before it answers.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 28)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct CodeHelpReplyPreview: View {
  let text: String
  let onClear: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "arrowshape.turn.up.left")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 2)
      Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 8)
      Button(action: onClear) {
        Image(systemName: "xmark")
          .font(.caption2.weight(.bold))
          .frame(width: 44, height: 44)
      }
      .buttonStyle(LiquidPressButtonStyle())
      .accessibilityLabel("Clear reply")
      .help("Clear reply")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(Color.primary.opacity(0.045))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}

private struct CodeHelpSendButton: View {
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "paperplane.fill")
        .font(.system(size: 14, weight: .semibold))
        .frame(width: 44, height: 44)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
    }
    .buttonStyle(LiquidPressButtonStyle())
    .accessibilityLabel("Send question")
    .help("Send question")
    .foregroundStyle(isEnabled ? Color.white : Color.secondary)
    .background(isEnabled ? Color.accentColor : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
    .overlay(
      RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
        .stroke(isEnabled ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
    )
    .disabled(!isEnabled)
  }
}
