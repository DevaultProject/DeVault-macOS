# Git Flow 브랜치 전략

DeVault-macOS는 [git-flow](https://nvie.com/posts/a-successful-git-branching-model/) 기반으로 브랜치를 운영한다. GitHub 기본 브랜치는 `main`이며, `main`은 릴리즈 관련 용도로만 쓴다. `feature/`·`release/`·`hotfix/` 브랜치는 모두 `develop`에서 분기한다.

## 브랜치 구조

| 브랜치 | 역할 | 분기 기준 | 머지 대상 |
|---|---|---|---|
| `main` | 배포 버전. 릴리즈·핫픽스 머지로만 갱신 | — | — |
| `develop` | 개발 기반. 모든 기능 PR의 타겟 | `main` | — |
| `feature/#이슈번호` | 기능 개발 | `develop` | `develop` |
| `release/버전` | 릴리즈 준비 (버전 범프, QA 수정) | `develop` | `main` + `develop` 백머지 |
| `hotfix/버전` | 배포 버전 긴급 수정 | `develop` | `main` + `develop` 백머지 |

## 최초 1회 로컬 세팅

```sh
brew install git-flow
```

클론한 레포 루트에서 아래를 복사해 실행한다. git-flow 설정은 `.git/config` 로컬 전용이라 클론마다 한 번씩 필요하다.

```sh
git config gitflow.branch.master main
git config gitflow.branch.develop develop
git config gitflow.prefix.feature feature/
git config gitflow.prefix.release release/
git config gitflow.prefix.hotfix hotfix/
git config gitflow.prefix.support support/
git config gitflow.prefix.versiontag ""
```

## 작업 흐름

### 기능 개발

```sh
git flow feature start '#123'   # develop에서 feature/#123 분기
```

작업 후 push하고 **develop 타겟으로 PR**을 연다. `git flow feature finish`는 로컬에서 직접 머지하므로 쓰지 않는다 — PR 머지 후 브랜치를 삭제한다.

> ⚠️ 기본 브랜치가 `main`이라 PR의 base가 `main`으로 잡힌다. 기능 PR은 base를 `develop`으로 바꿔야 한다.

### 릴리즈

```sh
git flow release start 1.1.0    # develop에서 release/1.1.0 분기
```

버전 범프와 QA 수정만 커밋한다. 완료되면 **main 타겟으로 PR** → 머지 후 main에 태그를 찍고 develop으로 백머지한다.

```sh
git tag 1.1.0 main && git push origin 1.1.0
```

### 핫픽스

```sh
git flow hotfix start 1.1.1 develop   # develop에서 hotfix/1.1.1 분기 (도구 기본값이 main이라 base를 명시)
```

수정 후 **main 타겟으로 PR** → 머지 후 태그를 찍고 develop으로 백머지한다.

## 태그

버전 태그는 prefix 없이 버전 그대로 쓴다 — `v1.0.0`이 아니라 `1.0.0`.

## 태그 push 자동화

태그가 push되면 두 가지가 자동으로 실행된다.

| 자동화 | 하는 일 |
|---|---|
| Xcode Cloud `Deploy` 워크플로우 | 배포용 macOS 아카이브를 만들어 App Store Connect에 업로드한다 (심사 제출 시 첨부용) |
| GitHub Actions `GitHub Release` (`.github/workflows/release.yml`) | GitHub Release를 생성하고 직전 릴리즈 이후 머지된 PR 목록으로 릴리즈 노트를 자동 작성한다 |

> ⚠️ Xcode Cloud의 빌드 번호(`CI_BUILD_NUMBER`)가 `CFBundleVersion`에 주입된다. App Store Connect는 같은 버전에서 이전 업로드보다 높은 빌드 번호를 요구하므로, 수동 업로드로 번호를 선점했다면 Xcode Cloud 설정에서 다음 빌드 번호를 그보다 크게 올려야 한다.
