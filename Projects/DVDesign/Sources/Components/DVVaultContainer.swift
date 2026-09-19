// Copyright © 2026 Devault. All rights reserved

import SwiftUI

/// 시스템 `List(selection:)` 안에 행으로 넣어 사용한다.
/// 선택 표시는 List(.sidebar) + `.tint(...)`에 위임, 컨텍스트 메뉴는 호출부에서 `.contextMenu`로 부착.
public struct DVVaultContainer: View {

    // MARK: - Properties

    public let name: String
    public let date: String
    public let service: String?
    /// `service`가 비어 있을 때만 쓰이는 최종 폴백. 호출부가 자신의 타입 분류에 맞는 SF Symbol 등을 넘긴다.
    public let typeIcon: Image?
    /// 우측 만료 강조 아이콘. 어떤 단계로 볼지는 호출부의 만료 정책이 결정한다.
    public let trailingIcon: DVExpiryEmphasis?
    /// `trailingIcon`에 hover 시 뜨는 설명 문구. `trailingIcon`이 `nil`이면 무시된다.
    public let trailingIconTooltip: String?

    // MARK: - Init

    public init(
        name: String,
        date: String,
        service: String? = nil,
        typeIcon: Image? = nil,
        trailingIcon: DVExpiryEmphasis? = nil,
        trailingIconTooltip: String? = nil
    ) {
        self.name = name
        self.date = date
        self.service = service
        self.typeIcon = typeIcon
        self.trailingIcon = trailingIcon
        self.trailingIconTooltip = trailingIconTooltip
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 14) {
            avatarCircle
            textStack
            Spacer(minLength: 8)
            trailingIconView
        }
        .padding(8)
        .frame(minWidth: 200, alignment: .leading)
    }
}

// MARK: - Subviews

extension DVVaultContainer {

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
            .frame(width: 44, height: 44)
            .overlay {
                if logo.rendersAsTemplate {
                    Image(logo.assetName, bundle: .module)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(logo.glyphColor)
                        .frame(width: 22, height: 22)
                } else {
                    // 배경+글리프가 한 path로 합쳐진 에셋: template 틴트를 걸지 않고 원본 색상 그대로 그린다.
                    Image(logo.assetName, bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
            }
    }

    private func initialAvatar(_ initial: String) -> some View {
        Circle()
            .fill(Color.dv(.gray300))
            .frame(width: 44, height: 44)
            .overlay(
                Text(initial)
                    .dvFont(.headingLG)
                    .foregroundStyle(Color.dv(.gray600))
            )
    }

    @ViewBuilder
    private var typeIconAvatar: some View {
        Circle()
            .fill(Color.dv(.gray300))
            .frame(width: 44, height: 44)
            .overlay {
                if let typeIcon {
                    typeIcon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
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

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .dvFont(.bodyLG)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(date)
                .dvFont(.captionMDRegular)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(minWidth: 60, alignment: .leading)
    }

    @ViewBuilder
    private var trailingIconView: some View {
        if let trailingIcon {
            trailingIcon.icon
                .foregroundStyle(Color.dv(trailingIcon.colorToken))
                .fixedSize()
                // `.help(_:)`가 List 행 안에서 안 떠서 커스텀 말풍선으로 우회한다.
                .hoverTooltip(trailingIconTooltip)
                // 툴팁은 마우스 전용이라 접근성 트리에 없다. 상태 문구를 VoiceOver에도 노출한다.
                // 문구가 없으면 요소째 숨긴다 — 빈 라벨은 읽을 것 없는 요소에 VoiceOver를 멈춰 세운다.
                .accessibilityLabel(trailingIconTooltip ?? "")
                .accessibilityHidden(trailingIconTooltip == nil)
        }
    }
}
