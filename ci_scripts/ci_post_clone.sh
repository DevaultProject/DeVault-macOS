#!/bin/sh

#  ci_post_clone.sh
#  Xcode Cloud가 소스를 클론한 직후, 의존성 해석·빌드 전에 실행된다.
#
#  이 레포는 .xcworkspace/.xcodeproj를 커밋하지 않고 Tuist로 생성한다(.gitignore 참고).
#  따라서 Xcode Cloud가 빌드를 시작하려면 여기서 워크스페이스를 먼저 만들어야 한다.
#
#    mise로 .mise.toml에 핀된 Tuist(4.191.0)를 설치 → tuist install(SPM) → tuist generate
#
#  로컬 setup.sh와 같은 도구/버전을 쓰므로 CI와 로컬 빌드가 어긋나지 않는다.

set -e

# Xcode Cloud는 ci_scripts/에서 스크립트를 실행한다. .mise.toml·Tuist 매니페스트가 있는
# 레포 루트로 이동해야 mise가 핀된 버전을, tuist가 프로젝트를 올바르게 읽는다.
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "=== [ci_post_clone] mise 설치 ==="
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
export MISE_YES=1                                  # 비대화형 CI: 확인 프롬프트 자동 승인
mise trust "$CI_PRIMARY_REPOSITORY_PATH/.mise.toml" # 처음 클론한 config를 신뢰 처리

echo "=== [ci_post_clone] 핀된 도구 설치 (.mise.toml → Tuist 4.191.0) ==="
mise install

echo "=== [ci_post_clone] SPM 의존성 해석 (tuist install) ==="
mise exec -- tuist install

# TUIST_CI_SIGNING=1 → Project.swift가 CI 배포 서명(Apple Distribution, Automatic)을 선택한다.
#   로컬 개발용 "Apple Development" 고정을 그대로 쓰면 App Store 아카이브가 개발 인증서로
#   서명되어 업로드에서 거부되므로, CI에서는 반드시 이 분기로 생성한다.
# TUIST_BUILD_NUMBER=$CI_BUILD_NUMBER → 업로드마다 고유·증가하는 빌드 번호를 CFBundleVersion에 주입.
#   Xcode Cloud가 제공하는 값이며, 없으면(로컬 등) Project.swift 기본값 "1"로 떨어진다.
# TUIST_MARKETING_VERSION=$CI_TAG → 태그 빌드의 버전을 CFBundleShortVersionString에 주입.
#   태그가 없는 CI 빌드는 기존 마케팅 버전(1.0.0)을 사용한다.
marketing_version="${CI_TAG:-1.0.0}"
if [ -n "${CI_TAG:-}" ]; then
    if ! printf '%s\n' "$CI_TAG" | awk -F. 'NF == 3 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ { valid = 1 } END { exit !valid }'; then
        echo "유효하지 않은 릴리스 태그: $CI_TAG (예: 1.0.1)" >&2
        exit 1
    fi
fi

echo "=== [ci_post_clone] 워크스페이스 생성 (배포 서명 + 버전 $marketing_version + 빌드 번호 ${CI_BUILD_NUMBER:-1}) ==="
TUIST_CI_SIGNING=1 \
TUIST_MARKETING_VERSION="$marketing_version" \
TUIST_BUILD_NUMBER="${CI_BUILD_NUMBER:-1}" \
    mise exec -- tuist generate --no-open

echo "=== [ci_post_clone] 완료 ==="
