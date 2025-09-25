# Flutter 프론트 착수 메모

## 1. 현재 정리된 디자인 문서
- `design/design-pillars.md`: 브랜드 톤, 레이아웃 규칙, 색상/타이포 원칙
- `design/layout-blueprint.md`: BottomNavigation 4탭 구조, 탭별 와이어프레임, 컴포넌트 정의

## 2. 다음 개발 단계 로드맵
1. Flutter 프로젝트 생성 (`flutter create sodamrok_app`) 및 모듈 구조 세팅 (`lib/core`, `lib/features/...`).
2. 디자인 토큰 정의: `ThemeData`, 컬러/타입 스케일, spacing constant, BottomNav 스타일.
3. Navigation Shell 구현: BottomNavigationBar + GoRouter, 기본 탭(`홈`, `트립`, `검색`, `프로필`) scaffold.
4. 공통 컴포넌트(FAB 확장, BadgeChip, TripCard, TripPlaceStepper) 위젯 작성 및 스토리용 샘플 스크린.
5. 탐색 탭: Mock 지도 + Bottom Sheet 인터랙션 프로토타입 (추천 CTA, 미션 배지).
6. 트립 탭: 추천 Carousel, 저장 리스트, 회고 섹션 UI 스텁 구성.
7. 검색/프로필 탭: 리스트/설정 화면 골격과 모달/Drawer 흐름 연결.
8. 상태관리(Riverpod) 컨테이너 및 Mock Provider로 UI 순회 테스트.

## 3. 요구 패키지 (추가 예정)
- `flutter_riverpod`, `flutter_hooks`, `hooks_riverpod`
- `go_router`
- `freezed`, `json_serializable`
- `dio`, `retrofit`
- `mapbox_gl` 또는 `google_maps_flutter`
- `lottie`

## 4. 검증 계획
- Sprint 1: Bottom Navigation + 각 탭 골격, 홈/트립 탭 클릭더미 완성
- Sprint 2: 추천 API Mock 연동, 상태 관리 와이어링, 미션/회고 플로우 연결
- 이후: 실제 API 연동, 위치 권한/오프라인 처리, 파티/친구 기능 확장

