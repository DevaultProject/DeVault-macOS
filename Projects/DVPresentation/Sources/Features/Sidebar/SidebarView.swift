// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign

// MARK: - SidebarView

struct SidebarView: View {

  // MARK: - Metrics

  private enum Metrics {
    /// 더 낮추면 목록이 비활성처럼 보인다.
    static let refreshingOpacity: Double = 0.55
  }

  // MARK: - Properties

  @Bindable var store: StoreOf<SidebarFeature>

  // MARK: - Body

  var body: some View {
    content
      .task { store.send(.task) }
      .alert($store.scope(state: \.alert, action: \.alert))
  }
}

// MARK: - Subviews

extension SidebarView {

  private var content: some View {
    VStack(spacing: 10) {
      logoView
        .padding(.leading, 4)
      filterGrid
        .padding(.bottom, 10)
      projectSection
        .frame(maxHeight: .infinity)
      bottomBar
        .padding(.bottom, 10)
    }
    .padding(.horizontal, 12)
  }

  private var logoView: some View {
    HStack(spacing: 4) {
      Image.dv(.appIcon)
        .resizable()
        .scaledToFit()
        .frame(width: 28)
        
      (
        Text("De").foregroundStyle(Color.dv(.vaultDark))
        +
        Text("Vault").foregroundStyle(Color.dv(.vaultGreen))
      )
      .font(.dv(.headingXL))
      Spacer()
    }
  }

  private var filterGrid: some View {
    VStack(spacing: 12) {
      DVCategory(
        title: SidebarFilter.all.title,
        count: count(for: .all),
        systemImage: SidebarFilter.all.icon,
        isSelected: store.highlighted == .filter(.all)
      ) {
        store.send(.didSelect(.filter(.all)))
      }
      .frame(height: 72)
      .accessibilityElement(children: .combine)

      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: 12
      ) {
        ForEach([SidebarFilter.starred, .notice, .expired, .deleted], id: \.self) { filter in
          DVCategory(
            title: filter.title,
            count: count(for: filter),
            systemImage: filter.icon,
            iconColor: filter.iconColor,
            isSelected: store.highlighted == .filter(filter)
          ) {
            store.send(.didSelect(.filter(filter)))
          }
          .frame(height: 72)
          .accessibilityElement(children: .combine)
        }
      }
    }
  }

  private var projectSection: some View {
    VStack(spacing: 12) {
      projectSectionHeader
        .padding(.horizontal, 4)
      collapsibleProjectBody
    }
    // `value`를 좁히지 않으면 이름 변경 입력 한 글자마다 섹션 전체가 다시 애니메이션된다.
    .dvAnimation(MotionMetrics.subtle, value: store.projectsState)
    .dvAnimation(MotionMetrics.subtle, value: store.isRefreshingProjects)
  }

  /// **접힘 마스크가 헤더를 포함하면 안 된다.** 경계가 헤더보다 위에 생겨,
  /// 접히는 목록이 "Project" 라벨 위를 지나간 뒤에야 잘린다.
  private var collapsibleProjectBody: some View {
    VStack(spacing: 0) {
      if store.isProjectSectionExpanded {
        projectSectionBody
          // opacity만 주면 자리는 그대로인 채 내용만 없어져 접히는 것으로 보이지 않는다.
          .transition(.move(edge: .top).combined(with: .opacity))
      } else {
        Spacer(minLength: 0)
      }
    }
    // 접힘은 세로만 자르면 된다. 리스트가 `.padding(.horizontal, -12)`로 넘치므로 마스크를 좌우 12pt 넓혀 하이라이트가 안 깎이게 한다.
    .mask {
      Rectangle().padding(.horizontal, -12)
    }
    .dvAnimation(MotionMetrics.layout, value: store.isProjectSectionExpanded)
  }

  /// 스피너 대신 자리를 유지한 채 opacity만 움직인다 — 갱신이 잦아 스피너로 갈아끼우면 목록이 사라졌다
  /// 나타나는 것으로 보인다. 첫 로드 동안에는 **아무것도 그리지 않는다** — 아직 목록이 없어 흐릴 대상이
  /// 없고, "없다"고 쓰면 로딩 중에 잘못 알린 셈이 된다(도착하면 opacity로 나타난다).
  @ViewBuilder
  private var projectSectionBody: some View {
    if case .failed = store.projectsState {
      Text(.module("Failed to load."))
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.danger))
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
      Spacer(minLength: 0)
    } else if store.projects.isEmpty {
      // 다 받아 놓고 정말 없을 때만 안내한다 — 로딩 중에 "없다"고 하면 잘못 알린 셈이 된다.
      if case .loaded = store.projectsState {
        Text(.module("No projects yet"))
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.gray500))
          .frame(maxWidth: .infinity)
          .padding(.top, 8)
      }
      Spacer(minLength: 0)
    } else {
      projectList
        .opacity(store.isRefreshingProjects ? Metrics.refreshingOpacity : 1)
        .transition(.opacity)
    }
  }

  private var projectSectionHeader: some View {
    HStack(spacing: 4) {
      Text(.module("Project"))
        .dvFont(.captionMDSemibold)
        .foregroundStyle(Color.dv(.vaultGreen))
      Spacer()
      DVIconButton(
        systemName: "plus.circle",
        idle: .gray500,
        hovered: .gray700,
        pressed: .gray800
      ) {
        store.send(.didTapAddProject)
      }
      .accessibilityLabel(String.module("Add Project"))
      // 아이콘을 갈아끼우면 서로 다른 뷰라 툭 바뀐다. 하나를 돌려야 각도가 이어진다.
      DVIconButton(
        systemName: "chevron.down",
        idle: .gray500,
        hovered: .gray700,
        pressed: .gray800
      ) {
        store.send(.didToggleProjectSection)
      }
      .rotationEffect(.degrees(store.isProjectSectionExpanded ? 0 : 180))
      .dvAnimation(MotionMetrics.layout, value: store.isProjectSectionExpanded)
      .accessibilityLabel(store.isProjectSectionExpanded ? String.module("Collapse Projects") : String.module("Expand Projects"))
    }
  }

  private var projectList: some View {
    // List(selection:)은 ProjectItem.ID?를 요구하지만 store.selection은 SidebarSelection(enum)이라 타입 불일치로 $store 직접 바인딩 불가 → 의도적 manual Binding 사용
    List(
      selection: Binding<ProjectItem.ID?>(
        get: {
          if case .project(id: let id) = store.highlighted { return id }
          return nil
        },
        set: { id in
          if let id { store.send(.didSelect(.project(id: id))) }
        }
      )
    ) {
      ForEach(store.projects) { project in
        projectRow(project)
          .accessibilityElement(children: .combine)
          .tag(project.id)
          .contextMenu {
            Button(String.module("Rename")) { store.send(.didTapRename(id: project.id)) }
            Divider()
            Button(String.module("Delete Project"), role: .destructive) {
              store.send(.didTapDelete(id: project.id))
            }
          }
      }
    }
    .listStyle(.sidebar)
    .tint(Color.dv(.vaultGreen))
    .dvAnimation(MotionMetrics.layout, value: store.projects)
    .scrollContentBackground(.hidden)
    .padding(.horizontal, -12)
    .onKeyPress(.return) {
      guard store.renamingProjectID == nil else { return .ignored }
      // 강조된 것에만 반응한다. `selection`을 보면 생성 중(강조 없음)에도 이전 프로젝트의
      // 이름 변경이 열린다.
      if case .project(id: let id) = store.highlighted {
        store.send(.didTapRename(id: id))
        return .handled
      }
      return .ignored
    }
  }

  @ViewBuilder
  private func projectRow(_ project: ProjectItem) -> some View {
    if store.renamingProjectID == project.id {
      DVProjectRenameContainer(
        text: Binding(
          get: { store.renameText },
          set: { store.send(.didChangeRenameText($0)) }
        ),
        onSubmit: { store.send(.didConfirmRename) },
        onCancel: { store.send(.didCancelRename) }
      )
    } else {
      DVProjectContainer(
        name: project.name,
        count: store.counts?.count(forProject: project.id)
      )
    }
  }

  private var bottomBar: some View {
    HStack {
      circleIconButton(icon: "gearshape") {
        store.send(.didTapSettings)
      }
      .accessibilityLabel(String.module("Settings"))
      Spacer()
      circleIconButton(icon: "plus") { store.send(.didTapAddButton) }
        .accessibilityLabel(String.module("Add Secret"))
    }
  }

  /// 로드 전·실패 시에는 nil을 넘겨 숫자 자리를 비운다 — 0으로 대체하면 "시크릿 없음"과 구분되지 않는다.
  private func count(for filter: SidebarFilter) -> Int? {
    store.counts?.count(for: filter)
  }


  /// 배포 타겟이 macOS 14라 분기가 필요하다. 이 SDK의 SwiftUI에는 `glassEffect` modifier가 없고
  /// 버튼용 `GlassProminentButtonStyle`이 제공되므로 그쪽을 쓴다 — 색을 잃지 않도록 `.glass`가
  /// 아니라 tint를 받는 prominent 쪽을 골랐다. 26 미만은 기존 초록 원형 그대로다.
  @ViewBuilder
  private func circleIconButton(icon: String, action: @escaping () -> Void) -> some View {
    if #available(macOS 26.0, *) {
      Button(action: action) {
        Image(systemName: icon)
          .dvFont(.captionLG)
          .frame(width: 32, height: 32)
      }
      .buttonStyle(.glassProminent)
      .buttonBorderShape(.circle)
      .tint(Color.dv(.vaultGreen))
    } else {
      Button(action: action) {
        Image(systemName: icon)
          .dvFont(.captionLG)
          .frame(width: 32, height: 32)
          .background(Color.dv(.vaultGreen), in: Circle())
          .foregroundStyle(Color.dv(.white))
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - SidebarFilter + View

private extension SidebarFilter {
  var iconColor: Color {
    switch self {
    case .notice:  Color.dv(.warning)
    case .starred: Color.dv(.vaultGreen)
    case .expired: Color.dv(.danger)
    default:       Color.dv(.gray800)
    }
  }
}

// MARK: - Preview

#if DEBUG

#Preview {
  Group {
    SidebarView(
      store: Store(initialState: SidebarFeature.State()) {
        SidebarFeature()
      }
    )
    .frame(width: 200)

    SidebarView(
      store: Store(initialState: SidebarFeature.State()) {
        SidebarFeature()
      }
    )
    .frame(width: 250)

    SidebarView(
      store: Store(initialState: SidebarFeature.State()) {
        SidebarFeature()
      }
    )
    .frame(width: 270)
  }
}

#endif
