# Performance budget tooling guide

Use only after routes, slices, baselines, variance and budgets are defined.

Configure the repository's installed build analyzer, lab runner and RUM provider rather than introducing a preferred stack. Pin browser/runtime/action versions from repository policy and current official sources. Run equivalent build modes, routes, cache state, device/network emulation and repeated samples.

Artifact gates should use the actual route/chunk graph and distinguish initial, lazy and shared bytes. Lab gates should retain protected diagnostic artifacts and account for variance. Field gates should compare release cohorts by route/device/network/geography with bounded privacy-safe dimensions and sufficient volume; sampling/missingness must be explicit.

Never publish raw traces, URLs, headers, screenshots or RUM exports containing sensitive data. Test permissions, retention, exception expiry, a known regression and rollback before making the gate required.
