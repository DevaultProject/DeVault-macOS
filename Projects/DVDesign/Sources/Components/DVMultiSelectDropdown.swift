// Copyright © 2026 Devault. All rights reserved

import SwiftUI

// MARK: - Metrics

/// DVMultiSelectDropdown 내부 서브뷰들이 공유하는 레이아웃 상수.
/// 매직 넘버 하드코딩을 피하고 한 곳에서 튜닝하기 위함.
/// 메인 struct 내부에선 `typealias Metrics = DropdownMetrics`로 축약해 사용.
fileprivate enum DropdownMetrics {

    // MARK: Shared

    /// 팝오버 내부 row/header/footer가 좌우 정렬선을 공유하는 horizontal padding.
    static let contentHorizontalPadding: CGFloat = 12

    // MARK: Trigger

    static let triggerHeight: CGFloat = DVComponentSize.fieldHeight
    static let triggerCornerRadius: CGFloat = 6
    static let triggerLeadingPadding: CGFloat = 8
    static let triggerTrailingPadding: CGFloat = 4
    static let chipsPadding: CGFloat = 6
    static let chipsSpacing: CGFloat = 6
    static let chevronSize: CGFloat = 24

    // MARK: Row

    static let rowVerticalPadding: CGFloat = 8
    static let rowContentSpacing: CGFloat = 10

    // MARK: Section header

    static let sectionHeaderTopPadding: CGFloat = 8
    static let sectionHeaderBottomPadding: CGFloat = 4

    // MARK: Search header

    static let searchIconSpacing: CGFloat = 6
    static let searchVerticalPadding: CGFloat = 10

    // MARK: Create footer

    static let footerIconSpacing: CGFloat = 8
    static let footerVerticalPadding: CGFloat = 10

    // MARK: Empty state

    static let emptyStateVerticalPadding: CGFloat = 24

    // MARK: List

    static let listVerticalPadding: CGFloat = 4
    static let listMaxHeight: CGFloat = 260
}

// MARK: - DVMultiSelectDropdown

/// 다중 선택 드롭다운. 트리거는 값이 없으면 placeholder + chevron, 값이 있으면
/// 선택된 항목을 chip 그리드로 표시 (read-only). 클릭 시 popover가 열리고
/// 체크박스 리스트에서 선택/해제.
///
/// 옵션은 모두 caller가 opt-in 하는 방식으로 노출:
/// - `searchText` binding을 넘기면 헤더에 검색 필드 표시. 필터링은 caller가
///   `items` 재산정으로 수행 (컴포넌트는 UI + 하이라이트만 담당).
/// - `onCreate` 콜백을 넘기면 푸터에 "+ Add new" 액션 노출.
/// - `groupsSelectedAtTop`이 true거나 선택 2개 이상 + 전체 4개 이상이면
///   "Selected" / "All" 섹션으로 자동 분리.
public struct DVMultiSelectDropdown<Item: Identifiable>: View {

    /// 파일 스코프 `DropdownMetrics`를 이 컴포넌트의 컨텍스트에서 축약한 별칭.
    private typealias Metrics = DropdownMetrics

    // MARK: - Props

    private let placeholder: String
    private let items: [Item]
    @Binding private var selection: Set<Item.ID>
    private let label: (Item) -> String
    private let size: DVComponentSize

    private let searchText: Binding<String>?
    private let searchPlaceholder: String

    private let onCreate: (() -> Void)?
    private let createLabel: String

    private let emptyMessage: String
    private let noResultsMessage: ((String) -> String)?

    private let groupsSelectedAtTop: Bool
    private let isReadOnly: Bool

    @State private var isOpen: Bool = false

    // MARK: - Init

    /// 다중 선택 드롭다운을 생성합니다.
    ///
    /// - Parameters:
    ///   - placeholder: 값이 없을 때 트리거에 표시할 문구 (예: "Select Project").
    ///   - items: 표시 대상 목록. caller가 검색 결과에 맞춰 필터한 상태로 넘긴다.
    ///   - selection: 선택된 항목 ID 집합.
    ///   - label: 각 item을 표시 문자열로 변환하는 클로저.
    ///   - size: 트리거·popover 너비. 기본값 ``DVComponentSize/sm`` (330pt).
    ///   - searchText: 헤더 검색 필드 바인딩. `nil`이면 헤더 미표시.
    ///   - searchPlaceholder: 검색 필드 placeholder. `searchText`가 `nil`이면 무시.
    ///   - onCreate: 푸터 "+ Add new" 클릭 콜백. `nil`이면 푸터 미표시.
    ///   - createLabel: 푸터 액션 문구.
    ///   - emptyMessage: `items`가 비었고 검색 중이 아닐 때 표시할 안내.
    ///   - noResultsMessage: 검색 결과가 없을 때 표시할 안내 (검색어 인자). `nil`이면 기본 포맷.
    ///   - groupsSelectedAtTop: true면 항상 "Selected" / "All" 섹션 분리.
    ///     false여도 선택 2개 이상 + 전체 4개 이상이면 자동 분리.
    ///   - isReadOnly: true면 트리거 클릭이 no-op — 팝오버가 열리지 않는다.
    ///     시각 변화는 없으며, selection 바인딩은 여전히 외부에서 프로그램적으로 변경 가능.
    public init(
        _ placeholder: String,
        items: [Item],
        selection: Binding<Set<Item.ID>>,
        label: @escaping (Item) -> String,
        size: DVComponentSize = .sm,
        searchText: Binding<String>? = nil,
        searchPlaceholder: String = "Search",
        onCreate: (() -> Void)? = nil,
        createLabel: String = "Add new",
        emptyMessage: String = "No items yet",
        noResultsMessage: ((String) -> String)? = nil,
        groupsSelectedAtTop: Bool = false,
        isReadOnly: Bool = false
    ) {
        self.placeholder = placeholder
        self.items = items
        self._selection = selection
        self.label = label
        self.size = size
        self.searchText = searchText
        self.searchPlaceholder = searchPlaceholder
        self.onCreate = onCreate
        self.createLabel = createLabel
        self.emptyMessage = emptyMessage
        self.noResultsMessage = noResultsMessage
        self.groupsSelectedAtTop = groupsSelectedAtTop
        self.isReadOnly = isReadOnly
    }

    // MARK: - Body

    public var body: some View {
        Button {
            guard !isReadOnly else { return }
            isOpen.toggle()
        } label: {
            triggerContent
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            PopoverContentView(
                items: items,
                initialSelection: selection,
                onSelectionChange: { selection = $0 },
                label: label,
                // 트리거는 `.fill`에서 컨테이너를 따라 늘어나지만 팝오버는 토큰 폭 고정이다.
                // 넓혀 봐야 라벨 오른쪽 여백만 늘고, 컬럼 폭에 따라 같은 목록이 달라 보인다.
                width: size.width,
                searchText: searchText,
                searchPlaceholder: searchPlaceholder,
                onCreate: onCreate,
                createLabel: createLabel,
                emptyMessage: emptyMessage,
                noResultsMessage: noResultsMessage,
                groupsSelectedAtTop: groupsSelectedAtTop
            )
            // 항목이 추가·삭제되면(예: "+ Add new"로 만든 프로젝트) 팝오버를 새 정체성으로 다시 만들어
            // 아래 `@State`가 현재 selection으로 다시 시드되게 한다.
            .id(items.map(\.id))
        }
    }
}

// MARK: - Trigger

private extension DVMultiSelectDropdown {

    @ViewBuilder
    var triggerContent: some View {
        if selectedItems.isEmpty {
            placeholderTrigger
        } else {
            chipsTrigger
        }
    }

    /// 값이 없을 때: placeholder 텍스트 + chevron.
    var placeholderTrigger: some View {
        HStack(spacing: 0) {
            Text(placeholder)
                .dvFont(.bodyLG)
                .foregroundStyle(Color.dv(.gray600))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: Metrics.triggerTrailingPadding)
            chevron
        }
        .padding(.leading, Metrics.triggerLeadingPadding)
        .padding(.trailing, Metrics.triggerTrailingPadding)
        .dvComponentWidth(size, height: Metrics.triggerHeight)
        .background(triggerBackground)
    }

    /// 값이 있을 때: chip flow (read-only, chip 자체 클릭은 무시).
    var chipsTrigger: some View {
        DVFlowLayout(hSpacing: Metrics.chipsSpacing, vSpacing: Metrics.chipsSpacing) {
            ForEach(selectedItems, id: \.id) { item in
                DVChip(label(item))
                    .allowsHitTesting(false)
            }
        }
        .padding(Metrics.chipsPadding)
        .dvComponentWidth(size, alignment: .leading)
        .background(triggerBackground)
    }

    var chevron: some View {
        Image(systemName: "chevron.down")
            .font(DVFont.captionMDSemibold.font)
            .foregroundStyle(Color.dv(.gray600))
            .frame(width: Metrics.chevronSize, height: Metrics.chevronSize)
    }

    var triggerBackground: some View {
        RoundedRectangle(cornerRadius: Metrics.triggerCornerRadius)
            .fill(Color.dv(.gray300))
    }

    var selectedItems: [Item] {
        items.filter { selection.contains($0.id) }
    }
}

// MARK: - PopoverContent

/// 팝오버 본문. **선택 상태를 직접 소유하고** 바깥에는 `onSelectionChange`로 알린다.
/// 부모가 소유하면, 팝오버가 별도 윈도우에 호스팅돼 부모의 상태 변경이 이 서브트리까지 내려오지
/// 않아 연속으로 누를 때 방금 누른 행만 갱신되고 이전 행은 옛 체크 상태로 남는다.
private struct PopoverContentView<Item: Identifiable>: View {

    let items: [Item]
    let label: (Item) -> String
    let width: CGFloat

    let searchText: Binding<String>?
    let searchPlaceholder: String

    let onCreate: (() -> Void)?
    let createLabel: String

    let emptyMessage: String
    let noResultsMessage: ((String) -> String)?

    let groupsSelectedAtTop: Bool
    let onSelectionChange: (Set<Item.ID>) -> Void

    @State private var selection: Set<Item.ID>

    /// 섹션 배치 기준 — 열린 순간의 선택으로 고정되어 세션 중 재정렬되지 않는다.
    @State private var groupingSnapshot: Set<Item.ID>

    init(
        items: [Item],
        initialSelection: Set<Item.ID>,
        onSelectionChange: @escaping (Set<Item.ID>) -> Void,
        label: @escaping (Item) -> String,
        width: CGFloat,
        searchText: Binding<String>?,
        searchPlaceholder: String,
        onCreate: (() -> Void)?,
        createLabel: String,
        emptyMessage: String,
        noResultsMessage: ((String) -> String)?,
        groupsSelectedAtTop: Bool
    ) {
        self.items = items
        self.onSelectionChange = onSelectionChange
        self.label = label
        self.width = width
        self.searchText = searchText
        self.searchPlaceholder = searchPlaceholder
        self.onCreate = onCreate
        self.createLabel = createLabel
        self.emptyMessage = emptyMessage
        self.noResultsMessage = noResultsMessage
        self.groupsSelectedAtTop = groupsSelectedAtTop
        _selection = State(initialValue: initialSelection)
        _groupingSnapshot = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let searchText {
                SearchHeaderView(text: searchText, placeholder: searchPlaceholder)
                Divider()
            }

            if items.isEmpty {
                EmptyStateView(message: emptyStateMessage)
            } else if useSectioning {
                SectionedListView(
                    items: items,
                    selection: selection,
                    onToggle: toggle(_:),
                    groupingSnapshot: groupingSnapshot,
                    label: label,
                    query: searchText?.wrappedValue ?? ""
                )
            } else {
                FlatListView(
                    items: items,
                    selection: selection,
                    onToggle: toggle(_:),
                    label: label,
                    query: searchText?.wrappedValue ?? ""
                )
            }

            if let onCreate {
                Divider()
                CreateFooterView(label: createLabel, action: onCreate)
            }
        }
        .frame(width: width)
        .onChange(of: selection) { _, new in onSelectionChange(new) }
    }

    private func toggle(_ id: Item.ID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private var useSectioning: Bool {
        if groupsSelectedAtTop { return true }
        return groupingSnapshot.count >= 2 && items.count >= 4
    }

    /// 빈 상태 문구: 검색 중이면 no-results, 아니면 empty.
    private var emptyStateMessage: String {
        let query = searchText?.wrappedValue ?? ""
        guard !query.isEmpty else { return emptyMessage }
        if let noResultsMessage {
            return noResultsMessage(query)
        }
        return "No results match \"\(query)\""
    }
}

// MARK: - SearchHeader

private struct SearchHeaderView: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: DropdownMetrics.searchIconSpacing) {
            Image(systemName: "magnifyingglass")
                .font(DVFont.bodyMD.font)
                .foregroundStyle(Color.dv(.gray600))
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .dvFont(.bodyLG)
                .foregroundStyle(Color.dv(.gray900))
        }
        .padding(.horizontal, DropdownMetrics.contentHorizontalPadding)
        .padding(.vertical, DropdownMetrics.searchVerticalPadding)
    }
}

// MARK: - List bodies

private struct FlatListView<Item: Identifiable>: View {
    let items: [Item]
    let selection: Set<Item.ID>
    let onToggle: (Item.ID) -> Void
    let label: (Item) -> String
    let query: String

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    RowView(
                        text: label(item),
                        isSelected: selection.contains(item.id),
                        query: query
                    ) {
                        onToggle(item.id)
                    }
                }
            }
            .padding(.vertical, DropdownMetrics.listVerticalPadding)
        }
        .frame(maxHeight: DropdownMetrics.listMaxHeight)
    }
}

private struct SectionedListView<Item: Identifiable>: View {
    let items: [Item]
    let selection: Set<Item.ID>
    let onToggle: (Item.ID) -> Void
    /// 섹션 배치는 이 스냅샷 기준으로 고정 — 세션 중 selection 변경으로 재정렬되지 않음.
    let groupingSnapshot: Set<Item.ID>
    let label: (Item) -> String
    let query: String

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                if !snapshotSelected.isEmpty {
                    SectionHeaderView(title: "Selected")
                    ForEach(snapshotSelected) { item in
                        RowView(
                            text: label(item),
                            isSelected: selection.contains(item.id),
                            query: query
                        ) {
                            onToggle(item.id)
                        }
                    }
                }
                if !snapshotUnselected.isEmpty {
                    SectionHeaderView(title: "All")
                    ForEach(snapshotUnselected) { item in
                        RowView(
                            text: label(item),
                            isSelected: selection.contains(item.id),
                            query: query
                        ) {
                            onToggle(item.id)
                        }
                    }
                }
            }
            .padding(.vertical, DropdownMetrics.listVerticalPadding)
        }
        .frame(maxHeight: DropdownMetrics.listMaxHeight)
    }

    private var snapshotSelected: [Item] {
        items.filter { groupingSnapshot.contains($0.id) }
    }
    private var snapshotUnselected: [Item] {
        items.filter { !groupingSnapshot.contains($0.id) }
    }
}

// MARK: - Row / Section header

private struct RowView: View {
    let text: String
    let isSelected: Bool
    let query: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DropdownMetrics.rowContentSpacing) {
                DVCheckBox(isChecked: isSelected) { action() }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Text(highlighted)
                    .dvFont(.bodyLG)
                    .foregroundStyle(Color.dv(.gray900))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DropdownMetrics.contentHorizontalPadding)
            .padding(.vertical, DropdownMetrics.rowVerticalPadding)
            .contentShape(Rectangle())
            .background(isSelected ? Color.dv(.vaultGreenTint) : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 라벨을 AttributedString으로 렌더링. `query`와 정확히 일치하는(대소문자 무관)
    /// 첫 range에 semibold + vaultGreenDark 강조.
    private var highlighted: AttributedString {
        var attr = AttributedString(text)
        guard !query.isEmpty,
              let range = attr.range(of: query, options: .caseInsensitive)
        else { return attr }
        attr[range].font = .system(size: DVFont.bodyLG.size, weight: .semibold)
        attr[range].foregroundColor = Color.dv(.vaultGreenDark)
        return attr
    }
}

private struct SectionHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .dvFont(.captionLG)
                .foregroundStyle(Color.dv(.gray600))
            Spacer()
        }
        .padding(.horizontal, DropdownMetrics.contentHorizontalPadding)
        .padding(.top, DropdownMetrics.sectionHeaderTopPadding)
        .padding(.bottom, DropdownMetrics.sectionHeaderBottomPadding)
    }
}

// MARK: - Empty / Footer

private struct EmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
            .dvFont(.bodyMD)
            .foregroundStyle(Color.dv(.gray600))
            .multilineTextAlignment(.center)
            .padding(.horizontal, DropdownMetrics.contentHorizontalPadding)
            .padding(.vertical, DropdownMetrics.emptyStateVerticalPadding)
            .frame(maxWidth: .infinity)
    }
}

private struct CreateFooterView: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DropdownMetrics.footerIconSpacing) {
                Image(systemName: "plus")
                    .font(DVFont.bodyMD.font)
                    .foregroundStyle(Color.dv(.vaultGreen))
                Text(label)
                    .dvFont(.bodyLG)
                    .foregroundStyle(Color.dv(.vaultGreen))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DropdownMetrics.contentHorizontalPadding)
            .padding(.vertical, DropdownMetrics.footerVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG

private struct PreviewProject: Identifiable, Hashable {
    let id: UUID
    let name: String
}

private let previewProjects: [PreviewProject] = [
    .init(id: UUID(), name: "DeVault"),
    .init(id: UUID(), name: "DrinkiG"),
    .init(id: UUID(), name: "CheerLot"),
    .init(id: UUID(), name: "SipStream"),
    .init(id: UUID(), name: "Fizzoraaaaa"),
    .init(id: UUID(), name: "Example"),
]

#Preview("v1 · Closed / empty") {
    DVMultiSelectDropdownV1Preview().padding(40)
}

#Preview("v2 · Open / mixed (flat)") {
    DVMultiSelectDropdownV2Preview().padding(40)
}

#Preview("v3 · Open / unselected") {
    DVMultiSelectDropdownV3Preview().padding(40)
}

#Preview("v4 · Open / sectioned") {
    DVMultiSelectDropdownV4Preview().padding(40)
}

#Preview("v5 · Empty repository") {
    DVMultiSelectDropdownV5Preview().padding(40)
}

#Preview("v6 · No results (search Zzz)") {
    DVMultiSelectDropdownV6Preview().padding(40)
}

#Preview("v7 · Filtered + highlight") {
    DVMultiSelectDropdownV7Preview().padding(40)
}

#Preview("v8 · Closed / chips") {
    DVMultiSelectDropdownV8Preview().padding(40)
}

#Preview("v9 · Closed / wrap chips") {
    DVMultiSelectDropdownV9Preview().padding(40)
}

private struct DVMultiSelectDropdownV1Preview: View {
    @State private var selection: Set<UUID> = []
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: previewProjects,
            selection: $selection,
            label: \.name
        )
    }
}

private struct DVMultiSelectDropdownV2Preview: View {
    @State private var selection: Set<UUID>
    @State private var query = ""
    init() {
        _selection = State(initialValue: Set(previewProjects.prefix(2).map(\.id)))
    }
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: previewProjects,
            selection: $selection,
            label: \.name,
            searchText: $query,
            searchPlaceholder: "Search Projects",
            onCreate: {},
            createLabel: "Add new project"
        )
    }
}

private struct DVMultiSelectDropdownV3Preview: View {
    @State private var selection: Set<UUID> = []
    @State private var query = ""
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: previewProjects,
            selection: $selection,
            label: \.name,
            searchText: $query,
            searchPlaceholder: "Search Projects",
            onCreate: {},
            createLabel: "Add new project"
        )
    }
}

private struct DVMultiSelectDropdownV4Preview: View {
    @State private var selection: Set<UUID>
    @State private var query = ""
    init() {
        _selection = State(initialValue: Set(previewProjects.prefix(2).map(\.id)))
    }
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: previewProjects,
            selection: $selection,
            label: \.name,
            searchText: $query,
            searchPlaceholder: "Search Projects",
            onCreate: {},
            createLabel: "Add new project",
            groupsSelectedAtTop: true
        )
    }
}

private struct DVMultiSelectDropdownV5Preview: View {
    @State private var selection: Set<UUID> = []
    @State private var query = ""
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: [] as [PreviewProject],
            selection: $selection,
            label: \.name,
            searchText: $query,
            searchPlaceholder: "Search Projects",
            onCreate: {},
            createLabel: "Add new project",
            emptyMessage: "No projects yet"
        )
    }
}

private struct DVMultiSelectDropdownV6Preview: View {
    @State private var selection: Set<UUID> = []
    @State private var query = "Zzz"
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: [] as [PreviewProject],
            selection: $selection,
            label: \.name,
            searchText: $query,
            searchPlaceholder: "Search Projects",
            onCreate: {},
            createLabel: "Add new project",
            noResultsMessage: { "No projects match \"\($0)\"" }
        )
    }
}

private struct DVMultiSelectDropdownV7Preview: View {
    @State private var selection: Set<UUID> = []
    @State private var query = "Che"
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: previewProjects.filter { $0.name.localizedCaseInsensitiveContains("Che") },
            selection: $selection,
            label: \.name,
            searchText: $query,
            searchPlaceholder: "Search Projects",
            onCreate: {},
            createLabel: "Add new project"
        )
    }
}

private struct DVMultiSelectDropdownV8Preview: View {
    @State private var selection: Set<UUID>
    init() {
        _selection = State(initialValue: Set(previewProjects.prefix(4).map(\.id)))
    }
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: previewProjects,
            selection: $selection,
            label: \.name
        )
    }
}

private struct DVMultiSelectDropdownV9Preview: View {
    @State private var selection: Set<UUID>
    init() {
        _selection = State(initialValue: Set(previewProjects.map(\.id)))
    }
    var body: some View {
        DVMultiSelectDropdown(
            "Select Project",
            items: previewProjects,
            selection: $selection,
            label: \.name
        )
    }
}

#endif
