// Copyright © 2026 Devault. All rights reserved

import SwiftUI

/// Import 화면들(Preview·Review Duplicates)이 공유하는 시크릿 행 — 원형 아이콘 + 이름 + 서브타입 배지.
/// `isHighlighted`는 Preview에서 "이게 들어온다"를 강조할 때만 켠다.
public struct ImportedSecretRowView: View {

    // MARK: - Properties

    private let name: String
    private let subTypeText: String
    private let isHighlighted: Bool
    /// "duplicated" 같은 우측 상태 문구. 문자열은 호출부가 로컬라이즈해서 넘긴다.
    private let statusText: String?
    /// 서비스 로고 매칭용(예: "GitHub"). `DVVaultContainer`와 같은 규칙 — 매칭 실패 시 첫 글자, 그마저 없으면 typeIcon.
    private let service: String?
    /// 원형 아이콘 폴백 — DVDesign은 DVDomain(`SecretType`)을 모르므로 호출부가 매핑해서 넘긴다.
    private let typeIcon: Image?

    // MARK: - Init

    public init(
        name: String,
        subTypeText: String,
        isHighlighted: Bool = false,
        statusText: String? = nil,
        service: String? = nil,
        typeIcon: Image? = nil
    ) {
        self.name = name
        self.subTypeText = subTypeText
        self.isHighlighted = isHighlighted
        self.statusText = statusText
        self.service = service
        self.typeIcon = typeIcon
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 14) {
            avatarCircle

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .dvFont(.bodyLG)
                    .foregroundStyle(Color.dv(.gray900))
                    .lineLimit(1)
                subTypeBadge
            }

            Spacer(minLength: 8)

            if let statusText {
                Text(statusText)
                    .dvFont(.bodyMD)
                    .foregroundStyle(Color.dv(.gray500))
            }
        }
        .padding(12)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.dv(.vaultGreenTint))
            }
        }
        // 강조되지 않은 행은 배경이 없어 Spacer가 밀어낸 빈 공간이 기본적으로 탭 영역 밖이다 —
        // 행 전체(패딩 포함)를 사각형 하나로 지정해 어디를 눌러도 반응하게 한다.
        .contentShape(Rectangle())
    }
}

// MARK: - Subviews

extension ImportedSecretRowView {

    /// `DVVaultContainer`와 같은 우선순위: 로고 매칭 → 첫 글자 → 타입 아이콘.
    @ViewBuilder
    private var avatarCircle: some View {
        if let logo = ServiceLogoCatalog.logo(forService: service) {
            logoAvatar(logo)
        } else if let serviceInitial {
            initialAvatar(serviceInitial)
        } else {
            typeIconAvatar
        }
    }

    private func logoAvatar(_ logo: DVServiceLogo) -> some View {
        Circle()
            .fill(logo.brandColor)
            .frame(width: 40, height: 40)
            .overlay {
                if logo.rendersAsTemplate {
                    Image(logo.assetName, bundle: .module)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(logo.glyphColor)
                        .frame(width: 20, height: 20)
                } else {
                    // 배경+글리프가 한 path로 합쳐진 에셋: template 틴트를 걸지 않고 원본 색상 그대로 그린다.
                    Image(logo.assetName, bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
            }
    }

    private func initialAvatar(_ initial: String) -> some View {
        Circle()
            .fill(Color.dv(.gray300))
            .frame(width: 40, height: 40)
            .overlay(
                Text(initial)
                    .dvFont(.headingLG)
                    .foregroundStyle(Color.dv(.gray600))
            )
    }

    @ViewBuilder
    private var typeIconAvatar: some View {
        Circle()
            .fill(Color.dv(.gray200))
            .frame(width: 40, height: 40)
            .overlay {
                if let typeIcon {
                    typeIcon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.dv(.gray600))
                }
            }
    }

    /// 로고 매칭에 실패했지만 `service` 자체는 채워져 있을 때 쓰는 중간 폴백.
    private var serviceInitial: String? {
        guard let service else { return nil }
        guard let first = service.trimmingCharacters(in: .whitespacesAndNewlines).first else { return nil }
        return String(first).uppercased()
    }

    private var subTypeBadge: some View {
        Text(subTypeText)
            .dvFont(.captionMDSemibold)
            .foregroundStyle(Color.dv(.white))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.dv(.vaultGreen)))
    }
}

// MARK: - Preview

#if DEBUG

#Preview("기본") {
    ImportedSecretRowView(name: "GitHub Token", subTypeText: "Access Token", typeIcon: Image(systemName: "key.fill"))
        .padding(20)
        .frame(width: 380)
}

#Preview("강조 — Preview 화면") {
    ImportedSecretRowView(
        name: "GitHub Token",
        subTypeText: "Access Token",
        isHighlighted: true,
        typeIcon: Image(systemName: "key.fill")
    )
    .padding(20)
    .frame(width: 380)
}

#Preview("중복됨") {
    ImportedSecretRowView(
        name: "GitHub Token",
        subTypeText: "Access Token",
        isHighlighted: true,
        statusText: "Duplicated",
        typeIcon: Image(systemName: "key.fill")
    )
    .padding(20)
    .frame(width: 380)
}

#Preview("서비스 로고 매칭") {
    ImportedSecretRowView(
        name: "Personal Access Token",
        subTypeText: "Access Token",
        isHighlighted: true,
        service: "GitHub",
        typeIcon: Image(systemName: "key.fill")
    )
    .padding(20)
    .frame(width: 380)
}

#Preview("좁은 폭 — 이름 길어짐") {
    ImportedSecretRowView(name: "Very Long Secret Name That Should Truncate", subTypeText: "API Webhook Secret")
        .padding(12)
        .frame(width: 240)
}

#endif
