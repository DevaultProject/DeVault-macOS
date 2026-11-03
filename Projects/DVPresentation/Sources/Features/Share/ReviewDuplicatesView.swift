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
    .frame(width: 720, height: 420)
  }
}

// MARK: - Subviews

extension ReviewDuplicatesView {

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(.module("Review duplicates"))
        .dvFont(.headingLG)
        .foregroundStyle(Color.dv(.gray900))
      Text(.module("\(store.judgement.conflicts.count) duplicates · \(store.judgement.totalCount) secrets selected"))
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray600))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
  }

  private var duplicateList: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(.module("Duplicates (\(store.judgement.conflicts.count))"))
        .dvFont(.captionLG)
        .foregroundStyle(Color.dv(.gray600))
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)

      ScrollView {
        LazyVStack(spacing: 4) {
          ForEach(store.judgement.conflicts) { conflict in
            Button {
              store.send(.didSelectConflict(index: conflict.index))
            } label: {
              ImportedSecretRowView(
                name: conflict.name,
                subTypeText: subTypeText(for: conflict),
                isHighlighted: store.selectedConflictIndex == conflict.index
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 16)
      }
    }
    .frame(width: 260)
  }

  @ViewBuilder
  private var actionPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(.module("Choose an action"))
        .dvFont(.bodyXL)
        .foregroundStyle(Color.dv(.gray900))

      if let conflict = store.selectedConflict {
        if conflict.target.isExistingSecret {
          DuplicateActionOptionView(
            title: String.module("Overwrite"),
            description: String.module("Replace the existing secret with the imported secret."),
            isSelected: store.resolutions[conflict.index] == .overwrite,
            action: { store.send(.didSelectOverwrite(index: conflict.index)) }
          )
        }

        DuplicateActionOptionView(
          title: String.module("Rename"),
          description: String.module("Keep both secrets by giving the imported secret a new name."),
          isSelected: isRenameSelected(conflict.index),
          action: { store.send(.didSelectRename(index: conflict.index)) }
        )

        if isRenameSelected(conflict.index) {
          TextField(conflict.name, text: renameTextBinding(for: conflict.index))
            .textFieldStyle(.roundedBorder)
            .padding(.leading, 16 + 8)
        }

        DuplicateActionOptionView(
          title: String.module("Skip"),
          description: String.module("Keep the existing secret and skip this item."),
          isSelected: store.resolutions[conflict.index] == .skip,
          action: { store.send(.didSelectSkip(index: conflict.index)) }
        )
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
  }

  private var footer: some View {
    HStack {
      Text(.module("\(store.importCount) to import · \(store.skippedCount) skipped"))
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray600))

      Spacer()

      DVButton(titleText: .module("Back"), style: .secondary) {
        store.send(.didTapCancel)
      }
      DVButton(titleText: .module("OK"), style: .secondaryProminent) {
        store.send(.didTapContinue)
      }
      .disabled(!store.canContinue)
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

// MARK: - Target

private extension ImportDuplicateConflict.Target {
  var isExistingSecret: Bool {
    if case .existingSecret = self { return true }
    return false
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
