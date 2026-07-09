import SwiftUI

struct SidebarView: View {
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

      SidebarSettingsFooter(selection: $selection, isCollapsed: isCollapsed)
    }
    .background(AppTheme.canvas)
  }
}

private struct SidebarHeader: View {
  @Binding var isCollapsed: Bool

  var body: some View {
    HStack(spacing: 8) {
      if !isCollapsed {
        Text("Jobmaxxing")
          .font(.system(size: 17, weight: .semibold))
          .lineLimit(1)
          .truncationMode(.tail)
          .layoutPriority(1)
      }

      Spacer(minLength: 0)

      Button {
        isCollapsed.toggle()
      } label: {
        Image(systemName: isCollapsed ? "sidebar.left" : "sidebar.leading")
          .font(.system(size: 15, weight: .semibold))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .help(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
      .contentShape(RoundedRectangle(cornerRadius: 6))
    }
    .foregroundStyle(Color.primary)
    .padding(.leading, isCollapsed ? 10 : 18)
    .padding(.trailing, 10)
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
    Button(action: action) {
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
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .help(section.title)
  }
}

private struct SidebarSettingsFooter: View {
  @Binding var selection: AppSection
  let isCollapsed: Bool
  @State private var isHovering = false

  var body: some View {
    Button {
      selection = .settings
    } label: {
      HStack(spacing: 11) {
        Image(systemName: selection == .settings ? "gearshape.fill" : "gearshape")
          .font(.system(size: 16, weight: .semibold))
          .frame(width: 20)
        if !isCollapsed {
          Text("Settings")
            .font(.system(size: 15, weight: selection == .settings ? .semibold : .medium))
            .lineLimit(1)
          Spacer(minLength: 0)
        }
      }
      .foregroundStyle(selection == .settings ? Color.primary : Color.secondary)
      .padding(.horizontal, 10)
      .frame(height: 34)
      .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
      .background(isHovering && selection != .settings ? AppTheme.hoverFill : Color.clear)
      .modifier(SelectedRowSurface(isSelected: selection == .settings))
      .contentShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .help("Settings")
    .padding(.horizontal, 10)
    .padding(.vertical, 10)
    .frame(height: 55)
    .background(AppTheme.canvas)
    .overlay(alignment: .top) {
      Divider()
    }
  }
}
