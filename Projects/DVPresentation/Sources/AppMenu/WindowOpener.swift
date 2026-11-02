// Copyright © 2026 Devault. All rights reserved

import Foundation

/// `openWindow`는 SwiftUI Environment라 Commands 밖(AppDelegate·리듀서)에서 못 부른다.
/// `AppCommands`는 창 상태와 무관하게 항상 평가되므로, 거기서 매번 최신 액션을 여기에 넣어둔다.
public final class WindowOpener {
  public static let shared = WindowOpener()

  public var openMainWindow: (() -> Void)?

  private init() {}
}
