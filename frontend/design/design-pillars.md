# 사용자 경험 방향 원칙

## 1. 브랜드 & 무드
- **Calm Dopamine**: 과도한 자극 대신 차분하고 묵직한 녹색 톤을 기본으로 하고, 개인화 컬러는 미션/배지에만 사용한다.
- **지도 중심 실시간성**: 홈(탐색) 화면의 60% 이상을 지도와 공간 정보가 차지하도록 하고, 추천/미션은 시트와 플로팅 버튼을 통해 자연스럽게 이어지게 한다.
- **로컬 감성**: 사진보다 스토리·아이콘 정보 우선, 간결한 서체와 따뜻한 색감 유지.

## 2. 핵심 사용자 흐름 & UI 우선순위
1. **탐색(Home)**: 실시간 위치 기반 지도 + 친구 경험 피드 → 플로팅 버튼/시트를 통해 행동 유도
2. **트립(Trips)**: 오버레이 모달에서 추천 3선 제시, 코스 편집 및 저장
3. **검색(Search)**: TopBar 검색 버튼 확장 후 전용 탭에서 키워드/카테고리 탐색
4. **프로필(Profile)**: 모달/풀스크린에서 활동 요약, 친구 · 파티 관리

## 3. 레이아웃 규칙
- **Navigation**: BottomNavigation 미사용. TopBar + FloatingActionDock(Trip, Profile, QuickAction) 조합으로 이동
- **Bottom Sheet & Modals**: 홈 피드/추천은 peek(16%) → half(60%) → full(95%) 단계. 트립/검색/프로필은 모달 오버레이로 표시
- **Grid & Spacing**: 8pt 베이스, 지도 여백 16, 카드 elevation 1~2 유지

## 4. 컬러 & 타이포 초안
- 베이스 배경: `#FAF7F2`
- 프라이머리: `#3A7D74` (지도 강조, 주요 CTA)
- 강조/배지: `#FFAB5C`
- 텍스트: Pretendard / Noto Sans (Korean), Poppins (영문). Heading 20pt, Body 16pt, Caption 13pt

## 5. 컴포넌트 메모
- **Map Pin**: 원형 배경 + 카테고리 전용 아이콘, 채도는 카테고리 컬러에 맞춤
- **Trip Card**: 코스별 예상 시간/비용, 장소 리스트
- **Mission Badge**: 라운드 캡슐 + 은은한 그래디언트
- **FloatingActionDock**: Trip/QuickAction/Profile을 묶은 버튼 클러스터, 시나리오별 확장 메뉴 제공
- **ExpandingSearchBar**: TopBar 검색 버튼이 자연스럽게 확장되는 애니메이션 컴포넌트

## 6. 접근성 & 모션
- 색 대비 WCAG AA 이상, 고대비 모드에서 지도 포커스 충분히 강조
- 애니메이션 200~250ms, `Curves.easeOutCubic` 기반. 모달/시트 전환은 fade + slide 혼합
- 배경 애니메이션은 Flutter Lottie 등 가벼운 자산 사용

## 7. 향후 TODO
- 색상/타이포 토큰 Figma 연동
- 브레이크포인트 정의(모바일, 태블릿) 및 NavigationRail 대체 전략
- 다크 모드 팔레트 도출
