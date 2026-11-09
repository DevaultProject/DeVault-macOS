// Copyright © 2026 Devault. All rights reserved

import DVDesign
import DVDomain
import SwiftUI

/// CreateSecret 폼의 Project 필드 (모든 secretType 공통, optional).
/// `SecretMetaFields.projectIds`(Array)에 바인딩. `DVMultiSelectDropdown`이 Set 기반이라
/// 내부에서 Array↔Set 어댑터로 브리지.
///
/// 검색 헤더는 비활성(자산 규모가 작아 불필요). Add-new footer는 활성 —
/// `onCreateProject` 콜백이 발동되면 상위에서 생성 시트를 라우팅.
struct ProjectFieldView: View {

    @Binding var projectIds: [Project.ID]
    let availableProjects: [Project]
    let onCreateProject: () -> Void
    var sizeMode: FormSlotSize = .fullWidth

    @Environment(\.formLayout) private var layout
    @Environment(\.isProjectLoading) private var isProjectLoading
    /// 스피너를 실제로 띄울지 정한다. 로컬 조회는 한두 프레임 만에 끝나 바로 띄우면 드롭다운이 깜빡이므로, 로딩이 ``Self/loadingIndicatorDelay``보다 길어질 때만 켠다.
    @State private var showsLoadingIndicator = false

    private static let loadingIndicatorDelay: Duration = .milliseconds(300)

    private var size: DVComponentSize {
        layout.size(for: sizeMode)
    }

    var body: some View {
        content
            .task(id: isProjectLoading) {
                guard isProjectLoading else {
                    showsLoadingIndicator = false
                    return
                }
                try? await Task.sleep(for: Self.loadingIndicatorDelay)
                if !Task.isCancelled { showsLoadingIndicator = true }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isProjectLoading && showsLoadingIndicator {
            DVLabeledField(.module("Project"), size: size) {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
            }
        } else {
            DVLabeledField(.module("Project"), size: size) {
                DVMultiSelectDropdown(
                    .module("Select Project"),
                    items: availableProjects,
                    selection: setBinding,
                    label: \.name,
                    size: size,
                    onCreate: onCreateProject,
                    createLabel: .module("Add new project"),
                    emptyMessage: .module("No projects yet"),
                    groupsSelectedAtTop: true
                )
            }
        }
    }

    /// Array<Project.ID> ↔ Set<Project.ID> 어댑터.
    /// 도메인은 Array (순서 보존 여지), UI는 Set (multi-select 특성).
    /// 현재 정렬 규칙 없음 — set→array 변환 순서는 arbitrary.
    private var setBinding: Binding<Set<Project.ID>> {
        Binding(
            get: { Set(projectIds) },
            set: { projectIds = Array($0) }
        )
    }
}

// MARK: - Preview

#if DEBUG

private let previewProjects: [Project] = [
    Project(id: UUID(), name: "DeVault",     createdAt: Date(), updatedAt: Date()),
    Project(id: UUID(), name: "DrinkiG",     createdAt: Date(), updatedAt: Date()),
    Project(id: UUID(), name: "CheerLot",    createdAt: Date(), updatedAt: Date()),
    Project(id: UUID(), name: "SipStream",   createdAt: Date(), updatedAt: Date()),
    Project(id: UUID(), name: "Example",     createdAt: Date(), updatedAt: Date()),
]

#Preview("Empty · Dual") {
    ProjectFieldPreview()
        .padding()
        .formLayout(.dual)
        .previewWidth(.wide)
}

#Preview("With selection · Single") {
    ProjectFieldPreview(initial: Array(previewProjects.prefix(2).map(\.id)))
        .padding()
        .formLayout(.single)
        .previewWidth(.narrow)
}

#Preview("No projects yet") {
    ProjectFieldPreview(items: [])
        .padding()
        .formLayout(.dual)
        .previewWidth(.wide)
}

private struct ProjectFieldPreview: View {
    let items: [Project]
    @State private var projectIds: [Project.ID]

    init(initial: [Project.ID] = [], items: [Project] = previewProjects) {
        self._projectIds = State(initialValue: initial)
        self.items = items
    }

    var body: some View {
        ProjectFieldView(
            projectIds: $projectIds,
            availableProjects: items,
            onCreateProject: {}
        )
    }
}

#endif
