# Directioner

macOS 메뉴바 앱. Logic Pro에 클릭 트랙 오디오 파일을 단축키로 빠르게 삽입.

## 빌드 및 실행

코드 수정 후 빌드·설치·실행은 항상 아래 스크립트를 사용:

```bash
cd ~/Desktop/app/ClickTrackInserter && ./dev-run.sh
```

`xcodebuild`만 단독으로 쓰지 말 것. `dev-run.sh`가 빌드 → 기존 앱 종료 → 손쉬운 사용 권한 초기화 → /Applications 설치 → 실행까지 자동으로 처리함.

## 프로젝트 구조

- `ClickTrackInserter.xcodeproj` — 메인 프로젝트 (이걸 사용)
- `ClickTrackInserter/ClickTrackInserter.xcodeproj` — 내부 서브 프로젝트 (빌드는 여기서 실제로 일어남)
- 새 Swift 파일 추가 시 두 xcodeproj 모두에 등록 필요

## 주요 파일

| 파일 | 역할 |
|------|------|
| `AppDelegate.swift` | 앱 진입점, 단축키·팝업·드롭 흐름 조율 |
| `HotkeyMonitor.swift` | Shift 두 번 감지 (CGEventTap) |
| `InputPopupController.swift` | 약어 입력 팝업 + 매핑 목록 드롭다운 |
| `DropIndicator.swift` | 커서 따라다니는 배지 + 클릭/ESC 감지 |
| `DragSourceWindow.swift` | NSDraggingSession으로 파일 드롭 실행 |
| `LogicProController.swift` | Logic Pro 프로세스 확인, 드롭 좌표 처리 |
| `MappingStore.swift` | 약어↔파일 매핑 저장 (UserDefaults) |
| `SettingsView.swift` | 설정 UI (파일 추가·편집·삭제·초기화) |
| `OnboardingView.swift` | 첫 실행 온보딩 (권한·파일등록·사용법) |

## 좌표계 주의

- AX API = CG 좌표 (좌상단 원점, Y 아래 증가)
- NSWindow.setFrameOrigin = AppKit 좌표 (좌하단 원점, Y 위 증가)
- CGWarp는 CG 좌표 직접 사용, 윈도우 배치만 `screenH - cgY` 변환
