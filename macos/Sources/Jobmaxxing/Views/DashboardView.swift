import SwiftUI

struct DashboardView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let openApplication: (String) -> Void

  private var jobs: [JobRecord] { store.state.jobs }
  private var draftCount: Int { jobs.filter { $0.draft != nil }.count }
  private var interviewCount: Int { jobs.filter { $0.stage == .interviewing }.count }
  private var companyCount: Int { store.companyProfiles.count }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        DashboardStats(
          jobs: jobs.count,
          companies: companyCount,
          drafts: draftCount,
          interviews: interviewCount
        )

        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 24) {
            applicationQueue
              .frame(minWidth: 420)
            sideQueue
              .frame(width: 320)
          }

          VStack(alignment: .leading, spacing: 20) {
            applicationQueue
            sideQueue
          }
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  private var applicationQueue: some View {
    DashboardGroup(title: "Open applications") {
      if jobs.isEmpty {
        DashboardEmptyText("Add an application.")
      } else {
        LazyVStack(spacing: 0) {
          ForEach(jobs) { job in
            DashboardApplicationRow(job: job, isSelected: store.selectedJobID == job.id)
              .onTapGesture {
                openApplication(job.id)
              }
              .accessibilityAddTraits(.isButton)
              .accessibilityLabel("\(job.role), \(job.company)")

            if job.id != jobs.last?.id {
              Divider()
            }
          }
        }
      }
    }
  }

  private var sideQueue: some View {
    VStack(alignment: .leading, spacing: 18) {
      evidenceGaps
      companyProfiles
      recentActivity
    }
  }

  private var evidenceGaps: some View {
    let missingLinks = store.state.profile.evidence.filter { $0.sourceURL.isEmpty }
    return DashboardGroup(title: "Evidence gaps") {
      if missingLinks.isEmpty {
        DashboardEmptyText("All proof linked.")
      } else {
        DashboardQueueList(items: missingLinks.prefix(5).map {
          DashboardQueueItem(
            id: $0.id,
            title: dashboardEvidenceGapTitle($0),
            detail: nil,
            action: dashboardEvidenceGapActionTitle($0)
          )
        })
      }
    }
  }

  private var companyProfiles: some View {
    DashboardGroup(title: "Companies") {
      if store.companyProfiles.isEmpty {
        DashboardEmptyText("No companies yet.")
      } else {
        DashboardQueueList(items: store.companyProfiles.prefix(5).map {
          DashboardQueueItem(
            id: $0.id,
            title: dashboardCompanyTitle($0),
            detail: dashboardCompanyResearchStatus($0),
            action: dashboardCompanyActionTitle($0)
          )
        })
      }
    }
  }

  private var recentActivity: some View {
    DashboardGroup(title: "Activity") {
      if store.state.events.isEmpty {
        DashboardEmptyText("No activity yet.")
      } else {
        DashboardQueueList(items: store.state.events.prefix(5).map {
          DashboardQueueItem(
            id: $0.id,
            title: dashboardActivityTitle($0),
            detail: dashboardActivityDetail($0),
            action: dashboardActivityActionTitle($0)
          )
        })
      }
    }
  }
}

func dashboardEvidenceGapTitle(_ item: EvidenceItem) -> String {
  trimmedFallback(item.title, fallback: "Untitled proof")
}

func dashboardEvidenceGapActionTitle(_: EvidenceItem) -> String {
  "Link source"
}

func dashboardCompanyTitle(_ company: CompanyProfile) -> String {
  trimmedFallback(company.name, fallback: "Untitled company")
}

func dashboardCompanyResearchStatus(_ company: CompanyProfile) -> String {
  let status = company.research.status.trimmed
  if status.isEmpty {
    return "Research status unknown"
  }

  switch status.lowercased() {
  case "not researched":
    return "Research needed"
  case "researched from official and public sources":
    return "Research ready"
  case "known from user evidence":
    return "Proof source"
  case "known from repository":
    return "Repository proof"
  default:
    return status
  }
}

func dashboardCompanyActionTitle(_ company: CompanyProfile) -> String {
  if company.research.status.trimmed.lowercased() == "not researched" {
    return "Research"
  }
  if let action = company.nextActions.first?.trimmed, !action.isEmpty {
    return dashboardShortActionTitle(action)
  }
  return "Review"
}

func dashboardActivityTitle(_ event: ActivityEvent) -> String {
  trimmedFallback(event.title, fallback: "Activity")
}

func dashboardActivityDetail(_ event: ActivityEvent) -> String {
  let detail = trimmedFallback(event.detail, fallback: "No detail.")
  return detail
    .replacingOccurrences(of: ". Not submitted.", with: ".")
    .replacingOccurrences(of: " Not submitted.", with: "")
    .replacingOccurrences(of: " Not submitted", with: "")
    .trimmed
}

func dashboardActivityActionTitle(_ event: ActivityEvent) -> String {
  let safetyText = "\(event.approval) \(event.detail)".lowercased()
  if safetyText.contains("not submitted") {
    return "Not submitted"
  }

  let approval = event.approval.trimmed
  if !approval.isEmpty {
    if approval.lowercased() == "not needed" {
      return "No approval"
    }
    return approval
  }

  return "Logged"
}

private func trimmedFallback(_ value: String, fallback: String) -> String {
  let trimmed = value.trimmed
  return trimmed.isEmpty ? fallback : trimmed
}

private func dashboardShortActionTitle(_ action: String) -> String {
  let normalized = action.lowercased()
  if normalized.contains("build source map") {
    return "Source map"
  }
  if normalized.contains("find likely hiring people") {
    return "Find people"
  }
  if normalized.contains("map saved roles") {
    return "Map proof"
  }
  if normalized.contains("prepare company-specific") {
    return "Prepare outreach"
  }
  if normalized.contains("use as proof") {
    return "Use proof"
  }
  if normalized.contains("attach") {
    return "Attach link"
  }
  if normalized.contains("draft application") {
    return "Draft"
  }
  if normalized.contains("browser handoff") {
    return "Browser plan"
  }

  return String(action.trimmed.prefix(24)).trimmingCharacters(in: .whitespacesAndNewlines)
}

private struct DashboardStats: View {
  let jobs: Int
  let companies: Int
  let drafts: Int
  let interviews: Int

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 0) {
        stat(label: "Applications", value: jobs)
        statDivider
        stat(label: "Companies", value: companies)
        statDivider
        stat(label: "Drafts", value: drafts)
        statDivider
        stat(label: "Interviews", value: interviews)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 0)], spacing: 0) {
        stat(label: "Applications", value: jobs)
        stat(label: "Companies", value: companies)
        stat(label: "Drafts", value: drafts)
        stat(label: "Interviews", value: interviews)
      }
    }
    .overlay(alignment: .bottom) {
      Divider()
    }
  }

  private func stat(label: String, value: Int) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("\(value)")
        .font(.system(.title2, design: .monospaced).weight(.bold))
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 10)
    .padding(.trailing, 16)
  }

  private var statDivider: some View {
    Rectangle()
      .fill(.separator)
      .frame(width: 1, height: 34)
      .padding(.trailing, 16)
  }
}

private struct DashboardGroup<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.headline.weight(.semibold))
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct DashboardApplicationRow: View {
  let job: JobRecord
  let isSelected: Bool
  @State private var isHovering = false

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .center, spacing: 12) {
        titleBlock

        Spacer(minLength: 12)

        statusTags
      }

      VStack(alignment: .leading, spacing: 7) {
        titleBlock
        statusTags
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 11)
    .background(isHovering && !isSelected ? AppTheme.hoverFill : Color.clear)
    .modifier(SelectedRowSurface(isSelected: isSelected))
    .contentShape(RoundedRectangle(cornerRadius: 6))
    .onHover { isHovering = $0 }
  }

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(job.role)
        .font(.headline)
        .lineLimit(1)
      Text(job.company)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private var statusTags: some View {
    HStack(spacing: 6) {
      TagText(text: job.stage.label)
      if job.draft != nil {
        TagText(text: "Draft")
      }
    }
  }
}

private struct DashboardQueueItem: Identifiable {
  let id: String
  let title: String
  let detail: String?
  let action: String?
}

private struct DashboardQueueList: View {
  let items: [DashboardQueueItem]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(items) { item in
        DashboardQueueRow(item: item)

        if item.id != items.last?.id {
          Divider()
        }
      }
    }
  }
}

private struct DashboardQueueRow: View {
  let item: DashboardQueueItem

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        textBlock
        Spacer(minLength: 10)
        actionTag
      }

      VStack(alignment: .leading, spacing: 7) {
        textBlock
        actionTag
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 7)
  }

  private var textBlock: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(item.title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)
        .lineLimit(1)

      if let detail = item.detail, !detail.trimmed.isEmpty {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
  }

  @ViewBuilder
  private var actionTag: some View {
    if let action = item.action, !action.trimmed.isEmpty {
      TagText(text: action)
    }
  }
}

private struct DashboardEmptyText: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
  }
}
