// Copyright © 2026 Devault. All rights reserved

import AppKit
import SwiftUI

/// 시스템 `TextField` 위에 디자인 토큰만 덧입힌 텍스트 입력 필드.
/// 너비는 ``DVComponentSize``, 높이 32pt 고정(``DVComponentSize/fieldHeight``).
///
/// `isSecure: true`이면 `SecureField` + 우측 눈 아이콘 토글이 자동 표시되고,
/// 토글 시 포커스와 커서 위치가 유지됩니다 (마스킹 상태는 내부 `@State`).
public struct DVTextField: View {

    // MARK: - Properties

    private let placeholder: String
    @Binding private var text: String
    private let size: DVComponentSize
    private let isSecure: Bool
    private let errorMessage: String?
    private let reservesErrorSpace: Bool
    private let revealAccessibilityLabel: String
    private let hideAccessibilityLabel: String

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    // MARK: - Init

    /// - Parameters:
    ///   - placeholder: 빈 값일 때 표시될 안내 문구.
    ///   - text: 입력 값 양방향 바인딩.
    ///   - size: 너비 변형. 기본 ``DVComponentSize/md``.
    ///   - isSecure: 민감 값 마스킹 여부. 기본 `false`.
    ///   - errorMessage: 입력이 거절된 상태의 안내 문구(이미 번역된 값). 있으면 테두리를 ``DVColor/danger``로 그리고 필드 아래에 문구를 보여준다. 기본 `nil`.
    ///   - reservesErrorSpace: 에러가 없을 때도 문구 자리를 비워 둔다. 문구가 생기고 사라질 때 아래 레이아웃이 밀리지 않아야 하는 곳(가운데 정렬 시트 등)에서 켠다. 기본 `false`.
    ///   - revealAccessibilityLabel: 마스킹 해제(표시) 눈 아이콘의 VoiceOver 라벨. 호출부가 번역해서 넘긴다.
    ///   - hideAccessibilityLabel: 마스킹(숨김) 눈 아이콘의 VoiceOver 라벨.
    public init(
        _ placeholder: String,
        text: Binding<String>,
        size: DVComponentSize = .md,
        isSecure: Bool = false,
        errorMessage: String? = nil,
        reservesErrorSpace: Bool = false,
        revealAccessibilityLabel: String = "Show",
        hideAccessibilityLabel: String = "Hide"
    ) {
        self.placeholder = placeholder
        self._text = text
        self.size = size
        self.isSecure = isSecure
        self.errorMessage = errorMessage
        self.reservesErrorSpace = reservesErrorSpace
        self.revealAccessibilityLabel = revealAccessibilityLabel
        self.hideAccessibilityLabel = hideAccessibilityLabel
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field
            if let errorMessage {
                Text(errorMessage)
                    .dvFont(.captionMDRegular)
                    .foregroundStyle(Color.dv(.danger))
                    .frame(maxWidth: size.width, alignment: .leading)
            } else if reservesErrorSpace {
                Text(verbatim: " ")
                    .dvFont(.captionMDRegular)
                    .hidden()
            }
        }
    }

    private var field: some View {
        HStack(spacing: 0) {
            inputField
                .focused($isFocused)
            if isSecure {
                revealToggle
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .dvComponentWidth(size, height: DVComponentSize.fieldHeight)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .stroke(errorMessage == nil ? Color.dv(.gray300) : Color.dv(.danger), lineWidth: 1)
        }
    }
}

// MARK: - Subviews

extension DVTextField {

    private var promptText: Text {
        Text(placeholder).foregroundStyle(Color.dv(.gray400))
    }

    @ViewBuilder
    private var inputField: some View {
        Group {
            if isSecure && !isRevealed {
                SecureField("", text: $text, prompt: promptText)
            } else {
                TextField("", text: $text, prompt: promptText)
            }
        }
        .textFieldStyle(.plain)
        .font(DVFont.bodyLG.font)
        .foregroundStyle(Color.dv(.gray900))
        .tint(Color.dv(.vaultGreen))
    }

    private var revealToggle: some View {
        Button {
            // 스왑 후 포커스 복원 + 커서를 끝으로 (기본 "전체 선택" 회피).
            let wasFocused = isFocused
            isRevealed.toggle()
            if wasFocused {
                Task { @MainActor in
                    isFocused = true
                    DispatchQueue.main.async {
                        Self.moveCursorToEnd()
                    }
                }
            }
        } label: {
            Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.dv(.gray900))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? hideAccessibilityLabel : revealAccessibilityLabel)
    }

    /// Field editor의 커서를 문자열 끝으로 이동 (`@FocusState = true` 시 macOS 기본 "전체 선택" 회피).
    private static func moveCursorToEnd() {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSText else { return }
        let end = (editor.string as NSString).length
        editor.selectedRange = NSRange(location: end, length: 0)
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Placeholder (Empty)") {
    DVTextFieldPlaceholderPreview()
        .padding()
}

#Preview("Active (Filled)") {
    DVTextFieldFilledPreview()
        .padding()
}

#Preview("Sizes") {
    DVTextFieldSizesPreview()
        .padding()
}

#Preview("Secure") {
    DVTextFieldSecurePreview()
        .padding()
}

#Preview("Error") {
    DVTextFieldErrorPreview()
        .padding()
}

private struct DVTextFieldPlaceholderPreview: View {
    @State private var text = ""
    var body: some View {
        DVTextField("e.g DeVault", text: $text, size: .md)
    }
}

private struct DVTextFieldFilledPreview: View {
    @State private var text = "DeVault"
    var body: some View {
        DVTextField("e.g DeVault", text: $text, size: .md)
    }
}

private struct DVTextFieldSizesPreview: View {
    @State private var xs = ""
    @State private var sm = ""
    @State private var md = "DeVault"
    @State private var lg = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DVTextField("XS", text: $xs, size: .xs)
            DVTextField("SM", text: $sm, size: .sm)
            DVTextField("MD", text: $md, size: .md)
            DVTextField("LG", text: $lg, size: .lg)
        }
    }
}

private struct DVTextFieldErrorPreview: View {
    @State private var text = ""

    var body: some View {
        DVTextField("password", text: $text, size: .lg, isSecure: true, errorMessage: "Incorrect password. Please try again.")
    }
}

private struct DVTextFieldSecurePreview: View {
    @State private var apiKey = "ghp_1234567890abcdef"
    @State private var empty = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DVTextField("secret value", text: $apiKey, size: .lg, isSecure: true)
            DVTextField("empty secure", text: $empty, size: .lg, isSecure: true)
        }
    }
}

#endif
