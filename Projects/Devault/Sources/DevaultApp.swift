import AppKit
import SwiftUI
import UserNotifications

import ComposableArchitecture
import DVPresentation

@main
struct DevaultApp: App {

  /// 메인 창을 닫아도 앱을 Dock에 유지한다(창은 Dock 클릭·Window 메뉴에서 다시 연다).
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  /// 창 닫힘·백그라운드 전환을 감지해 잠근다. 뷰는 창을 닫으면 파괴되므로 App 레벨에서 본다.
  @Environment(\.scenePhase) private var scenePhase

  /// ViewBuilder 안에서 만들면 body가 재평가될 때마다 Store가 새로 생성되어 상태가 날아간다.
  private let store = Store(initialState: AppFeature.State()) {
    AppFeature()
  }

  /// 트랜잭션 감시 Task. 앱이 사는 동안 유지해야 외부 갱신·환불·가족 공유 승인을 놓치지 않는다.
  private let transactionObserver: Task<Void, Never>

  init() {
    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    // 단일 창 앱이라 창 탭이 불필요
    NSWindow.allowsAutomaticWindowTabbing = false
    // 화면이 아니라 앱 수명에 묶는다. Feature effect로 띄우면 화면이 사라질 때 리스너가 죽는다.
    transactionObserver = LiveServices.purchase.observeTransactionUpdates()
  }

  var body: some Scene {
    mainWindow
      .onChange(of: scenePhase) { _, newPhase in
        // 창이 닫히거나 앱이 백그라운드로 가면 즉시 잠근다
        if newPhase == .background {
          store.send(.appDidEnterBackground)
        }
      }
  }
}

// MARK: - Scenes

extension DevaultApp {

  private var mainWindow: some Scene {
    // 단일 창: 닫아도 Dock·Window 메뉴에서 다시 연다.
    Window("DeVault", id: DevaultWindowID.main) {
      DevaultRootView(store: store)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(
      width: WindowLayoutMetrics.windowDefaultWidth,
      height: WindowLayoutMetrics.windowDefaultHeight
    )
    .commands {
      AppCommands(store: store)
    }
  }
}

// MARK: - Root View

private struct DevaultRootView: View {
  let store: StoreOf<AppFeature>

  var body: some View {
    AppView(store: store)
      // 컬럼 하한의 합에서 파생된다 (`WindowLayoutMetrics`). 컬럼 폭을 바꾸면 창도 함께 따라온다.
      .frame(
        minWidth: WindowLayoutMetrics.windowMinWidth,
        maxWidth: .infinity,
        minHeight: WindowLayoutMetrics.windowMinHeight,
        maxHeight: .infinity
      )
      .background(
        WindowCaptureBlocker(
          isEnabled: store.isWindowCaptureBlockingEnabled
        )
      )
      // nil이면 macOS 시스템 설정을 따르고, 그 외에는 앱 전체를 라이트/다크로 고정한다.
      .preferredColorScheme(store.appearance.colorScheme)
  }
}

// MARK: - App Delegate

/// 창을 닫아도 앱을 종료하지 않고 Dock에 유지한다(`Window` scene 기본 종료를 막는다).
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}
