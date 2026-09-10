// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain
import Testing

@testable import DVPresentation

@MainActor
@Suite("NotificationSettingsFeature")
struct NotificationSettingsFeatureTests {
  @Test("task는 현재 설정값과 알림 권한 상태를 읽어온다")
  func taskLoadsCurrentSettingsAndPermission() async {
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.isExpiryAlertsEnabled = { false }
      $0.notificationSettingsClient.expiryAlertDaysBefore = { [.sevenDaysBefore, .threeDaysBefore] }
      $0.notificationSettingsClient.isAuthFailureAlertEnabled = { false }
      $0.notificationSettingsClient.isClipboardAbnormalAccessAlertEnabled = { false }
      $0.notificationSettingsClient.isPermissionGranted = { false }
    }

    await store.send(.task) {
      $0.isExpiryAlertsEnabled = false
      $0.expiryAlertDaysBefore = [.sevenDaysBefore, .threeDaysBefore]
      $0.isAuthFailureAlertEnabled = false
      $0.isClipboardAbnormalAccessAlertEnabled = false
    }
    await store.receive(.permissionResponse(false)) {
      $0.isNotificationPermissionGranted = false
    }
  }

  @Test("Free 등급이면 저장된 선택은 그대로 두고 잠금 표시만 켠다")
  func taskDoesNotOverwriteExistingSelectionWhenLocked() async {
    let saved = LockIsolated<[ExpiryAlertDay]?>(nil)
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.expiryAlertDaysBefore = { ExpiryAlertDay.allCases }
      $0.notificationSettingsClient.isExpiryAlertsEnabled = { true }
      $0.notificationSettingsClient.isAuthFailureAlertEnabled = { true }
      $0.notificationSettingsClient.isClipboardAbnormalAccessAlertEnabled = { true }
      $0.notificationSettingsClient.isPermissionGranted = { true }
      $0.notificationSettingsClient.setExpiryAlertDaysBefore = { saved.setValue($0) }
      $0.entitlementClient.current = { .free }
      $0.entitlementClient.stream = { .finished }
      $0.entitlementClient.canUseMultipleExpiryAlertDays = { false }
    }

    await store.send(.task) {
      $0.expiryAlertDaysBefore = Set(ExpiryAlertDay.allCases)
      $0.isMultipleAlertDaysLocked = true
    }
    // 기본 상태가 이미 권한 허용(true)이고 stub도 true라 permissionResponse는 상태를 바꾸지 않는다.
    await store.receive(.permissionResponse(true))
    #expect(saved.value == nil)
  }

  // 등급 전환 리셋처럼 화면 밖에서 저장값이 바뀌어도, task 구독이 체크 상태를 즉시 따라오게 한다.
  @Test("저장값 스트림이 바뀌면 만료 알림 시점 체크가 갱신된다")
  func expiryAlertDaysStreamUpdatesSelection() async {
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.expiryAlertDaysBefore = { ExpiryAlertDay.allCases }
      $0.notificationSettingsClient.isExpiryAlertsEnabled = { true }
      $0.notificationSettingsClient.isAuthFailureAlertEnabled = { true }
      $0.notificationSettingsClient.isClipboardAbnormalAccessAlertEnabled = { true }
      $0.notificationSettingsClient.isPermissionGranted = { true }
      $0.notificationSettingsClient.expiryAlertDaysBeforeStream = {
        AsyncStream { continuation in
          continuation.yield([.sevenDaysBefore])
          continuation.finish()
        }
      }
      $0.entitlementClient.stream = { .finished }
    }
    store.exhaustivity = .off

    await store.send(.task)
    await store.receive(\.expiryAlertDaysChanged) {
      $0.expiryAlertDaysBefore = [.sevenDaysBefore]
    }
  }

  @Test("만료 알림 사용 토글을 저장한다")
  func expiryAlertsTogglePersists() async {
    let saved = LockIsolated<Bool?>(nil)
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.setExpiryAlertsEnabled = { saved.setValue($0) }
    }

    await store.send(.binding(.set(\.isExpiryAlertsEnabled, false))) {
      $0.isExpiryAlertsEnabled = false
    }
    #expect(saved.value == false)
  }

  @Test("만료 알림 타이밍 선택을 저장한다")
  func expiryAlertDaysBeforePersists() async {
    let saved = LockIsolated<[ExpiryAlertDay]?>(nil)
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.setExpiryAlertDaysBefore = { saved.setValue($0) }
    }

    await store.send(.didTapExpiryAlertDay(.thirtyDaysBefore)) {
      $0.expiryAlertDaysBefore = [.sevenDaysBefore, .threeDaysBefore, .expirationDay]
    }
    #expect(saved.value == [.sevenDaysBefore, .threeDaysBefore, .expirationDay])
  }

  @Test("만료 알림 재예약에 실패하면 설정 저장 결과와 재시도 안내를 표시한다")
  func expiryNotificationReschedulingFailureShowsAlert() async {
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.setExpiryAlertsEnabled = { _ in
        throw CancellationError()
      }
    }

    await store.send(.binding(.set(\.isExpiryAlertsEnabled, false))) {
      $0.isExpiryAlertsEnabled = false
    }
    await store.receive(.expiryNotificationsUpdateFailed) {
      $0.alert = AlertState {
        TextState(String.module("Couldn't update expiration alerts."))
      } actions: {
        ButtonState(role: .cancel) { TextState(String.module("OK")) }
      } message: {
        TextState(String.module("The setting was saved, but existing notifications couldn't be updated. Please try again."))
      }
    }
  }

  @Test("반복 인증 실패 알림 토글을 저장한다")
  func authFailureAlertTogglePersists() async {
    let saved = LockIsolated<Bool?>(nil)
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.setAuthFailureAlertEnabled = { saved.setValue($0) }
    }

    await store.send(.binding(.set(\.isAuthFailureAlertEnabled, false))) {
      $0.isAuthFailureAlertEnabled = false
    }
    #expect(saved.value == false)
  }

  @Test("클립보드 비정상 접근 알림 토글을 저장한다")
  func clipboardAbnormalAccessAlertTogglePersists() async {
    let saved = LockIsolated<Bool?>(nil)
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.setClipboardAbnormalAccessAlertEnabled = { saved.setValue($0) }
    }

    await store.send(.binding(.set(\.isClipboardAbnormalAccessAlertEnabled, false))) {
      $0.isClipboardAbnormalAccessAlertEnabled = false
    }
    #expect(saved.value == false)
  }

  @Test("시스템 알림 설정 열기를 요청하면 딥링크를 연다")
  func openNotificationSettingsCallsDeepLink() async {
    let opened = LockIsolated(false)
    let store = TestStore(initialState: NotificationSettingsFeature.State()) {
      NotificationSettingsFeature()
    } withDependencies: {
      $0.notificationSettingsClient.openSystemSettings = { opened.setValue(true) }
    }

    await store.send(.didTapOpenNotificationSettings)
    #expect(opened.value)
  }
}
