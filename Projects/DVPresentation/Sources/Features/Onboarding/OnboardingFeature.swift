// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - OnboardingFeature

@Reducer
public struct OnboardingFeature {

  // MARK: - Step

  public enum Step: Equatable, CaseIterable {
    case welcome
    case security
    case icloudSync
    case syncEnabled
  }

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    public var step: Step = .welcome
    public var isEnablingSync = false
    @Presents var alert: AlertState<Action.Alert>?
    /// free 사용자가 Enable Sync를 누르면 여기로 업그레이드 시트를 띄운다. 구매를 마치면 자동으로 동기화를 켠다.
    @Presents var paywall: DevaultProPaywallFeature.State?

    public init(step: Step = .welcome) {
      self.step = step
    }

    var currentStepIndex: Int {
      switch step {
      case .welcome:     return 0
      case .security:    return 1
      case .icloudSync:  return 2
      case .syncEnabled: return 2
      }
    }
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case didTapStart
    case didTapEnableTouchID
    case didTapNotNow
    case didTapEnableSync

    // MARK: - Internal

    case touchIDAuthSucceeded
    case touchIDAuthFailed(UserAuthenticationError)
    case iCloudSyncStatusResponse(ICloudAccountStatus)
    case enableSyncCompleted
    case entitlementRechecked

    // MARK: - Child

    case alert(PresentationAction<Alert>)
    case paywall(PresentationAction<DevaultProPaywallFeature.Action>)

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      case completed
    }

    public enum Alert: Equatable {
      case retry
      case continueWithoutSync
      case openSystemSettings
    }
  }

  // MARK: - Dependencies

  @Dependency(\.onboardingClient) var onboardingClient
  @Dependency(\.entitlementClient) var entitlementClient
  @Dependency(\.purchaseClient) var purchaseClient
  @Dependency(\.continuousClock) var clock

  // MARK: - Init

  public init() {}

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .didTapStart:
        state.step = .security
        return .none

      case .didTapEnableTouchID:
        return .run { send in
          do {
            try await onboardingClient.enableTouchID()
            await send(.touchIDAuthSucceeded)
          } catch let error as UserAuthenticationError {
            await send(.touchIDAuthFailed(error))
          } catch {
            await send(.touchIDAuthFailed(.failed))
          }
        }

      case .touchIDAuthSucceeded:
        state.step = .icloudSync
        return .none

      case .touchIDAuthFailed(let error):
        state.alert = makeTouchIDFailedAlert(error)
        return .none

      case .didTapNotNow:
        state.isEnablingSync = true
        return continueWithoutICloudEffect()

      case .didTapEnableSync:
        state.isEnablingSync = true
        // 이미 Pro면(다른 기기 구독 포함 — 대개 실행 시 이미 반영됨) 페이월 없이 바로 켠다.
        if entitlementClient.canEnableICloudSync() {
          return enableICloudSyncEffect()
        }
        // 아직 free로 보이면 스토어에 한 번 더 물어 다른 기기 구독을 인식한 뒤 판정한다.
        return .run { send in
          await purchaseClient.refreshEntitlement()
          await send(.entitlementRechecked)
        }

      case .entitlementRechecked:
        // 재조회 후에도 Pro가 아니면 진짜 free — 페이월을 띄운다. Pro면 그대로 켠다.
        guard entitlementClient.canEnableICloudSync() else {
          state.isEnablingSync = false
          state.paywall = DevaultProPaywallFeature.State()
          return .none
        }
        return enableICloudSyncEffect()

      case .iCloudSyncStatusResponse(let status):
        guard status == .available else {
          state.isEnablingSync = false
          state.alert = makeICloudSyncFailedAlert(status)
          return .none
        }
        return .run { send in
          try? await clock.sleep(for: .seconds(0.5))
          await send(.enableSyncCompleted)
        }

      case .enableSyncCompleted:
        state.step = .syncEnabled
        return .run { send in
          try? await clock.sleep(for: .seconds(2))
          await send(.delegate(.completed))
        }

      case .paywall(.presented(.delegate(.didFinish))):
        // 구매/복원 성공 → 이제 Pro. 페이월을 닫고 자동으로 동기화를 켠다.
        state.paywall = nil
        guard entitlementClient.canEnableICloudSync() else { return .none }
        state.isEnablingSync = true
        return enableICloudSyncEffect()

      case .paywall:
        return .none

      case .alert(.presented(.retry)):
        return .send(.didTapEnableSync)

      case .alert(.presented(.continueWithoutSync)):
        state.isEnablingSync = true
        return continueWithoutICloudEffect()

      case .alert(.presented(.openSystemSettings)):
        return .run { _ in await onboardingClient.openICloudSystemSettings() }

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.$paywall, action: \.paywall) {
      DevaultProPaywallFeature()
    }
  }
}

// MARK: - Private

private extension OnboardingFeature {

  func makeTouchIDFailedAlert(_ error: UserAuthenticationError) -> AlertState<Action.Alert> {
    makeUserAuthenticationFailedAlert(title: String.module("Authentication failed"), error: error)
  }

  func makeICloudSyncFailedAlert(_ status: ICloudAccountStatus) -> AlertState<Action.Alert> {
    makeICloudSyncUnavailableAlert(
      status,
      retry: .retry,
      continueWithoutSync: .continueWithoutSync,
      openSystemSettings: .openSystemSettings
    )
  }

  /// iCloud 계정 상태를 확인하고 동기화를 켠다. Pro가 확정된 뒤에만 호출한다(계정 미가용은 응답에서 알럿으로 처리).
  func enableICloudSyncEffect() -> Effect<Action> {
    .run { send in
      do {
        let status = try await onboardingClient.enableICloudSync()
        await send(.iCloudSyncStatusResponse(status))
      } catch {
        await send(.iCloudSyncStatusResponse(.configurationUnavailable))
      }
    }
  }

  func continueWithoutICloudEffect() -> Effect<Action> {
    .run { send in
      await onboardingClient.continueWithoutICloud()
      await send(.delegate(.completed))
    }
  }
}
