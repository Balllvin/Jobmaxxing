import AppKit
import SwiftUI

struct ContactsView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let initialCompanyID: String
  let openCompany: (String) -> Void

  @State private var query = ""
  @State private var selectedCompanyFilter = "all"
  @State private var selectedContactFilter = "all"
  @State private var selectedContactID = ""
  @State private var selectedCompanyID = ""
  @State private var name = ""
  @State private var role = ""
  @State private var jobDescription = ""
  @State private var linkedInURL = ""
  @State private var phone = ""
  @State private var email = ""
  @State private var location = ""
  @State private var sourceURL = ""
  @State private var relationship = "Contact"
  @State private var howMet = ""
  @State private var notes = ""
  @State private var personalNotes = ""
  @State private var projectNotes = ""
  @State private var whatsAppQuery = ""
  @State private var whatsAppStatus = ""
  @State private var whatsAppCandidates: [WhatsAppThreadCandidate] = []
  @State private var enhanceStatus = ""
  @State private var isAddingContact = false
  @State private var isImportingWhatsApp = false
  @State private var isAgentHistoryOpen = false

  private var filteredContacts: [ContactRecord] {
    store.contacts
      .filter(matchesCompany)
      .filter(matchesType)
      .filter(matchesQuery)
      .sorted { left, right in
        left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
      }
  }

  private var selectedContact: ContactRecord? {
    guard !selectedContactID.isEmpty else { return nil }
    return store.contacts.first(where: { $0.id == selectedContactID })
  }

  private var visibleRuns: [ResearchAgentRun] {
    if let selectedContact {
      return store.agentRuns(forContactID: selectedContact.id)
    }
    return store.agentRuns(for: filteredContacts.map(\.id))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        if let contact = selectedContact {
          VStack(alignment: .leading, spacing: 12) {
            Button {
              selectedContactID = ""
            } label: {
              Label("Back to people", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)

            ContactDetailPanel(contact: contact, openCompany: openCompany) {
              enhanceStatus = store.enhanceContact(contactID: contact.id)
              selectedContactID = contact.id
            }

            DisclosureGroup("Agent") {
              ContactAgentPanel(contact: contact)
            }
            .padding(.top, 4)
          }
          .frame(maxWidth: 1260, alignment: .topLeading)
        } else {
          VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
              HStack(alignment: .firstTextBaseline) {
                peopleTitle
                Spacer()
                contactActions
              }
              VStack(alignment: .leading, spacing: 8) {
                peopleTitle
                contactActions
              }
            }

            ContactFilterBar(
              query: $query,
              selectedCompanyFilter: $selectedCompanyFilter,
              selectedContactFilter: $selectedContactFilter,
              selectedContactID: $selectedContactID
            )

            if isAddingContact {
              ContactIntakePanel(
                selectedCompanyID: $selectedCompanyID,
                name: $name,
                role: $role,
                jobDescription: $jobDescription,
                linkedInURL: $linkedInURL,
                phone: $phone,
                email: $email,
                location: $location,
                sourceURL: $sourceURL,
                relationship: $relationship,
                howMet: $howMet,
                notes: $notes,
                personalNotes: $personalNotes,
                projectNotes: $projectNotes,
                save: saveContact
              )
            }

            if isImportingWhatsApp {
              WhatsAppContactPanel(
                selectedCompanyID: $selectedCompanyID,
                query: $whatsAppQuery,
                status: $whatsAppStatus,
                candidates: $whatsAppCandidates,
                selectedContactID: $selectedContactID
              )
            } else if !whatsAppStatus.trimmed.isEmpty {
              Text(whatsAppStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            ContactList(
              contacts: filteredContacts,
              selectedContactID: $selectedContactID
            )

            DisclosureGroup("Agent history", isExpanded: $isAgentHistoryOpen) {
              AgentManagerPanel(
                title: "Agents",
                runs: visibleRuns,
                actionTitle: "Enhance people",
                actionSystemImage: "sparkles"
              ) {
                enhanceStatus = store.enhanceContacts(contactIDs: filteredContacts.map(\.id))
              }
            }
            .font(.subheadline)
          }
          .frame(maxWidth: 1260, alignment: .topLeading)
        }

        if !enhanceStatus.trimmed.isEmpty {
          Text(enhanceStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 1260, alignment: .leading)
            .padding(.top, 8)
        }
      }
      .padding(18)
    }
    .onAppear(perform: selectDefaults)
    .onChange(of: filteredContacts.map(\.id)) { _, ids in
      if !ids.contains(selectedContactID) {
        selectedContactID = ""
      }
    }
  }

  private func saveContact() {
    guard let contactID = store.addContact(
      companyID: selectedCompanyID,
      name: name,
      role: role,
      jobDescription: jobDescription,
      linkedInURL: linkedInURL,
      phone: phone,
      email: email,
      location: location,
      sourceURL: sourceURL,
      relationship: relationship,
      howMet: howMet,
      notes: notes,
      personalNotes: personalNotes,
      projectNotes: projectNotes
    ) else { return }
    selectedContactID = contactID
    clearForm()
  }

  private func selectDefaults() {
    if !initialCompanyID.isEmpty {
      selectedCompanyID = initialCompanyID
      selectedCompanyFilter = initialCompanyID
    } else if selectedCompanyID.isEmpty {
      selectedCompanyID = store.companyProfiles.first(where: { $0.id == "medela" })?.id ?? store.companyProfiles.first?.id ?? ""
    }
    selectedContactID = ""
  }

  private func clearForm() {
    name = ""
    role = ""
    jobDescription = ""
    linkedInURL = ""
    phone = ""
    email = ""
    location = ""
    sourceURL = ""
    relationship = "Contact"
    howMet = ""
    notes = ""
    personalNotes = ""
    projectNotes = ""
  }

  private func toggleAddContact() {
    isAddingContact.toggle()
    if isAddingContact {
      isImportingWhatsApp = false
    }
  }

  private func toggleWhatsAppImport() {
    isImportingWhatsApp.toggle()
    if isImportingWhatsApp {
      isAddingContact = false
    }
  }

  private var peopleTitle: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text("People")
        .font(.title2.weight(.semibold))
      Text("\(filteredContacts.count)")
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
    }
  }

  private var contactActions: some View {
    HStack {
      Button {
        toggleAddContact()
      } label: {
        Label(isAddingContact ? "Hide add form" : "Add person", systemImage: "person.crop.circle.badge.plus")
      }
      .buttonStyle(.bordered)

      Button {
        toggleWhatsAppImport()
      } label: {
        Label(isImportingWhatsApp ? "Hide import" : "Import WhatsApp", systemImage: "message")
      }
      .buttonStyle(.borderedProminent)
    }
  }

  private func matchesCompany(_ contact: ContactRecord) -> Bool {
    selectedCompanyFilter == "all" || contact.companyLinks.contains(where: { $0.companyID == selectedCompanyFilter })
  }

  private func matchesType(_ contact: ContactRecord) -> Bool {
    switch selectedContactFilter {
    case "whatsapp":
      return contact.communicationProfile?.whatsApp != nil
    case "linkedin":
      return !contact.linkedInURL.trimmed.isEmpty
    case "notes":
      return !contact.notes.trimmed.isEmpty || !contact.personalNotes.trimmed.isEmpty || !contact.projectNotes.trimmed.isEmpty
    case "needs-research":
      return contact.research.publicFacts.isEmpty && contact.research.proposedAdditions.isEmpty
    default:
      return true
    }
  }

  private func matchesQuery(_ contact: ContactRecord) -> Bool {
    let clean = query.trimmed
    guard !clean.isEmpty else { return true }
    return [
      contact.name,
      contact.role,
      contact.jobDescription,
      contact.linkedInURL,
      contact.phone,
      contact.email,
      contact.location,
      contact.sourceURL,
      contact.relationship,
      contact.howMet,
      contact.notes,
      contact.personalNotes,
      contact.projectNotes,
      contact.companyLinks.map { "\($0.companyName) \($0.role) \($0.relationship) \($0.notes)" }.joined(separator: " "),
      contact.communicationProfile?.whatsApp?.displayName ?? "",
      contact.communicationProfile?.whatsApp?.jid ?? ""
    ]
    .joined(separator: " ")
    .localizedCaseInsensitiveContains(clean)
  }
}

private struct ContactFilterBar: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var query: String
  @Binding var selectedCompanyFilter: String
  @Binding var selectedContactFilter: String
  @Binding var selectedContactID: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        TextField("Search people", text: $query)
          .textFieldStyle(.roundedBorder)
        if !selectedContactID.isEmpty {
          Button {
            selectedContactID = ""
          } label: {
            Image(systemName: "xmark.circle")
          }
          .buttonStyle(.plain)
          .help("Clear contact selection")
        }
      }
      HStack(spacing: 8) {
        Picker("Company", selection: $selectedCompanyFilter) {
          Text("All companies").tag("all")
          ForEach(store.companyProfiles) { company in
            Text(company.name).tag(company.id)
          }
        }
        .frame(minWidth: 180)
        Picker("Filter", selection: $selectedContactFilter) {
          Text("All").tag("all")
          Text("WhatsApp").tag("whatsapp")
          Text("LinkedIn").tag("linkedin")
          Text("Has notes").tag("notes")
          Text("Needs research").tag("needs-research")
        }
        .frame(width: 150)
        Spacer()
      }
      .labelsHidden()
    }
  }
}

private struct ContactList: View {
  let contacts: [ContactRecord]
  @Binding var selectedContactID: String

  var body: some View {
    if contacts.isEmpty {
      EmptyPanel(title: "No people found", detail: "Clear filters or add a person.")
    } else {
      VStack(spacing: 0) {
        ForEach(contacts) { contact in
          Button {
            selectedContactID = contact.id
          } label: {
            ContactRow(contact: contact, isSelected: selectedContactID == contact.id)
          }
          .buttonStyle(.plain)
          if contact.id != contacts.last?.id {
            Divider()
          }
        }
      }
      .background(.background)
      .overlay(Rectangle().stroke(.separator, lineWidth: 1))
    }
  }
}

private struct ContactRow: View {
  let contact: ContactRecord
  let isSelected: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text(contact.name)
          .font(.headline)
          .lineLimit(1)
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        if !contactLine.isEmpty {
          Text(contactLine)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 12)
      VStack(alignment: .trailing, spacing: 5) {
        if contact.communicationProfile?.whatsApp != nil {
          Label("WhatsApp", systemImage: "message")
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 11)
    .frame(maxWidth: .infinity, alignment: .leading)
    .modifier(SelectedRowSurface(isSelected: isSelected))
    .contentShape(Rectangle())
  }

  private var subtitle: String {
    [
      contact.role,
      contact.companyLinks.map(\.companyName).joined(separator: ", ")
    ]
    .map(\.trimmed)
    .filter { !$0.isEmpty }
    .joined(separator: " - ")
  }

  private var contactLine: String {
    [contact.phone, contact.email, ContactSourceLabel(rawValue: contact.linkedInURL).rowLabel]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .joined(separator: " / ")
  }
}

private struct ContactIntakePanel: View {
  @Binding var selectedCompanyID: String
  @Binding var name: String
  @Binding var role: String
  @Binding var jobDescription: String
  @Binding var linkedInURL: String
  @Binding var phone: String
  @Binding var email: String
  @Binding var location: String
  @Binding var sourceURL: String
  @Binding var relationship: String
  @Binding var howMet: String
  @Binding var notes: String
  @Binding var personalNotes: String
  @Binding var projectNotes: String
  let save: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Divider()
      ContactCompanyPicker(selectedCompanyID: $selectedCompanyID)
        .frame(maxWidth: 320, alignment: .leading)
      ContactFieldPair(firstTitle: "Name", firstText: $name, secondTitle: "Role or title", secondText: $role)
      ContactFieldTriple(
        firstTitle: "Phone",
        firstText: $phone,
        secondTitle: "Email",
        secondText: $email,
        thirdTitle: "Public profile",
        thirdText: $linkedInURL
      )
      ContactContextField(text: $notes)
      Button {
        save()
      } label: {
        Label("Save person", systemImage: "checkmark")
      }
      .buttonStyle(.borderedProminent)
      .disabled(name.trimmed.isEmpty)
    }
    .padding(.vertical, 4)
  }
}

private struct WhatsAppContactPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var selectedCompanyID: String
  @Binding var query: String
  @Binding var status: String
  @Binding var candidates: [WhatsAppThreadCandidate]
  @Binding var selectedContactID: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Divider()
      Text("Local import. Drafts only. Nothing is sent.")
        .font(.caption)
        .foregroundStyle(.secondary)
      ViewThatFits(in: .horizontal) {
        HStack {
          ContactCompanyPicker(selectedCompanyID: $selectedCompanyID)
            .frame(maxWidth: 320, alignment: .leading)
          latestSenderButton
        }
        VStack(alignment: .leading, spacing: 8) {
          ContactCompanyPicker(selectedCompanyID: $selectedCompanyID)
          latestSenderButton
        }
      }
      ViewThatFits(in: .horizontal) {
        HStack {
          TextField("Name or phone", text: $query)
          findThreadButton
        }
        VStack(alignment: .leading, spacing: 8) {
          TextField("Name or phone", text: $query)
          findThreadButton
        }
      }
      if !status.trimmed.isEmpty {
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      VStack(spacing: 0) {
        ForEach(candidates) { candidate in
          HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
              Text(candidate.displayName)
                .font(.headline)
              Text("\(candidate.messageCount) messages")
                .font(.caption)
                .foregroundStyle(.secondary)
              if !candidate.jid.trimmed.isEmpty {
                Text(candidate.jid)
                  .font(.caption.monospaced())
                  .foregroundStyle(.secondary)
                  .textSelection(.enabled)
              }
            }
            Spacer()
            Button {
              let result = store.addWhatsAppContactMetadata(
                companyID: selectedCompanyID,
                candidate: candidate,
                fallbackName: query,
                title: "",
                relationship: "Contact",
                notes: "Added from WhatsApp search."
              )
              status = result.status
              if let contactID = result.contactID {
                selectedContactID = contactID
              }
              candidates = []
              query = ""
            } label: {
              Label("Save person", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCompanyID.isEmpty)
          }
          .padding(.vertical, 10)
          if candidate.id != candidates.last?.id {
            Divider()
          }
        }
      }
    }
    .padding(.vertical, 4)
  }

  private var latestSenderButton: some View {
    Button {
      let result = store.addLatestWhatsAppContactMetadata(companyID: selectedCompanyID)
      status = result.status
      if let contactID = result.contactID {
        selectedContactID = contactID
      }
    } label: {
      Label("Save latest sender", systemImage: "message.badge")
    }
    .buttonStyle(.bordered)
    .disabled(selectedCompanyID.isEmpty)
  }

  private var findThreadButton: some View {
    Button {
      let result = store.searchWhatsAppThreads(query: query)
      candidates = result.candidates
      status = result.status
    } label: {
      Label("Find thread", systemImage: "magnifyingglass")
    }
    .buttonStyle(.bordered)
  }
}

private struct ContactFieldPair: View {
  let firstTitle: String
  @Binding var firstText: String
  let secondTitle: String
  @Binding var secondText: String

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        TextField(firstTitle, text: $firstText)
        TextField(secondTitle, text: $secondText)
      }
      VStack(alignment: .leading, spacing: 8) {
        TextField(firstTitle, text: $firstText)
        TextField(secondTitle, text: $secondText)
      }
    }
  }
}

private struct ContactFieldTriple: View {
  let firstTitle: String
  @Binding var firstText: String
  let secondTitle: String
  @Binding var secondText: String
  let thirdTitle: String
  @Binding var thirdText: String

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        TextField(firstTitle, text: $firstText)
        TextField(secondTitle, text: $secondText)
        TextField(thirdTitle, text: $thirdText)
      }
      VStack(alignment: .leading, spacing: 8) {
        TextField(firstTitle, text: $firstText)
        TextField(secondTitle, text: $secondText)
        TextField(thirdTitle, text: $thirdText)
      }
    }
  }
}

private struct ContactContextField: View {
  @Binding var text: String
  var improveContext: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Spacer()
        ImproveTextControl(
          currentText: text,
          context: improveContext,
          kind: "contact context",
          onApply: { text = $0 }
        )
      }
      TextField("Relationship, request, and follow-up context", text: $text, axis: .vertical)
        .lineLimit(4...8)
        .textFieldStyle(.roundedBorder)
        .help("Use one grounded note: how you know them, what they asked, what to do next, and what must stay private.")
    }
  }
}

private struct ContactDetailPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let contact: ContactRecord
  let openCompany: (String) -> Void
  let enhance: () -> Void
  @State private var draft: ContactRecord?
  @State private var actionStatus = ""

  private var editable: Binding<ContactRecord> {
    Binding(
      get: { draft ?? contact },
      set: { draft = $0 }
    )
  }

  private var hasChanges: Bool {
    guard let draft else { return false }
    return draft != contact
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 12) {
          detailTitle
          Spacer()
          enhanceButton
        }
        VStack(alignment: .leading, spacing: 10) {
          detailTitle
          enhanceButton
        }
      }

      ContactEditFields(contact: editable)
      ViewThatFits(in: .horizontal) {
        HStack {
          saveButton
          if let companyID = contact.companyLinks.first?.companyID {
            openCompanyButton(companyID: companyID)
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          saveButton
          if let companyID = contact.companyLinks.first?.companyID {
            openCompanyButton(companyID: companyID)
          }
        }
      }

      if !actionStatus.trimmed.isEmpty {
        Text(actionStatus)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      ContactResearchPanel(contact: contact)

      if contact.communicationProfile?.whatsApp != nil || contact.sourceURL.trimmed.lowercased().hasPrefix("whatsapp:") {
        ContactWhatsAppThreadPanel(contact: contact, status: $actionStatus)
      }
    }
    .onAppear { draft = contact }
    .onChange(of: contact) { _, newContact in draft = newContact }
  }

  private var detailSubtitle: String {
    [
      contact.role,
      contact.companyLinks.map(\.companyName).joined(separator: ", ")
    ]
    .map(\.trimmed)
    .filter { !$0.isEmpty }
    .joined(separator: " - ")
  }

  private var detailTitle: some View {
    VStack(alignment: .leading, spacing: 5) {
      TextField("Name", text: editable.name)
        .font(.title2.weight(.semibold))
        .textFieldStyle(.plain)
        .help("Edit name")
      if !detailSubtitle.isEmpty {
        Text(detailSubtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
  }

  private var enhanceButton: some View {
    Button {
      enhance()
    } label: {
      Label("Enhance profile", systemImage: "sparkles")
    }
    .buttonStyle(.borderedProminent)
  }

  private var saveButton: some View {
    Button {
      if let draft {
        store.updateContact(draft)
        actionStatus = "Saved \(draft.name)."
      }
    } label: {
      Label("Save changes", systemImage: "checkmark")
    }
    .buttonStyle(.borderedProminent)
    .disabled(!hasChanges)
  }

  private func openCompanyButton(companyID: String) -> some View {
    Button {
      openCompany(companyID)
    } label: {
      Label("Open company", systemImage: "building.2")
    }
    .buttonStyle(.bordered)
  }
}

private struct ContactResearchPanel: View {
  let contact: ContactRecord

  private var hasProfile: Bool {
    !contact.research.summary.trimmed.isEmpty
      || !contact.research.publicFacts.isEmpty
      || !contact.research.openQuestions.isEmpty
      || !contact.research.proposedAdditions.isEmpty
  }

  private var nextAction: String {
    contact.research.proposedAdditions.first?.trimmed
      ?? contact.research.openQuestions.first?.trimmed
      ?? ""
  }

  var body: some View {
    if hasProfile {
      VStack(alignment: .leading, spacing: 12) {
        Divider()
        HStack(alignment: .firstTextBaseline) {
          Text("Profile")
            .font(.headline)
          if !contact.research.status.trimmed.isEmpty {
            TagText(text: contact.research.status)
          }
          Spacer()
        }
        if !nextAction.isEmpty {
          ContactNextAction(text: nextAction)
        }
        if !contact.research.summary.trimmed.isEmpty {
          Text(contact.research.summary)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 18)], alignment: .leading, spacing: 14) {
          if !contact.research.publicFacts.isEmpty {
            ProfileList(title: "Facts", systemImage: "checkmark.circle", items: contact.research.publicFacts)
          }
          if !contact.research.openQuestions.isEmpty {
            ProfileList(title: "Open questions", systemImage: "questionmark.circle", items: contact.research.openQuestions)
          }
          if !contact.research.proposedAdditions.isEmpty {
            ProfileList(title: "Next steps", systemImage: "arrow.right.circle", items: contact.research.proposedAdditions)
          }
          if !contact.research.sourceURLs.isEmpty {
            ContactSourceList(sources: contact.research.sourceURLs)
          }
        }
      }
    }
  }
}

private struct ContactNextAction: View {
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "arrow.up.right.circle.fill")
        .foregroundStyle(Color.accentColor)
        .padding(.top, 1)
      VStack(alignment: .leading, spacing: 3) {
        Text("Next action")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        Text(text)
          .font(.subheadline.weight(.semibold))
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, 8)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}

private struct ProfileList: View {
  let title: String
  let systemImage: String
  let items: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: systemImage)
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      ForEach(items, id: \.self) { item in
        HStack(alignment: .top, spacing: 7) {
          Image(systemName: "minus")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
          Text(item)
            .font(.caption)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}

private struct ContactSourceList: View {
  let sources: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label("Sources", systemImage: "link")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(sourceLabels, id: \.rawValue) { source in
          ContactSourceChip(source: source)
        }
      }
    }
  }

  private var sourceLabels: [ContactSourceLabel] {
    sources
      .map(ContactSourceLabel.init(rawValue:))
      .filter { !$0.title.isEmpty }
  }
}

private struct ContactSourceChip: View {
  let source: ContactSourceLabel

  var body: some View {
    Group {
      if let url = source.url {
        Link(destination: url) {
          label
        }
        .buttonStyle(.plain)
      } else {
        label
      }
    }
    .help(source.helpText)
  }

  private var label: some View {
    HStack(spacing: 5) {
      Image(systemName: source.systemImage)
        .font(.caption2.weight(.semibold))
      Text(source.title)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.primary)
    .padding(.horizontal, 7)
    .padding(.vertical, 5)
    .background(.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}

struct ContactSourceLabel: Hashable {
  let rawValue: String

  private var value: String {
    rawValue.trimmed
  }

  var url: URL? {
    URL(string: value).flatMap { $0.scheme?.hasPrefix("http") == true ? $0 : nil }
  }

  var title: String {
    if value.isEmpty {
      return ""
    }
    if value.lowercased().hasPrefix("whatsapp:") {
      return "WhatsApp thread"
    }
    guard let components = URLComponents(string: value),
      let host = components.host?.lowercased().withoutWWW
    else {
      return value
    }
    let path = components.path.lowercased()
    if host.contains("linkedin.com") {
      if path.contains("/in/") {
        return "LinkedIn profile"
      }
      if path.contains("/company/") {
        return "LinkedIn company"
      }
      return "LinkedIn"
    }
    if host.contains("workdayjobs.com") {
      return "Workday careers"
    }
    if host.contains("medela.com") {
      if path.hasSuffix(".pdf") {
        return "Company PDF"
      }
      if path.contains("working-at-medela") {
        return "Company careers"
      }
      if path.contains("medela-news") {
        return "Company news"
      }
      if path.contains("leadership") {
        return "Company leadership"
      }
      if path.contains("history") {
        return "Company history"
      }
      if path.contains("corporate-social") || path.contains("responsibilities") {
        return "Company CSR"
      }
      if path.contains("products") || path.contains("solutions") {
        return "Company products"
      }
      return "Company"
    }
    return host
  }

  var rowLabel: String {
    guard !value.isEmpty else { return "" }
    if title == value {
      return value
    }
    return title
  }

  var systemImage: String {
    if value.lowercased().hasPrefix("whatsapp:") {
      return "message"
    }
    if url != nil {
      return "safari"
    }
    return "doc.text"
  }

  var helpText: String {
    value.isEmpty ? title : value
  }
}

private extension String {
  var withoutWWW: String {
    hasPrefix("www.") ? String(dropFirst(4)) : self
  }
}

private struct ContactEditFields: View {
  @Binding var contact: ContactRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ContactFieldPair(firstTitle: "Phone", firstText: $contact.phone, secondTitle: "Email", secondText: $contact.email)
      ContactFieldPair(firstTitle: "Public profile", firstText: $contact.linkedInURL, secondTitle: "Role or title", secondText: $contact.role)
      ContactContextField(
        text: $contact.notes,
        improveContext: [
          "Name: \(contact.name)",
          "Company: \(contact.companyLinks.map(\.companyName).joined(separator: ", "))",
          "Role: \(contact.role)",
          "Email: \(contact.email)"
        ].joined(separator: "\n")
      )
    }
  }
}

private struct ContactWhatsAppThreadPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let contact: ContactRecord
  @Binding var status: String

  private var profile: WhatsAppThreadProfile? {
    store.contacts.first(where: { $0.id == contact.id })?.communicationProfile?.whatsApp
      ?? contact.communicationProfile?.whatsApp
  }

  private var messages: [WhatsAppThreadMessage] {
    profile?.messages ?? []
  }

  private var visibleMessages: [WhatsAppThreadMessage] {
    Array(messages.suffix(16))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Divider()
      ViewThatFits(in: .horizontal) {
        HStack {
          whatsAppTitle
          Spacer()
          whatsAppActions
        }
        VStack(alignment: .leading, spacing: 8) {
          whatsAppTitle
          whatsAppActions
        }
      }

      if let draft = profile?.suggestedDirectMessage.trimmed, !draft.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text("Draft")
              .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(draft, forType: .string)
              status = "Copied reply for \(contact.name)."
            } label: {
              Label("Copy draft", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
          }
          Text(draft)
            .font(.body)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if messages.isEmpty {
        EmptyPanel(title: "No messages", detail: "Refresh thread to import messages.")
      } else {
        VStack(alignment: .leading, spacing: 0) {
          Text("Conversation")
            .font(.subheadline.weight(.semibold))
            .padding(.bottom, 6)
          ForEach(visibleMessages) { message in
            WhatsAppMessageRow(message: message, contactName: contact.name)
            if message.id != visibleMessages.last?.id {
              Divider()
            }
          }
        }
      }
    }
  }

  private var whatsAppTitle: some View {
    HStack {
      Text("WhatsApp")
        .font(.headline)
      if let profile {
        TagText(text: "\(profile.messageCount) messages")
      }
    }
  }

  private var whatsAppActions: some View {
    HStack {
      Button {
        status = store.refreshWhatsAppThread(contactID: contact.id)
      } label: {
        Label("Refresh thread", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.bordered)
      Button {
        status = store.draftWhatsAppReply(contactID: contact.id)
      } label: {
        Label("Draft reply", systemImage: "text.bubble")
      }
      .buttonStyle(.bordered)
    }
  }
}

private struct WhatsAppMessageRow: View {
  let message: WhatsAppThreadMessage
  let contactName: String

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 10) {
        sender
          .frame(width: 96, alignment: .leading)
        messageText
      }
      VStack(alignment: .leading, spacing: 4) {
        sender
        messageText
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
    .padding(.horizontal, 2)
  }

  private var sender: some View {
    Text(message.isFromMe ? "the user" : contactName)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .lineLimit(1)
  }

  private var messageText: some View {
    Text(message.text)
      .font(.body)
      .textSelection(.enabled)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ContactCompanyPicker: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var selectedCompanyID: String

  var body: some View {
    Picker("Company", selection: $selectedCompanyID) {
      ForEach(store.companyProfiles) { company in
        Text(company.name).tag(company.id)
      }
    }
    .onAppear {
      if selectedCompanyID.isEmpty {
        selectedCompanyID = store.companyProfiles.first(where: { $0.id == "medela" })?.id ?? store.companyProfiles.first?.id ?? ""
      }
    }
  }
}

private struct ContactAgentPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let contact: ContactRecord
  @State private var draft = ""
  @State private var modelTier = "Medium"
  @State private var status = ""

  private var messages: [HermesChatMessage] {
    store.contactAgentMessages(contactID: contact.id)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "sparkles")
        Text("Agent")
          .font(.caption.weight(.bold))
        Spacer()
        Picker("Model", selection: $modelTier) {
          Text("Medium").tag("Medium")
          Text("High").tag("High")
        }
        .labelsHidden()
        .frame(width: 116)
      }
      .foregroundStyle(.secondary)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
        ContactAgentAction(title: "Deep profile", systemImage: "person.text.rectangle") {
          run("deep-profile")
        }
        ContactAgentAction(title: "Find email", systemImage: "envelope") {
          run("find-email")
        }
        ContactAgentAction(title: "Draft follow-up", systemImage: "text.bubble") {
          run("draft-follow-up")
        }
        ContactAgentAction(title: "Chrome research", systemImage: "safari") {
          run("chrome-research")
        }
      }

      if messages.isEmpty {
        EmptyPanel(title: "No agent messages", detail: "Run a profile, email, or follow-up action.")
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(messages) { message in
              ContactAgentMessageRow(message: message)
            }
          }
        }
        .frame(minHeight: 260, maxHeight: 520)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Spacer()
          ImproveTextControl(
            currentText: draft,
            context: [
              "Contact: \(contact.name)",
              "Company: \(contact.companyLinks.map(\.companyName).joined(separator: ", "))",
              "Role: \(contact.role)",
              "Email: \(contact.email)",
              "Notes: \(contact.notes.bounded(to: 500))"
            ].joined(separator: "\n"),
            kind: "agent request",
            onApply: { draft = $0 }
          )
        }
        TextEditor(text: $draft)
          .font(.body)
          .frame(minHeight: 88)
          .scrollContentBackground(.hidden)
          .padding(8)
          .background(.background)
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
        HStack {
          Button {
            send()
          } label: {
            Label("Ask agent", systemImage: "arrow.up.circle.fill")
          }
          .buttonStyle(.borderedProminent)
          .disabled(draft.trimmed.isEmpty)
          Spacer()
          if !status.trimmed.isEmpty {
            Text(status)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }
      }
    }
    .padding(14)
    .background(AppTheme.panel)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 1))
  }

  private func send() {
    status = store.sendContactAgentMessage(contactID: contact.id, text: draft, modelTier: modelTier)
    draft = ""
  }

  private func run(_ action: String) {
    status = store.runContactQuickAction(contactID: contact.id, action: action, modelTier: modelTier)
    if action == "chrome-research" {
      status = [status, openChromeResearchTarget().message]
        .map(\.trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }
  }

  private func openChromeResearchTarget() -> ExternalOpenResult {
    ExternalURL.openWebURLInChrome(contact.linkedInURL, label: "LinkedIn profile")
  }
}

private struct ContactAgentAction: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
  }
}

private struct ContactAgentMessageRow: View {
  let message: HermesChatMessage

  private var isUser: Bool {
    message.role.lowercased() == "user"
  }

  private var visibleTraces: [HermesTraceStep] {
    message.traces.filter { trace in
      !["reasoning"].contains(trace.toolName.trimmed.lowercased())
    }
  }

  var body: some View {
    HStack(alignment: .top) {
      if isUser {
        Spacer(minLength: 36)
      }
      VStack(alignment: .leading, spacing: 6) {
        if !isUser && !visibleTraces.isEmpty {
          ContactCompactTraceDisclosure(traces: visibleTraces)
        }
        Text(message.text)
          .font(.body)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isUser ? Color.accentColor.opacity(0.10) : Color(nsColor: .textBackgroundColor))
      .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
      if !isUser {
        Spacer(minLength: 36)
      }
    }
  }
}

private struct ContactCompactTraceDisclosure: View {
  let traces: [HermesTraceStep]
  @State private var expanded = false

  private var summary: String {
    traces.first(where: { $0.toolName.trimmed.lowercased() != "reasoning" })?.label
      ?? traces.first?.label
      ?? "Details"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Button {
        expanded.toggle()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.caption.weight(.semibold))
          Text(summary)
            .font(.caption.weight(.semibold))
          Spacer()
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if expanded {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(traces) { trace in
            ContactTraceRow(trace: trace)
          }
        }
      }
    }
  }
}

private struct ContactTraceRow: View {
  let trace: HermesTraceStep

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(trace.label)
          .font(.caption.weight(.semibold))
        if trace.status != "complete" {
          Text(trace.status)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      Text(trace.detail.trimmed.isEmpty ? "Completed." : trace.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }
    .padding(.vertical, 3)
  }
}

struct AgentManagerPanel: View {
  let title: String
  let runs: [ResearchAgentRun]
  var actionTitle: String? = nil
  var actionSystemImage = "sparkles"
  var action: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "rectangle.stack.badge.play")
        Text(title.uppercased())
          .font(.caption.weight(.bold))
        Spacer()
        if let actionTitle, let action {
          Button(action: action) {
            Label(actionTitle, systemImage: actionSystemImage)
              .labelStyle(.iconOnly)
          }
          .buttonStyle(.bordered)
          .help(actionTitle)
        }
      }
      .foregroundStyle(.secondary)

      if runs.isEmpty {
        EmptyPanel(title: "No agents", detail: "Run Enhance.")
      } else {
        VStack(spacing: 0) {
          ForEach(runs) { run in
            AgentRunRow(run: run)
            if run.id != runs.last?.id {
              Divider()
            }
          }
        }
      }
    }
    .padding(14)
    .background(AppTheme.panel)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 1))
  }
}

private struct AgentRunRow: View {
  let run: ResearchAgentRun
  @State private var isTraceOpen = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          Text(run.title)
            .font(.headline)
          Text(run.modelTier)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        TagText(text: run.status)
      }

      Button {
        isTraceOpen.toggle()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: isTraceOpen ? "chevron.down" : "chevron.right")
            .font(.caption.weight(.bold))
          Text("Trace")
            .font(.subheadline.weight(.semibold))
          Text("\(run.trace.count)")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
          Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if isTraceOpen {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(run.trace) { step in
            AgentTraceStepRow(step: step)
          }
        }
        .padding(.leading, 2)
      }
    }
    .padding(.vertical, 10)
  }
}

private struct AgentTraceStepRow: View {
  let step: ResearchAgentTraceStep

  private var kindLabel: String {
    (step.kind ?? "reasoning").localizedCaseInsensitiveContains("tool") ? "Tool" : "Reasoning"
  }

  private var toolLabel: String {
    switch (step.toolName ?? "").trimmed.lowercased() {
    case "", "reasoning":
      return ""
    case "local_state":
      return "Local state"
    case "web_search":
      return "Search plan"
    case "browser":
      return "Browser plan"
    default:
      return step.toolName ?? ""
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        TagText(text: kindLabel)
        if !toolLabel.isEmpty {
          Text(toolLabel)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
      }
      Text(step.title)
        .font(.caption.weight(.bold))
      Text(step.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 4)
  }
}
