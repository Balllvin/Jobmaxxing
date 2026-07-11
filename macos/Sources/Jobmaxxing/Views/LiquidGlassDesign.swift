import AppKit
import SwiftUI

enum AppTheme {
  static let canvas = adaptive(
    light: NSColor(calibratedRed: 0.965, green: 0.948, blue: 0.918, alpha: 1),
    dark: NSColor(calibratedRed: 0.105, green: 0.098, blue: 0.088, alpha: 1)
  )
  static let canvasDepth = adaptive(
    light: NSColor(calibratedRed: 0.925, green: 0.898, blue: 0.856, alpha: 1),
    dark: NSColor(calibratedRed: 0.145, green: 0.132, blue: 0.116, alpha: 1)
  )
  static let primaryText = Color.primary
  static let secondaryText = Color.secondary
  static let accent = adaptive(
    light: NSColor(calibratedRed: 0.49, green: 0.38, blue: 0.27, alpha: 1),
    dark: NSColor(calibratedRed: 0.76, green: 0.65, blue: 0.51, alpha: 1)
  )
  static let accentForeground = adaptive(
    light: NSColor(calibratedWhite: 0.98, alpha: 1),
    dark: NSColor(calibratedWhite: 0.10, alpha: 1)
  )
  static let glassSurface = adaptive(
    light: NSColor(calibratedRed: 0.995, green: 0.985, blue: 0.965, alpha: 0.58),
    dark: NSColor(calibratedRed: 0.20, green: 0.185, blue: 0.16, alpha: 0.58)
  )
  static let strongGlassSurface = adaptive(
    light: NSColor(calibratedRed: 0.995, green: 0.985, blue: 0.965, alpha: 0.88),
    dark: NSColor(calibratedRed: 0.20, green: 0.185, blue: 0.16, alpha: 0.88)
  )
  static let opaqueSurface = adaptive(
    light: NSColor(calibratedRed: 0.985, green: 0.972, blue: 0.945, alpha: 1),
    dark: NSColor(calibratedRed: 0.17, green: 0.158, blue: 0.14, alpha: 1)
  )
  static let opaqueStrongSurface = adaptive(
    light: NSColor(calibratedRed: 0.972, green: 0.956, blue: 0.925, alpha: 1),
    dark: NSColor(calibratedRed: 0.135, green: 0.125, blue: 0.11, alpha: 1)
  )
  static let panel = strongGlassSurface
  static let border = adaptive(
    light: NSColor(calibratedWhite: 0.31, alpha: 0.16),
    dark: NSColor(calibratedWhite: 0.90, alpha: 0.16)
  )
  static let refractiveBorder = adaptive(
    light: NSColor(calibratedWhite: 1, alpha: 0.72),
    dark: NSColor(calibratedWhite: 1, alpha: 0.20)
  )
  static let glassShadow = adaptive(
    light: NSColor(calibratedRed: 0.24, green: 0.18, blue: 0.12, alpha: 0.14),
    dark: NSColor(calibratedRed: 0.03, green: 0.025, blue: 0.02, alpha: 0.34)
  )
  static let selectedFill = accent.opacity(0.12)
  static let selectedStroke = accent.opacity(0.30)
  static let hoverFill = accent.opacity(0.075)
  static let focusRing = accent

  static let glassBlurRadius: CGFloat = 18
  static let radiusSmall: CGFloat = 8
  static let radiusMedium: CGFloat = 12
  static let radiusLarge: CGFloat = 18
  static let spacingSmall: CGFloat = 8
  static let spacingMedium: CGFloat = 12
  static let spacingLarge: CGFloat = 18
  static let focusRingWidth: CGFloat = 2
  static let motionFast = 0.12
  static let motionStandard = 0.20

  private static func adaptive(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    })
  }
}

enum LiquidGlassSurfaceKind {
  case regular
  case strong

  fileprivate var fallbackMaterial: Material {
    switch self {
    case .regular: .regular
    case .strong: .thick
    }
  }

  fileprivate var opaqueFallback: Color {
    switch self {
    case .regular: AppTheme.opaqueSurface
    case .strong: AppTheme.opaqueStrongSurface
    }
  }

  fileprivate var tint: Color {
    switch self {
    case .regular: AppTheme.glassSurface
    case .strong: AppTheme.strongGlassSurface
    }
  }
}

struct LiquidGlassContainer<Content: View>: View {
  let spacing: CGFloat?
  private let content: Content

  init(spacing: CGFloat? = AppTheme.spacingSmall, @ViewBuilder content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }

  @ViewBuilder
  var body: some View {
    if #available(macOS 26.0, *) {
      GlassEffectContainer(spacing: spacing) {
        content
      }
    } else {
      content
    }
  }
}

struct AppBackdrop: View {
  var body: some View {
    LinearGradient(
      colors: [AppTheme.canvas, AppTheme.canvasDepth.opacity(0.72)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

struct SelectedRowSurface: ViewModifier {
  let isSelected: Bool
  var cornerRadius: CGFloat = AppTheme.radiusSmall

  func body(content: Content) -> some View {
    content
      .background(isSelected ? AppTheme.selectedFill : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(isSelected ? AppTheme.selectedStroke : Color.clear, lineWidth: 1)
      )
  }
}

private struct LiquidGlassSurfaceModifier: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  let kind: LiquidGlassSurfaceKind
  let cornerRadius: CGFloat
  let isInteractive: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    if reduceTransparency {
      content
        .background(kind.opaqueFallback, in: shape)
        .liquidGlassEdge(shape: shape)
    } else if #available(macOS 26.0, *) {
      let baseGlass = Glass.regular.tint(kind.tint)
      content
        .glassEffect(isInteractive ? baseGlass.interactive() : baseGlass, in: shape)
        .liquidGlassEdge(shape: shape)
    } else {
      content
        .background(kind.fallbackMaterial, in: shape)
        .liquidGlassEdge(shape: shape)
    }
  }
}

struct LiquidPressButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    LiquidPressButtonBody(
      configuration: configuration,
      reduceMotion: reduceMotion,
      isEnabled: isEnabled
    )
  }
}

private struct LiquidPressButtonBody: View {
  let configuration: ButtonStyle.Configuration
  let reduceMotion: Bool
  let isEnabled: Bool

  @State private var isHovering = false

  var body: some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .opacity(buttonOpacity)
      .focusEffectDisabled(false)
      .animation(
        reduceMotion ? nil : .easeOut(duration: AppTheme.motionFast),
        value: configuration.isPressed
      )
      .animation(
        reduceMotion ? nil : .easeOut(duration: AppTheme.motionFast),
        value: isHovering
      )
      .onHover { hovering in
        isHovering = hovering
      }
  }

  private var buttonOpacity: Double {
    guard isEnabled else { return 0.46 }
    if configuration.isPressed { return 0.82 }
    return isHovering ? 0.88 : 1
  }
}

extension View {
  func liquidGlassSurface(
    _ kind: LiquidGlassSurfaceKind = .regular,
    cornerRadius: CGFloat = AppTheme.radiusMedium,
    isInteractive: Bool = false
  ) -> some View {
    modifier(
      LiquidGlassSurfaceModifier(
        kind: kind,
        cornerRadius: cornerRadius,
        isInteractive: isInteractive
      )
    )
  }

  fileprivate func liquidGlassEdge<S: InsettableShape>(shape: S) -> some View {
    overlay(
      shape.strokeBorder(
        LinearGradient(
          colors: [AppTheme.refractiveBorder, AppTheme.border],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      )
    )
    .shadow(color: AppTheme.glassShadow, radius: 16, x: 0, y: 8)
  }
}
