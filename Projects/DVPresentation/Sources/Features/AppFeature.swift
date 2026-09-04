// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture

// MARK: - AppFeature

@Reducer
public struct AppFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    // 세 프로퍼티 중 항상 하나만 non-nil — reducer 로직으로 불변식 보장
    var onboarding: OnboardingContainerFeature.State?
    var locked: LockFeature.State?
    var main: MainFeature.State?
    public var isWindowCaptureBlockingEnabled = true
    public var appearance: AppAppearance = .system

    /// 지금 어느 화면인지. 전환 애니메이션이 이 값 하나를 본다.
    /// 셋을 다 비웠다가 하나를 세우는 구간이 있어(`task`) 옵셔널이다.
    var screen: Screen? {
      if onboarding != nil { return .onboarding }
      if locked != nil { return .locked }
      if main != nil { return .main }
      return nil
    }

    enum Screen: Equatable {
      case onboarding
      case locked
      case main
    }

    public init() {}
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case task
    case inactivityTimeoutReached

    // MARK: - Internal

    case windowCaptureBlockingChanged(Bool)
    case appearanceChanged(AppAppearance)
    case iCloudRemoteChangeDetected
    case iCloudRemoteChangeHandled
    case entitlementChanged
    case entitlementSettledAtLaunch(isFree: Bool)

    // MARK: - Child

    case onboarding(OnboardingContainerFeature.Action)
    case locked(LockFeature.Action)
    case main(MainFeature.Action)

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {}
  }

  // MARK: - Dependencies

  @Dependency(\.appLaunchClient) var appLaunchClient
  @Dependency(\.appSecurityClient) var appSecurityClient
  @Dependency(\.windowCaptureBlockerClient) var windowCaptureBlockerClient
  @Dependency(\.generalSettingsClient) var generalSettingsClient
  @Dependency(\.entitlementClient) var entitlementClient
  @Dependency(\.continuousClock) var clock
  @Dependency(\.date.now) var now

  // MARK: - Init

  public init() {}

  // MARK: - Cancellation

  private enum CancelID {
    case inactivityWatch
    case windowCaptureSettingsWatch
    case appearanceWatch
    case iCloudRemoteChangeWatch
    case iCloudRemoteChangeHandling
    case entitlementWatch
  }

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        state.onboarding = nil
        state.locked = nil
        state.main = nil

        let hasCompletedOnboarding = appLaunchClient.hasCompletedOnboarding()
        if hasCompletedOnboarding {
          state.locked = appSecurityClient.isRequireAuthOnLaunchEnabled() ? .init() : nil
          if state.locked == nil {
            state.main = .init()
          }
        } else {
          state.onboarding = .init()
        }

        // 온보딩에서 iCloud 사용 여부를 고르기 전에는 저장소를 지연 초기화한다.
        return .merge(
          .run { _ in
            _ = await appLaunchClient.requestNotificationAuthorization()
          },
          hasCompletedOnboarding
            ? .run { _ in await appLaunchClient.syncExpiryNotifications() }
            : .none,
          state.main != nil ? inactivityWatchEffect() : .none,
          windowCaptureSettingsWatchEffect(),
          appearanceWatchEffect(),
          iCloudRemoteChangeWatchEffect(),
          entitlementWatchEffect()
        )

      case let .windowCaptureBlockingChanged(isEnabled):
        state.isWindowCaptureBlockingEnabled = isEnabled
        return .none

      case let .appearanceChanged(appearance):
        state.appearance = appearance
        return .none

      case .iCloudRemoteChangeDetected:
        let detectedAt = now
        return .run { send in
          do {
            try await clock.sleep(for: .seconds(1))
          } catch {
            return
          }
          appLaunchClient.setICloudLastUpdateDetectedAt(detectedAt)
          await appLaunchClient.syncExpiryNotifications()
          await send(.iCloudRemoteChangeHandled)
        }
        .cancellable(id: CancelID.iCloudRemoteChangeHandling, cancelInFlight: true)

      case .entitlementChanged:
        // 등급이 바뀌면 만료 알림 시점 한도가 달라진다. 예약은 저장된 선택이 아니라 등급을 함께 보고 계산되므로, 다시 예약해야 강등 뒤에도 무료 한도가 지켜진다.
        return .merge(
          .run { _ in await appLaunchClient.syncExpiryNotifications() },
          // iCloud 동기화는 Pro 전용이라, free로 내려가면 자동으로 끈다(로컬 데이터는 유지, 미러링만 중단).
          entitlementClient.current() == .free
            ? .run { _ in await appLaunchClient.disableICloudSyncForDowngrade() }
            : .none
        )

      case let .entitlementSettledAtLaunch(isFree):
        // 앱 꺼진 사이 만료돼 free로 시작하면 여기서 동기화를 끈다(bootstrap이 stale .pro로 켜뒀어도 정리). Pro면 무시.
        guard isFree else { return .none }
        return .run { _ in await appLaunchClient.disableICloudSyncForDowngrade() }

      case .iCloudRemoteChangeHandled:
        guard state.main != nil else { return .none }
        return .send(.main(.iCloudRemoteChangeDetected))

      case .onboarding(.delegate(.completed)):
        state.onboarding = nil
        state.main = .init()
        return .merge(
          .run { _ in appLaunchClient.setOnboardingCompleted() },
          .run { _ in await appLaunchClient.syncExpiryNotifications() },
          inactivityWatchEffect()
        )

      case .onboarding:
        return .none

      case .locked(.delegate(.unlockCompleted)):
        state.locked = nil
        state.main = .init()
        return inactivityWatchEffect()

      case .locked:
        return .none

      case .main(.delegate(.lockRequested)):
        state.main = nil
        state.locked = .init()
        return .cancel(id: CancelID.inactivityWatch)

      case .inactivityTimeoutReached:
        guard state.main != nil else { return .none }
        state.main = nil
        state.locked = .init()
        return .cancel(id: CancelID.inactivityWatch)

      case .main:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.onboarding, action: \.onboarding) {
      OnboardingContainerFeature()
    }
    .ifLet(\.locked, action: \.locked) {
      LockFeature()
    }
    .ifLet(\.main, action: \.main) {
      MainFeature()
    }
  }
}

// MARK: - Private

private extension AppFeature {
  /// Main 세션마다 앱 상호작용 감시를 새로 시작한다. 타임아웃 계산은 UseCase가 담당하며,
  /// 이 Effect는 타임아웃을 AppFeature의 잠금 Action으로 변환한다.
  func inactivityWatchEffect() -> Effect<Action> {
    .run { send in
      for await _ in appSecurityClient.inactivityTimeoutStream() {
        await send(.inactivityTimeoutReached)
      }
    }
    .cancellable(id: CancelID.inactivityWatch, cancelInFlight: true)
  }

  func windowCaptureSettingsWatchEffect() -> Effect<Action> {
    .run { send in
      for await isEnabled in windowCaptureBlockerClient.enabledStream() {
        await send(.windowCaptureBlockingChanged(isEnabled))
      }
    }
    .cancellable(id: CancelID.windowCaptureSettingsWatch, cancelInFlight: true)
  }

  func appearanceWatchEffect() -> Effect<Action> {
    .run { send in
      for await rawValue in generalSettingsClient.appearanceStream() {
        await send(.appearanceChanged(AppAppearance(rawValue: rawValue) ?? .system))
      }
    }
    .cancellable(id: CancelID.appearanceWatch, cancelInFlight: true)
  }

  /// 등급 변경을 감시한다. 스트림이 구독 즉시 현재 등급을 한 번 내보내므로 첫 방출은 건너뛴다 — 앱 시작 동기화와 겹친다.
  func entitlementWatchEffect() -> Effect<Action> {
    .run { send in
      var isFirst = true
      for await entitlement in entitlementClient.stream() {
        if isFirst {
          isFirst = false
          // 첫 방출은 알림 재동기화(.task가 이미 함)는 건너뛰되, 이미 free면 동기화 종료는 처리한다.
          await send(.entitlementSettledAtLaunch(isFree: entitlement == .free))
        } else {
          await send(.entitlementChanged)
        }
      }
    }
    .cancellable(id: CancelID.entitlementWatch, cancelInFlight: true)
  }

  func iCloudRemoteChangeWatchEffect() -> Effect<Action> {
    .run { send in
      for await _ in appLaunchClient.iCloudRemoteChangeStream() {
        await send(.iCloudRemoteChangeDetected)
      }
    }
    .cancellable(id: CancelID.iCloudRemoteChangeWatch, cancelInFlight: true)
  }
}
