// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign
import DVDomain

// MARK: - ReviewDuplicatesView

public struct ReviewDuplicatesView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<ReviewDuplicatesFeature>

  // MARK: - Init

  public init(store: StoreOf<ReviewDuplicatesFeature>) {
    self.store = store
  }

  // MARK: - Body

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      HStack(spacing: 0) {
        duplicateList
        Divider()
        actionPanel
      }
      Divider()
      footer
    }
    .frame(width: 760, height: 550)
  }
}

// MARK: - Subviews

extension ReviewDuplicatesView {

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(.module("Review duplicates"))
        .dvFont(.headingLG)
        .foregroundStyle(Color.dv(.gray900))
      ImportSubtitleView(String.module("\(store.judgement.conflicts.count) duplicates · \(store.judgement.totalCount) secrets selected"))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
  }

  private var duplicateList: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(.module("Duplicates (\(store.judgement.conflicts.count))"))
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray700))
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)

      // 목록만 스크롤한다. 순차로만 이동하므로 행은 누를 수 없고, 현재 검토 중인 행이 선택 표시다.
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 4) {
            ForEach(store.judgement.conflicts) { conflict in
              ImportedSecretRowView(
                name: conflict.name,
                subTypeText: subTypeText(for: conflict),
                isHighlighted: store.selectedConflictIndex == conflict.index,
                service: conflict.service,
                typeIcon: conflict.secretType.icon
              )
              .id(conflict.index)
            }
          }
          .padding(.horizontal, 16)
        }
        .onChange(of: store.selectedConflictIndex) { _, index in
          guard let index else { return }
          withAnimation { proxy.scrollTo(index, anchor: .center) }
        }
        .padding(.bottom, 12)
      }
    }
    .frame(width: 260)
  }

  @ViewBuilder
  private var actionPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(.module("Choose an action"))
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray700))

      if let conflict = store.selectedConflict {
        if conflict.target.isExistingSecret {
          HStack(alignment: .top, spacing: 8) {
            DuplicateActionOptionView(
              title: String.module("Overwrite"),
              description: String.module("Replace the existing secret with the imported secret."),
              isSelected: store.resolutions[conflict.index] == .overwrite,
              action: { store.send(.didSelectOverwrite(index: conflict.index)) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            if hasMultipleConflicts {
              applyToAllButton { store.send(.didTapApplyOverwriteToAll) }
            }
          }
        }

        DuplicateActionOptionView(
          title: String.module("Rename"),
          description: String.module("Keep both secrets by giving the imported secret a new name."),
          isSelected: isRenameSelected(conflict.index),
          action: { store.send(.didSelectRename(index: conflict.index)) }
        )

        if isRenameSelected(conflict.index) {
          DVTextField(
            conflict.name,
            text: renameTextBinding(for: conflict.index),
            errorMessage: store.renameConflicts.contains(conflict.index) ? String.module("This name is already in use.") : nil,
            reservesErrorSpace: true
          )
          .dvShake(trigger: store.shakeCount)
          .padding(.leading, 16 + 8)
        }

        HStack(alignment: .top, spacing: 8) {
          DuplicateActionOptionView(
            title: String.module("Skip"),
            description: String.module("Keep the existing secret and skip this item."),
            isSelected: store.resolutions[conflict.index] == .skip,
            action: { store.send(.didSelectSkip(index: conflict.index)) }
          )
          .frame(maxWidth: .infinity, alignment: .leading)
          if hasMultipleConflicts {
            applyToAllButton { store.send(.didTapApplySkipToAll) }
          }
        }
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
  }

  private var footer: some View {
    HStack {
      Text(.module("\(store.importCount) to import · \(store.skippedCount) skipped"))
        .dvFont(.captionMDRegular)
        .foregroundStyle(Color.dv(.gray700))

      Spacer()

      DVButton(titleText: .module("Back"), style: .secondary) {
        store.send(.didTapCancel)
      }
      DVButton(titleText: .module("Prev"), style: .secondary) {
        store.send(.didTapPrevious)
      }
      .disabled(!store.canGoBack)
      DVButton(
        titleText: store.isLastConflict ? String.module("Done") : String.module("Next"),
        style: .secondaryProminent
      ) {
        store.send(.didTapNext)
      }
      .disabled(!store.canAdvance)
    }
    .padding(20)
  }
}

// MARK: - Private

extension ReviewDuplicatesView {

  private func isRenameSelected(_ index: Int) -> Bool {
    if case .rename = store.resolutions[index] { return true }
    return false
  }

  private var hasMultipleConflicts: Bool {
    store.judgement.conflicts.count > 1
  }

  private func applyToAllButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(.module("Apply to all"))
        .dvFont(.captionMDSemibold)
        .foregroundStyle(Color.dv(.vaultGreen))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.dv(.vaultGreenTint)))
    }
    .buttonStyle(.plain)
    .fixedSize()
  }

  private func renameTextBinding(for index: Int) -> Binding<String> {
    Binding(
      get: { store.resolutions[index]?.renamedName ?? "" },
      set: { store.send(.didChangeRenameText(index: index, text: $0)) }
    )
  }

  private func subTypeText(for conflict: ImportDuplicateConflict) -> String {
    if let subType = conflict.subType {
      return String(localized: subType.creatableSubType.displayName)
    }
    return String(localized: conflict.secretType.creatableType.displayName)
  }
}

// MARK: - Preview

#if DEBUG

#Preview("충돌 2건 — 금고/파일 내부") {
  ReviewDuplicatesView(
    store: Store(
      initialState: ReviewDuplicatesFeature.State(
        judgement: ImportDuplicateJudgement(
          totalCount: 5,
          conflicts: [
            ImportDuplicateConflict(
              index: 0,
              name: "GitHub Token",
              secretType: .apiKeyToken,
              subType: .accessToken,
              target: .existingSecret(id: UUID())
            ),
            ImportDuplicateConflict(
              index: 1,
              name: "Staging DB",
              secretType: .database,
              subType: nil,
              target: .itemInFile(index: 0)
            ),
            ImportDuplicateConflict(
              index: 2,
              name: "Example Secret",
              secretType: .apiKeyToken,
              subType: .apiKey,
              target: .existingSecret(id: UUID())
            )
          ]
        )
      )
    ) {
      ReviewDuplicatesFeature()
    }
  )
}

#endif
