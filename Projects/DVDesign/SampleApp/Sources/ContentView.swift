// Copyright © 2026 Devault. All rights reserved

import SwiftUI
import DVDesign

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section("Foundation") {
                    NavigationLink("Typography") {
                        TypographyPreviewView()
                    }
                    NavigationLink("Color") {
                        ColorPreviewView()
                    }
                    NavigationLink("Size") {
                        SizePreviewView()
                    }
                }

                Section("Components") {
                    ForEach(Component.all, id: \.self) { component in
                        NavigationLink(component.name) {
                            detailView(for: component)
                        }
                    }
                }
            }
            .navigationTitle("DVDesign")
        } detail: {
            Text("컴포넌트를 선택하세요")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    @ViewBuilder
    private func detailView(for component: Component) -> some View {
        switch component.name {
        case "DVStepIndicator":
            DVStepIndicatorPreviewView()
        case "DVCategory":
            DVCategoryPreviewView()
        case "DVProjectContainer":
            DVProjectContainerPreviewView()
        case "DVVaultContainer":
            DVVaultContainerPreviewView()
        case "DVButton":
            DVButtonPreviewView()
        case "DVCheckBox":
            DVCheckBoxPreviewView()
        case "DVTitleBar":
            DVTitleBarPreviewView()
        case "DVSecretType":
            DVSecretTypePreviewView()
        case "DVRadioButton", "DVRadioButtonGroup":
            RadioButtonPreviewView()
        case "DVTextField":
            TextFieldPreviewView()
        case "DVTextContainer":
            TextContainerPreviewView()
        case "DVChip":
            DVChipPreviewView()
        case "DVMultilineTextField":
            DVMultilineTextFieldPreviewView()
        case "DVDropdown":
            DVDropdownPreviewView()
        case "DVLabeledField":
            DVLabeledFieldPreviewView()
        case "DVChipsField":
            DVChipsFieldPreviewView()
        case "DVMultiSelectDropdown":
            DVMultiSelectDropdownPreviewView()
        default:
            ComponentPlaceholderView(name: component.name)
        }
    }
}

// MARK: - Placeholder Detail

private struct ComponentPlaceholderView: View {
    let name: String

    var body: some View {
        VStack(spacing: 12) {
            Text(name)
                .font(.title2)
                .fontWeight(.semibold)
            Text("🚧 구현 예정")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(name)
    }
}

// MARK: - Data

private struct Component: Hashable {
    let name: String

    static let all: [Component] = [
        Component(name: "DVStepIndicator"),
        Component(name: "DVProjectContainer"),
        Component(name: "DVVaultContainer"),
        Component(name: "DVCategory"),
        Component(name: "DVButton"),
        Component(name: "DVCheckBox"),
        Component(name: "DVMultiSelectDropdown"),
        Component(name: "DVTitleBar"),
        Component(name: "DVSecretType"),
        Component(name: "DVRadioButton"),
        Component(name: "DVRadioButtonGroup"),
        Component(name: "DVTextContainer"),
        Component(name: "DVTextField"),
        Component(name: "DVChip"),
        Component(name: "DVMultilineTextField"),
        Component(name: "DVDropdown"),
        Component(name: "DVLabeledField"),
        Component(name: "DVChipsField"),
    ]
}
