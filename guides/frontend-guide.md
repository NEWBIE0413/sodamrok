# 프론트엔드 개발 가이드

## 1. 목표 및 사용자 가치
- "오늘 2시간, 1만원, 도보 15분" 같은 제약 속에서도 실행 가능한 로컬 코스를 빠르게 추천받는 경험을 완성한다.
- 자극적 피드 대신 건강한 도파민을 주는 지도 중심 UI, 미션 루프, 낙서 기능을 신뢰감 있게 제공한다.
- 온보딩부터 피드백(좋았어요/보통/별로)까지의 루프를 끊김 없이 연결하고, 오프라인 상황에서도 코스를 확인할 수 있도록 설계한다.

## 2. 기술 스택 및 프로젝트 구조
- Flutter 3.x (안드로이드/iOS 동시 지원), 최소 SDK 21(Android) / iOS 14.
- 패키지 권장: Riverpod(상태관리), GoRouter(내비게이션), Freezed/JsonSerializable(모델), Dio+Retrofit(네트워크), Drift 또는 Hive(캐시), mapbox_gl 혹은 google_maps_flutter(지도), flutter_local_notifications.
- 프로젝트 구조: `lib/` 하위에 `core/`(공통), `features/`(도메인별), `shared/`(위젯·유틸)로 나눈 모듈형 클린 아키텍처.
- 기능 단위 폴더 구성: `features/map`, `features/trip`, `features/feed`, `features/mission`, `features/party`, `features/profile`.

## 3. 핵심 사용자 플로우
1. 온보딩 & 콜드스타트: 분위기/관심사/예산/이동수단 입력 → 3개 테스트 코스 제안 → 선택 결과를 Local DB에 저장.
2. 홈 지도: 현재 위치 기반 지도 렌더링, 상단 필터(시간·예산·동선 슬라이더, 날씨 배지)와 주변 스팟 클러스터.
3. 개별 코스 상세: 총 소요시간, 이동 수단, 예상 비용, 분위기 아이콘, 스팟별 카드(사진, 태그, 운영정보) 표시.
4. 미션 루프: 제안된 3단계 미션 카드 → 완료 체크 → 원터치 회고 → 배지 애니메이션.
5. 탐색 피드: 스와이프 업으로 인기/친구 경험 카드, 태그·카테고리 기반 필터.
6. 낙서: 현장 반경 50~150m 안에서만 작성·열람 가능, 기본 이모지 반응.
7. 트립 파티: 친구 초대 → 세션(2시간) 동안 위치 공유 옵션 및 역할 배정 → 종료 후 공동 배지.

## 4. 주요 기능 구현 전략
- 지도: Mapbox 스타일 커스터마이징, 클러스터링·heatmap으로 혼잡도 시각화, 우천/야간 테마 스위칭.
- 추천 카드: 백엔드 제공 JSON(Trip + Place) → 모델 변환 → `PageView`/`Carousel` UI, 3안 비교 카드 UI.
- 자연어 검색 입력창은 `TextField` + debounce → 추천 엔드포인트 호출 → 후보 카드 표시.
- 미션/배지: 로컬 큐 관리, 애니메이션은 `ImplicitlyAnimatedWidget` 혹은 `rive`를 사용해 경량화.
- 알림: 추천 타이밍(주말 오전/퇴근 전)만 푸시 노출, Firebase Cloud Messaging과 OS 스케줄러 활용.
- 접근 제어: 위치 권한 흐름을 별도 상태(`LocationPermissionState`)로 관리, 권한 미부여 시 온보딩·낙서 기능 제한 안내 모달.

## 5. 데이터 연동 및 상태 관리
- Riverpod 기반 Feature 단위 Provider(예: `tripRecommendationsProvider`, `missionStatusProvider`).
- API 통신: Dio 인터셉터로 인증 토큰 자동 첨부, 네트워크 오류 시 로컬 캐시(Drift/Hive) fallback.
- 오브젝트 모델은 Freezed로 정의, fromJson/toJson 생성, 버전 필드를 포함해 마이그레이션 대비.
- 백엔드 이벤트 스트림(예: 실시간 파티 위치)을 위해 WebSocket 채널을 `riverpod + StreamProvider`로 관리.

## 6. 성능, 오프라인, 품질 전략
- 지도 타일/코스 카드는 첫 실행 시 주변 3km 범위를 프리페치, 이동 시 Prefetch 큐 유지.
- 저성능 디바이스 위한 Lite 모드(애니메이션 축소, 2D 마커) 제공 플래그.
- 오프라인: 최근 조회한 코스와 낙서 텍스트를 로컬 저장, 네트워크 복구 시 동기화 큐 업로드.
- 이미지 로딩은 `cached_network_image` + LRU 캐시, 저해상/고해상 단계적 로딩.

## 7. 접근성 및 UX 일관성
- 고대비 모드/폰트 크기 토글은 `MediaQuery`와 `ThemeExtension`으로 관리.
- 거리·비용·시간 단위는 Locale에 따라 포맷(예: 1.2km, ₩9,000). 통화/시간 포맷 유틸을 `core/formatters.dart`로 공통화.
- 태그 배지, 필터 슬라이더, 카드 정보 배치는 디자인 시스템 컴포넌트(`ds_badge`, `ds_card`)로 추출해 재사용.

## 8. 테스트 및 모니터링
- 단위 테스트: 뷰모델/프로바이더 단위 로직 검증(제약 조건 필터링, 미션 상태 머신 등).
- 위젯 테스트: 지도 오버레이, 추천 카드 스와이프, 회고 플로우 UI.
- 골든 테스트: 카드 컴포넌트, 배지 애니메이션 썸네일.
- 통합 테스트(E2E): 온보딩→추천→코스 완료까지의 핵심 플로우, Firebase Test Lab과 Codemagic를 활용.
- 런타임 로깅: Sentry for Flutter + Firebase Analytics, UX 이벤트(코스 조회, 회고 입력) 트래킹.

## 9. 배포 및 환경 구성
- Flavors: dev / staging / prod, 각각 다른 API baseUrl·Mapbox token·Firebase 프로젝트 사용.
- CI: Codemagic 또는 GitHub Actions → lint(`flutter analyze`) → 테스트 → Fastlane 빌드 → 스토어 배포.
- 환경 변수는 `flutter_dotenv`로 주입, 민감 정보는 CI 시크릿에 저장.

## 10. 협업 체크리스트
- 신규 화면은 Figma 레퍼런스와 컴포넌트 매핑 문서를 확인하고 디자인 토큰만 사용한다.
- API 스펙 변경 시 `openapi.yaml` 혹은 Postman 컬렉션을 동시에 갱신하고, 모델 버전 필드를 증가시킨다.
- 모듈 추가 시 README에 라우트, 의존 Provider, 캐시 전략을 명시한다.
- 성능 임계치: cold start 3초 이하, 지도 첫 로딩 1.5초 이하, 프레임 드랍 2% 이하를 유지한다.
- QA 빌드 제출 전 주요 플로우(온보딩/추천/낙서/파티)를 수동 점검하고 Crashlytics 경고를 확인한다.
