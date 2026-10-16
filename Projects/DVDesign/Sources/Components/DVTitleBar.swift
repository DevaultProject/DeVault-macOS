// Copyright © 2026 Devault. All rights reserved

import SwiftUI

public struct DVTitleBar: View {

    // MARK: - Metrics

    private enum Metrics {
        static let verticalSpacing: CGFloat = 14
        static let titleRowVerticalPadding: CGFloat = 4
        static let searchFieldHeight: CGFloat = 36
    }

    /// 이 컴포넌트 전체의 세로 높이. 위아래로 다른 컴포넌트를 쌓거나 중앙 정렬을 보정할 때
    /// 매직 넘버 대신 여기서 계산한 값을 쓴다.
    public static var totalHeight: CGFloat {
        let titleRowHeight = DVFont.headingXL.lineHeight + Metrics.titleRowVerticalPadding * 2
        return titleRowHeight + Metrics.verticalSpacing + Metrics.searchFieldHeight
    }

    // MARK: - Properties

    public let titleText: String
    public let searchText: Binding<String>
    public let searchPromptText: String
    /// 검색 필드의 포커스를 바깥에서 풀 수 있게 열어 둔다
    /// 한 번 커서가 들어가면 다른 곳을 눌러도 놓지 않는 경우가 있다. `nil`이면 시스템에 맡긴다.
    public let isSearchFocused: Binding<Bool>?
    /// 제목행 우측 정렬 메뉴. `nil`이면 정렬 버튼 자체를 그리지 않는다.
    /// `trailingAction`과 상호배타 — 둘 다 있으면 정렬이 우선한다.
    public let sortMenu: SortMenu?
    /// 정렬 버튼이 없는 화면에서 제목행 우측(정렬 자리)에 놓는 '비우기/모두 삭제' 버튼.
    public let trailingAction: TrailingAction?
    /// 정렬/정리 버튼 왼쪽에 독립적으로 놓는 아이콘 버튼(예: 내보내기). `sortMenu`/`trailingAction`과 상호배타가 아니다.
    public let shareAction: IconAction?

    @FocusState private var searchFieldFocused: Bool
    // 정렬 버튼과 정리 버튼은 상호배타(같은 자리)라 hover 상태를 공유한다.
    @State private var isHovered = false

    /// 제목행 우측 정렬 메뉴. `content`가 반환하는 뷰가 시스템 `Menu` 안에 들어가므로
    /// 바깥 클릭·ESC·포커스 상실 처리는 시스템이 담당한다.
    public struct SortMenu {
        public let accessibilityLabel: String
        public let content: () -> AnyView

        public init(accessibilityLabel: String = "Sort", content: @escaping () -> AnyView) {
            self.accessibilityLabel = accessibilityLabel
            self.content = content
        }
    }

    /// 제목행 우측 '비우기/모두 삭제' 버튼. 아이콘은 고정이라 호출부는 라벨·활성·동작만 넘긴다.
    public struct TrailingAction {
        public let accessibilityLabel: String
        public let isEnabled: Bool
        public let handler: () -> Void

        public init(
            accessibilityLabel: String,
            isEnabled: Bool = true,
            handler: @escaping () -> Void
        ) {
            self.accessibilityLabel = accessibilityLabel
            self.isEnabled = isEnabled
            self.handler = handler
        }
    }

    /// `shareAction`처럼 아이콘을 호출부가 고르는 범용 제목행 아이콘 버튼.
    public struct IconAction {
        public let systemName: String
        public let accessibilityLabel: String
        public let isEnabled: Bool
        public let handler: () -> Void

        public init(
            systemName: String,
            accessibilityLabel: String,
            isEnabled: Bool = true,
            handler: @escaping () -> Void
        ) {
            self.systemName = systemName
            self.accessibilityLabel = accessibilityLabel
            self.isEnabled = isEnabled
            self.handler = handler
        }
    }

    // MARK: - Init

    public init(
        titleText: String,
        searchText: Binding<String>,
        searchPromptText: String = "Search",
        isSearchFocused: Binding<Bool>? = nil,
        sortMenu: SortMenu? = nil,
        trailingAction: TrailingAction? = nil,
        shareAction: IconAction? = nil
    ) {
        self.titleText = titleText
        self.searchText = searchText
        self.searchPromptText = searchPromptText
        self.isSearchFocused = isSearchFocused
        self.sortMenu = sortMenu
        self.trailingAction = trailingAction
        self.shareAction = shareAction
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.verticalSpacing) {
            titleRow
            searchField
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subviews

extension DVTitleBar {

    private var titleRow: some View {
        HStack(spacing: 12) {
            Text(titleText)
                .dvFont(.headingXL)
                .foregroundStyle(Color.dv(.gray900))
            Spacer()
            if let shareAction {
                iconActionButton(shareAction)
            }
            if let sortMenu {
                sortMenuButton(sortMenu)
            } else if let trailingAction {
                trailingActionButton(trailingAction)
            }
        }
        .padding(.vertical, Metrics.titleRowVerticalPadding)
    }

    private func iconActionButton(_ action: IconAction) -> some View {
        DVIconButton(
            systemName: action.systemName,
            font: .bodyXL,
            idle: .gray800,
            hovered: .gray900,
            pressed: .gray900,
            disabled: .gray400,
            hitSize: 30,
            action: action.handler
        )
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private func trailingActionButton(_ action: TrailingAction) -> some View {
        Button(action: action.handler) {
            Image(systemName: "xmark.bin")
                .dvFont(.bodyXL)
                .foregroundStyle(Color.dv(action.isEnabled ? (isHovered ? .gray900 : .gray800) : .gray400))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(!action.isEnabled)
        .onHover { isHovered = $0 }
        .animation(MotionMetrics.hover, value: isHovered)
        .accessibilityLabel(action.accessibilityLabel)
    }

    /// hover만 준다. `Menu`는 `ButtonStyle`을 타지 않아 눌림 상태를 알 수 없고,
    /// 누르는 즉시 메뉴가 열려 그 자체가 되먹임이 된다.
    private func sortMenuButton(_ sortMenu: SortMenu) -> some View {
        Menu {
            sortMenu.content()
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .dvFont(.bodyXL)
                .foregroundStyle(Color.dv(isHovered ? .gray900 : .gray800))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovered = $0 }
        .animation(MotionMetrics.hover, value: isHovered)
        .accessibilityLabel(sortMenu.accessibilityLabel)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .dvFont(.bodyMD)
                .foregroundStyle(Color.dv(.gray500))
                .accessibilityHidden(true)
            TextField(searchPromptText, text: searchText)
                .dvFont(.bodyMD)
                .foregroundStyle(Color.dv(.gray900))
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
                .focused($searchFieldFocused)
                // `@FocusState`는 뷰 안에서만 쓸 수 있어 두 방향을 각각 흘려보내야 한다.
                .onChange(of: searchFieldFocused) { _, focused in
                    isSearchFocused?.wrappedValue = focused
                }
                .onChange(of: isSearchFocused?.wrappedValue) { _, requested in
                    guard let requested, requested != searchFieldFocused else { return }
                    searchFieldFocused = requested
                }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.searchFieldHeight)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
