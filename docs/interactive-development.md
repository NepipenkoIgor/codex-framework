# Interactive development contract

This framework makes visible, interactive execution the default for runnable web and native-mobile implementation or diagnosis. Native Browser and platform tooling remain authoritative; the framework adds no browser, server, emulator, retry, or lifecycle wrapper.

## Applicability

Apply the loop to any feature, bug fix, refactor, or review that can change caller-visible behavior in a runnable web or native-mobile application. Read-only explanations, plan-only work, documentation-only changes, backend-only work with no runnable UI effect, and repositories without a runnable UI are exempt.

## Web loop

1. Discover the repository-native package manager, server command, environment, target route, dependencies, and application-level readiness signal. Attach to a compatible healthy server without claiming ownership, or start a task-owned persistent terminal session and record its exact session/PID/port.
2. Lock the task to the in-app Browser binding. Claim a matching existing tab when supported; otherwise create and record a task-owned tab. Navigate to the concrete localhost route and make Browser visible. Chrome or Edge may be used only when the user explicitly names that browser for the current task, and external-browser evidence never substitutes for required in-app product acceptance.
3. Reproduce or inspect the initial state before editing when the task is diagnostic or behavioral. During implementation, use the rendered DOM, console, network, runtime errors, interactions, responsive states, and screenshots only where visual evidence is material.
4. After a meaningful change, rely on verified hot reload only when it actually occurred. Otherwise reload the task tab. Finish with a fresh-load journey and affected loading, empty, error, success, auth, responsive, keyboard/focus, and persisted/server outcomes.
5. Headless browser tests remain valuable regression evidence but do not replace the visible in-app Browser loop. A build, unit test, HTTP status, or screenshot alone is not interactive acceptance.

Visible in-app Browser evidence is a delivery gate for a runnable web path. Record the exact binding, route, state, interaction, console/network result, and final source/environment identity. Automated browser suites prove their own harness only. If the active surface has no in-app Browser, UI acceptance stays unverified and delivery stops before PR; do not substitute `curl`, HTTP 200, a provider dashboard, Chrome/Edge, another external browser profile, or a headless-only run.

Provider control planes use the opposite route: authenticated connector/MCP or CLI/API for data and actions. Open GitHub Actions, Sentry, Supabase, Vercel or another provider in Browser only for an irreducibly visual/UI-only question after same-scope authenticated paths are exhausted and the gap is stated. Browser downloads are not an API.

## Browser recovery and cleanup

- A missing, stale, or closed tab does not invalidate the browser. Discard only the tab binding, inspect current session tabs, and reacquire the exact owned tab or create a fresh task-owned tab in the same binding. Re-select only after an explicit browser-disconnected result.
- Compaction, resume, authentication discovered in another browser, or an external browser already being open does not change the selected binding. Reestablish the task-owned in-app tab and current target; do not silently migrate the task.
- Browser/site approval is native security policy. Never bypass it or switch silently to headless automation. Record the blocked hostname/route and leave interactive acceptance incomplete until approval is available.
- Multiple agents may use separate task-owned tabs or sessions. Parallel writers also require separate worktrees, server ports, and application state.
- On normal closeout, stop only a server started by the task and close/finalize only exact task-owned tabs. Keep a tab only when it is an explicit deliverable or a continuing handoff. Never enumerate localhost tabs and close them broadly.

## Native-mobile loop

1. Discover the installed framework, platform projects, supported launch commands, SDK/toolchain, existing configured targets, app/build variant, backend/Metro/dev-server needs, and device-dependent acceptance.
2. Prefer an already-running compatible configured target without claiming ownership. Otherwise boot a repository-supported visible simulator/emulator/device and record the exact UDID, AVD, process, terminal session, and ports started by the task.
3. Launch the app early and interact during implementation. Reverify the smallest affected platform/device/lifecycle path after changes, including fresh launch or restoration where relevant.
4. Unit, widget, component, headless, and build checks supplement visible device evidence. Physical-only behavior remains explicitly unverified when only a simulator/emulator was available.
5. Stop only task-owned app/server processes and shut down only a target booted by the task. Never reset, erase, or shut down a pre-existing user or other-agent device.

## Failure behavior

Retry a crashed task-owned server or lost task tab only after diagnosing the bounded failure and preserving the same ownership record. If Browser, localhost approval, credentials, SDK, build, device, or isolated parallel target is unavailable, continue safe work that does not depend on it and report the exact missing acceptance evidence. Abrupt host/task termination is best-effort cleanup; do not add a `Stop` hook or global process killer to simulate lifecycle ownership.
