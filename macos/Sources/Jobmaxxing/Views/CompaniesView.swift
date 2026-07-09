import SwiftUI

struct CompaniesView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let openApplication: (String) -> Void
  let openContacts: (String) -> Void
  @AppStorage("jobmaxxing.companyDetailOpen") private var companyDetailOpen = false
  @State private var name = ""
  @State private var website = ""
  @State private var linkedInURL = ""
  @State private var category = "Target company"
  @State private var relationship = "Application target"
  @State private var notes = ""

  var body: some View {
    ScrollView {
      if companyDetailOpen, store.selectedCompany != nil {
        CompanyDetailView(
          openApplication: openApplication,
          openContacts: openContacts
        ) {
          companyDetailOpen = false
        }
      } else {
        CompanyDirectoryView(
          name: $name,
          website: $website,
          linkedInURL: $linkedInURL,
          notes: $notes,
          openCompany: { company in
            store.selectedCompanyID = company.id
            companyDetailOpen = true
          },
          saveCompany: saveCompany
        )
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onAppear {
      if store.selectedCompany == nil {
        companyDetailOpen = false
      }
    }
  }

  private func saveCompany() {
    store.addCompany(
      name: name,
      website: website,
      linkedInURL: linkedInURL,
      category: category,
      relationship: relationship,
      notes: notes
    )
    name = ""
    website = ""
    linkedInURL = ""
    notes = ""
    companyDetailOpen = true
  }
}

private struct CompanyDirectoryView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var name: String
  @Binding var website: String
  @Binding var linkedInURL: String
  @Binding var notes: String
  @State private var query = ""
  @State private var selectedFilter = "all"
  let openCompany: (CompanyProfile) -> Void
  let saveCompany: () -> Void

  private var filteredCompanies: [CompanyProfile] {
    store.companyProfiles
      .filter(matchesFilter)
      .filter(matchesQuery)
  }

  private var targetCompanies: [CompanyProfile] {
    filteredCompanies.filter { !$0.applicationIDs.isEmpty || $0.relationship.localizedCaseInsensitiveContains("target") }
  }

  private var proofCompanies: [CompanyProfile] {
    filteredCompanies.filter { $0.applicationIDs.isEmpty && (!$0.experienceIDs.isEmpty || !$0.relationship.localizedCaseInsensitiveContains("target")) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          TextField("Search companies, locations, sources, notes", text: $query)
          Picker("Filter", selection: $selectedFilter) {
            Text("All").tag("all")
            Text("Targets").tag("targets")
            Text("Applications").tag("applications")
            Text("Contacts").tag("contacts")
            Text("Proof").tag("proof")
          }
          .labelsHidden()
          .frame(width: 150)
          Text("\(filteredCompanies.count)")
            .font(.caption.monospaced().weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: 28, alignment: .trailing)
        }

        if filteredCompanies.isEmpty {
          CompanyInlineEmpty(title: "No companies found", detail: "Adjust search or add a company.")
        } else {
          CompanyGroup(title: "Targets", companies: targetCompanies, openCompany: openCompany)
          CompanyGroup(title: "Worked with / proof", companies: proofCompanies, openCompany: openCompany)
        }
      }

      Divider()

      DisclosureGroup {
        VStack(alignment: .leading, spacing: 8) {
          TextField("Company name", text: $name)
          TextField("Website or careers URL", text: $website)
          TextField("LinkedIn company URL", text: $linkedInURL)
          MultilineInput(
            title: "Company context",
            text: $notes,
            minHeight: 96,
            improveContext: "Company: \(name)\nWebsite: \(website)\nLinkedIn: \(linkedInURL)",
            improveKind: "company context"
          )
          Button {
            saveCompany()
          } label: {
            Label("Save and open company", systemImage: "arrow.right")
          }
          .buttonStyle(.borderedProminent)
          .disabled(name.trimmed.isEmpty)
        }
        .padding(.top, 8)
      } label: {
        Label("Add company", systemImage: "plus")
          .font(.headline)
      }
    }
    .frame(maxWidth: 980, alignment: .topLeading)
  }

  private func matchesFilter(_ company: CompanyProfile) -> Bool {
    switch selectedFilter {
    case "targets":
      return company.relationship.localizedCaseInsensitiveContains("target")
    case "applications":
      return !company.applicationIDs.isEmpty
    case "contacts":
      return !store.contacts(for: company.id).isEmpty
    case "proof":
      return !company.experienceIDs.isEmpty || company.relationship.localizedCaseInsensitiveContains("built")
    default:
      return true
    }
  }

  private func matchesQuery(_ company: CompanyProfile) -> Bool {
    let clean = query.trimmed
    guard !clean.isEmpty else { return true }
    return [
      company.name,
      company.website,
      company.linkedInURL,
      company.category,
      company.size,
      company.headquarters,
      company.publicStatus,
      company.summary,
      company.relationship,
      company.notes,
      store.contacts(for: company.id).map { "\($0.name) \($0.role)" }.joined(separator: " ")
    ]
    .joined(separator: " ")
    .localizedCaseInsensitiveContains(clean)
  }
}

private struct CompanyGroup: View {
  let title: String
  let companies: [CompanyProfile]
  let openCompany: (CompanyProfile) -> Void

  var body: some View {
    if !companies.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        Text(title.uppercased())
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .padding(.top, 8)
          .padding(.bottom, 4)
        Divider()
        ForEach(companies) { company in
          Button {
            openCompany(company)
          } label: {
            CompanyListRow(company: company)
          }
          .buttonStyle(.plain)
          Divider()
        }
      }
    }
  }
}

private struct CompanyListRow: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let company: CompanyProfile

  private var detailText: String {
    [company.relationship, company.publicStatus]
      .filter { !$0.trimmed.isEmpty }
      .joined(separator: " - ")
  }

  private var countText: String {
    let roleCount = company.applicationIDs.count
    let contactCount = store.contacts(for: company.id).count
    return "\(roleCount) roles / \(contactCount) contacts"
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(company.name)
          .font(.headline)
          .lineLimit(1)
        if !detailText.isEmpty {
          Text(detailText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      Spacer()
      Text(countText)
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }
}

private struct CompanyWorkspaceSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Divider()
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      content
    }
  }
}

private struct CompanyInlineEmpty: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.subheadline.weight(.semibold))
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 4)
  }
}

private struct CompanyDetailView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let openApplication: (String) -> Void
  let openContacts: (String) -> Void
  let onBack: () -> Void
  @State private var localNotes = ""
  @State private var applicationRole = ""
  @State private var applicationURL = ""
  @State private var applicationContext = ""

  var body: some View {
    if let company = store.selectedCompany {
      VStack(alignment: .leading, spacing: 14) {
        Button {
          onBack()
        } label: {
          Label("Show companies", systemImage: "chevron.left")
        }
        .buttonStyle(.bordered)

        CompanyHeader(company: company)

        CompanyApplicationIntakeSection(
          company: company,
          role: $applicationRole,
          sourceURL: $applicationURL,
          context: $applicationContext,
          openApplication: openApplication
        )
        CompanyApplicationsSection(company: company, openApplication: openApplication)
        CompanyResearchSection(research: company.research)
        CompanyContactsSection(
          company: company,
          openContacts: openContacts
        )
        DocumentProofPanel(
          title: "Documents",
          detail: "Source files for research and proof. No external send happens here.",
          contextCompany: company.name,
          defaultTask: .companyAnalysis
        )

        CompanyMaterialsSection(company: company)

        CompanyWorkspaceSection(title: "Notes") {
          HStack {
            Spacer()
            ImproveTextControl(
              currentText: localNotes,
              context: [
                "Company: \(company.name)",
                "Summary: \(company.summary)",
                "Category: \(company.category)",
                "Research: \(company.research.status)"
              ].joined(separator: "\n"),
              kind: "company notes",
              onApply: { localNotes = $0 }
            )
          }
          TextEditor(text: $localNotes)
            .frame(minHeight: 100)
            .onAppear { localNotes = company.notes }
            .onChange(of: company.id) { _, _ in localNotes = company.notes }
          Button("Save notes") {
            store.updateCompanyNotes(companyID: company.id, notes: localNotes)
          }
          .buttonStyle(.borderedProminent)
        }

        DisclosureGroup("Agent runs") {
          AgentManagerPanel(title: "Agents", runs: store.agentRuns(forCompanyID: company.id))
        }
      }
      .frame(maxWidth: 980, alignment: .topLeading)
    } else {
      EmptyPanel(title: "No company open", detail: "Return to the company directory or create a company profile.")
        .padding(18)
    }
  }
}

private struct CompanyHeader: View {
  let company: CompanyProfile

  private var detailItems: [String] {
    [
      company.category,
      company.relationship,
      company.publicStatus,
      company.size,
      company.headquarters
    ].filter { !$0.trimmed.isEmpty }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text(company.name)
            .font(.title.weight(.bold))
          if !company.summary.trimmed.isEmpty {
            Text(company.summary)
              .font(.body)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          if !detailItems.isEmpty {
            Text(detailItems.joined(separator: " - "))
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          LinkRow(title: "Website", url: company.website)
          LinkRow(title: "LinkedIn", url: company.linkedInURL)
        }
      }
    }
  }
}

private struct CompanyApplicationIntakeSection: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let company: CompanyProfile
  @Binding var role: String
  @Binding var sourceURL: String
  @Binding var context: String
  let openApplication: (String) -> Void

  var body: some View {
    CompanyWorkspaceSection(title: "Create application") {
      TextField("Role", text: $role)
      TextField("Job post URL", text: $sourceURL)
      MultilineInput(
        title: "Role context",
        text: $context,
        minHeight: 140,
        improveContext: "Company: \(company.name)\nSummary: \(company.summary)\nRole: \(role)\nSource: \(sourceURL)",
        improveKind: "role context"
      )
      Button {
        store.addJob(
          company: company.name,
          role: role,
          sourceURL: sourceURL,
          description: context,
          notes: ""
        )
        if let jobID = store.selectedJobID {
          openApplication(jobID)
        }
        role = ""
        sourceURL = ""
        context = ""
      } label: {
        Label("Create and open application", systemImage: "briefcase")
      }
      .buttonStyle(.borderedProminent)
      .disabled(role.trimmed.isEmpty || context.trimmed.isEmpty)
    }
  }
}

private struct CompanyApplicationsSection: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let company: CompanyProfile
  let openApplication: (String) -> Void

  private var jobs: [JobRecord] {
    store.state.jobs.filter { company.applicationIDs.contains($0.id) }
  }

  var body: some View {
    CompanyWorkspaceSection(title: "Applications") {
      if jobs.isEmpty {
        CompanyInlineEmpty(title: "No applications", detail: "Create one from a job post.")
      } else {
        VStack(spacing: 0) {
          ForEach(jobs) { job in
            HStack(alignment: .top, spacing: 10) {
              VStack(alignment: .leading, spacing: 4) {
                Text(job.role)
                  .font(.headline)
                Text(job.stage.label)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                CompactSourceLink(label: "Job post", url: job.sourceURL)
              }
              Spacer()
              Button {
                openApplication(job.id)
              } label: {
                Label("Open application", systemImage: "arrow.right")
              }
            }
            .padding(.vertical, 8)
            Divider()
          }
        }
      }
    }
  }
}

private struct CompanyResearchSection: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let research: CompanyResearch
  @State private var status = ""

  var body: some View {
    CompanyWorkspaceSection(title: "Research") {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(research.status)
          .font(.headline)
        Spacer()
        if let company = store.selectedCompany {
          HStack {
            Button {
              store.prepareCompanyResearch(companyID: company.id)
              status = "Research packet prepared."
            } label: {
              Label("Prepare research", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)

            Button {
              status = store.enhanceCompany(companyID: company.id)
            } label: {
              Label("Enhance profile", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
          }
        }
      }
      if !status.trimmed.isEmpty {
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if !research.websitePages.isEmpty {
        VStack(alignment: .leading, spacing: 0) {
          Text("Sources")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .padding(.bottom, 6)
          Divider()
          ForEach(research.websitePages) { page in
            VStack(alignment: .leading, spacing: 4) {
              Text(page.title)
                .font(.headline)
              CompactSourceLink(label: "Source", url: page.url)
              Text(page.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            Divider()
          }
        }
      }

      ResearchBlock(title: "Products", items: research.products)
      ResearchTextBlock(title: "Business model", value: research.businessModel)
      ResearchBlock(title: "Leadership", items: research.leadership)
      ResearchBlock(title: "Hiring signals", items: research.hiringSignals)
      ResearchBlock(title: "Risks", items: research.risks)
      ResearchBlock(title: "Open questions", items: research.openQuestions)
    }
  }
}

private struct CompanyContactsSection: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let company: CompanyProfile
  let openContacts: (String) -> Void
  @State private var contactSearch = ""

  private var linkedContacts: [ContactRecord] {
    let query = contactSearch.trimmed
    return store.contacts(for: company.id).filter { contact in
      query.isEmpty || [
        contact.name,
        contact.role,
        contact.relationship,
        contact.notes,
        contact.linkedInURL,
        contact.phone,
        contact.email
      ].joined(separator: " ").localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    CompanyWorkspaceSection(title: "Contacts") {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        TextField("Filter linked contacts", text: $contactSearch)
        Text("\(linkedContacts.count)")
          .font(.caption.monospaced().weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(minWidth: 24, alignment: .trailing)
        Button {
          store.selectedCompanyID = company.id
          openContacts(company.id)
        } label: {
          Label("Open Contacts", systemImage: "person.crop.circle")
        }
        .buttonStyle(.borderedProminent)
      }

      if linkedContacts.isEmpty {
        CompanyInlineEmpty(title: "No linked contacts", detail: "Open Contacts to add or link a person.")
      } else {
        VStack(spacing: 0) {
          Divider()
          ForEach(linkedContacts) { contact in
            CompanyContactRow(contact: contact)
            Divider()
          }
        }
      }
    }
  }
}

private struct CompanyContactRow: View {
  let contact: ContactRecord

  private var relationText: String {
    [contact.role, contact.relationship]
      .filter { !$0.trimmed.isEmpty }
      .joined(separator: " - ")
  }

  private var directContactText: String {
    [contact.phone, contact.email]
      .filter { !$0.trimmed.isEmpty }
      .joined(separator: " / ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        Text(contact.name)
          .font(.headline)
        if !relationText.isEmpty {
          Text(relationText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if !contact.linkedInURL.trimmed.isEmpty {
          CompactSourceLink(label: "LinkedIn", url: contact.linkedInURL)
        }
        if !directContactText.isEmpty {
          Text(directContactText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        if !contact.notes.trimmed.isEmpty {
          Text(contact.notes)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      if let profile = contact.communicationProfile?.whatsApp {
        PersonWhatsAppSummary(profile: profile)
      }
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct PersonWhatsAppSummary: View {
  let profile: WhatsAppThreadProfile

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Text("WhatsApp")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text("\(profile.messageCount) messages")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      Text(profile.styleSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(profile.relationshipSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if !profile.topics.isEmpty {
        FlowTags(items: profile.topics)
      }
      if !profile.suggestedDirectMessage.trimmed.isEmpty {
        DisclosureGroup("WhatsApp draft") {
          Text(profile.suggestedDirectMessage)
            .font(.caption)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      if !profile.suggestedEmailMessage.trimmed.isEmpty {
        DisclosureGroup("Email draft") {
          Text(profile.suggestedEmailMessage)
            .font(.caption.monospaced())
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

private struct CompanyMaterialsSection: View {
  let company: CompanyProfile

  var body: some View {
    CompanyWorkspaceSection(title: "Submitted material") {
      if company.submittedMaterials.isEmpty {
        CompanyInlineEmpty(title: "No submitted material", detail: "User-approved submissions appear here.")
      } else {
        VStack(spacing: 0) {
          ForEach(company.submittedMaterials) { material in
            VStack(alignment: .leading, spacing: 5) {
              HStack {
                Text(material.title)
                  .font(.headline)
                Spacer()
                Text(material.status)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
              }
              Text(material.materialType)
                .font(.caption)
                .foregroundStyle(.secondary)
              Text(material.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
              CompactSourceLink(label: "Source", url: material.sourceURL)
            }
            .padding(.vertical, 8)
            Divider()
          }
        }
      }
    }
  }
}

private struct ResearchBlock: View {
  let title: String
  let items: [String]

  var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(title.uppercased())
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        CompactList(items: items)
      }
      Divider()
    }
  }
}

private struct ResearchTextBlock: View {
  let title: String
  let value: String

  var body: some View {
    if !value.trimmed.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(title.uppercased())
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        Text(value)
          .font(.subheadline)
          .fixedSize(horizontal: false, vertical: true)
      }
      Divider()
    }
  }
}

private struct LinkRow: View {
  let title: String
  let url: String

  var body: some View {
    if let destination = ExternalURL.normalizedWebURL(url) {
      Link("\(title): \(displayWebSource(destination))", destination: destination)
        .font(.caption)
        .lineLimit(1)
        .truncationMode(.middle)
        .help(destination.absoluteString)
    } else if !url.trimmed.isEmpty {
      Text("\(title): invalid URL")
        .font(.caption)
        .foregroundStyle(.secondary)
        .help(url)
    }
  }
}

private struct CompactSourceLink: View {
  let label: String
  let url: String

  var body: some View {
    if let destination = ExternalURL.normalizedWebURL(url) {
      Link(destination: destination) {
        HStack(spacing: 4) {
          Text("\(label):")
            .foregroundStyle(.secondary)
          Text(displayWebSource(destination))
            .lineLimit(1)
            .truncationMode(.middle)
          Image(systemName: "arrow.up.right")
            .font(.caption2.weight(.semibold))
        }
      }
      .font(.caption)
      .help(destination.absoluteString)
    } else if !url.trimmed.isEmpty {
      Text("\(label): invalid URL")
        .font(.caption)
        .foregroundStyle(.secondary)
        .help(url)
    }
  }
}

private func displayWebSource(_ url: URL) -> String {
  let host = (url.host ?? url.absoluteString)
    .replacingOccurrences(of: "www.", with: "")
  let pathParts = url.path
    .split(separator: "/")
    .prefix(2)
    .map(String.init)

  guard !pathParts.isEmpty else { return host }
  return "\(host) / \(pathParts.joined(separator: "/"))"
}
