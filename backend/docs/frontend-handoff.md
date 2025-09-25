# 프론트 연동 핸드오프 가이드

이 문서는 Flutter 프론트팀이 백엔드와 연동하기 위해 필요한 환경 구성, 주요 워크플로, 핵심 API를 정리합니다.

## 1. 로컬 환경 구성
- Python 3.12, Docker Desktop, Redis/Postgres 클라이언트가 설치되어 있어야 합니다.
- 최초 설치
  - `cd backend`
  - `copy .env.example .env`
  - `python -m venv .venv`
  - `. .venv/Scripts/Activate.ps1`
  - `pip install -r requirements/dev.txt`
- 인프라 기동
  - `docker compose up -d db redis`
  - `. .venv/Scripts/Activate.ps1`
  - `python src/manage.py migrate`
  - `python src/manage.py seed_dev` (데모 사용자·장소·미션·추천 데이터 생성)
  - `python src/manage.py runserver 0.0.0.0:8000`
  - (권장) 추천 태스크 실시간 확인: `celery -A lifelog worker -l info`

## 2. 환경 변수 & 서비스
- `.env` 주요 키
  - `DATABASE_URL`: 기본은 SQLite. Postgres 사용 시 `postgresql://lifelog:lifelog@127.0.0.1:5432/lifelog`
  - `REDIS_URL`: Celery 브로커/백엔드. 로컬은 `redis://127.0.0.1:6379/0`
  - `CHANNEL_LAYER_BACKEND`: 개발용 InMemory, 배포 시 `channels_redis.core.RedisChannelLayer`
  - `SENTRY_DSN`, `SENTRY_TRACES_SAMPLE_RATE`: 관측성 연동(없으면 비활성화)
- 개발용 계정: `demo@example.com / DemoPass123!`
- 관리자: `python src/manage.py createsuperuser` 로 추가 생성

## 3. API 퀵 레퍼런스
- 문서: Swagger UI `http://localhost:8000/api/docs/`, 스키마 `http://localhost:8000/api/schema/`
- 인증 흐름
  - `POST /api/v1/users/` : 이메일 가입 (비로그인 허용)
  - `POST /api/auth/token/` : JWT 발급 (`email`, `password`)
  - `POST /api/auth/token/refresh/`
  - `GET/PATCH /api/v1/users/me/` : 프로필/환경 수정
- 장소 & 태그
  - `GET /api/v1/places/` : 누구나 조회, `category`, `tags__name`, `q` 필터 지원
  - `POST /api/v1/places/` : `is_staff`만 생성(`tag_ids`로 태그 연결)
  - `GET /api/v1/tags/` : 태그 목록, `type` 필터 가능
- 추천 & 트립
  - `POST /api/v1/trips/recommendations/`
    ```json
    {
      "categories": ["cafe"],
      "mood": ["calm"],
      "limit": 3,
      "time_budget_min": 120
    }
    ```
    응답: 추천된 Trip 전체(노드, 예상시간 포함)
  - `GET /api/v1/trips/` : 사용자별 저장된 추천 이력
- 포스트 & 낙서
  - `POST /api/v1/posts/` : 경험 공유. 본인만 수정, 리스트는 본인 게시물만 표시
  - `GET /api/v1/posts/` : Pagination 응답(`count`, `results`)
- 미션 & 피드백
  - `GET /api/v1/missions/` : 활성 미션 목록
  - `POST /api/v1/mission-assignments/` : 미션 큐 생성 (자동으로 본인에게 귀속)
  - `POST /api/v1/feedback/` : 트립 완료 피드백, 트립 주인만 작성 가능
- 파티 & 노티피케이션
  - `POST /api/v1/party/sessions/` : 친구와 동기화 세션 생성
  - `POST /api/v1/push-subscriptions/` : 푸시 구독 토큰 등록

## 4. 테스트 & 품질 체크
- 유닛/통합 테스트: `python src/manage.py test`
- Lint: `black . && isort . && flake8`
- 타입 체크: `mypy src`
- 로컬에서 API 변경 시 Swagger 문서 자동 갱신 (drf-spectacular)

## 5. 데이터 초기화 & 샘플 워크플로
1. `python src/manage.py seed_dev`
2. 앱 실행 후 `POST /api/auth/token/` 으로 데모 계정 로그인
3. `POST /api/v1/trips/recommendations/` 으로 추천 코스 확인
4. `POST /api/v1/feedback/` 으로 회고 기록 → 콘솔에서 Celery 로그 확인

## 6. 배포/스테이징 체크리스트
- `.env`에서 SQLite → Postgres로 전환
- Redis, Celery 워커 프로세스 분리 기동
- `DEBUG=False`, `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS` 설정
- Sentry DSN 및 샘플링 비율 주입
- `python src/manage.py collectstatic` (필요시)

