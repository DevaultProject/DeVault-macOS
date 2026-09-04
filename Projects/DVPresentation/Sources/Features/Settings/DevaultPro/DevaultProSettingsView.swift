// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign
import DVDomain

/// 구독 상태 업셀/관리 화면. 등급과 갱신 정보는 `DevaultProSettingsFeature`가 `PurchaseClient`로 StoreKit에서 읽어 온다.
struct DevaultProSettingsView: View {

  @Bindable var store: StoreOf<DevaultProSettingsFeature>

  /// 카운트를 아직 못 읽어 온 동안은(로딩 중) 가짜 숫자로 오해하지 않도록 사용량 표시 자체를 비워 둔다.
  private var usage: (used: Int, limit: Int)? {
    guard let count = store.secretCount else { return nil }
    return (count, EntitlementLimits.maxSecrets)
  }

  var body: some View {
    content
      .sheet(item: $store.scope(state: \.paywall, action: \.paywall)) { paywallStore in
        DevaultProPaywallView(store: paywallStore)
      }
      .task { await store.send(.task).finish() }
  }
}

// MARK: - Subviews

extension DevaultProSettingsView {

  private var content: some View {
    SettingsDetailContainer(title: "DeVault Pro") {
      SettingsSection(title: .module("Current Plan")) {
        currentPlanRow
      }

      // Pro면 이미 누리고 있는 혜택이라 "얻을 수 있는"이 아니라 "누리고 있는" 어조로 바꾼다.
      SettingsSection(title: store.isPro ? String.module("Your Pro Benefits") : String.module("What You Get with Pro")) {
        ForEach(DevaultProFeature.all) { feature in
          SettingsValueRow(
            title: feature.title,
            description: feature.description,
            systemImage: feature.systemImage,
            iconColor: Color.dv(.vaultGreen)
          )
        }
      }
    }
  }

  private var currentPlanRow: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 4) {
          // 새로고침 버튼은 플랜명과 같은 줄에 둬야 한다 — 바깥 HStack에 형제로 두면
          // 플랜명+갱신일(또는 사용량) 두 줄 전체 높이 기준으로 세로 중앙 정렬되어
          // 버튼이 두 줄 사이 어중간한 위치로 밀린다.
          HStack(spacing: 6) {
            Text(store.isPro ? (store.currentPlanName ?? SettingsCategory.devaultPro.title) : String.module("Free Plan"))
              .dvFont(.bodyLG)
              .foregroundStyle(Color.dv(.gray900))
            refreshButton
          }
          if store.isPro, let renewalDescription {
            Text(renewalDescription)
              .dvFont(.captionMDRegular)
              .foregroundStyle(Color.dv(.gray600))
          } else if let usage {
            Text(usageDescription(usage))
              .dvFont(.captionMDRegular)
              .foregroundStyle(Color.dv(.gray600))
          }
        }
        Spacer(minLength: 12)
        if store.isPro {
          HStack(spacing: 8) {
            // secondary/secondaryProminent는 같은 지오메트리를 공유해 나란히 둬도 크기가 어긋나지 않는다.
            // macOS StoreKit에는 iOS의 manageSubscriptionsSheet(isPresented:) 같은 인앱 시트가 없다 —
            // App Store의 구독 관리 페이지를 직접 연다.
            DVButton(titleText: .module("Manage Subscription"), style: .secondary) {
              store.send(.didTapManageSubscription)
            }
            DVButton(titleText: .module("Change Plan"), style: .secondaryProminent) {
              store.send(.didTapChangePlan)
            }
          }
        } else {
          DVButton(titleText: .module("Upgrade to DeVault Pro"), style: .primarySmall) {
            store.send(.didTapUpgrade)
          }
        }
      }
      if !store.isPro, let usage {
        ProgressView(value: Double(usage.used), total: Double(usage.limit))
          .tint(usageTint(usage.used))
      }
    }
    .settingsRowLayout()
  }

  /// `Transaction.updates`가 아직 반영되기 전이면 방금 결제해도 잠깐 무료로 보일 수 있다.
  /// 앱을 재시작하지 않아도 등급을 강제로 다시 물을 수 있는 탈출구.
  private var refreshButton: some View {
    Group {
      if store.isRefreshing {
        ProgressView()
          .controlSize(.small)
          .frame(width: 22, height: 22)
      } else {
        DVIconButton(
          systemName: "arrow.clockwise",
          idle: .gray500,
          hovered: .gray700,
          pressed: .gray800
        ) {
          store.send(.didTapRefresh)
        }
      }
    }
    .accessibilityLabel(String.module("Refresh subscription status"))
  }

  private func usageDescription(_ usage: (used: Int, limit: Int)) -> String {
    String(format: String.module("%lld of %lld secrets used"), usage.used, usage.limit)
  }

  /// 한도(15개)에 가까워질수록 경고 색으로 바꿔 남은 여유를 직관적으로 보여준다.
  /// 11~13개는 곧 막힌다는 걸 미리 알리고, 14~15개(수정 잠금 직전·잠김)는 위험으로 표시한다.
  private func usageTint(_ used: Int) -> Color {
    switch used {
    case ..<11: Color.dv(.vaultGreen)
    case 11...13: Color.dv(.warning)
    default: Color.dv(.danger)
    }
  }

  private var renewalDescription: String? {
    let dateText = store.subscriptionStatus.renewsAt?.formatted(date: .abbreviated, time: .omitted)
    // 변경 예약이 있으면(다음 갱신부터 다른 플랜) 그걸 우선 안내한다 — "현재는 1개월인데 3개월로 바꿨다"는 혼란을 없앤다.
    // 갱신일이 없어도(드묾) 예약 사실 자체는 알려, 예약 안내가 날짜 유무에 가려지지 않게 한다.
    if let renewalPlanName = store.renewalPlanName {
      guard let dateText else {
        return String(format: String.module("Changes to %@ at your next renewal"), renewalPlanName)
      }
      return String(format: String.module("Changes to %@ on %@"), renewalPlanName, dateText)
    }
    guard let dateText else { return nil }
    return store.subscriptionStatus.willAutoRenew
      ? String(format: String.module("Renews on %@"), dateText)
      : String(format: String.module("Expires on %@"), dateText)
  }
}

// MARK: - Preview

#Preview("Devault Pro") {
  SettingsDetailPreview {
    DevaultProSettingsView(
      store: Store(initialState: DevaultProSettingsFeature.State()) {
        DevaultProSettingsFeature()
      }
    )
  }
}
