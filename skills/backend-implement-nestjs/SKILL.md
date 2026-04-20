---
name: backend-implement-nestjs
description: NestJS 10+ patterns — modules, DI, controllers, services, pipes, guards, interceptors, Prisma/TypeORM
metadata:
  version: 1.0
  domain: backend
  keywords: [nestjs, nest, nest.js, typescript, module, controller, service, guard, pipe, interceptor, decorator, di, dependency injection, typeorm, prisma, fastify nest]
---

# Backend Implement — NestJS

Pair with `backend-implement` for universal rules. Also pair with `backend-implement-node` for Node.js-specific patterns.

## Module Structure

- One feature module per domain: `UsersModule`, `OrdersModule`, `AuthModule` — never one giant `AppModule`.
- Module exports only what other modules need — keep providers private by default.
- Use `forRoot()` / `forRootAsync()` for global singleton modules (DB, config, cache).
- Use `forFeature()` for feature-scoped registrations (TypeORM repositories, Prisma models).
- Never import `AppModule` from feature modules — only upward dependencies.

## Controllers

- Controllers handle HTTP only — no business logic, no DB calls.
- Use `@Controller('resource')` with plural noun resource names — matches REST conventions.
- Always use typed DTOs for `@Body()`, `@Param()`, `@Query()` — never `any` or plain `object`.
- Return data directly from controller methods — NestJS serializes automatically via `ClassSerializerInterceptor`.
- Use `@HttpCode(HttpStatus.CREATED)` on POST endpoints that return 201.

## Services

- All business logic lives in services — never in controllers, guards, or pipes.
- Services depend on other services or repositories via constructor injection only.
- Never use `ModuleRef.get()` to manually resolve — redesign if circular dependency appears.
- Mark services as `@Injectable()` — never instantiate with `new`.

## Dependency Injection

- Always constructor injection: `constructor(private readonly usersService: UsersService)`.
- Use `@Optional()` only when a dependency is genuinely optional — not to paper over missing registrations.
- Use `@Inject(TOKEN)` for value/factory providers — always pair with typed interface.
- Circular dependencies signal design problems — resolve with `forwardRef()` only as last resort, then refactor.

## Validation with Pipes

- Register `ValidationPipe` globally in `main.ts`:
  ```ts
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,        // strip unknown properties
    forbidNonWhitelisted: true,
    transform: true,        // auto-transform types (string → number for @Param)
    transformOptions: { enableImplicitConversion: true },
  }))
  ```
- Use `class-validator` decorators on DTOs — never manual validation logic in controllers or services.
- Use `class-transformer` `@Exclude()` on response DTOs to strip sensitive fields — always register `ClassSerializerInterceptor` globally.
- Never accept `any` in a DTO — every field must be typed and decorated.

## Guards (Auth & Authorization)

- Implement auth as a `CanActivate` guard — never inline token checks in controllers.
- Attach with `@UseGuards(JwtAuthGuard)` at controller or method level.
- Use `@SetMetadata` + custom decorator for role/permission metadata:
  ```ts
  export const Roles = (...roles: Role[]) => SetMetadata('roles', roles)
  ```
- Use `Reflector` in guards to read metadata — never hard-code roles in guard logic.
- Mark public endpoints with `@Public()` decorator — guards check for it before validating token.

## Interceptors

- Use `ClassSerializerInterceptor` globally for response transformation.
- Use interceptors for cross-cutting concerns: logging, response wrapping, caching.
- Never put business logic in interceptors — only infrastructure concerns.

## Exception Filters

- Use `HttpException` subclasses for expected errors: `NotFoundException`, `BadRequestException`, `UnauthorizedException`.
- Create custom exception filter with `@Catch(ExceptionClass)` for domain exceptions.
- Register global exception filter in `main.ts` — never try/catch in every controller.
- Never expose stack traces in responses — log them, return structured `ProblemDetails`-style response.

## Configuration

- Always use `@nestjs/config` `ConfigService` — never `process.env.VAR` in services or controllers.
- Validate config at startup with `Joi` or `zod` schema passed to `ConfigModule.forRoot({ validationSchema })`.
- Use `ConfigModule.forRoot({ isGlobal: true })` — avoids importing ConfigModule in every feature module.

## Database — Prisma (preferred)

- Use `PrismaService` extending `PrismaClient` registered as a global module.
- Inject `PrismaService` in services — never access `prisma` as a global singleton.
- Always use Prisma transactions for multi-step mutations: `prisma.$transaction([...])`.
- Never call `$connect()` / `$disconnect()` in request handlers.

## Database — TypeORM (if used)

- Use `TypeOrmModule.forFeature([Entity])` in feature module — never import repositories directly.
- Inject repositories via `@InjectRepository(Entity)`.
- Always use query builder or repository methods — never raw SQL string concatenation.
- Use migrations — never `synchronize: true` in production.

## Hard Rules

- Never business logic in controllers — services only.
- Never `process.env` in services/controllers — `ConfigService` always.
- Never `any` typed DTOs — all fields decorated with `class-validator`.
- Never `synchronize: true` in TypeORM production config — migrations always.
- Never circular imports without `forwardRef()` — prefer redesign.
- Never manual `new Service()` — DI container always.

## Done Criteria

- `ValidationPipe` with `whitelist: true` registered globally.
- `ClassSerializerInterceptor` registered globally.
- `ConfigModule` global, all env access via `ConfigService`.
- All auth via `@UseGuards()` — no inline token checks.
- All DTOs have `class-validator` decorators — no `any`.
- No `synchronize: true` in DB config.
- LSP reports zero errors.
