# 디자인 방향 및 원칙

## 1. 브랜드 톤 & 무드
- **Calm Dopamine**: 과도한 자극 대신 차분하고 따뜻한 색조(크림/소프트 그린)를 기본으로 하고, 포인트 컬러는 미션/배지에만 사용한다.
- **지도 중심 실시간성**: 홈(탐색) 화면의 60% 이상을 지도와 공간 정보가 차지하도록 하고, 추천/미션은 하단 시트와 탭을 통해 자연스럽게 이어지게 한다.
- **로컬 감성**: 사진보다 텍스트·아이콘 정보를 우선 노출해 간결한 정보 탐색감을 유지한다.

## 2. 핵심 사용자 플로우 & UI 우선순위
1. **탐색(Home)**: 실시간 지도 + 주변 스팟 발견, peek bottom sheet에서 추천 CTA 노출.
2. **트립(Trips)**: 제약 설정 → 3안 추천 → 저장/실행 → 회고까지 이어지는 코어 플로우.
3. **검색(Discover)**: 태그/카테고리/검색 결과를 리스트로 탐색, 즐겨찾기 관리.
4. **프로필(Profile)**: 환경 설정, 친구/파티 관리, 배지·활동 통계.

## 3. 레이아웃 규칙
- **Navigation**: BottomNavigationBar (모바일) / NavigationRail (태블릿) 4탭 구성 (`탐색`, `트립`, `검색`, `프로필`).
- **Bottom Sheet 사용**: 탐색 탭은 peek 16%, half 60%, full 95% 단계. 추천/트립 탭은 half/full 시트를 주요 콘텐츠 컨테이너로 사용.
- **Grid & Spacing**: 8pt 베이스, 지도 UI는 여백 16, 카드 요소는 Elevation 1~2.

## 4. 컬러 & 타이포 초안
- 베이스 배경: `#FAF7F2`
- 프라이머리: `#3A7D74` (지도 강조, 주 CTA)
- 강조/배지: `#FFAB5C`
- 텍스트: 다크 그린 `#1F3A36`, 보조 `#5C6D68`
- 폰트: Pretendard / Noto Sans (Korean), Poppins (숫자). Heading 20pt, Body 16pt, Caption 13pt.

## 5. 컴포넌트 톤
- **Map Pin**: 원형 배경 + 아이콘(카페/산책/전시), 채도 낮은 카테고리 컬러.
- **Trip Card**: 코스명, 예상 시간/비용 아이콘, 장소 칩 리스트.
- **Mission Badge**: 둥근 Capsule + 미묘한 그라데이션.
- **Quick Actions**: FAB 속 확장 메뉴 또는 Bottom Sheet의 토글 버튼으로 일관된 스타일 유지.

## 6. 접근성 & 모션
- 색 대비 WCAG AA 기준 유지, 고대비 모드 시 지도 마커 테두리 강조.
- 전환 애니메이션 200~250ms, bottom sheet 슬라이드는 `Curves.easeOutCubic`.
- 배지 애니메이션은 Flutter Lottie 등 경량 자산 활용.

## 7. 향후 TODO
- 실제 컬러/폰트 토큰을 Figma와 동기화.
- Breakpoint 정의(모바일/태블릿) 및 NavigationRail 대응.
- Dark Mode 팔레트 도출.
