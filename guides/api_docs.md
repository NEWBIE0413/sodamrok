# API Reference for Frontend Integration

## Authentication

### Sign Up
- **Endpoint**: `POST /api/v1/users/`
- **Description**: Create a new user account (email + password).
- **Payload**:
  ```json
  {
    "email": "user@example.com",
    "password": "Password123!",
    "display_name": "Sodam User"
  }
  ```
- **Response**: `201 Created` with user profile.
- **Notes**: No auth required.

### Obtain JWT Token
- **Endpoint**: `POST /api/auth/token/`
- **Description**: Retrieve access/refresh JWT tokens.
- **Payload**:
  ```json
  {
    "email": "user@example.com",
    "password": "Password123!"
  }
  ```
- **Response**: `200 OK`
  ```json
  {
    "access": "<JWT access token>",
    "refresh": "<JWT refresh token>",
    "user": {
      "id": "...",
      "email": "...",
      "display_name": "...",
      "nickname": "..."
    }
  }
  ```
- **Notes**: Use `Authorization: Bearer <access>` for subsequent calls.

### Refresh Token
- **Endpoint**: `POST /api/auth/token/refresh/`
- **Payload**:
  ```json
  { "refresh": "<JWT refresh token>" }
  ```
- **Response**: `200 OK` with new access token.

### User Profile
- **Endpoint**: `GET /api/v1/users/me/`
- **Description**: Fetch logged-in user profile.
- **Endpoint**: `PATCH /api/v1/users/me/`
- **Description**: Update profile fields (e.g., nickname).

---

## Home Feed & Posts

### List Feed Posts
- **Endpoint**: `GET /api/v1/posts/`
- **Query Params**: `page`, `limit`, optional filters (`tag`, `author`).
- **Response**: `200 OK`
  ```json
  {
    "count": 42,
    "next": "...",
    "previous": null,
    "results": [
      {
        "id": "...",
        "author": {
          "id": "...",
          "display_name": "...",
          "avatar_url": "..."
        },
        "body": "Story text",
        "media_urls": ["https://..."],
        "like_count": 10,
        "comment_count": 3,
        "is_liked": false,
        "tags": ["calm", "cafe"],
        "published_at": "2025-09-26T12:34:00Z"
      }
    ]
  }
  ```
- **Notes**: Requires auth for personalized data; fallback to public feed otherwise.

### Create Post
- **Endpoint**: `POST /api/v1/posts/`
- **Payload**: multipart or JSON with text + media URLs.
- **Response**: `201 Created`.

### Like / Unlike Post
- **Like**: `POST /api/v1/posts/{id}/like/`
- **Unlike**: `DELETE /api/v1/posts/{id}/like/`
- **Response**: `{ "post_id": "...", "liked": true, "like_count": 11 }`

### Comments
- **List**: `GET /api/v1/posts/{id}/comments/`
- **Create**: `POST /api/v1/posts/{id}/comments/`

---

## Places & Favorites

### Search Places
- **Endpoint**: `GET /api/v1/places/`
- **Query**: `q`, `category`, `tags__name`, `district`.
- **Response**: list of places with metadata (address, stay_min, mood tags).

### Favorite Places
- **List**: `GET /api/v1/favorites/places/`
- **Add**: `POST /api/v1/favorites/places/`
  ```json
  { "place": "<place_uuid>", "note": "Loved the vibe" }
  ```
- **Update**: `PATCH /api/v1/favorites/places/{favorite_id}/`
- **Remove**: `DELETE /api/v1/favorites/places/{favorite_id}/`

### User Preferred Tags
- **List**: `GET /api/v1/users/preferred-tags/`
- **Add**: `POST /api/v1/users/preferred-tags/`
- **Update/Delete**: `PATCH`/`DELETE` on `/api/v1/users/preferred-tags/{id}/`

---

## Trips & Recommendations

### Create Recommendation on the Fly
- **Endpoint**: `POST /api/v1/trips/recommendations/`
- **Payload**:
  ```json
  {
    "time_budget_min": 150,
    "budget_min": 5000,
    "budget_max": 20000,
    "mode": "walk",
    "categories": ["cafe", "gallery"],
    "mood": ["calm"],
    "tags": ["minimal"],
    "district": "paldal-gu"
  }
  ```
- **Response**: `201 Created` with full Trip object (nodes + summary).
- **Errors**: `400 Bad Request` with `{"error": "no_places_available"}` if nothing matches.

### Trip CRUD
- **List**: `GET /api/v1/trips/`
- **Retrieve**: `GET /api/v1/trips/{id}/`
- **Create**: `POST /api/v1/trips/`
- **Update/Delete**: `PATCH`/`DELETE /api/v1/trips/{id}/`

### Instantiate from Templates
- **Endpoint**: `POST /api/v1/trips/from-template/`
- **Payload**:
  ```json
  {
    "template_id": "<template_uuid>",
    "title": "Weekend course"
  }
  ```
- **Response**: `201 Created` with new Trip cloned from template nodes.

### Trip Templates
- **List**: `GET /api/v1/trip-templates/`
  - Non-staff users see only `is_published=true` templates.
- **Detail**: `GET /api/v1/trip-templates/{id}/`
- **Create/Update/Delete**: Staff-only via `POST/PATCH/DELETE`.

---

## AI Trip Template Jobs

### Create AI Template Job
- **Endpoint**: `POST /api/v1/trip-template-ai-jobs/`
- **Payload**:
  ```json
  {
    "brief": "Calm afternoon in Suwon with local cafes and bookstores",
    "location": "Suwon Paldal-gu",
    "mood_tags": ["calm", "minimal"],
    "avoid": ["crowded"],
    "duration_min": 240,
    "stops": 3,
    "budget_level": "standard",
    "time_of_day": "afternoon",
    "additional_notes": "Prefer walking distance between stops"
  }
  ```
- **Response**: `201 Created`
  ```json
  {
    "id": "<job_uuid>",
    "status": "queued",
    "prompt": { ... },
    "result": {},
    "created_at": "..."
  }
  ```
- **Behavior**: Backend enqueues Celery task (`trips.request_ai_template`). Frontend should poll job detail until `status` becomes `completed` or `failed`.

### List Jobs
- **Endpoint**: `GET /api/v1/trip-template-ai-jobs/`
- **Response**: Paginated list of jobs belonging to the current user.

### Retrieve Job Detail
- **Endpoint**: `GET /api/v1/trip-template-ai-jobs/{id}/`
- **Completed Response Example**:
  ```json
  {
    "id": "<job_uuid>",
    "status": "completed",
    "model": "anthropic/claude-3.5-sonnet",
    "prompt": { ... },
    "result": {
      "title": "Suwon Slow Day",
      "summary": "Cozy cafes and local markets for a slow afternoon",
      "duration_min": 210,
      "mood_tags": ["warm", "cozy"],
      "stops": [
        {
          "name": "팔달문시장",
          "description": "Street food and artisan shops",
          "stay_min": 50,
          "place_id": "..."
        }
      ],
      "tips": "Leave room for spontaneous discoveries",
      "slug": "suwon-slow-day"
    },
    "created_at": "...",
    "updated_at": "...",
    "completed_at": "..."
  }
  ```

### Error Handling
- If OpenRouter is misconfigured, job transitions to `status = failed` with `error_code = "openrouter_not_configured"`.
- For unexpected issues, frontend will see `error_code = "processing_error"`.

---

## Missions & Gamification (Optional)

### Mission Queue
- **List**: `GET /api/v1/missions/`
- **Complete**: `POST /api/v1/mission-assignments/`

### Feedback
- **Endpoint**: `POST /api/v1/feedback/`
- Gather user mood/experience after trips.

---

## Notifications & Party

- **Notifications**: `GET /api/v1/notifications/`
- **Push Subscriptions**: `POST /api/v1/push-subscriptions/`
- **Party Sessions**: `POST /api/v1/party/sessions/`

---

## Common Notes

- **Base URL**: All paths above are relative to `/api/v1/` unless specified (e.g., auth endpoints under `/api/auth/`).
- **Auth**: JWT access token via `Authorization: Bearer <token>`.
- **Pagination**: DRF LimitOffsetPagination, default `limit=20`. Use `limit` & `offset` query params.
- **Error Format**: Standard DRF error JSON, e.g., `{"detail": "Authentication credentials were not provided."}`.
- **Rate Limiting**: Deployments may enable throttling for heavy endpoints (recommendation/AI jobs). Handle `429 Too Many Requests` gracefully.

---

For additional endpoints or schema updates, check the live OpenAPI schema at `GET /api/schema/` or Swagger UI at `/api/docs/` when the backend server is running.
## Daily Missions

### Sync Daily Missions
- **Endpoint**: `POST /api/v1/mission-assignments/daily-sync/`
- **Description**: Assign all active daily missions to the current user for today. Returns the assignment list.
- **Response**: `200 OK` with mission assignment objects.

### Update Assignment Status
- **Endpoint**: `PATCH /api/v1/mission-assignments/{id}/`
- **Payload**:
  ```json
  {
    "status": "completed",
    "result_metadata": {
      "note": "Visited two spots"
    }
  }
  ```
- **Behavior**: When `status` becomes `completed`, the backend grants the configured reward (currency, stamp, or badge) and locks the assignment.
- **Response**: Updated assignment with `reward_granted=true`.

### Assignment Schema Notes
- `reward` field summarizes the reward (`type`, `code`, `amount`).
- `profile_token_balance` on the user model reflects cumulative currency earned.
- `stamps` / `badges` arrays returned from the user profile list unlocked customization items.
