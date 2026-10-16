// Copyright © 2026 Devault. All rights reserved

/// 시스템 인증 시트(Touch ID·암호)에 표시할 인증 사유.
///
/// 한곳에 모으는 이유는 **같은 동작이 경로에 따라 다른 문장을 보여주지 않게** 하려는 것이다.
/// 시크릿 값 열람은 첫 복호화(`RevealSecretPayloadUseCase`)와 인증 창 만료 후 재인증(조회 화면)으로
/// 갈리는데, 사용자에게는 눈 버튼 하나를 누른 것일 뿐이다.
///
/// 문자열이 아니라 case인 것은 **문구를 소비처(Presentation)가 만들기 때문**이다. 로컬라이제이션
/// 카탈로그가 DVPresentation에만 있어 도메인은 문장을 들 수 없다. `SecurityNotification`과 같은
/// 구조로, 도메인은 사유만 말하고 실제 문장은 `LocalUserAuthenticationServiceImpl`이 주입받은
/// 팩토리로 만든다.
public enum AuthenticationReason: Equatable, Sendable {

    /// 시크릿 값 열람. 첫 복호화와 재인증이 같은 사유를 쓴다.
    case revealSecret

    /// 시크릿 값 복사. 복사 시 인증 설정이 켜진 경우에만 사용한다.
    case copySecret

    /// 수정 화면 진입. 열람과 같은 복호화를 타지만 사용자가 누른 것은 수정 버튼이므로 사유를 나눈다 —
    /// 고치려고 눌렀는데 "확인하려면"이라고 물으면 잘못 눌렀나 싶어진다.
    case editSecret

    /// 잠금 화면에서의 잠금 해제.
    case unlock

    /// 온보딩에서 Touch ID 사용을 켤 때.
    case enableTouchID

    /// 설정의 전체 데이터 삭제. 되돌릴 수 없는 작업이라 삭제 직전에 한 번 더 묻는다.
    case deleteAllData

    /// 시크릿 공유(.dvt) 파일 생성 직전.
    case exportSecrets

    /// 시크릿 공유(.dvt) 파일 가져오기 실행 직전.
    case importSecrets
}
