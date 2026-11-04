// Copyright © 2026 Devault. All rights reserved

import SwiftUI

import ComposableArchitecture
import DVDesign
import DVDomain

// MARK: - ImportPreviewView

public struct ImportPreviewView: View {

  // MARK: - Properties

  @Bindable var store: StoreOf<ImportPreviewFeature>

  // MARK: - Init

  public init(store: StoreOf<ImportPreviewFeature>) {
    self.store = store
  }

  // MARK: - Body

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      if case .single = store.variant {
        singleContent
      } else {
        selectionHeader
        secretList
      }
      Divider()
      footer
    }
    .frame(width: 480)
    .task { store.send(.task) }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

// MARK: - Header

extension ImportPreviewView {

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(.module("Import \(store.payload.secrets.count) secrets"))
        .dvFont(.headingLG)
        .foregroundStyle(Color.dv(.gray900))
      Text(store.fileName)
        .dvFont(.bodyMD)
        .foregroundStyle(Color.dv(.gray600))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
  }
}

// MARK: - Single

extension ImportPreviewView {

  private var singleContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let export = store.payload.secrets.first {
        ImportedSecretRowView(
          name: export.name,
          subTypeText: subTypeText(for: export),
          isHighlighted: true
        )
      }
      Divider()
      HStack {
        Text(.module("Add to project"))
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.gray900))
        Spacer()
        singleProjectDropdown
      }
    }
    .padding(20)
  }

  private var singleProjectDropdown: some View {
    DVDropdown(selectedProjectName ?? String.module("Select Project")) {
      Button(String.module("None")) { store.send(.didSelectProjectChoice(.none)) }
      ForEach(store.availableProjects) { project in
        Button(project.name) { store.send(.didSelectProjectChoice(.existing(id: project.id))) }
      }
    }
  }

  private var selectedProjectName: String? {
    guard case .existing(let id) = store.projectChoice else { return nil }
    return store.availableProjects.first { $0.id == id }?.name
  }
}

// MARK: - Selection header (Project · Multiple)

extension ImportPreviewView {

  private var selectionHeader: some View {
    HStack {
      HStack(spacing: 8) {
        DVCheckBox(isChecked: store.selectedIndices.count == store.payload.secrets.count) {
          store.send(.didToggleSelectAll)
        }
        Text(.module("\(store.selectedIndices.count) selected"))
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.gray900))
        if case .project(let name) = store.variant {
          Text(.module("From \(name)"))
            .dvFont(.bodyMD)
            .foregroundStyle(Color.dv(.gray600))
        }
      }
      Spacer()
      if let remaining = store.remainingSlots {
        Text(.module("\(remaining) secrets available"))
          .dvFont(.bodyMD)
          .foregroundStyle(Color.dv(.danger))
      }
    }
    .padding(20)
  }

  private var secretList: some View {
    ScrollView {
      LazyVStack(spacing: 4) {
        ForEach(Array(store.payload.secrets.enumerated()), id: \.offset) { index, export in
          HStack(spacing: 14) {
            DVCheckBox(isChecked: store.selectedIndices.contains(index)) {
              store.send(.didToggleSelection(index: index))
            }
            ImportedSecretRowView(
              name: export.name,
              subTypeText: subTypeText(for: export),
              isHighlighted: store.selectedIndices.contains(index),
              statusText: store.duplicateIndices.contains(index) ? String.module("Duplicated") : nil
            )
          }
        }
      }
      .padding(.horizontal, 20)

      if store.showsProjectSelection {
        Divider().padding(.vertical, 12)
        projectSection
      }
    }
  }
}

// MARK: - Project section (Project 변형만)

extension ImportPreviewView {

  private var projectSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(.module("Import project as"))
        .dvFont(.captionLG)
        .foregroundStyle(Color.dv(.gray600))

      if case .project(let name) = store.variant {
        DVRadioButton(
          isSelected: isCreateNewSelected,
          isInteractive: store.canCreateNewProject,
          action: { store.send(.didSelectProjectChoice(.create(name: name))) }
        ) {
          Text(.module("Create new project \"\(name)\""))
            .dvFont(.bodyMD)
            .foregroundStyle(store.canCreateNewProject ? Color.dv(.gray900) : Color.dv(.gray400))
        }
      }

      DVRadioButton(
        isSelected: isMergeSelected,
        isInteractive: !store.availableProjects.isEmpty,
        action: {
          if case .existing(let id) = store.projectChoice { store.send(.didSelectProjectChoice(.existing(id: id))) }
          else if let first = store.availableProjects.first {
            store.send(.didSelectProjectChoice(.existing(id: first.id)))
          }
        }
      ) {
        HStack(spacing: 8) {
          Text(.module("Merge into existing project"))
            .dvFont(.bodyMD)
            .foregroundStyle(store.availableProjects.isEmpty ? Color.dv(.gray400) : Color.dv(.gray900))
          mergeProjectDropdown
        }
      }

      DVRadioButton(
        String.module("Import without project"),
        isSelected: store.projectChoice == .none,
        action: { store.send(.didSelectProjectChoice(.none)) }
      )
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
  }

  private var isCreateNewSelected: Bool {
    if case .create = store.projectChoice { return true }
    return false
  }

  private var isMergeSelected: Bool {
    if case .existing = store.projectChoice { return true }
    return false
  }

  private var mergeProjectDropdown: some View {
    DVDropdown(mergeProjectName ?? String.module("Select Project"), size: .xs) {
      ForEach(store.availableProjects) { project in
        Button(project.name) { store.send(.didSelectProjectChoice(.existing(id: project.id))) }
      }
    }
  }

  private var mergeProjectName: String? {
    guard case .existing(let id) = store.projectChoice else { return nil }
    return store.availableProjects.first { $0.id == id }?.name
  }
}

// MARK: - Footer

extension ImportPreviewView {

  private var footer: some View {
    HStack {
      Spacer()
      DVButton(titleText: .module("Cancel"), style: .secondary) {
        store.send(.didTapCancel)
      }
      DVButton(titleText: importButtonTitle, style: .secondaryProminent) {
        store.send(.didTapImport)
      }
      .disabled(store.selectedIndices.isEmpty || store.isCheckingImport)
    }
    .padding(20)
  }

  private var importButtonTitle: String {
    if case .single = store.variant { return String.module("Import") }
    return String.module("Import (\(store.selectedIndices.count))")
  }
}

// MARK: - Private

extension ImportPreviewView {

  private func subTypeText(for export: DevaultSecretExport) -> String {
    if let subType = export.content.subType {
      return String(localized: subType.creatableSubType.displayName)
    }
    return String(localized: export.content.secretType.creatableType.displayName)
  }
}

// MARK: - Preview

#if DEBUG

#Preview("Single") {
  ImportPreviewView(store: previewStore(fileName: "GitHub-Token.dvt", count: 1, projectName: nil))
}

#Preview("Project") {
  ImportPreviewView(store: previewStore(fileName: "DrinkiG.dvt", count: 4, projectName: "DrinkiG"))
}

#Preview("Multiple") {
  ImportPreviewView(store: previewStore(fileName: "AWS-Keys.dvt", count: 5, projectName: nil))
}

private func previewStore(fileName: String, count: Int, projectName: String?) -> StoreOf<ImportPreviewFeature> {
  let secrets = (0..<count).map { index in
    DevaultSecretExport(
      name: "Secret \(index + 1)",
      content: .accessToken(.init(value: "token"), nil),
      payloadSchemaVersion: 1
    )
  }
  return Store(
    initialState: ImportPreviewFeature.State(
      fileName: fileName,
      payload: DevaultContainerPayload(projectName: projectName, secrets: secrets)
    )
  ) {
    ImportPreviewFeature()
  }
}

#endif
