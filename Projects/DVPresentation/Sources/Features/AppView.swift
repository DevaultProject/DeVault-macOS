// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign

// MARK: - AppView

public struct AppView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<AppFeature>

  @State private var isDropTargeted = false

  // MARK: - Init

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  // MARK: - Body

  public var body: some View {
    content
      .dvAnimation(MotionMetrics.transition, value: store.screen)
      // 진행 오버레이를 그리는 유일한 지점 (`.omc/GUIDELINES.md`).
      .windowBusyOverlay()
      // 잠금 전환 시 메인이 사라지며 남는 고아 시트·알럿을 창에서 직접 닫는다.
      .background(LockSheetDismisser(isLocked: store.locked != nil))
      .dropDestination(for: URL.self) { urls, _ in
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "dvt" }) else { return false }
        store.send(.fileOpened(url))
        return true
      } isTargeted: { isDropTargeted = $0 }
      .overlay { if isDropTargeted { DropImportOverlay() } }
      .task { store.send(.task) }
      .alert($store.scope(state: \.alert, action: \.alert))
  }
}

// MARK: - Drop Overlay

private struct DropImportOverlay: View {
  var body: some View {
    ZStack {
      Color.dv(.vaultGreenTint).opacity(0.9)
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color.dv(.vaultGreen), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        .padding(10)
      VStack(spacing: 4) {
        Text(.module("Drop a file to import"))
          .dvFont(.headingLG)
          .foregroundStyle(Color.dv(.vaultGreenDark))
        Text(.module("Drop a .devault file"))
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.vaultGreenDark))
      }
    }
    .allowsHitTesting(false)
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

// MARK: - Subviews

extension AppView {

  /// **메인은 사라질 때 애니메이션하지 않는다(`removal: .identity`).** 잠기는 순간 서서히
  /// 흐려지면 그 시간 동안 시크릿 목록이 화면에 남는다.
  @ViewBuilder
  private var content: some View {
    if let store = store.scope(state: \.onboarding, action: \.onboarding) {
      OnboardingContainerView(store: store)
        .transition(.opacity)
    } else if let store = store.scope(state: \.locked, action: \.locked) {
      LockView(store: store)
        .transition(.opacity)
    } else if let store = store.scope(state: \.main, action: \.main) {
      MainView(store: store)
        .transition(.asymmetric(insertion: .opacity, removal: .identity))
    }
  }
}

// MARK: - Preview

#if DEBUG

#Preview {
  AppView(
    store: Store(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.appLaunchClient.hasCompletedOnboarding = { false }
      $0.appLaunchClient.setOnboardingCompleted = { }
    }
  )
}

#endif
