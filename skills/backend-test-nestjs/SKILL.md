---
name: backend-test-nestjs
description: NestJS testing with Test.createTestingModule, provider mocking, guard/pipe/interceptor isolation, supertest e2e
metadata:
  version: 1.0
  domain: backend
  keywords: [nestjs, nest, testing, testingmodule, createtestingmodule, e2e test, supertest, guard test, pipe test, interceptor test, jest nest]
---

# Backend Test — NestJS

Pair with `backend-test` for universal principles.

## Unit Testing — Services

Bootstrap only the slice under test — never the full AppModule:

```ts
let service: UsersService
let prisma: DeepMockProxy<PrismaClient>

beforeEach(async () => {
  const module = await Test.createTestingModule({
    providers: [
      UsersService,
      { provide: PrismaService, useValue: mockDeep<PrismaClient>() },
      { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue('value') } },
    ],
  }).compile()

  service = module.get(UsersService)
  prisma = module.get(PrismaService)
})
```

- Never import `AppModule` in unit tests — always create minimal module with only the dependencies under test
- Use `jest-mock-extended` `mockDeep<PrismaClient>()` for type-safe Prisma mocks
- Override every provider the service depends on — never let real implementations leak in

## Unit Testing — Controllers

```ts
const module = await Test.createTestingModule({
  controllers: [UsersController],
  providers: [{ provide: UsersService, useValue: { findAll: jest.fn(), create: jest.fn() } }],
}).compile()
```

- Test controllers independently from services — mock all service methods
- Verify controller calls the correct service method with correct args
- Never test business logic through controller unit tests — that lives in service tests

## Unit Testing — Guards

```ts
const guard = new JwtAuthGuard(jwtService, reflector)
const context = createMock<ExecutionContext>()
context.switchToHttp().getRequest.mockReturnValue({ headers: { authorization: 'Bearer valid' } })

const result = await guard.canActivate(context)
expect(result).toBe(true)
```

- Use `@golevelup/ts-jest` `createMock<ExecutionContext>()` for typed mocks of NestJS internals
- Test both allowed and denied paths
- Test `@Public()` decorator bypass — verify guard allows unauthenticated access on public routes

## Unit Testing — Pipes

```ts
const pipe = new ValidationPipe({ whitelist: true })

it('throws on invalid input', async () => {
  await expect(pipe.transform({ email: 'bad' }, { type: 'body', metatype: CreateUserDto }))
    .rejects.toThrow(BadRequestException)
})
```

- Test pipes directly by calling `transform()` — no HTTP layer needed

## E2E Testing

```ts
let app: INestApplication

beforeAll(async () => {
  const module = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(PrismaService)
    .useValue(mockPrisma)
    .compile()

  app = module.createNestApplication()
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }))
  await app.init()
})

afterAll(() => app.close())

it('POST /users returns 201', () =>
  request(app.getHttpServer())
    .post('/users')
    .send({ name: 'Igor', email: 'igor@test.com' })
    .expect(201)
    .expect(({ body }) => expect(body.id).toBeDefined()))
```

- Always apply the same global pipes/interceptors/filters in test as `main.ts` — never skip them
- Use `overrideProvider()` to substitute real DB with mock — never hit real DB in e2e tests
- Always test: 401 without token, 403 with wrong role, 400 with invalid body, 201/200 happy path
- Call `app.close()` in `afterAll` — prevents open handle warnings

## Testing Auth Flows

```ts
// Bypass guard for non-auth tests
.overrideGuard(JwtAuthGuard)
.useValue({ canActivate: () => true })

// Test guard rejection
.overrideGuard(JwtAuthGuard)
.useValue({ canActivate: () => false })
```

- Use `overrideGuard()` to control auth in e2e tests — never forge real JWTs in unit tests
- Always have a dedicated auth e2e test file that uses real `JwtAuthGuard` with valid/invalid tokens

## Hard Rules

- Never import `AppModule` in unit tests — minimal module always
- Never use `app.useGlobalPipes()` differently in tests vs `main.ts` — parity required
- Always `app.close()` in `afterAll`
- Never real DB in any NestJS test — always `overrideProvider(PrismaService)`
- Always test 401/403 paths in e2e

## Done Criteria

- All services unit tested with mocked dependencies
- All controllers unit tested with mocked services
- Guards tested for both allow and deny paths including `@Public()` bypass
- E2E tests cover: 401 no token, 403 wrong role, 400 invalid body, success path
- `app.close()` called in all e2e `afterAll` hooks
- Tests pass with no open handle warnings
