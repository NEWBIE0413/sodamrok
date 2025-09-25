# 라이프집 백엔드

Django 4.2 기반 API/추천 백엔드.

## 빠른 시작

```bash
cd backend
copy .env.example .env  # Windows PowerShell
python -m venv .venv
. .venv/Scripts/Activate.ps1
pip install -r requirements/dev.txt
python src/manage.py migrate
python src/manage.py runserver 0.0.0.0:8000
```

### Postgres & Redis (선택)

```bash
cd backend
copy .env.example .env
# .env에서 DATABASE_URL, REDIS_URL을 Postgres/Redis 값으로 변경
# 예: DATABASE_URL=postgresql://lifelog:lifelog@127.0.0.1:5432/lifelog
#     REDIS_URL=redis://127.0.0.1:6379/0

docker compose up -d db redis
```

Docker Compose는 로컬 개발용 Postgres 15 / Redis 7 서비스를 제공합니다.

### Celery 워커 실행

```bash
cd backend
. .venv/Scripts/Activate.ps1
celery -A lifelog worker -l info
```

환경 변수는 `.env` 파일 혹은 OS 환경 변수로 주입합니다. 세부 키는 `lifelog/settings/base.py` 참고.

## 서비스 계층
- `users`, `places`, `posts`, `trips`, `missions`, `feedback`, `party`, `notifications`, `analytics` 앱으로 구성합니다.
- 추천·분석 파이프라인은 Celery/Redis, Channels 기반 실시간 스트림은 WebSocket으로 제공합니다.

## 품질 체크
```bash
pytest --cov
black .
isort .
flake8
```

### 데이터 시드

```bash
cd backend
. .venv/Scripts/Activate.ps1
python src/manage.py seed_dev
```

- 데모 계정: `demo@example.com / DemoPass123!`
- 명령 실행 후 추천 코스, 태그, 미션이 자동 생성됩니다.

### 추가 문서
- `docs/frontend-handoff.md`: 프론트 연동 절차, API 요약, 배포 체크리스트
