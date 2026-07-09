import SwiftUI

struct InterviewsView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var mode: InterviewMode = .text
  @State private var selectedSessionID: String?
  @State private var notes = ""

  private var visibleSessions: [InterviewSession] {
    guard let jobID = store.selectedJob?.id else { return [] }
    return store.state.interviewSessions.filter { $0.jobID == jobID }
  }

  private var selectedSession: InterviewSession? {
    if let selectedSessionID,
       let session = visibleSessions.first(where: { $0.id == selectedSessionID }) {
      return session
    }
    return visibleSessions.first
  }

  var body: some View {
    HSplitView {
      VStack(alignment: .leading, spacing: 14) {
        if let job = store.selectedJob {
          PlainHeader(title: job.role, detail: job.company)

          Picker("Mode", selection: $mode) {
            ForEach(InterviewMode.allCases) { mode in
              Text(mode.label).tag(mode)
            }
          }
          .pickerStyle(.segmented)

          Button {
            store.createInterview(jobID: job.id, mode: mode)
            selectedSessionID = visibleSessions.first?.id
          } label: {
            Label("Create practice", systemImage: "plus")
          }
          .buttonStyle(.borderedProminent)
        } else {
          InlineEmptyState(title: "No role selected", detail: "Select an application before creating practice.")
        }

        Divider()

        VStack(alignment: .leading, spacing: 8) {
          Text("Practice")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)

          if visibleSessions.isEmpty {
            InlineEmptyState(title: "No practice for this role", detail: "Create practice from the selected mode.")
          } else {
            PracticeSessionList(sessions: visibleSessions, selectedSessionID: $selectedSessionID)
          }
        }
      }
      .padding(18)
      .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
      .frame(maxHeight: .infinity, alignment: .top)

      ScrollView {
        if let session = selectedSession {
          VStack(alignment: .leading, spacing: 22) {
            SessionSummary(title: sessionTitle(session), mode: session.mode.label)

            Divider()

            FlatSection(title: "Questions") {
              InterviewQuestionList(questions: session.questions)
            }

            Divider()

            FlatSection(title: "Scorecard") {
              CompactList(items: session.scorecard)
            }

            Divider()

            InterviewNotesSection(
              notes: $notes,
              improveContext: [
                "Session: \(sessionTitle(session))",
                "Mode: \(session.mode.label)",
                "Questions: \(session.questions.prefix(6).joined(separator: " | ").bounded(to: 700))",
                "Scorecard: \(session.scorecard.prefix(6).joined(separator: " | ").bounded(to: 500))"
              ].joined(separator: "\n"),
              save: {
                store.updateInterviewNotes(sessionID: session.id, notes: notes)
              }
            )
            .onAppear { notes = session.notes }
            .onChange(of: session.id) { _, _ in notes = session.notes }
          }
          .padding(22)
        } else {
          InlineEmptyState(title: "No practice selected", detail: "Create practice for the selected role.")
            .padding(22)
        }
      }
      .frame(minWidth: 620)
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .onChange(of: store.selectedJobID) { _, _ in
      selectedSessionID = nil
      notes = selectedSession?.notes ?? ""
    }
  }

  private func sessionTitle(_ session: InterviewSession) -> String {
    guard let job = store.state.jobs.first(where: { $0.id == session.jobID }) else {
      return "Interview practice"
    }
    return "\(job.company) - \(job.role)"
  }
}

private struct PracticeSessionList: View {
  let sessions: [InterviewSession]
  @Binding var selectedSessionID: String?

  private var currentSelectionID: String? {
    selectedSessionID ?? sessions.first?.id
  }

  private var listHeight: CGFloat {
    min(CGFloat(sessions.count) * 52, 220)
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 4) {
        ForEach(sessions) { session in
          Button {
            selectedSessionID = session.id
          } label: {
            InterviewSessionRow(
              title: session.mode.label,
              detail: "\(session.questions.count) questions",
              isSelected: currentSelectionID == session.id
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
    .frame(height: listHeight)
  }
}

private struct PlainHeader: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title3.weight(.semibold))
        .lineLimit(2)
      Text(detail)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
}

private struct InterviewSessionRow: View {
  let title: String
  let detail: String
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .lineLimit(2)
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background {
      if isSelected {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.primary.opacity(0.08))
      }
    }
  }
}

private struct SessionSummary: View {
  let title: String
  let mode: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.title2.weight(.bold))
        .fixedSize(horizontal: false, vertical: true)
      Text(mode)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct InterviewQuestionList: View {
  let questions: [String]

  var body: some View {
    CompactList(items: questions.map(normalizedInterviewQuestion))
  }
}

private struct InterviewNotesSection: View {
  @Binding var notes: String
  var improveContext: String = ""
  let save: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 8) {
        Text("NOTES")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)

        Spacer()

        ImproveTextControl(
          currentText: notes,
          context: improveContext,
          kind: "interview notes",
          onApply: { notes = $0 }
        )

        Button("Save notes", action: save)
          .controlSize(.small)
      }

      TextEditor(text: $notes)
        .frame(height: 110)
        .scrollContentBackground(.hidden)
        .padding(8)
        .background(.background)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
    }
  }
}

private func normalizedInterviewQuestion(_ question: String) -> String {
  let prefix = "What question would you ask the hiring manager about "
  guard question.localizedCaseInsensitiveContains(prefix),
        let range = question.range(of: prefix, options: [.caseInsensitive]) else {
    return question
  }

  let candidate = String(question[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
  guard startsLikeQuestion(candidate) else {
    return question
  }
  return candidate
}

private func startsLikeQuestion(_ text: String) -> Bool {
  let normalizedText = text.lowercased()
  let questionOpeners = ["which", "what", "how", "why", "who", "when", "where"]
  return questionOpeners.contains { opener in
    normalizedText == opener || normalizedText.hasPrefix("\(opener) ")
  }
}

private struct FlatSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      content
    }
  }
}

private struct InlineEmptyState: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
  }
}
