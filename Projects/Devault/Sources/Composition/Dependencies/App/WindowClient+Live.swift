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
    }
  )
}
