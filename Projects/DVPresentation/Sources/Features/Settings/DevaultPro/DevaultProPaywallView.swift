// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign
import DVDomain

/// `DevaultProSettingsView`의 업그레이드 버튼에서 여는 시트.
///
/// 가격 문자열은 `SubscriptionProduct`가 StoreKit에서 로케일에 맞춰 이미 포맷해 온 값이다 —
/// 여기서 통화·자릿수를 다시 계산하지 않는다.
struct DevaultProPaywallView: View {

  // MARK: - Properties

  let store: StoreOf<DevaultProPaywallFeature>

  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  // MARK: - Body

  var body: some View {
    content
      .task { await store.send(.task).finish() }
  }

  /// `vaultGreenTint` 배경 위에 놓이는 아이콘·배지 글자색. 다크모드의 `vaultGreenTint`는 `vaultGreen`과 명도차가 거의 없어 흰색으로 바꿔 대비를 확보한다.
  private var accentOnTint: Color {
    colorScheme == .dark ? Color.dv(.white) : Color.dv(.vaultGreen)
  }
}

// MARK: - Subviews

extension DevaultProPaywallView {

  private var content: some View {
    VStack(spacing: 20) {
      header

      HStack(alignment: .top, spacing: 24) {
        featureList
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        planGrid
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }

      if let errorMessage = store.errorMessage {
        Text(errorMessage)
          .dvFont(.captionMDRegular)
          .foregroundStyle(Color.dv(.danger))
          .multilineTextAlignment(.center)
      }

      subscribeButton
        .padding(.top, 8)
      footer
    }
    .padding(24)
    .frame(width: 880)
  }

  /// 닫기 버튼을 별도 행으로 두면 그 줄만큼 위가 비어 보인다 — 코너에 얹어서
  /// 배지·타이틀이 시트 맨 위에서 바로 시작하게 한다.
  private var header: some View {
    VStack(spacing: 12) {
      iconBadge

      VStack(spacing: 6) {
        Text(store.isChangingPlan ? String.module("Change Your Plan") : String.module("Upgrade to DeVault Pro"))
          .dvFont(.headingLG)
          .foregroundStyle(Color.dv(.gray900))
        Text(.module("Manage your secrets more securely on every device, without the 15-item limit."))
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.gray600))
          .multilineTextAlignment(.center)
          // fixedSize가 없으면 VStack이 제안하는 높이에 맞춰 한 줄로 줄여버려 "…"로 잘린다.
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity)
    .overlay(alignment: .topTrailing) {
      DVIconButton(
        systemName: "xmark",
        idle: .gray500,
        hovered: .gray700,
        pressed: .gray800
      ) {
        dismiss()
      }
      .accessibilityLabel(String.module("Close"))
    }
  }

  private var iconBadge: some View {
    Circle()
      .fill(Color.dv(.vaultGreenTint))
      .frame(width: 56, height: 56)
      .overlay(
        Image(systemName: "crown")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(accentOnTint)
      )
  }

  /// 오른쪽 플랜 카드 열이 더 길면 이 열의 남는 높이를 행 사이 `Spacer`가 흡수해
  /// 두 열의 전체 높이가 맞아떨어지도록 한다 — 고정 spacing 값을 추측해 넣는 대신
  /// 실제 남는 만큼만 나눠 갖는다.
  private var featureList: some View {
    VStack(spacing: 0) {
      ForEach(Array(DevaultProFeature.all.enumerated()), id: \.element.id) { index, feature in
        featureRow(feature)
        if index < DevaultProFeature.all.count - 1 {
          Spacer(minLength: 12)
        }
      }
    }
  }

  private func featureRow(_ feature: DevaultProFeature) -> some View {
    HStack(spacing: 12) {
      Circle()
        .fill(Color.dv(.vaultGreenTint))
        .frame(width: 40, height: 40)
        .overlay(
          Image(systemName: feature.systemImage)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(accentOnTint)
        )
      VStack(alignment: .leading, spacing: 2) {
        Text(feature.title)
          .dvFont(.bodyLG)
          .foregroundStyle(Color.dv(.gray900))
        Text(feature.description)
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.gray600))
      }
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private var planGrid: some View {
    if store.products.isEmpty {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(spacing: 10) {
        ForEach(store.products) { product in
          planCard(product)
        }
      }
    }
  }

  private func planCard(_ product: SubscriptionProduct) -> some View {
    let isSelected = product.id == store.selectedProductID

    return DVRadioButton(isSelected: isSelected, action: { store.send(.didSelectProduct(product.id)) }) {
      HStack(alignment: .center) {
        Text(product.displayName)
          .dvFont(.bodyLG)
          .foregroundStyle(Color.dv(.gray900))
        planBadge(for: product)
        Spacer(minLength: 12)
        priceText(for: product)
          .dvFont(.bodyLG)
      }
      // DVRadioButton 내부 인디케이터-라벨 간격(3pt)이 좁아 카드 안에서는 답답해 보인다 —
      // 컴포넌트를 고치는 대신 라벨 쪽에서 여유를 더 준다.
      .padding(.leading, 4)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    // 미선택 카드는 채우지 않고 테두리만 그린다 — 회색으로 채우면 라이트/다크 어느 쪽이든
    // 밋밋하고 탁해 보인다. 선택 카드만 tint로 채워서 시선을 끈다.
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(isSelected ? Color.dv(.vaultGreenTint) : Color.clear)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(isSelected ? Color.dv(.vaultGreen) : Color.dv(.gray300), lineWidth: isSelected ? 1.5 : 1)
    )
    // DVRadioButton 자체의 탭 영역은 인디케이터+라벨에만 붙어 있어 패딩(카드 여백)을 누르면
    // 반응하지 않는다 — 카드 전체를 눌러도 선택되도록 별도로 씌운다.
    .contentShape(Rectangle())
    .onTapGesture { store.send(.didSelectProduct(product.id)) }
  }

  /// 현재 플랜과 예약된 다음 플랜을 배지로 구분한다.
  @ViewBuilder
  private func planBadge(for product: SubscriptionProduct) -> some View {
    if product.id == store.currentProductID {
      badgeLabel(String.module("Current Plan"), accent: false)
    } else if product.id == store.renewalProductID {
      badgeLabel(String.module("Next renewal"), accent: true)
    }
  }

  private func badgeLabel(_ text: String, accent: Bool) -> some View {
    Text(text)
      .dvFont(.captionMDRegular)
      .foregroundStyle(accent ? Color.dv(.white) : Color.dv(.gray600))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        Capsule().fill(accent ? Color.dv(.vaultGreen) : Color.dv(.gray200))
      )
  }

  private var subscribeButton: some View {
    DVButton(titleText: subscribeButtonTitle, style: .primary) {
      store.send(.didTapSubscribe)
    }
    .disabled(store.selectedProduct == nil || store.isBusy || store.isSelectingCurrentPlan)
    .frame(maxWidth: .infinity)
  }

  private var footer: some View {
    VStack(spacing: 8) {
      Text(footerText)
        .dvFont(.captionMDRegular)
        .foregroundStyle(Color.dv(.gray500))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 12) {
        Link(String.module("Terms of Service"), destination: HelpMenuLink.termsOfService.url)
          .underline()
        Link(String.module("Privacy Policy"), destination: HelpMenuLink.privacyPolicy.url)
          .underline()
        Button(String.module("Restore Purchase")) {
          store.send(.didTapRestore)
        }
        .buttonStyle(.plain)
        .underline()
        .disabled(store.isBusy)
      }
      .dvFont(.captionMDRegular)
      .foregroundStyle(Color.dv(.gray500))
    }
  }
}

// MARK: - Formatting

extension DevaultProPaywallView {

  /// 1개월 요금제는 `monthlyEquivalentPrice`가 없어(전체가와 같으므로) 총액만 보여준다.
  /// 총액 부분만 더 진하게 보이도록 `Text`를 이어붙인다 — 하나의 문자열로 합치면
  /// 부분별로 다른 색을 줄 수 없다.
  private func priceText(for product: SubscriptionProduct) -> Text {
    guard let monthlyEquivalentPrice = product.monthlyEquivalentPrice else {
      return Text(product.displayPrice).foregroundStyle(Color.dv(.gray600))
    }

    let monthly = Text(String(format: String.module("%@/mo"), monthlyEquivalentPrice))
      .foregroundStyle(Color.dv(.gray600))
    let total = Text(String(format: String.module("Total %@"), product.displayPrice))
      .foregroundStyle(Color.dv(.gray700))
      .fontWeight(.semibold)

    return monthly + Text(" · ").foregroundStyle(Color.dv(.gray600)) + total
  }

  private var subscribeButtonTitle: String {
    guard let selectedProduct = store.selectedProduct else {
      return store.isChangingPlan ? String.module("Change Plan") : String.module("Subscribe")
    }
    if store.isSelectingCurrentPlan {
      // 예약이 있으면 기본 선택이 예약 플랜이라, 그걸 고른 건 현재 플랜이 아니라 이미 예약된 플랜이다.
      return store.renewalProductID != nil
        ? String.module("Scheduled for Next Renewal")
        : String.module("Your Current Plan")
    }
    return store.isChangingPlan
      ? String(format: String.module("Change to %@"), selectedProduct.displayName)
      : String(format: String.module("Subscribe for %@"), selectedProduct.displayName)
  }

  private var footerText: String {
    // 플랜 변경이면 "다음 갱신부터 적용, 지금은 청구 없음"을 명확히 한다. 그 외는 일반 안내.
    if store.isChangingPlan, !store.isSelectingCurrentPlan, let selected = store.selectedProduct {
      return String(
        format: String.module("Switches to %@ at your next renewal — no charge now. Cancel anytime in Settings."),
        selected.displayName
      )
    }
    return String.module(
      "Automatically renews after the period ends. You can cancel anytime in Settings."
    )
  }
}

// MARK: - Preview

#Preview("Devault Pro Paywall") {
  DevaultProPaywallView(
    store: Store(initialState: DevaultProPaywallFeature.State()) {
      DevaultProPaywallFeature()
    }
  )
}
