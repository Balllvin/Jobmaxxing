import AppKit
import SwiftUI

@main
struct JobmaxxingApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var store = JobmaxxingStore()

  var body: some Scene {
    WindowGroup("Jobmaxxing", id: "main") {
      ContentView()
        .environmentObject(store)
        .frame(minWidth: JobmaxxingWindowLayout.minimumSize.width, minHeight: JobmaxxingWindowLayout.minimumSize.height)
    }
    .commands {
      SidebarCommands()

      CommandMenu("Jobmaxxing") {
        Button("Upload Proof") {
          NotificationCenter.default.post(name: .openDocumentImporter, object: nil)
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])
      }
    }

    Settings {
      SettingsView()
        .environmentObject(store)
        .frame(minWidth: JobmaxxingWindowLayout.minimumSize.width, minHeight: JobmaxxingWindowLayout.minimumSize.height)
        .frame(idealWidth: 1040, idealHeight: 700)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var didRepairLaunchPlacement = false
  private var didClearInitialFocus = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    applyWindowSizing(repairPlacement: true)
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    // Repair placement at most once (launch may race before the window exists).
    // After that, only re-apply minSize so maximized/edge-docked windows stay put.
    applyWindowSizing(repairPlacement: !didRepairLaunchPlacement)
  }

  private func applyWindowSizing(repairPlacement: Bool) {
    DispatchQueue.main.async {
      let windows = NSApp.windows.filter { $0.isVisible }
      for window in windows {
        window.minSize = JobmaxxingWindowLayout.minimumSize
        guard repairPlacement, !self.didRepairLaunchPlacement else { continue }
        guard let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {
          continue
        }
        let repairedFrame = JobmaxxingWindowLayout.repairedFrame(
          currentFrame: window.frame,
          visibleFrame: visibleFrame
        )
        if repairedFrame != window.frame {
          window.setFrame(repairedFrame, display: true)
        }
      }
      if repairPlacement, !windows.isEmpty {
        self.didRepairLaunchPlacement = true
      }

      guard !self.didClearInitialFocus,
            let window = windows.first(where: \.isKeyWindow) ?? windows.first
      else { return }
      DispatchQueue.main.async {
        guard !self.didClearInitialFocus else { return }
        self.didClearInitialFocus = true
        window.makeFirstResponder(nil)
      }

    }
  }
}

enum JobmaxxingWindowLayout {
  static let minimumSize = NSSize(width: 820, height: 620)

  /// Restores unusable launch frames without shrinking a healthy user-sized window.
  /// Shrinks only when the frame cannot fit the visible screen. Moves only when the
  /// frame has no useful intersection with the visible area.
  static func repairedFrame(currentFrame: NSRect, visibleFrame: NSRect) -> NSRect {
    let size = repairedSize(currentSize: currentFrame.size, visibleSize: visibleFrame.size)
    var origin = currentFrame.origin
    var frame = NSRect(origin: origin, size: size)

    if needsRecentering(frame, visibleFrame: visibleFrame) {
      origin = NSPoint(
        x: visibleFrame.midX - (size.width / 2),
        y: visibleFrame.midY - (size.height / 2)
      )
      frame = NSRect(origin: origin, size: size)
    } else {
      origin.x = min(max(origin.x, visibleFrame.minX), max(visibleFrame.minX, visibleFrame.maxX - size.width))
      origin.y = min(max(origin.y, visibleFrame.minY), max(visibleFrame.minY, visibleFrame.maxY - size.height))
      frame = NSRect(origin: origin, size: size)
    }

    return frame
  }

  private static func repairedSize(currentSize: NSSize, visibleSize: NSSize) -> NSSize {
    NSSize(
      width: min(max(currentSize.width, minimumSize.width), max(minimumSize.width, visibleSize.width)),
      height: min(max(currentSize.height, minimumSize.height), max(minimumSize.height, visibleSize.height))
    )
  }

  /// True when the window is effectively off-screen (no substantial overlap).
  private static func needsRecentering(_ frame: NSRect, visibleFrame: NSRect) -> Bool {
    let overlap = frame.intersection(visibleFrame)
    guard !overlap.isNull, !overlap.isEmpty else { return true }
    // Require at least a usable title-bar-sized intersection so the window can be grabbed.
    return overlap.width < 80 || overlap.height < 40
  }
}

extension Notification.Name {
  static let openDocumentImporter = Notification.Name("JobmaxxingOpenDocumentImporter")
}
