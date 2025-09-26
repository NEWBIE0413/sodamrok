# Flutter 프런트 착수 메모

## 1. 현재 정리된 참고 문서
- `design/design-pillars.md`: 브랜드 무드, 레이아웃 규칙, 색상/타이포 정책
- `design/layout-blueprint.md`: TopBar + FloatingActionDock 구조, 오버레이/시트 패턴, 컴포넌트 정의

## 2. 초반 개발 로드맵
1. Flutter 프로젝트 생성 (`flutter create sodamrok_app`) 후 모듈 구조 세팅 (`lib/core`, `lib/features/...`)
2. 전역 테마 구성: `ThemeData`, 색상/타이포/spacing constant, ExpandingSearchBar, FloatingActionDock 기본 구현
3. Navigation Shell: TopBar + GoRouter + 플로팅 도크 조합. 홈 지도 + 피드 시트, Trip/검색/프로필 모달 라우트 정의
4. 공통 위젯 제작 (FloatingActionDock, BadgeChip, TripCard, TripPlaceStepper 등) 과 데모 스토리 작성
5. 탐색 화면: 지도 mock + 피드 peek sheet + 추천 CTA 시나리오
6. Trip 오버레이: 추천 Carousel, Stepper, CTA (시작/저장)
7. 검색 탭: TopBar 확장 애니메이션, 필터 칩/장소 리스트 골격
8. 상태관리(Riverpod) 컨테이너 세팅, Mock Provider로 UI 연동

## 3. 환경 변수 & 실행 가이드
- API 서버:
  - Django 백엔드 기동 후 `http://localhost:8000/api/v1` 기준으로 통신
  - `seed_home_feed` 명령으로 홈 피드 샘플 데이터 준비
- 런 명령 예시
  ```bash
  flutter run \
    --dart-define=API_BASE_URL=http://localhost:8000/api \
    --dart-define=API_AUTH_TOKEN=<JWT 토큰> \
    --dart-define=USE_MOCK_FEED=false
  ```
- 토큰 오류(401) 시 `USE_MOCK_FEED=true`로 Mock 피드 전환 후 UI 확인 가능
- 의존 패키지 추가 후 `flutter pub get` 필수 (dio, shared_preferences 등)
- 최초 실행 시 로그인 모달이 노출되며, 성공 후 홈 피드가 갱신됨

## 4. 주요 패키지 (계획)
- `flutter_riverpod`, `flutter_hooks`, `hooks_riverpod`
- `go_router`
- `freezed`, `json_serializable`
- `retrofit`
- `mapbox_gl` 또는 `google_maps_flutter`
- `lottie`

## 5. 검증 계획
- Sprint 1: TopBar + FloatingActionDock + 홈 피드 시트 골격
- Sprint 2: 추천/검색 오버레이 Mock 연동, 상태 관리 구조 정리
- 이후: 실제 API 연동, 위치 권한/푸시 처리, 파티·친구 기능 확장
