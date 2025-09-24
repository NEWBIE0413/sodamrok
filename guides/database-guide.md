# 데이터베이스 설계 가이드

## 1. 목표와 기술 스택
- 실행 가능한 로컬 트립 추천을 위한 정규화된 모델과 지리 정보 처리를 제공한다.
- PostgreSQL 15 + PostGIS 3.x를 기본으로 사용하고, pgvector(선호도/텍스트 임베딩)와 TimescaleDB(이벤트 시계열) 확장을 고려한다.
- 데이터 품질과 개인정보 보호를 균형 있게 유지하며, 백엔드/분석/ML 파이프라인이 안정적으로 접근할 수 있는 계층 구조를 설계한다.

## 2. 핵심 스키마 개요
- 주요 엔티티
  - `users`: 기본 사용자 정보, 온보딩 선호, 권한/동의.
  - `places`: 장소 기본 정보, 좌표, 운영시간, 분위기/태그 스코어.
  - `posts`: 후기/낙서, 이미지, 태그, 모더레이션 상태.
  - `trips`: 추천 코스, 제안 핑거프린트(시간·예산·기상), 스팟 순서.
  - `trip_nodes`: 코스 내 개별 장소, 이동수단, 체류 권장시간.
  - `missions`: 미션 템플릿 및 개인 큐(`mission_assignments`).
  - `feedback`: 회고 피드백, 체류시간, 반복 방문 여부.
  - `party_sessions`, `party_members`: 트립 파티 세션, 역할, 위치 공유 로그.
  - `tags`, `place_tags`, `post_tags`: 카테고리·분위기·시간대 태그 매핑.
  - `ingestion_jobs`, `content_sources`: 외부 데이터 수집 이력.

## 3. 상세 테이블 설계
- `users`
  - `id`, `email`, `password_hash`, `onboarded_at`, `locale`, `time_budget_min`, `budget_band`, `mobility_mode`, `privacy_level`.
  - `preferences` JSONB(선호 분위기, 태그 우선순위), `push_opt_in`, `location_opt_in`.
- `places`
  - `id` PK, `name`, `external_ref`, `category`, `geo`(geometry(Point, 4326)), `address`, `district`, `cost_band`, `stay_min`, `hours` JSONB.
  - `mood_scores` JSONB(조용, 활기, 빈티지 등), `congestion_score`, `last_synced_at`, `is_active`.
- `posts`
  - `id`, `user_id` FK, `place_id` nullable FK, `type`(review/doodle), `body`, `media_urls` JSONB, `visibility`, `status`, `geofence` geometry(Point,4326), `expires_at`(낙서용), `created_at`.
- `trips`
  - `id`, `user_id` nullable(추천), `context_hash`(시간/예산/기상), `duration_min`, `budget_min`, `budget_max`, `mode`(walk/transit/bike), `freshness_score`, `created_at`.
- `trip_nodes`
  - `id`, `trip_id`, `place_id`, `sequence`, `planned_stay_min`, `transition_mode`, `notes`, `eta`.
- `missions`
  - `id`, `title`, `description`, `steps` JSONB, `badge_type`, `is_active`.
- `mission_assignments`
  - `id`, `user_id`, `mission_id`, `assigned_at`, `due_at`, `status`(pending/completed/expired), `result_metadata` JSONB.
- `feedback`
  - `id`, `trip_id`, `trip_node_id`, `user_id`, `rating`(1~3), `stay_actual_min`, `comments`, `submitted_at`.
- `party_sessions`
  - `id`, `trip_id`, `host_user_id`, `status`, `started_at`, `ended_at`, `sharable_token`, `precision`(exact/rough/private), `options` JSONB.
- `party_positions`
  - `session_id`, `user_id`, `recorded_at`, `loc` geometry(Point,4326), `accuracy_m`, `ttl_expired`.
- `tags`
  - `id`, `name`, `type`(category/mood/time/congestion/budget), `metadata` JSONB.
- 교차 테이블은 단일 책임을 유지하고, `place_tags(place_id, tag_id, weight)`, `post_tags(post_id, tag_id)` 구조로 정규화.

## 4. 공간 데이터 및 위치 정보 처리
- PostGIS를 사용해 `geo` 컬럼에 SRID 4326 좌표 저장, 지도 질의 시 `ST_DWithin`으로 반경 N미터 필터.
- 혼잡도 집계는 `place_congestion_daily`(date, place_id, visitors_count, wait_time_estimate) 테이블로 별도 관리.
- 낙서 지오펜스 검증: 저장 시 `ST_Distance(user_loc, geofence) <= 0.15km` 조건을 트리거 혹은 애플리케이션 레이어에서 확인.
- 거리 계산은 `ST_DistanceSphere` 사용, 파티 위치 스트림은 5초 단위 스냅샷으로 downsample 후 보관.

## 5. 데이터 품질·거버넌스
- 외부 크롤링 데이터는 `raw_ingestion` 스키마에 원본 저장 후 정제 파이프라인(`clean_places`)을 통해 본 스키마로 이동.
- 태그 자동화 결과는 신뢰도 점수와 함께 저장하고, ± 임계값에 따라 운영자 검수 큐로 분류.
- KPI(코스 시작율/완료율/다양성)는 `metrics.daily_product_metrics` 뷰로 집계, Looker 등 BI 도구 연동.
- 민감 데이터(이메일, 위치)는 `row level security` 정책과 뷰를 통해 접근 제어.

## 6. 성능 최적화 전략
- 주요 인덱스: `places`에 GIST(`geo`), `trips(context_hash)`, `trip_nodes(trip_id, sequence)`, `feedback(trip_id, submitted_at)`, `posts`에 `GIST(geofence)`.
- 파티션 전략: `posts`와 `feedback`은 월 단위 파티션으로 삭제/보관 비용 절약, `party_positions`는 하루 단위 파티션.
- 캐시: 빈번한 추천 컨텍스트는 Redis 캐싱하되, DB에도 `trip_cache` 테이블(유효기간 포함)을 둬 재사용.
- 대용량 텍스트 검색은 `pg_trgm`으로 자연어 질의 선처리, 태그 검색은 `GIN` 인덱스로 가속.

## 7. 데이터 파이프라인과 운영 작업
- ETL: Airflow 혹은 Prefect에서 ingestion→정제→피처 업데이트 DAG 구성, 실패 시 슬랙 알림.
- 날씨·교통 API 데이터는 `external_conditions` 테이블에 저장 후 추천 컨텍스트 조합.
- ML 학습용 피처 스토어: `feature_store.user_trip_features`(JSONB)로 사용자별 선호도, 최근 회고 요약을 보관.
- 데이터 삭제 요청(탈퇴) 시 `users` 레코드 익명화 + 위치 로그 파티션 즉시 삭제.

## 8. 보안·백업·재해 복구
- 정기 백업: pgBackRest로 주간 풀, 일간 증분, S3 버킷(버전관리) 저장.
- PITR(Point-In-Time Recovery) 설정, staging 환경에서 복구 리허설 월 1회 실시.
- DB 접속은 IAM 기반(예: AWS RDS IAM auth)으로 관리, 운영 쿼리는 Bastion 호스트에서만 허용.
- 파티션 삭제·임시 테이블 생성은 migration 사용자가 아닌 별도 유지보수 역할에게 부여.

## 9. 마이그레이션 및 테스트 전략
- Alembic 대신 Django migrations 사용 시에도 SQL 리뷰 프로세스 마련, 복잡한 변경은 `RunSQL`로 명시.
- Zero-downtime 마이그레이션: 1) 새 컬럼 추가 2) 백필 Celery 작업 3) 애플리케이션 배포 4) 구 칼럼 제거 순서.
- 마이그레이션 테스트: 로컬 docker-compose + 샘플 데이터, staging에서 프로덕션 스냅샷 리플레이.
- 데이터 유효성 테스트(Great Expectations)로 핵심 규칙(예: `trip_nodes.sequence` 중복 금지, `feedback.rating` 범위) 검증.

## 10. 협업 체크리스트
- 새로운 테이블 추가 시 ERD, DDL, 관련 백엔드 모델/시리얼라이저 링크를 공유한다.
- GIST/GiN 인덱스 추가는 분석팀 쿼리 영향, storage 비용을 함께 평가한다.
- ETL DAG 수정 시 데이터 공백을 방지하기 위한 catch-up 전략과 누락된 날짜 범위를 명시한다.
- RLS/뷰 수정은 보안 담당자 코드 리뷰 필수, 접근 레벨 매트릭스 최신화.
- 대규모 삭제/파티션 드롭 전 후 상태를 메트릭으로 기록하고, 복구 계획을 문서화한다.
