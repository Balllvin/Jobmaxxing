import SwiftUI

struct BrowserWorkspaceDraft: Equatable {
  var request: String
  var sourceURL: String
  var plan: BrowserPlan?
}

struct BrowserPlanView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var drafts: [String: BrowserWorkspaceDraft]
  @State private var request = "Prepare the browser steps for the selected role."
  @State private var sourceURL = ""
  @State private var plan: BrowserPlan?
  @State private var showsSource = false
  @State private var showsPolicy = false
  @State private var loadedDraftKey = ""

  private let compactBreakpoint: CGFloat = 860

  var body: some View {
    GeometryReader { proxy in
      let compact = proxy.size.width < compactBreakpoint
      let layout = compact
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 22))
        : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
      ScrollView {
        layout {
          requestContent
            .padding(compact ? 16 : 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
          Divider()
          planContent
            .padding(compact ? 16 : 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    }
    .onAppear {
      enforceSafetyPolicy()
      applySelectedJobDefaults()
    }
    .onChange(of: store.selectedJob?.id) { _, _ in
      applySelectedJobDefaults()
    }
    .onDisappear(perform: saveCurrentDraft)
  }

  private var requestContent: some View {
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
          enforceSafetyPolicy()
          plan = store.makeBrowserPlan(request: request, sourceURL: sourceURL)
        } label: {
          Label("Build plan", systemImage: "shield.checkered")
        }
        .buttonStyle(.borderedProminent)
        .disabled(request.trimmed.isEmpty)
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
  }

  @ViewBuilder
  private var planContent: some View {
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
  }

  private func applySelectedJobDefaults() {
    let nextKey = store.selectedJob?.id ?? "freeform"
    guard loadedDraftKey != nextKey else { return }
    saveCurrentDraft()
    loadedDraftKey = nextKey
    if let saved = drafts[nextKey] {
      request = saved.request
      sourceURL = saved.sourceURL
      plan = saved.plan
    } else if let job = store.selectedJob {
      sourceURL = job.sourceURL
      request = "Prepare the browser steps for \(job.company) \(job.role)."
      plan = nil
    } else {
      sourceURL = ""
      request = "Prepare the browser steps for a job-search task."
      plan = nil
    }
  }

  private func saveCurrentDraft() {
    guard !loadedDraftKey.isEmpty else { return }
    drafts[loadedDraftKey] = BrowserWorkspaceDraft(
      request: request,
      sourceURL: sourceURL,
      plan: plan
    )
  }

  private func enforceSafetyPolicy() {
    let current = store.state.browserPolicy
    let enforced = enforcedBrowserPolicy(current)
    if enforced != current {
      store.updateBrowserPolicy(enforced)
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
          BrowserPolicyChoiceRow(
            mode: mode,
            isSelected: store.state.browserPolicy.permissionMode == mode
          ) {
            updatePolicy { $0.permissionMode = mode }
          }
        }
      }

      Divider()

      BrowserLockedGateRow(
        title: "Protected sites",
        detail: "Manual only. Jobmaxxing can research and prepare a handoff, but it does not operate protected job boards."
      )
      BrowserLockedGateRow(
        title: "External actions",
        detail: "Prepare only. No external message, upload, or application is submitted from this screen."
      )
      BrowserLockedGateRow(
        title: "Final submit",
        detail: "the user always reviews the final state and presses submit. This gate cannot be disabled here."
      )

      Divider()

      Text(browserSafetyRule(for: store.state.browserPolicy.permissionMode))
        .font(.headline)
        .fixedSize(horizontal: false, vertical: true)
    }
    .onAppear(perform: enforceSafetyGates)
  }

  private func updatePolicy(_ update: (inout BrowserPolicy) -> Void) {
    var policy = store.state.browserPolicy
    update(&policy)
    store.updateBrowserPolicy(enforcedBrowserPolicy(policy))
  }

  private func enforceSafetyGates() {
    let current = store.state.browserPolicy
    let enforced = enforcedBrowserPolicy(current)
    if enforced != current {
      store.updateBrowserPolicy(enforced)
    }
  }
}

func enforcedBrowserPolicy(_ policy: BrowserPolicy) -> BrowserPolicy {
  var safePolicy = policy
  safePolicy.allowLinkedInAutomation = false
  safePolicy.allowExternalSubmission = false
  safePolicy.requireFinalHumanSubmit = true
  return safePolicy
}

func browserSafetyRule(for mode: PermissionMode) -> String {
  switch mode {
  case .manualOnly:
    "the user controls every browser action and presses final submit."
  case .assistFill:
    "Jobmaxxing may prepare reviewed fields on allowed sites. Protected sites stay manual, and the user presses final submit."
  case .autonomousPrepare:
    "Jobmaxxing may prepare drafts and checklists. It does not operate protected sites or submit, and the user keeps final control."
  }
}

private struct BrowserPolicyChoiceRow: View {
  let mode: PermissionMode
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? Color.green : Color.secondary)
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
      .padding(.vertical, 7)
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .background(isHovering && !isSelected ? AppTheme.hoverFill : Color.clear)
      .modifier(SelectedRowSurface(isSelected: isSelected))
      .contentShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(LiquidPressButtonStyle())
    .onHover { isHovering = $0 }
    .accessibilityLabel(mode.label)
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
  }
}

private struct BrowserLockedGateRow: View {
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "lock.fill")
        .foregroundStyle(.secondary)
        .frame(width: 18)
        .padding(.top, 2)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .accessibilityElement(children: .combine)
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
      Text("Protected sites stay manual. Jobmaxxing prepares a reviewed handoff and does not submit externally.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("the user always reviews the final state and presses submit.")
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
