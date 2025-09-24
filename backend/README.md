# 라이프집 백엔드

Django 4.2 기반 API/추천 백엔드.

## 빠른 시작

```bash
python -m venv .venv
. .venv/Scripts/Activate.ps1  # PowerShell
pip install -r requirements/dev.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
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

