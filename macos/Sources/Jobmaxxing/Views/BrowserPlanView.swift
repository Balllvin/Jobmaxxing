import SwiftUI

struct BrowserPlanView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var request = "Prepare the browser steps for the selected role."
  @State private var sourceURL = ""
  @State private var plan: BrowserPlan?
  @State private var showsSource = false
  @State private var showsPolicy = false

  var body: some View {
    HSplitView {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if let job = store.selectedJob {
            BrowserJobHeader(job: job)
          }

          VStack(alignment: .leading, spacing: 12) {
            MultilineInput(
              title: "Browser request",
              text: $request,
              minHeight: 118,
              improveContext: store.selectedJob.map { job in
                "Company: \(job.company)\nRole: \(job.role)\nSource: \(job.sourceURL)\nDescription: \(job.description.bounded(to: 600))"
              } ?? "",
              improveKind: "browser request"
            )
            Button {
              plan = store.makeBrowserPlan(request: request, sourceURL: sourceURL)
            } label: {
              Label("Build plan", systemImage: "shield.checkered")
            }
            .buttonStyle(.borderedProminent)
          }

          BrowserSourceDisclosure(
            sourceURL: $sourceURL,
            isExpanded: $showsSource,
            selectedJob: store.selectedJob
          )

          Divider()

          BrowserSafetySummary(policy: store.state.browserPolicy)

          DisclosureGroup("Policy gates", isExpanded: $showsPolicy) {
            BrowserPolicyEditor(showsHeading: false)
              .padding(.top, 8)
          }
        }
        .padding(18)
      }
      .frame(minWidth: 460)
      .frame(maxHeight: .infinity, alignment: .top)

      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          if let plan {
            BrowserPlanSummary(plan: plan)

            Divider()

            BrowserFlatSection(title: "Steps") {
              CompactList(items: plan.steps.map(browserHumanResponsibilityCopy))
            }

            Divider()

            BrowserFlatSection(title: "Blocked") {
              CompactList(items: plan.blocked.map(browserHumanResponsibilityCopy))
            }
          } else {
            BrowserInlineEmptyState(title: "No browser plan yet", detail: "Build the steps before opening any external site.")
          }
        }
        .padding(22)
      }
      .frame(minWidth: 560)
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .onAppear {
      applySelectedJobDefaults()
    }
    .onChange(of: store.selectedJob?.id) { _, _ in
      applySelectedJobDefaults()
    }
  }

  private func applySelectedJobDefaults() {
    guard let job = store.selectedJob else { return }
    if sourceURL.isEmpty {
      sourceURL = job.sourceURL
    }
    if request == "Prepare the browser steps for the selected role." {
      request = "Prepare the browser steps for \(job.company) \(job.role)."
    }
  }
}

struct BrowserPolicyEditor: View {
  @EnvironmentObject private var store: JobmaxxingStore
  var showsHeading = true

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showsHeading {
        Text("Approval gates")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 6) {
        ForEach(PermissionMode.allCases) { mode in
          Button {
            updatePolicy { $0.permissionMode = mode }
          } label: {
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: store.state.browserPolicy.permissionMode == mode ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(store.state.browserPolicy.permissionMode == mode ? Color.green : Color.secondary)
                .padding(.top, 2)
              VStack(alignment: .leading, spacing: 3) {
                Text(mode.label)
                  .font(.headline)
                Text(mode.detail)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .modifier(SelectedRowSurface(isSelected: store.state.browserPolicy.permissionMode == mode))
          }
          .buttonStyle(.plain)
        }
      }

      Divider()

      PolicyToggleRow(
        title: "LinkedIn automation",
        detail: "Off: Jobmaxxing may research only. It does not automate protected sites.",
        isOn: Binding(
          get: { store.state.browserPolicy.allowLinkedInAutomation },
          set: { value in updatePolicy { $0.allowLinkedInAutomation = value } }
        )
      )
      PolicyToggleRow(
        title: "External submit",
        detail: "Off: Jobmaxxing prepares only. On: the user must still approve the external action.",
        isOn: Binding(
          get: { store.state.browserPolicy.allowExternalSubmission },
          set: { value in updatePolicy { $0.allowExternalSubmission = value } }
        )
      )
      PolicyToggleRow(
        title: "the user presses submit",
        detail: "On: the user presses final submit. Jobmaxxing stops before that action.",
        isOn: Binding(
          get: { store.state.browserPolicy.requireFinalHumanSubmit },
          set: { value in updatePolicy { $0.requireFinalHumanSubmit = value } }
        )
      )

      Divider()

      Text(effectiveRule)
        .font(.headline)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var effectiveRule: String {
    let policy = store.state.browserPolicy
    if policy.permissionMode == .manualOnly {
      return "Rule: the user controls every browser action."
    }
    if policy.requireFinalHumanSubmit {
      return "Rule: Jobmaxxing prepares and fills reviewed fields. the user submits."
    }
    if policy.allowExternalSubmission {
      return "Rule: Jobmaxxing submits only after the user gives explicit approval."
    }
    return "Rule: Jobmaxxing does not submit external forms."
  }

  private func updatePolicy(_ update: (inout BrowserPolicy) -> Void) {
    var policy = store.state.browserPolicy
    update(&policy)
    store.updateBrowserPolicy(policy)
  }
}

private struct BrowserJobHeader: View {
  let job: JobRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        Text(job.role)
          .font(.title3.weight(.semibold))
          .lineLimit(2)
        Text(job.company)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}

private struct BrowserSourceDisclosure: View {
  @Binding var sourceURL: String
  @Binding var isExpanded: Bool
  let selectedJob: JobRecord?

  var body: some View {
    DisclosureGroup(sourceLabel, isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 8) {
        TextField("https://company.example/role", text: $sourceURL)
          .textFieldStyle(.roundedBorder)
        if let selectedJob, !selectedJob.sourceURL.isEmpty {
          Button("Use selected job URL") {
            sourceURL = selectedJob.sourceURL
          }
        }
        Text("Optional. Jobmaxxing validates http and https links before opening them.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, 8)
    }
  }

  private var sourceLabel: String {
    sourceURL.trimmed.isEmpty ? "Add source URL" : "Source URL set"
  }
}

private struct BrowserSafetySummary: View {
  let policy: BrowserPolicy

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Safety")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      Text(modeLine)
        .font(.subheadline.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
      Text(submitLine)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("Protected sites stay read-only unless the user enables automation.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var modeLine: String {
    switch policy.permissionMode {
    case .manualOnly:
      "the user controls every browser action."
    case .assistFill:
      "Jobmaxxing fills reviewed fields, then stops before submit."
    case .autonomousPrepare:
      "Jobmaxxing prepares drafts and queues. It does not submit."
    }
  }

  private var submitLine: String {
    if policy.requireFinalHumanSubmit {
      return "the user presses final submit."
    }
    if policy.allowExternalSubmission {
      return "Jobmaxxing can submit only after the user gives explicit approval."
    }
    return "Jobmaxxing does not submit external forms."
  }
}

private struct BrowserPlanSummary: View {
  let plan: BrowserPlan

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text("Risk")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        Text(plan.risk)
          .font(.headline.weight(.semibold))
          .foregroundStyle(plan.risk == "High" ? .orange : .primary)
      }

      Text(browserHumanResponsibilityCopy(plan.checkpoint))
        .font(.title3.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct BrowserFlatSection<Content: View>: View {
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

private struct BrowserInlineEmptyState: View {
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

private struct PolicyToggleRow: View {
  let title: String
  let detail: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer()
      Toggle(title, isOn: $isOn)
        .labelsHidden()
    }
    .padding(.vertical, 6)
  }
}

private extension PermissionMode {
  var detail: String {
    switch self {
    case .manualOnly:
      "the user controls every action."
    case .assistFill:
      "Jobmaxxing fills reviewed fields. It stops before submit."
    case .autonomousPrepare:
      "Jobmaxxing prepares drafts and queues. It does not submit."
    }
  }
}

private func browserHumanResponsibilityCopy(_ text: String) -> String {
  text
    .replacingOccurrences(of: "User reviews", with: "the user reviews")
    .replacingOccurrences(of: "user reviews", with: "the user reviews")
    .replacingOccurrences(of: "user review", with: "the user review")
    .replacingOccurrences(of: "the user", with: "the user")
}
