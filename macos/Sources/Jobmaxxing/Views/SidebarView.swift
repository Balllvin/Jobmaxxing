import SwiftUI

struct SidebarView: View {
  @Binding var selection: AppSection
  @FocusState private var focusedSection: AppSection?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 4) {
        ForEach(AppSection.primarySections) { section in
          Button {
            selection = section
          } label: {
            Label(section.title, systemImage: section.systemImage)
              .symbolRenderingMode(.monochrome)
              .font(.system(size: 14, weight: selection == section ? .semibold : .medium))
              .foregroundStyle(selection == section ? Color.primary : Color.secondary)
              .padding(.horizontal, 10)
              .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              .contentShape(Rectangle())
              .modifier(SelectedRowSurface(isSelected: selection == section, cornerRadius: AppTheme.radiusSmall))
          }
          .buttonStyle(LiquidPressButtonStyle())
          .focused($focusedSection, equals: section)
          .help(section.title)
          .accessibilityLabel(section.title)
          .accessibilityValue(selection == section ? "Selected" : "")
          .accessibilityAddTraits(selection == section ? .isSelected : [])
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 8)
    }
    .scrollIndicators(.hidden)
    .navigationTitle("Jobmaxxing")
    .onMoveCommand { direction in
      moveSelection(direction)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      SidebarSettingsFooter(selection: $selection)
    }
  }

  private func moveSelection(_ direction: MoveCommandDirection) {
    guard let destination = SidebarKeyboardNavigation.destination(
      from: focusedSection ?? selection,
      moving: direction
    ) else { return }
    focusedSection = destination
    selection = destination
  }
}

enum SidebarKeyboardNavigation {
  static func destination(from current: AppSection, moving direction: MoveCommandDirection) -> AppSection? {
    guard let currentIndex = AppSection.primarySections.firstIndex(of: current) else { return nil }
    switch direction {
    case .up:
      return AppSection.primarySections[max(AppSection.primarySections.startIndex, currentIndex - 1)]
    case .down:
      return AppSection.primarySections[
        min(AppSection.primarySections.index(before: AppSection.primarySections.endIndex), currentIndex + 1)
      ]
    default:
      return nil
    }
  }
}

private struct SidebarSettingsFooter: View {
  @Binding var selection: AppSection

  var body: some View {
    VStack(spacing: 0) {
      Divider()

      Button {
        selection = .settings
      } label: {
        HStack(spacing: 10) {
          Text("Settings")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)

          Spacer(minLength: 8)

          Image(systemName: "gearshape")
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(LiquidPressButtonStyle())
      .help("Settings")
      .accessibilityLabel("Settings")
    }
    .background(.bar)
  }
}
