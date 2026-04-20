---
name: backend-test-python
description: Python API testing with pytest, pytest-asyncio, httpx, SQLAlchemy test fixtures, factory_boy
metadata:
  version: 1.0
  domain: backend
  keywords: [python, pytest, pytest-asyncio, httpx, fastapi test, django test, sqlalchemy test, factory boy, respx]
---

# Backend Test — Python

Pair with `backend-test` for universal testing principles.

## Setup

- Use `pytest` with `pytest-asyncio` for async test support — never `unittest` for new code
- Use `httpx.AsyncClient` for FastAPI integration tests — never `requests` (sync)
- Use `pytest-asyncio` with `asyncio_mode = "auto"` in `pyproject.toml` — never `@pytest.mark.asyncio` per test
- Use a real test database — never mock SQLAlchemy session or Django ORM (schema bugs hide behind mocks)
- Use separate test DB configured via `DATABASE_URL` in `.env.test` or pytest fixture override

## FastAPI Integration Testing

```python
# Always use httpx.AsyncClient with ASGITransport
async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
    response = await client.post("/users", json=body)
```

- Always test at HTTP layer — never call route handlers directly
- Override dependencies for test DB: `app.dependency_overrides[get_db] = get_test_db`
- Clear `dependency_overrides` after each test — never let overrides leak

## Database Fixtures

- Use `pytest` fixtures with `scope="function"` for DB transactions — roll back after each test
- Use SQLAlchemy: begin transaction in fixture, yield session, rollback in teardown
- Use `factory_boy` with SQLAlchemy integration for test data — never hardcoded fixture dicts
- Never use production DB — always test-scoped DB or SQLite for pure logic tests

## Django Testing

- Use `pytest-django` with `@pytest.mark.django_db` — never `TestCase` for new code
- Use `django.test.AsyncClient` for async views — never sync client with async views
- Use `mixer` or `factory_boy` for model factories — never raw `Model.objects.create()` inline in tests
- Use `@pytest.mark.django_db(transaction=True)` only when testing transaction behavior — default is non-transactional (faster)

## External Services

- Use `respx` to mock external HTTP calls in async tests — never mock `httpx.AsyncClient` directly
- Use `responses` library for sync HTTP mocking (requests-based) — never monkeypatch `requests.get`
- Always assert mock was called: `respx.calls.call_count`, `respx.calls.last.request`

## Auth Testing

- Always test protected endpoints return `401` without Authorization header
- Always test `403` when authenticated user lacks required permission/role
- Use fixture that returns valid JWT or session cookie for authenticated requests

## Hard Rules

- Never mock SQLAlchemy session or Django ORM for integration tests — real DB always
- Never `requests` in async test context — `httpx.AsyncClient` always
- Never hardcode test data inline — `factory_boy` or fixtures always
- Always test 401 on protected endpoints
- Always clean DB state between tests — never share mutable DB state

## Done Criteria

- All API endpoints tested via `httpx.AsyncClient` or Django test client at HTTP layer
- Auth enforcement tested (401 without token, 403 with wrong role)
- Validation rejection tested (422 with invalid body for FastAPI, 400 for Django)
- Real DB used with per-test transaction rollback
- All external HTTP mocked via `respx` or `responses`
- `factory_boy` used for all test model creation
