import SwiftUI

struct SidebarView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var selection: AppSection
  @Binding var isCollapsed: Bool

  var body: some View {
    VStack(spacing: 0) {
      SidebarHeader(isCollapsed: $isCollapsed)

      ScrollView {
        VStack(spacing: 4) {
          ForEach(AppSection.primarySections) { section in
            SidebarNavigationButton(
              section: section,
              isSelected: selection == section,
              isCollapsed: isCollapsed
            ) {
              selection = section
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
      }

      SidebarSettingsFooter(
        selection: $selection,
        isCollapsed: isCollapsed,
        displayName: SidebarDisplayName.userName(from: store.state.profile.name)
      )
    }
    .background(AppTheme.canvas)
  }
}

enum SidebarDisplayName {
  static func userName(from rawName: String) -> String {
    let name = rawName.trimmed
    return name.isEmpty ? "Local Candidate" : name
  }
}

private struct SidebarHeader: View {
  @Binding var isCollapsed: Bool

  var body: some View {
    HStack(spacing: isCollapsed ? 0 : 8) {
      if !isCollapsed {
        Text("Jobmaxxing")
          .font(.system(size: 17, weight: .semibold))
          .lineLimit(1)
          .truncationMode(.tail)
          .layoutPriority(1)
      }

      Spacer(minLength: 0)

      SidebarUtilityIconButton(
        help: isCollapsed ? "Expand sidebar" : "Collapse sidebar",
        action: {
          isCollapsed.toggle()
        }
      ) {
        SidebarCollapseGlyph(isCollapsed: isCollapsed)
      }

      if isCollapsed {
        Spacer(minLength: 0)
      }
    }
    .foregroundStyle(Color.primary)
    .padding(.leading, isCollapsed ? 0 : 18)
    .padding(.trailing, isCollapsed ? 0 : 10)
    .frame(height: 48)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}

private struct SidebarNavigationButton: View {
  let section: AppSection
  let isSelected: Bool
  let isCollapsed: Bool
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 11) {
      Image(systemName: section.systemImage)
        .font(.system(size: 15, weight: .medium))
        .frame(width: 20)
      if !isCollapsed {
        Text(section.title)
          .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
          .lineLimit(1)
        Spacer()
      }
    }
    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
    .padding(.horizontal, 10)
    .frame(height: 34)
    .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
    .background(isHovering && !isSelected ? AppTheme.hoverFill : Color.clear)
    .modifier(SelectedRowSurface(isSelected: isSelected))
    .contentShape(RoundedRectangle(cornerRadius: 6))
    .onTapGesture(perform: action)
    .onHover { isHovering = $0 }
    .help(section.title)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(section.title)
  }
}

private struct SidebarSettingsFooter: View {
  @Binding var selection: AppSection
  let isCollapsed: Bool
  let displayName: String

  var body: some View {
    HStack(spacing: isCollapsed ? 0 : 8) {
      if isCollapsed {
        Spacer(minLength: 0)
      } else {
        Text(displayName)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(Color.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
          .layoutPriority(1)
      }

      if !isCollapsed {
        Spacer(minLength: 0)
      }

      SidebarUtilityIconButton(
        help: "Settings",
        action: {
          selection = .settings
        }
      ) {
        Image(systemName: "gearshape")
          .symbolRenderingMode(.monochrome)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color.secondary)
      }

      if isCollapsed {
        Spacer(minLength: 0)
      }
    }
    .padding(.leading, isCollapsed ? 0 : 18)
    .padding(.trailing, isCollapsed ? 0 : 10)
    .frame(height: 55)
    .background(AppTheme.canvas)
    .overlay(alignment: .top) {
      Divider()
    }
  }
}

private struct SidebarUtilityIconButton<Icon: View>: View {
  let help: String
  let action: () -> Void
  let icon: () -> Icon
  @State private var isHovering = false

  init(help: String, action: @escaping () -> Void, @ViewBuilder icon: @escaping () -> Icon) {
    self.help = help
    self.action = action
    self.icon = icon
  }

  var body: some View {
    icon()
      .frame(width: 28, height: 28)
      .background(isHovering ? AppTheme.hoverFill : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .contentShape(RoundedRectangle(cornerRadius: 6))
      .onTapGesture(perform: action)
    .onHover { isHovering = $0 }
    .help(help)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(help)
  }
}

private struct SidebarCollapseGlyph: View {
  let isCollapsed: Bool

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 3)
        .stroke(Color.secondary, lineWidth: 1.5)
        .frame(width: 18, height: 15)

      HStack(spacing: 0) {
        if isCollapsed {
          Spacer(minLength: 0)
        }

        Rectangle()
          .fill(Color.secondary.opacity(0.85))
          .frame(width: 4, height: 11)

        if !isCollapsed {
          Spacer(minLength: 0)
        }
      }
      .frame(width: 14, height: 11)
    }
  }
}
