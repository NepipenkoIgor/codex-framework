---
name: mlops
description: Design and implement dataset and model artifact lineage, training or fine-tuning pipelines, registries, evaluation gates, rollout, monitoring, drift response, and rollback. Use when learned-model lifecycle operations are primary; do not use for prompt evaluation, production LLM usage accounting, or ordinary application deployment.
metadata:
  owner: codex-framework
  reviewed: "2026-09-09"
  version: 1.1
  argument-hint: "model, data, training, registry, deployment and drift requirements"
---

## Workflow

1. Generate project stack context and inspect manifests/lockfiles, dataset sources/licensing/privacy, feature and label definitions, split logic, experiment tracking, training code and preprocessing, artifact store/format, registry, serving runtime and hardware/accelerator capability, evaluation, and the monitoring feature pipeline as one compatibility unit. Verify that monitoring consumes the same compatible feature/schema/transform lineage as training and serving rather than merely detecting drift afterward. Preserve pins, verify version-sensitive behavior with installed capability plus matching official documentation, and treat migration separately.
2. Make data, code, environment, configuration, base model, preprocessing/feature schema, and artifact lineage reproducible. Prevent train/eval leakage and cross-tenant data mixing. Define privacy deletion propagation through source datasets, derived features/artifacts, registry lineage and deployed models, including retraining or revocation when deletion cannot be applied in place.
3. Define offline and online acceptance gates tied to product harm, not one aggregate score. Record exact, estimated, and missing cost/usage separately.
4. Use immutable artifacts and a signed or equivalently authenticated/integrity-verifiable promotion decision bound to exact data/code/config/model digests, approver authority and policy version. Resolve promotion plus incident/rollback/revocation authority before release. Apply staged/canary rollout, compatibility checks, rollback, revocation and dynamically resolved provider/model capabilities.
5. Verify reproducibility, corrupted/missing artifacts, leakage, cross-tenant isolation, training-serving skew, hardware/runtime compatibility, privacy deletion through derived artifacts and deployed lineage, rollback, shadow/canary behavior, drift alerts, revocation and caller-visible product outcomes.

## Output

Report lineage, data rights/deletion propagation and risks, pipeline and registry, signed promotion evidence, evaluation gates, serving runtime/hardware compatibility, rollout/rollback, monitoring and drift policy, executed evidence, costs, and untested provider boundaries.
