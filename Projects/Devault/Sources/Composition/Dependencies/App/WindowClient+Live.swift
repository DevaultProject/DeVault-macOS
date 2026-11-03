// Copyright © 2026 Devault. All rights reserved

import AppKit
import ComposableArchitecture
import DVPresentation

extension WindowClient: @retroactive DependencyKey {
  public static let liveValue = WindowClient(
    ensureMainWindowOpen: {
      await MainActor.run {
        // 앱이 이미 활성 상태면 isVisible 순간 오독으로 openWindow를 또 불러 창을 재생성하지 않는다
        // — Window(id:) 재생성은 AppView.task를 다시 태워 인증 요구 시 재잠금을 유발한다.
        guard !NSApp.isActive, !NSApp.windows.contains(where: \.isVisible) else { return }
        WindowOpener.shared.openMainWindow?()
      }
    }
  )
}
