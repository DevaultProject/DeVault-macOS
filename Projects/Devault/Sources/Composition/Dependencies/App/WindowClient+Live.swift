// Copyright © 2026 Devault. All rights reserved

import AppKit
import ComposableArchitecture
import DVPresentation

extension WindowClient: @retroactive DependencyKey {
  public static let liveValue = WindowClient(
    ensureMainWindowOpen: {
      await MainActor.run {
        guard !hasVisibleWindow() else { return }
        WindowOpener.shared.openMainWindow?()
      }
    },
    isMainWindowVisible: {
      MainActor.assumeIsolated { hasVisibleWindow() }
    },
    activateMainWindow: {
      await MainActor.run {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: \.isVisible)?.makeKeyAndOrderFront(nil)
      }
    }
  )
}

@MainActor
private func hasVisibleWindow() -> Bool {
  NSApp.windows.contains(where: \.isVisible)
}
