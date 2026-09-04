// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign

// MARK: - OnboardingView

public struct OnboardingView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<OnboardingFeature>

  // MARK: - Init

  public init(store: StoreOf<OnboardingFeature>) {
    self.store = store
  }

  // MARK: - Body

  public var body: some View {
    content
      .dvScreenBackground()
      .alert($store.scope(state: \.alert, action: \.alert))
      .sheet(item: $store.scope(state: \.paywall, action: \.paywall)) { paywallStore in
        DevaultProPaywallView(store: paywallStore)
      }
  }
}

// MARK: - Subviews

extension OnboardingView {

  private var content: some View {
    stepContent
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var stepContent: some View {
    switch store.step {
    case .welcome:    welcomeView
    case .security:   securityView
    case .icloudSync:  icloudSyncView
    case .syncEnabled: syncEnabledView
    }
  }

  // MARK: 1.0 Welcome

  private var welcomeView: some View {
    VStack(spacing: 40) {
      appIconWithLogoView
      DVButton(titleText: String.module("Start"), style: .primary) {
        store.send(.didTapStart)
      }
    }
  }

  // MARK: 1.1 Security

  private var securityView: some View {
    VStack(spacing: 56) {
      appIconWithTextView(String.module("Your secrets are protected with Touch ID."))
      VStack(spacing: 12) {
        DVButton(titleText: String.module("Enable Touch ID"), style: .primary) {
          store.send(.didTapEnableTouchID)
        }
        Text(.module("If Touch ID is unavailable,\nsystem password will be used."))
          .dvFont(.captionMDRegular)
          .foregroundStyle(Color.dv(.gray900))
          .multilineTextAlignment(.center)
      }
    }
  }

  // MARK: 1.2 iCloud Sync

  private var icloudSyncView: some View {
    VStack(spacing: 20) {
      appIconWithTextView(String.module("Sync your secrets with iCloud?"))
      Text(.module("Access your secrets on all your\nApple devices, securely encrypted."))
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray900))
        .multilineTextAlignment(.center)
        .padding(.bottom, 12)
      VStack(spacing: 15) {
        HStack(spacing: 16) {
          DVButton(titleText: String.module("Not Now"), style: .primarySmall) {
            store.send(.didTapNotNow)
          }
          DVButton(titleText: String.module("Enable Sync"), style: .primarySmall) {
            store.send(.didTapEnableSync)
          }
        }
        .disabled(store.isEnablingSync)
        Text(.module("You can change this anytime in Settings."))
          .dvFont(.captionMDRegular)
          .foregroundStyle(Color.dv(.gray600))
      }
    }
  }

  // MARK: 1.3 Sync Enabled

  private var syncEnabledView: some View {
    VStack(spacing: 20) {
      Image(systemName: "checkmark.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 64)
        .foregroundStyle(Color.dv(.vaultGreen))
        .accessibilityHidden(true)
      Text(.module("iCloud Sync Enabled!"))
        .dvFont(.headingXL)
        .foregroundStyle(Color.dv(.gray900))
      Text(.module("Your secrets will sync automatically when a connection is available."))
        .dvFont(.captionMDRegular)
        .foregroundStyle(Color.dv(.gray600))
        .multilineTextAlignment(.center)
    }
  }

  // MARK: Shared

  private var appIcon: some View {
    Image.dv(.appIcon)
      .resizable()
      .scaledToFit()
      .frame(width: 80)
      .accessibilityHidden(true)
  }

  private var appIconWithLogoView: some View {
    VStack(spacing: 20) {
      appIcon
      (
        Text("De").foregroundStyle(Color.dv(.vaultDark))
        +
        Text("Vault").foregroundStyle(Color.dv(.vaultGreen))
      )
      .font(.dv(.displayBrand))
    }
  }

  private func appIconWithTextView(_ title: String) -> some View {
    VStack(spacing: 20) {
      appIcon
      Text(title)
        .dvFont(.headingXL)
        .foregroundStyle(Color.dv(.gray900))
    }
  }
}

// MARK: - Preview

#if DEBUG

#Preview("Welcome") {
  OnboardingView(
    store: Store(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }
  )
  .frame(width: 540, height: 400)
}

#Preview("Security") {
  OnboardingView(
    store: Store(
      initialState: OnboardingFeature.State(step: .security)
    ) {
      OnboardingFeature()
    }
  )
  .frame(width: 540, height: 400)
}

#Preview("iCloud Sync") {
  OnboardingView(
    store: Store(
      initialState: OnboardingFeature.State(step: .icloudSync)
    ) {
      OnboardingFeature()
    }
  )
  .frame(width: 540, height: 400)
}

#Preview("Sync Enabled") {
  OnboardingView(
    store: Store(
      initialState: OnboardingFeature.State(step: .syncEnabled)
    ) {
      OnboardingFeature()
    }
  )
  .frame(width: 540, height: 400)
}

#endif
