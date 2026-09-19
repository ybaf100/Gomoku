# Gomoku — Xcode / TestFlight 전달 안내

## 바로 열기

ZIP 전체를 압축 해제한 뒤 **Gomoku-Xcode/Gomoku.xcodeproj**를 Xcode에서 여세요.
`.xcodeproj`만 따로 옮기면 소스 경로가 끊어집니다. **Gomoku-Xcode 폴더 전체**를 유지해 주세요.
프로젝트는 이미 생성되어 있어 XcodeGen 설치가 필요 없습니다. 외부 패키지 의존성도 없습니다.

게임 코드는 ybaf100/Gomoku의 main 커밋 `32e234e42b454d1dfb6e170ef47a1f22b40eba2e` 기준입니다.
랜덤/지능형 흑백 교대, 흑 차례 금수 표시, 기권패, 시간 충전, 라이트/다크/시스템 모드를 포함합니다.
전달본에 버전 1.0 / 빌드 1, 자동 서명 설정, 기본 앱 아이콘, 개인정보 API 사용 사유 파일을 추가했습니다.
원본 main 게임 로직은 변경하지 않았습니다.

## 개발자가 진행할 순서

1. Mac에서 최신 지원 Xcode를 사용하세요. 현재 Apple 안내상 iOS 업로드 빌드는 Xcode 26 이상이 필요합니다.
2. Xcode > Settings > Accounts에 Apple Developer Program 계정을 추가하세요.
3. 프로젝트 > TARGETS > Gomoku > Signing & Capabilities에서 Automatically manage signing을 켜고 본인의 유료 개발자 Team을 선택하세요. UI 테스트를 실행할 경우 GomokuUITests에도 Team을 지정하세요.
4. 기본 Bundle Identifier는 `com.ybaf100.Gomoku`입니다. 본인 팀에서 이 ID를 사용할 수 없다면 고유한 ID로 변경하고, App Store Connect의 앱 기록에도 같은 ID를 사용하세요. 테스트 타깃 ID도 충돌하지 않게 맞추세요.
5. App Store Connect > Apps > + > New App에서 iOS 앱 기록을 생성하세요. 이름, 기본 언어, Bundle ID, SKU를 입력합니다. 기존 앱을 업데이트하는 경우에는 기존 Bundle ID를 유지하세요.
6. Xcode에서 Gomoku 스킴과 Any iOS Device (arm64) 등 실제 기기용 빌드 대상을 선택하고 Product > Archive를 실행하세요.
7. Organizer에서 해당 아카이브를 선택하고 Distribute App > App Store Connect 경로로 업로드하세요. 필요한 경우 Validate App으로 먼저 확인하세요. 배포 화면의 표현은 Xcode 버전에 따라 조금 다를 수 있습니다.
8. 처리 완료 후 App Store Connect > TestFlight에서 테스트 정보·연락 이메일·수출 규정 질문을 확인하고 테스터를 추가하세요. 외부 테스터에게 처음 배포할 때는 베타 심사가 필요할 수 있습니다.
9. 환희에게 TestFlight 초대 이메일 또는 공개 초대 링크를 보내 주세요. 공개 링크는 외부 테스트 그룹에서 설정합니다.

같은 버전으로 다시 업로드할 때는 Build 값을 증가시켜 주세요. 다른 Team/Bundle ID로 설치하면 기존 사이드로딩 앱의 저장 데이터가 이어지지 않을 수 있습니다.

## 포함 파일과 검증 범위

- Gomoku.xcodeproj: 생성된 Xcode 프로젝트와 공유 Gomoku 스킴
- Gomoku/: Swift 소스, Assets.xcassets/AppIcon, PrivacyInfo.xcprivacy
- GomokuUITests/ 및 Tests/: UI/게임 로직 회귀 검사
- project.yml: 프로젝트 재생성용 XcodeGen 설정
- scripts/make-handoff-icon.swift: 기본 아이콘을 다시 만드는 편집 가능한 코드
- BUILD-ENVIRONMENT.txt: 전달본 Archive 검증에 사용한 Xcode 버전
- HANDOFF-COMMIT.txt: 전달본 생성 커밋

서명 없는 Release Archive를 CI에서 검증했습니다. 개발자 인증서와 프로비저닝 프로파일은 포함하지 않았으며, 실제 App Store Connect 업로드·Apple 심사는 수행하지 않았습니다.

이 버전은 네트워크 전송·광고·분석 SDK가 없는 로컬 게임입니다. PrivacyInfo.xcprivacy에는 앱 자체 설정/기보 저장(UserDefaults: CA92.1)과 게임 시계/AI 시간 제한의 경과 시간 측정(SystemBootTime: 35F9.1)을 선언했습니다. 추적/수집은 선언하지 않습니다. 이후 SDK나 네트워크 기능을 추가하면 선언을 다시 검토하세요.

## Apple 공식 안내

- [빌드 업로드와 Xcode 요구사항](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [App Store Connect 앱 기록 생성](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [TestFlight 배포 흐름](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Required Reason API 선언](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
