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
  - `python src/manage.py seed_home_feed` (홈 피드 샘플 데이터 생성)
  - `python src/manage.py runserver 0.0.0.0:8000`
  - (선택) 추천 태스크 실시간 확인: `celery -A lifelog worker -l info`

## 2. 환경 변수 & 서비스
- `.env` 주요 키
  - `DATABASE_URL`: 기본은 SQLite. Postgres 사용 시 `postgresql://lifelog:lifelog@127.0.0.1:5432/lifelog`
  - `REDIS_URL`: Celery 브로커/백엔드. 로컬은 `redis://127.0.0.1:6379/0`
  - `CHANNEL_LAYER_BACKEND`: 개발용 InMemory, 배포 시 `channels_redis.core.RedisChannelLayer`
  - `SENTRY_DSN`, `SENTRY_TRACES_SAMPLE_RATE`: 관측성 연동(없으면 비활성화)
- 개발용 계정: `demo@example.com / DemoPass123!`
- 관리자: `python src/manage.py createsuperuser` 로 추가 생성

## 3. API 핵심 레퍼런스
- 문서: Swagger UI `http://localhost:8000/api/docs/`, 스키마 `http://localhost:8000/api/schema/`

### 인증 흐름
- `POST /api/v1/users/` : 이메일 가입 (비로그인 허용)
- `POST /api/auth/token/` : JWT 발급 (`email`, `password`). 응답 예시:
  ```json
  {
    "access": "...",
    "refresh": "...",
    "user": {
      "id": "...",
      "email": "...",
      "display_name": "...",
      "nickname": "..."
    }
  }
  ```
- `POST /api/auth/token/refresh/` : 만료 직전 `refresh` 토큰으로 갱신
- `POST /api/auth/reset-password/` : 새 비밀번호 설정. Django 기본 비밀번호 정책(최소 길이, 공통 패턴 금지 등)을 통과해야 함
- `GET/PATCH /api/v1/users/me/` : 프로필/환경 설정 조회 및 수정

### 게시글 & 피드
- `POST /api/v1/posts/` : 경험 공유. 본인만 수정 가능, 리스트에는 본인 글 + 공개 글 노출
- `GET /api/v1/posts/` : Pagination 응답(`count`, `results`). 각 항목은 다음 필드를 포함합니다.
  - `author`(id, display_name, nickname, avatar)
  - `author_name` : 프론트 기본 노출용 문자열
  - `like_count`, `comment_count`, `is_liked`
  - `media_urls`, `tags`, `published_at`
- `POST /api/v1/posts/{id}/like/` : 좋아요 토글. 응답은 `{post_id, liked, like_count, comment_count}`
- `DELETE /api/v1/posts/{id}/like/` : 좋아요 해제
- `GET /api/v1/posts/{id}/comments/` : 최신 순 댓글 목록
- `POST /api/v1/posts/{id}/comments/` : 댓글 작성. 성공 시 `{comment, comment_count}` 반환

### 장소 & 태그
- `GET /api/v1/places/` : 누구나 조회, `category`, `tags__name`, `q` 필터 지원
- `POST /api/v1/places/` : `is_staff`만 생성(`tag_ids`로 태그 연결)
- `GET /api/v1/tags/` : 태그 목록, `type` 필터 가능

### 추천 & 트립
- `POST /api/v1/trips/recommendations/` : AI 추천 (limit/budget/mood 반영)
- `GET /api/v1/trips/` : 사용자별 저장된 추천 이력
- `POST /api/v1/trips/from-template/` : 템플릿 기반 Trip 인스턴스 생성 (title override 가능)
- (준비) `trips.request_ai_template` Celery 태스크는 OpenRouter 연동 시 활성화 예정 (`openrouter_not_configured` 응답)

### 즐겨찾기 & 선호 태그
- `GET/POST /api/v1/favorites/places/` : 찜한 장소 목록, 생성(이미 존재하면 노트 업데이트)
- `PATCH/DELETE /api/v1/favorites/places/{id}/` : 노트 수정, 제거
- `GET/POST /api/v1/users/preferred-tags/` : 선호 태그(무드/카테고리) 관리
- `PATCH/DELETE /api/v1/users/preferred-tags/{id}/` : 우선순위/메모 수정, 삭제

### 큐레이션 트립 템플릿
- `GET /api/v1/trip-templates/` : 퍼블릭 템플릿 목록 (비공개 템플릿은 스태프만 조회)
- `POST /api/v1/trip-templates/` : (스태프) 에디터 코스 등록, `nodes` + `tag_ids` 포함
### 미션 & 피드백
- `GET /api/v1/missions/` : 활성 미션 목록
- `POST /api/v1/mission-assignments/` : 미션 큐 생성(자동으로 본인에게 귀속)
- `POST /api/v1/feedback/` : 트립 완료 피드백, 트립 주인만 작성 가능

### 파티 & 알림
- `POST /api/v1/party/sessions/` : 친구와 동기화 세션 생성
- `POST /api/v1/push-subscriptions/` : 푸시 구독 토큰 등록

## 4. 테스트 & 품질 체크
- 유닛/통합 테스트: `python src/manage.py test`
- Lint: `black . && isort . && flake8`
- 타입 체크: `mypy src`
- 로컬에서 API 변경 시 Swagger 문서 자동 갱신(drf-spectacular)

## 5. 홈 피드 샘플 데이터
- `python src/manage.py seed_home_feed` 실행 시 다음 데이터가 생성/갱신됩니다.
  - `feed-author@example.com` 작성자의 샘플 게시글 1건(미디어 URL, 태그 없음)
  - `feed-friend@example.com` 계정의 좋아요/댓글 1건
- 명령은 멱등합니다. 이미 존재하면 업데이트만 수행합니다.
- 샘플 사용자 비밀번호: `FeedDemo123!`

## 6. 배포/스테이징 체크리스트
- `.env`에서 SQLite → Postgres로 전환
- Redis, Celery 워커 프로세스 분리 기동
- `DEBUG=False`, `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS` 설정
- Sentry DSN 및 샘플링 비율 주입
- `python src/manage.py collectstatic` (필요 시)

## 7. 추가 연동 메모
1. **토큰 자동 갱신**: 프론트는 401 응답 시 `refresh` 토큰으로 재발급 후 원 요청을 재시도하십시오.
2. **추천/미션 실서비스화**: 현재 일부 API는 Mock 데이터 기반입니다. Celery 태스크(`trips.generate_recommendations`)와 실데이터 매칭 로직이 완성되면 프론트 이벤트(추천 카드, 미션 핸들러)에 연결해야 합니다.
3. **푸시 알림 고도화**: `/api/v1/push-subscriptions/` 저장 후 FCM 토큰 검증 로직을 추가 예정입니다. 실제 배포 전 검증 API가 추가되면 본 문서를 업데이트합니다.

