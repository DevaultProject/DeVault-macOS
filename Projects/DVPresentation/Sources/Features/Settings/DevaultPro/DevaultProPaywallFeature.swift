// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain

// MARK: - DevaultProPaywallFeature

@Reducer
public struct DevaultProPaywallFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    var products: [SubscriptionProduct] = []
    var selectedProductID: String?
    var isPurchasing = false
    var isRestoring = false
    var errorMessage: String?
    /// 이미 구독 중인 채로 열리면 카피와 버튼 문구가 "가입"이 아니라 "변경"이어야 한다.
    var isChangingPlan = false
    var currentProductID: String?
    var renewalProductID: String?

    var isBusy: Bool { isPurchasing || isRestoring }
    var selectedProduct: SubscriptionProduct? { products.first { $0.id == selectedProductID } }
    /// 다음 갱신에 적용될 플랜 — 예약이 있으면 예약 상품, 없으면 현재 상품.
    var effectivePlanID: String? { renewalProductID ?? currentProductID }
    /// 지금 고른 것이 다음 갱신에 적용될 플랜과 같으면 변경이 아니라 버튼을 막는다.
    var isSelectingCurrentPlan: Bool { selectedProductID != nil && selectedProductID == effectivePlanID }

    public init() {}
  }

  // MARK: - Action

  public enum Action: Equatable {

    // MARK: - View

    case task
    case didSelectProduct(String)
    case didTapSubscribe
    case didTapRestore

    // MARK: - Internal

    case statusLoaded(SubscriptionStatus)
    case productsLoaded([SubscriptionProduct])
    case productsLoadFailed
    case purchaseSucceeded
    case purchaseCancelled
    case purchasePending
    case purchaseFailed
    case restoreSucceeded
    case restoreFailed

    // MARK: - Delegate

    case delegate(Delegate)

    public enum Delegate: Equatable {
      /// 구매/복원이 끝났다(성공). 부모가 시트를 닫는다.
      case didFinish
    }
  }

  // MARK: - Dependencies

  @Dependency(\.purchaseClient) var purchaseClient

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { send in
          let status = await purchaseClient.subscriptionStatus()
          await send(.statusLoaded(status))
          do {
            let products = try await purchaseClient.products()
            await send(.productsLoaded(products))
          } catch {
            await send(.productsLoadFailed)
          }
        }

      case .statusLoaded(let status):
        state.isChangingPlan = status.entitlement == .pro
        state.currentProductID = status.productID
        state.renewalProductID = status.hasPendingPlanChange ? status.renewalProductID : nil
        return .none

      case .productsLoaded(let products):
        state.products = products
        if state.selectedProductID == nil {
          // 예약이 있으면 예약 플랜, 구독 중이면 현재 플랜, 신규면 가장 짧은 상품을 기본 선택한다.
          state.selectedProductID = state.effectivePlanID ?? products.first?.id
        }
        return .none

      case .productsLoadFailed:
        state.errorMessage = String.module("Couldn't load subscription plans. Check your connection and try again.")
        return .none

      case .didSelectProduct(let id):
        state.selectedProductID = id
        return .none

      case .didTapSubscribe:
        guard let productID = state.selectedProduct?.id else { return .none }
        state.isPurchasing = true
        state.errorMessage = nil
        return .run { send in
          do {
            let result = try await purchaseClient.purchase(productID: productID)
            switch result {
            case .success:
              await send(.purchaseSucceeded)
            case .userCancelled:
              await send(.purchaseCancelled)
            case .pending:
              await send(.purchasePending)
            }
          } catch {
            await send(.purchaseFailed)
          }
        }

      case .purchaseSucceeded:
        state.isPurchasing = false
        return .send(.delegate(.didFinish))

      case .purchaseCancelled:
        // 오류가 아니라 시트가 조용히 남아있는 경로다. 알럿을 띄우지 않는다.
        state.isPurchasing = false
        return .none

      case .purchasePending:
        state.isPurchasing = false
        state.errorMessage = String.module("Your purchase is pending approval.")
        return .none

      case .purchaseFailed:
        state.isPurchasing = false
        state.errorMessage = String.module("Purchase failed. Please try again.")
        return .none

      case .didTapRestore:
        state.isRestoring = true
        state.errorMessage = nil
        return .run { send in
          do {
            try await purchaseClient.restore()
            await send(.restoreSucceeded)
          } catch {
            await send(.restoreFailed)
          }
        }

      case .restoreSucceeded:
        state.isRestoring = false
        return .send(.delegate(.didFinish))

      case .restoreFailed:
        state.isRestoring = false
        state.errorMessage = String.module("Couldn't restore your purchase. Please try again.")
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
