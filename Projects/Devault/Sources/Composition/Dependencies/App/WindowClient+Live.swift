// Copyright © 2026 Devault. All rights reserved

import AppKit
import ComposableArchitecture
import DVPresentation

extension WindowClient: @retroactive DependencyKey {
  public static let liveValue = WindowClient(
    ensureMainWindowOpen: {
      await MainActor.run {
        guard !NSApp.windows.contains(where: \.isVisible) else { return }
        WindowOpener.shared.openMainWindow?()
      }
    },
    isMainWindowVisible: {
      MainActor.assumeIsolated { NSApp.windows.contains(where: \.isVisible) }
    },
    activateMainWindow: {
      await MainActor.run {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: \.isVisible)?.makeKeyAndOrderFront(nil)
      }
    }
  )
}
