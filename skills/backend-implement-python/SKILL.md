---
name: backend-implement-python
description: Python 3.12+ backend patterns — FastAPI, Django REST, SQLAlchemy 2.x, Pydantic v2, Alembic
metadata:
  version: 1.0
  domain: backend
  keywords: [python, fastapi, django, sqlalchemy, pydantic, alembic, rest api, async, celery, pytest, uvicorn]
---

# Backend Implement — Python

Pair with `backend-implement` for universal rules.

## Async Patterns

- FastAPI: always `async def` for route handlers that perform I/O — never `def` (blocks the event loop)
- Use `asyncio.gather()` for parallel independent async calls — never sequential `await` when parallelism is possible
- Never mix sync and async DB drivers — pick asyncpg/aiomysql for async or psycopg2/mysqlclient for sync WSGI
- Use `anyio.to_thread.run_sync()` to run blocking code from async context — never `asyncio.run()` inside a coroutine

## Validation — FastAPI + Pydantic v2

- Always Pydantic v2 models for request bodies, response models, and settings — never plain `dict` inputs
- Always set `response_model=` on every route — never return raw dicts from FastAPI endpoints
- Use `model_config = ConfigDict(str_strip_whitespace=True, strict=True)` on models
- Never `.dict()` on Pydantic models — always `.model_dump()` (v2 API)
- Validate env config with `pydantic-settings` `BaseSettings` — never raw `os.environ` in application code

## Validation — Django REST Framework

- Always DRF serializers or `django-ninja` schemas for request validation — never raw `request.data` access
- Always `serializer.is_valid(raise_exception=True)` — never manually check `.errors` and return yourself
- Never bypass serializer validation with direct model `.save()` from request data

## ORM / Database

- SQLAlchemy 2.x: always use `select()` / `insert()` / `update()` Core-style statements — never legacy `Query` API (`.query(Model)`)
- Always use Alembic for schema migrations — never `Base.metadata.create_all()` in production
- Use `async with AsyncSession() as session:` scoped per request — never reuse sessions across requests
- Django ORM: always `select_related()` / `prefetch_related()` for related objects — never trigger N+1 in views
- Always use `F()` expressions for atomic numeric field updates — never read-modify-write patterns

## Error Handling

- FastAPI: always `raise HTTPException(status_code=..., detail={...})` — never raise plain Python exceptions from routes
- Register custom exception handlers with `@app.exception_handler(MyException)` for domain exceptions
- Django: use DRF `EXCEPTION_HANDLER` setting for custom handling — never `try/except` in every view function
- Use `structlog` or stdlib `logging` with JSON formatter — never bare `print()` in production code
- Never expose Python tracebacks in API responses — log them, return only structured error to client

## Security

- Always `python-jose[cryptography]` or `PyJWT` for JWT — validate `exp`, `iss`, `aud` — never trust unvalidated tokens
- Always hash passwords with `passlib[bcrypt]` or Django's built-in hasher — never `hashlib.md5/sha1`
- Never put secrets in code or `.env` committed to git — always `pydantic-settings` sourced from environment
- Always ORM or `text()` with bound parameters for SQL — never f-string or `%`-formatted SQL

## Type Hints

- Always type-annotate all function signatures — never untyped functions in new code
- Use `from __future__ import annotations` for forward references in Python < 3.12
- Run `pyright` (preferred) or `mypy` in strict mode as part of CI

## Hard Rules

- Never `def` route handlers in FastAPI doing I/O — `async def` always
- Never `os.environ` in application code — `pydantic-settings` always
- Never `Base.metadata.create_all()` — Alembic migrations always
- Never f-string SQL or `%`-formatted SQL — ORM / bound params always
- Never `print()` in production — structured logger always
- Never return raw `dict` from FastAPI routes — `response_model` always

## Done Criteria

- All FastAPI routes have `response_model` set
- All env config via `pydantic-settings` BaseSettings — no `os.environ`
- No `Base.metadata.create_all()` in production code paths
- No f-string or string-format SQL anywhere
- All function signatures type-annotated
- Structured logging used — no `print()` calls
- `pyright`/`mypy` reports zero errors
