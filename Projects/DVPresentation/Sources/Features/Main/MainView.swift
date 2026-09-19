// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign

// MARK: - MainView

struct MainView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<MainFeature>

  /// 생성 오버레이의 왼쪽 인셋. 사이드바 컬럼 폭 상수를 쓰지 않는 이유는 AppKit이 사이드바 영역을 컬럼 폭보다 몇 pt 넓게 잡아서다(250 지정에 실측 258) — 목록 컬럼의 실측 왼쪽 끝을 따라가면 그 오프셋이 기기마다 달라도 맞고, 사이드바를 토글로 접으면 0 근처로 내려가 오버레이가 전체 폭을 덮는다.
  @State private var creatingOverlayInset: CGFloat = WindowLayoutMetrics.sidebarWidth

  /// ``creatingOverlayInset`` 실측에 쓰는 좌표계 이름. `NavigationSplitView`에 붙는다.
  private static let splitCoordinateSpaceName = "MainSplit"

  // MARK: - Body

  var body: some View {
    content
      // `screen`으로 좁히지 않으면 목록·상세가 바뀔 때마다 화면 전체가 다시 페이드된다.
      .dvAnimation(MotionMetrics.transition, value: store.screen)
      .dvScreenBackground()
      .task { store.send(.task) }
      .sheet(
        item: $store.scope(state: \.createProject, action: \.createProject)
      ) { createProjectStore in
        CreateProjectView(store: createProjectStore)
      }
      .toolbar {
        ToolbarItemGroup(placement: .primaryAction) {
          Spacer()
          lockButton
        }
      }
      .sheet(
        item: $store.scope(state: \.paywall, action: \.paywall)
      ) { paywallStore in
        DevaultProPaywallView(store: paywallStore)
      }
  }
}

// MARK: - Subviews

extension MainView {
    
  /// **`NavigationSplitView`는 하나뿐이다.** 생성 화면은 브라우즈 3컬럼을 그대로 둔 채 사이드바 오른쪽을 오버레이로 덮어 2컬럼처럼 보이게 한다.
  ///
  /// 컬럼 수가 다른 두 `NavigationSplitView`는 타입이 달라 `if/else`로 교체하면 서브트리가 통째로 새로 만들어진다 — 사이드바까지 재생성되어 토글 버튼이 튀고 `.task`가 재실행돼 목록이 깜빡였다.
  ///
  /// 가운데 컬럼을 폭 0으로 접는 방식은 쓰지 않는다. 일부 macOS에서 브리지가 콘텐츠 컬럼 가이드에 이름 없는 required `width >= 200`을 걸어 두어, 접힘 클램프(`NSSplitViewItem.MaxSize <= 0`)와 required끼리 충돌하고 어느 쪽이 깨질지가 기기마다 달라 200pt 잔폭이 남는다.
  @ViewBuilder
  private var content: some View {
    switch store.screen {
    case .settings:
      if let settingsStore = store.scope(state: \.settings, action: \.settings) {
        SettingsView(store: settingsStore)
          .transition(.opacity)
      }

    case .browsing, .creating:
      NavigationSplitView {
        sidebarColumn
      } content: {
        contentColumn
      } detail: {
        detailColumn
      }
      .navigationSplitViewStyle(.balanced)
      .toolbarBackground(.hidden, for: .windowToolbar)
      .coordinateSpace(name: Self.splitCoordinateSpaceName)
      .overlay { creatingOverlay }
      .transition(.opacity)
    }
  }

  @ViewBuilder
  private var creatingOverlay: some View {
    if store.screen == .creating {
      HStack(spacing: 0) {
        // Spacer는 히트 테스트를 받지 않아 밑의 사이드바가 그대로 조작된다.
        Spacer()
          .frame(width: creatingOverlayInset)
        creatingArea
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          // 왼쪽 모서리만 둥글린다 — 컬럼이 카드처럼 그려지는 macOS에서 직각 평면 오버레이가 이질적으로 보여서다. 배경만 안전 영역을 넘겨 툴바 아래까지 채우고, 콘텐츠는 안전 영역 안에 남긴다.
          .background {
            let shape = UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12)
            shape
              .fill(Color.dv(.gray100))
              // 사이드바가 옆 컬럼에 드리우는 그림자를 재현한다 — 브라우즈 화면 실측으로 경계에서 검정 ~5%가 36pt에 걸쳐 사라진다.
              .overlay(alignment: .leading) {
                LinearGradient(
                  colors: [.black.opacity(0.05), .clear],
                  startPoint: .leading,
                  endPoint: .trailing
                )
                .frame(width: 36)
              }
              .clipShape(shape)
              .ignoresSafeArea(edges: [.top, .bottom])
          }
      }
      .transition(.opacity)
    }
  }

  @ViewBuilder
  private var creatingArea: some View {
    // 폼이 떠 있는 동안에도 타입 선택 State는 살아 있으므로 폼을 먼저 본다.
    if let createSecretStore = store.scope(state: \.createSecret, action: \.createSecret) {
      CreateSecretView(store: createSecretStore)
    } else if let selectStore = store.scope(state: \.selectSecretType, action: \.selectSecretType) {
      SelectSecretTypeView(store: selectStore)
    }
  }

  /// 폭을 고정한다(min == ideal == max). 범위를 주면 `.balanced`가 남는 폭을 컬럼끼리 나눠 가져 화면 전환 때 사이드바 폭이 흔들린다.
  private var sidebarColumn: some View {
    SidebarView(store: store.scope(state: \.sidebar, action: \.sidebar))
      .navigationSplitViewColumnWidth(
        min: WindowLayoutMetrics.sidebarWidth,
        ideal: WindowLayoutMetrics.sidebarWidth,
        max: WindowLayoutMetrics.sidebarWidth
      )
  }

  /// 드래그 하한은 컬럼이 아니라 콘텐츠가 갖는다 — 컬럼 `min`은 분할 뷰의 required 제약으로 격상되어 다른 required와 충돌한 이력이 있어 0으로 둔다.
  private var contentColumn: some View {
    SecretListView(store: store.scope(state: \.secretList, action: \.secretList))
      .navigationTitle("")
      // 오버레이는 밑의 뷰를 접근성 트리에서 빼 주지 않는다. 숨기지 않으면 VoiceOver가 가려진 목록을 계속 탐색한다.
      .accessibilityHidden(store.screen == .creating)
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.frame(in: .named(Self.splitCoordinateSpaceName)).minX
      } action: { minX in
        creatingOverlayInset = minX
      }
      .frame(minWidth: WindowLayoutMetrics.listMinWidth)
      .navigationSplitViewColumnWidth(
        min: 0,
        ideal: WindowLayoutMetrics.listIdealWidth,
        max: WindowLayoutMetrics.listMaxWidth
      )
  }

  /// detail 컬럼이 상세 대신 그리는 안내. 시크릿 미선택과 삭제된 시크릿 선택이 같은 모양을 쓴다.
  private func detailPlaceholder(
    title: LocalizedStringResource,
    description: LocalizedStringResource? = nil
  ) -> some View {
    VStack(spacing: 4) {
      Text(title)
        .dvFont(.captionLG)
        .foregroundStyle(Color.dv(.gray700))
      if let description {
        Text(description)
          .dvFont(.captionLG)
          .foregroundStyle(Color.dv(.gray500))
      }
    }
    .multilineTextAlignment(.center)
    .accessibilityElement(children: .combine)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var detailColumn: some View {
    Group {
      if let detailStore = store.scope(state: \.secretDetail, action: \.secretDetail) {
        SecretDetailView(store: detailStore)
          .transition(.opacity)
      } else if store.deletedNoticeSecret != nil {
        detailPlaceholder(
          title: .module("This secret was deleted."),
          description: .module("Recover it to view this secret.")
        )
        .transition(.opacity)
      } else {
        detailPlaceholder(title: .module("No secret selected"))
          .transition(.opacity)
      }
    }
    // id로 좁힌다. State 전체로 넓히면 조회 화면 안에서 필드를 열 때마다 상세가 다시 페이드된다.
    // 안내끼리 옮겨 다닐 때는 `secretDetail`이 계속 nil이라 안내 대상 id도 함께 본다.
    .dvAnimation(MotionMetrics.transition, value: store.secretDetail?.id ?? store.deletedNoticeSecret?.id)
    .navigationTitle("")
    // 오버레이는 밑의 뷰를 접근성 트리에서 빼 주지 않는다. 숨기지 않으면 VoiceOver가 가려진 상세를 계속 탐색한다.
    .accessibilityHidden(store.screen == .creating)
    // max는 주지 않는다 — 컬럼이 창을 채우지 못하면 윈도우 배경이 양옆에 드러난다.
    // 폼 폭 상한은 컬럼이 아니라 `SecretDetailView` 안의 `formMaxWidth()`가 담당한다.
    .navigationSplitViewColumnWidth(
      min: WindowLayoutMetrics.detailMinWidth,
      ideal: WindowLayoutMetrics.detailIdealWidth
    )
  }

  /// 초록 토큰이 둘뿐이라 press는 색만으로 hover와 구분되지 않아 흐림을 함께 준다.
  private var lockButton: some View {
    DVIconButton(
      systemName: "lock",
      font: .headingLG,
      idle: .vaultGreen,
      hovered: .vaultGreenDark,
      pressed: .vaultGreenDark,
      pressedOpacity: 0.7,
      hitSize: 28
    ) {
      store.send(.didTapLock)
    }
    .accessibilityLabel(String.module("Lock App"))
  }
}

// MARK: - Preview

#if DEBUG

#Preview {
  MainView(
    store: Store(initialState: MainFeature.State()) {
      MainFeature()
    }
  )
}

#endif
