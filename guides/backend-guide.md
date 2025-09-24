# 백엔드 개발 가이드

## 1. 서비스 목표와 시스템 개요
- 지도 기반 로컬 트립 추천, 미션 루프, 낙서, 트립 파티 등 핵심 경험을 안정적으로 제공하는 API 레이어를 구축한다.
- 실행 가능한 제약 기반 추천(시간·예산·동선)과 개인화 루프(좋았어요/보통/별로 피드백)를 지속적으로 학습하는 데이터 허브를 담당한다.
- Django를 중심으로 모듈형 모노리식 구조를 유지하되, 비동기 추천/분석 워크로드는 별도 워커로 분리한다.

## 2. 아키텍처 설계 원칙
- Django 4.x + Django REST Framework(DRF) 기반, Python 3.11.
- 데이터베이스: PostgreSQL 15 + PostGIS 확장, 캐시: Redis.
- 비동기 작업: Celery + RabbitMQ(또는 Redis) → 콘텐츠 크롤링, 추천 모델 업데이트, 알림 예약.
- 서비스 레이어 패턴 적용(도메인 Service 객체)으로 뷰/시리얼라이저에서 비즈니스 로직 분리.
- 환경 변수를 통한 3계층(dev/staging/prod) 구성, 12-Factor 원칙 준수.

## 3. 도메인 모듈 설계
- `users`: 가입, 온보딩 설문, 관심사/제약 프로필, 위치 권한/알림 동의 기록.
- `places`: 장소 마스터, 운영정보, 태그/분위기/혼잡도 스코어, 외부 API 동기화 로그.
- `posts`: 유저 생성 콘텐츠(후기, 낙서), 이미지/태그, 모더레이션 상태.
- `trips`: 추천 코스 엔티티, 스팟 순서, 이동 수단, 예상 비용·시간, 3안 비교 카드 데이터.
- `missions`: 미션 템플릿, 개인화된 미션 큐, 완료 기록, 배지 발급.
- `feedback`: 회고(좋았어요/보통/별로), 체류시간, 반복 방문 판단, 학습용 피처 저장.
- `party`: 트립 파티 세션, 멤버 역할(길잡이/기록가/시간지기), 위치 공유 토큰.
- `notifications`: 스마트 푸시 예약(주말/퇴근 전), 미션 갱신.
- `analytics`: 이벤트 수집, 추천 품질 지표(완료율, 다양성 지수) 계산.

## 4. API 및 통신 설계
- RESTful JSON API v1 `/api/v1/...`, ACL 기반 JWT(Access 15분, Refresh 14일).
- 주요 엔드포인트: 
  - `POST /auth/signup`, `POST /auth/token/refresh`
  - `GET /trips/recommendations` (시간·예산·동선·기상 파라미터 + 자연어 질의), 3안 카드 반환.
  - `POST /missions/complete`, `POST /feedback` (피드백 + 체류시간), `GET /missions/queue`.
  - `POST /posts`(낙서/후기), `GET /posts?bbox=...` → 지오펜스 필터.
  - `POST /party/sessions`, `PATCH /party/sessions/{id}/heartbeat`.
- 자연어 질의는 백엔드에서 파싱 후 추천 엔진에 전달 → Score 설명을 함께 반환.
- 응답 캐싱: 동일 파라미터의 추천 요청은 Redis와 DRF Throttling을 조합해 30초 캐시.
- 실시간 파티 위치 공유는 WebSocket(`channels`) 혹은 Server-Sent Events로 제공.

## 5. 추천·분석 파이프라인
- 콘텐츠 파이프라인: Celery Beat → 외부 블로그/Foursquare/네이버 플레이스 크롤러 → NLP 태깅(BERT 기반) → 이미지 인식(Places365 등) → 태그/분위기/비용 피처 저장.
- 온보딩/자연어 입력을 벡터화 → Faiss 혹은 pgvector를 이용한 유사도 검색.
- 랭킹: 근접도 × 선호 유사도 × 시간/예산 적합도 - 혼잡 리스크 + 신선도 보정. ReRanker는 Python 서비스 객체로 구현.
- 학습 데이터: 회고 피드백, 체류시간, 미션 완료 여부를 주기적으로 집계 → 추천 파라미터 업데이트.
- 모델 배포: MLflow로 버전 관리, 추천 서비스는 별도 Celery Task 혹은 FastAPI microservice와 gRPC 연동 검토.

## 6. 인증, 권한, 보안
- JWT 저장은 모바일에서 Secure Storage 사용, 파티 세션 토큰은 단기 UUID + 서명.
- 위치 데이터는 파티 세션 opt-in 시에만 저장, TTL 만료(24시간), 익명화된 집계만 영구 보관.
- 게시글/낙서는 기본 비공개, 공개 전 자동 필터(욕설/이미지 스캔)와 운영자 승인 워크플로 제공.
- 요청 제한: 사용자별 추천 API 분당 10회, 낙서 작성 시간당 5회.
- 감사 로그: 관리자 행동, 데이터 수정은 `audit_log` 테이블과 CloudWatch/ELK 연동.

## 7. 운영 및 인프라 전략
- 컨테이너: Docker + docker-compose(dev)/Kubernetes(prod). Gunicorn+Uvicorn Workers(h11)로 ASGI 지원.
- 정적 자산 및 미디어는 S3 + CloudFront, 이미지 업로드 후 백그라운드 리사이즈.
- 모니터링: Prometheus + Grafana, Sentry Python SDK, OpenTelemetry Trace.
- 배치 스케줄: Celery Beat (미션 큐 업데이트, 혼잡도 계산, 날씨 데이터 동기화).
- 지도/날씨 API 키는 AWS Parameter Store 혹은 HashiCorp Vault에서 주입.

## 8. 테스트 및 품질 관리
- 단위 테스트: 서비스 레이어, 추천 랭커, 자연어 파서, 미션 상태머신.
- API 테스트: pytest + DRF test client, Swagger/OpenAPI 스펙 자동 검증.
- 통합 테스트: Docker Compose로 Postgres(PostGIS) + Redis 환경 구성, 주요 플로우 시나리오 검증.
- 로드 테스트: k6 혹은 Locust로 추천 API(95p latency 700ms 이하), 파티 위치 스트림.
- 품질 게이트: pre-commit(black, isort, flake8, mypy), SonarCloud 혹은 Codecov 커버리지 80% 이상.

## 9. 배포 파이프라인과 환경 구성
- GitHub Actions: lint → 테스트 → Docker 이미지 빌드 → staging 배포(ArgoCD) → 승인 후 prod.
- 데이터 마이그레이션은 `python manage.py migrate`를 배포 step에 포함, 강한 의존 테이블은 롤링 전략(새 칼럼 추가 → 코드 업데이트 → 기존 칼럼 제거).
- Feature Flag는 Django-Waffle 혹은 LaunchDarkly로 제약 기반 추천 실험을 관리.
- Blue/Green 배포 시 추천 캐시 warming 스크립트를 실행해 Cold Start 감소.

## 10. 협업 및 코드 리뷰 기준
- 도메인별 README(예: `trips/README.md`)에 API 계약, 의존 서비스, Celery 태스크를 명시한다.
- 새로운 엔드포인트 추가 시 OpenAPI 문서, Postman, 모바일 팀 메모 동시 업데이트.
- 데이터 스키마 변경은 DB 가이드와 동기화하고, 샘플 payload, 마이그레이션 영향도를 PR 설명에 포함한다.
- 추천 로직 수정을 리뷰할 때는 A/B 실험 계획, 지표(완료율, 다양성, 체류시간) 모니터링 항목을 함께 제시한다.
- 장애 대응 프로세스: 1) SLO 확인 2) 로그/메트릭 링크 공유 3) RC 문서 초안 작성 → 24시간 내 회고.
