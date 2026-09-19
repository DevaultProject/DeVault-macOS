// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVCore
import DVDesign
import DVDomain

// MARK: - SecretListView

struct SecretListView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<SecretListFeature>

  /// 목록을 누르면 내려 준다. 그러지 않으면 커서가 검색창에 남아 타이핑이 그리로 들어간다.
  @State private var isSearchFocused = false

  // MARK: - Body

  var body: some View {
    content
      .task(id: store.collection) { store.send(.task) }
      .alert($store.scope(state: \.alert, action: \.alert))
  }
}

// MARK: - Subviews

extension SecretListView {

  /// `DVTitleBar`-리스트 사이 spacing. 헤더가 차지하는 총 높이를 계산할 때도 같이 쓴다.
  private static let headerContentSpacing: CGFloat = 12

  /// 헤더(`DVTitleBar` + spacing)가 차지하는 총 높이. `list`가 헤더 밑에서 시작하도록
  /// 위쪽에 이만큼 여백을 예약해 둘 때 쓴다.
  private static var headerReservedHeight: CGFloat {
    DVTitleBar.totalHeight + headerContentSpacing
  }

  /// 헤더를 `ZStack`으로 얹어, empty/error 상태가 헤더 높이를 뺀 "남은 영역"이 아니라
  /// **창 전체 높이 기준**으로 중앙 정렬되게 한다. 헤더 아래에 리스트를 두는 `VStack` 구조였을 때는
  /// empty 상태가 항상 헤더 높이의 절반만큼 아래로 처져 보였다 — 디테일뷰(헤더 없음)와 비교하면
  /// 어긋난다.
  private var content: some View {
    ZStack(alignment: .top) {
      Group {
        switch store.secretsState {
        case .failed:
          errorView.transition(.opacity)
        case .loaded(let secrets) where secrets.isEmpty:
          emptyView.transition(.opacity)
        default:
          list.transition(.opacity)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .dvAnimation(MotionMetrics.transition, value: store.secretsState)

      DVTitleBar(
        titleText: titleText,
        searchText: searchTextBinding,
        searchPromptText: .module("Search"),
        isSearchFocused: $isSearchFocused,
        sortMenu: showsSort ? DVTitleBar.SortMenu(accessibilityLabel: .module("Sort")) { AnyView(sortMenuContent) } : nil,
        trailingAction: emptyAction
      )
      .padding(.horizontal, 12)
      .background {
        Color.dv(.gray100).ignoresSafeArea(edges: .top)
      }
    }
  }

  private var list: some View {
    List(selection: selectedSecretIDBinding) {
      if isNoticeCollection {
        noticeSection(for: .critical)
        noticeSection(for: .upcoming)
      } else {
        ForEach(secrets) { secret in
          row(for: secret)
        }
      }
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.hidden)
    .tint(Color.dv(.vaultGreen))
    .dvAnimation(MotionMetrics.layout, value: secrets)
    // 필터가 바뀌면 행이 통째로 갈린다. 같은 목록으로 두면 무관한 행을 하나씩 지우고 넣는
    // 것으로 그려 어수선해지므로 새 내용으로 본다.
    .id(store.collection)
    .transition(.opacity)
    .dvAnimation(MotionMetrics.transition, value: store.collection)
    // 어디를 누르든 검색 포커스를 놓는다. `onTapGesture`는 탭을 삼켜 NSTableView가 처리하는
    // 행 클릭과 경합하므로, 이벤트를 흘려보내는 `simultaneousGesture`를 쓴다.
    // `contentShape`은 행이 없는 빈 영역도 눌리게 하려고 남긴다.
    .contentShape(Rectangle())
    .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
      // `content`가 헤더를 ZStack으로 위에 얹으므로, 리스트 쪽만 헤더 높이만큼 안전 영역을 예약해 헤더에 가리지 않게 한다.
    .safeAreaInset(edge: .top, spacing: 0) {
      Color.dv(.gray100).frame(height: Self.headerReservedHeight)
    }
  }

  private func row(for secret: Secret) -> some View {
    // 이미 지난 건 배지로 안 보여준다 — Expired 탭이 전담한다.
    let badgeStatus = expiryStatus(for: secret).flatMap { $0 == .expired ? nil : $0 }

    return DVVaultContainer(
      name: secret.name,
      date: SecretDateFormatter.displayString(from: secret.updatedAt),
      service: secret.service,
      typeIcon: secret.secretType.icon,
      trailingIcon: badgeStatus?.emphasis,
      trailingIconTooltip: badgeStatus?.tooltipText
    )
    .tag(secret.id)
    .listRowInsets(EdgeInsets())
    .listRowSeparator(.hidden)
    // 이름·날짜·만료 배지를 하나의 접근성 요소로 묶어 VoiceOver가 한 번에 읽게 한다.
    .accessibilityElement(children: .combine)
    .accessibilityHint(rowAccessibilityHint)
    .contextMenu {
      contextMenuItems(for: secret)
    }
  }

  /// VoiceOver는 행만 읽어 탭 맥락을 얻지 못하므로, Deleted 행은 골라도 상세가 열리지 않는다는 것을 알린다. 빈 `Text`는 힌트 없음으로 취급된다.
  private var rowAccessibilityHint: Text {
    guard case .deleted = store.collection else { return Text(verbatim: "") }
    return Text(.module("Recover it to view this secret."))
  }

  /// All/Star/Expired/Deleted 어디서든 만료 상태를 알려준다.
  /// 임계값은 `SecretExpiryPolicy`가 소유한다 — 조회 화면 Expire Date 필드와 같은 정책을 써야 한다.
  private func expiryStatus(for secret: Secret) -> SecretExpiryStatus? {
    SecretExpiryStatus(expiresAt: secret.expiresAt)
  }

  private var isNoticeCollection: Bool {
    if case .notice = store.collection { return true }
    return false
  }

  /// `secrets`는 이미 만료 임박 순으로 정렬돼 온다(`SecretListFeature.State.query`) —
  /// 여기서는 `status`로 걸러내기만 하면 섹션 내부 순서가 그대로 유지된다.
  @ViewBuilder
  private func noticeSection(for status: SecretExpiryStatus) -> some View {
    let items = secrets.filter { expiryStatus(for: $0) == status }
    if !items.isEmpty {
      Section {
        ForEach(items) { secret in
          row(for: secret)
        }
      } header: {
        Text(status.tooltipText)
          .dvFont(.captionMDSemibold)
          .foregroundStyle(Color.dv(.vaultGreen))
          .textCase(nil)
      }
    }
  }

  /// All/Star/Expired는 "프로젝트에 추가/삭제", Deleted는 "복구/영구 삭제"를 보여준다.
  @ViewBuilder
  private func contextMenuItems(for secret: Secret) -> some View {
    switch store.collection {
    case .deleted:
      Button(.module("Recover")) {
        store.send(.didTapRecover(id: secret.id))
      }
      Button(.module("Delete Forever"), role: .destructive) {
        store.send(.didTapDeleteForever(id: secret.id))
      }

    case .all, .liked, .notice, .expired, .project:
      Button(.module("Delete"), role: .destructive) {
        store.send(.didTapDelete(id: secret.id))
      }
    }
  }

  /// divider 위: 정렬 기준(시간/만료/이름). divider 아래: 방향(오름/내림차순).
  /// `Menu`가 바깥 클릭·ESC·포커스 상실 처리를 대신하므로 이 화면은 두 축의 값만 계산하면 된다.
  @ViewBuilder
  private var sortMenuContent: some View {
    Picker(.module("Sort by"), selection: sortKeyBinding) {
      Text(.module("Time")).tag(SecretQuery.Sort.Key.time)
      Text(.module("Expiry")).tag(SecretQuery.Sort.Key.expiry)
      Text(.module("Name")).tag(SecretQuery.Sort.Key.name)
    }
    .pickerStyle(.inline)

    Divider()

    Picker(.module("Direction"), selection: sortDirectionBinding) {
      Text(.module("Ascending")).tag(SecretQuery.Sort.Direction.ascending)
      Text(.module("Descending")).tag(SecretQuery.Sort.Direction.descending)
    }
    .pickerStyle(.inline)
  }

  private var sortKeyBinding: Binding<SecretQuery.Sort.Key> {
    Binding(
      get: { store.sort.key },
      set: { store.send(.didSelectSort(SecretQuery.Sort(key: $0, direction: store.sort.direction))) }
    )
  }

  private var sortDirectionBinding: Binding<SecretQuery.Sort.Direction> {
    Binding(
      get: { store.sort.direction },
      set: { store.send(.didSelectSort(SecretQuery.Sort(key: store.sort.key, direction: $0))) }
    )
  }

  private var errorView: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: "exclamationmark.triangle")
        .dvFont(.bodyLG)
        .foregroundStyle(Color.dv(.gray400))
        .accessibilityHidden(true)
      Text(.module("Failed to load the list."))
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray500))
      DVButton(titleText: .module("Retry"), style: .secondary) {
        store.send(.didTapRetry)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyView: some View {
    Text(.module("No secrets."))
      .dvFont(.captionLG)
      .foregroundStyle(Color.dv(.gray700))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var secrets: IdentifiedArrayOf<Secret> {
    if case let .loaded(secrets) = store.secretsState {
      return secrets
    }
    return []
  }

  private var titleText: String {
    switch store.collection {
    case .all: return .module("All")
    case .liked: return .module("Star")
    case .notice: return .module("Notice")
    case .expired: return .module("Expired")
    case .deleted: return .module("Deleted")
    case .project: return store.projectName ?? .module("Project")
    }
  }

  /// Notice/Expired/Deleted는 정렬이 필요 없는 화면이라 정렬 UI 자체를 숨긴다.
  /// Notice는 항상 만료 임박 순으로 고정되므로(`SecretListFeature.State.query`) 사용자가 바꿀 이유가 없다.
  private var showsSort: Bool {
    switch store.collection {
    case .all, .liked:
      return true
    case .notice, .expired, .deleted, .project:
      return false
    }
  }

  /// Expired/Deleted 탭의 제목행 우측 정리 버튼(정렬 자리). 아이콘 하나를 공유한다.
  /// Expired="모두 삭제"(→삭제됨으로 이동), Deleted="비우기"(→영구 삭제).
  /// 활성 여부는 검색과 무관한 컬렉션 전체 수(`collectionCount`)로 판단
  private var emptyAction: DVTitleBar.TrailingAction? {
    switch store.collection {
    case .expired:
      return DVTitleBar.TrailingAction(
        accessibilityLabel: .module("Delete All"),
        isEnabled: store.collectionCount > 0
      ) { store.send(.didTapEmptyCollection) }
    case .deleted:
      return DVTitleBar.TrailingAction(
        accessibilityLabel: .module("Empty"),
        isEnabled: store.collectionCount > 0
      ) { store.send(.didTapEmptyCollection) }
    case .all, .liked, .notice, .project:
      return nil
    }
  }

  private var selectedSecretIDBinding: Binding<Secret.ID?> {
    Binding(
      get: { store.selectedSecretID },
      set: {
        isSearchFocused = false
        store.send(.didSelectSecret(id: $0))
      }
    )
  }

  private var searchTextBinding: Binding<String> {
    Binding(
      get: { store.searchText },
      set: { store.send(.didChangeSearchText($0)) }
    )
  }
}

// MARK: - Preview

#if DEBUG

#Preview("All - 정렬 있음") {
  SecretListView(
    store: Store(initialState: SecretListFeature.State(collection: .all)) {
      SecretListFeature()
    } withDependencies: {
      $0.secretClient = .previewValue
    }
  )
  .frame(width: 300, height: 500)
}

#Preview("Notice - 3일/7일 섹션 분리, 정렬 없음") {
  SecretListView(
    store: Store(initialState: SecretListFeature.State(collection: .notice(referenceDate: .now))) {
      SecretListFeature()
    } withDependencies: {
      $0.secretClient = .previewValue
    }
  )
  .frame(width: 300, height: 500)
}

#Preview("Expired - 이미 만료된 것만") {
  SecretListView(
    store: Store(initialState: SecretListFeature.State(collection: .expired(referenceDate: .now))) {
      SecretListFeature()
    } withDependencies: {
      $0.secretClient = .previewValue
    }
  )
  .frame(width: 300, height: 500)
}

#Preview("Deleted - 정렬 없음, 우클릭: Recover/Delete Forever") {
  SecretListView(
    store: Store(initialState: SecretListFeature.State(collection: .deleted)) {
      SecretListFeature()
    } withDependencies: {
      $0.secretClient = .previewValue
    }
  )
  .frame(width: 300, height: 500)
}

#Preview("Project - CheerLot에 속한 Secret만") {
  SecretListView(
    store: Store(
      initialState: SecretListFeature.State(
        collection: .project(id: [Project].preview[0].id),
        projectName: [Project].preview[0].name
      )
    ) {
      SecretListFeature()
    } withDependencies: {
      $0.secretClient = .previewValue
    }
  )
  .frame(width: 300, height: 500)
}

#endif
