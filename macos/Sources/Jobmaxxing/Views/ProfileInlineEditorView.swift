import SwiftUI

struct ProfileInlineEditButton: View {
  let profile: CandidateProfile
  let scope: ProfileEditorScope
  let onSave: (CandidateProfile) -> Bool

  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented = true
    } label: {
      Image(systemName: "pencil")
        .font(.system(size: 12, weight: .semibold))
        .frame(width: 26, height: 26)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.secondary)
    .accessibilityLabel("Edit \(editTargetName)")
    .help("Edit \(editTargetName)")
    .popover(isPresented: $isPresented, arrowEdge: .trailing) {
      ProfileEditorView(
        profile: profile,
        scope: scope,
        onCancel: { isPresented = false },
        onSave: { updatedProfile in
          guard onSave(updatedProfile) else { return false }
          isPresented = false
          return true
        }
      )
      .frame(width: 440, height: 520)
    }
  }

  private var editTargetName: String {
    switch scope {
    case .experience(let id):
      guard let item = profile.experience?.first(where: { $0.id == id }) else { return scope.accessibilityName }
      let label = [item.title, item.organization].map(\.trimmed).filter { !$0.isEmpty }.joined(separator: " at ")
      return label.isEmpty ? scope.accessibilityName : label
    case .selectedProject(let id):
      let label = profile.profileProjects?.first(where: { $0.id == id })?.name.trimmed ?? ""
      return label.isEmpty ? scope.accessibilityName : label
    case .evidence(let id):
      guard let item = profile.evidence.first(where: { $0.id == id }) else { return scope.accessibilityName }
      let label = ProfileStorySupport.evidenceText(item)
      return label.isEmpty ? scope.accessibilityName : String(label.prefix(64))
    case .education(let id):
      guard let item = profile.education?.first(where: { $0.id == id }) else { return scope.accessibilityName }
      let label = [item.credential, item.school].map(\.trimmed).first(where: { !$0.isEmpty }) ?? ""
      return label.isEmpty ? scope.accessibilityName : label
    default:
      return scope.accessibilityName
    }
  }
}
