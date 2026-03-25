# Deployment Helper Scripts

Utility scripts supporting the `Deploy-All.sh` deployment engine.

---

## check-deps.sh

Checks that required binaries exist before deployment begins.

Prevents partial execution failures caused by missing tools (`tar`, `jq`, `realpath`, `install`).

Run this before `Deploy-All.sh` if you are unsure whether all dependencies are present.

---

## pack-deployable.sh

Packages a set of files into a deployable archive — a tarball that carries its own deployment markers.

When the archive is deployed via `Deploy-All.sh` with `type=deployable-archive`, it is extracted and the engine recursively processes the unpacked contents, dispatching any markers found inside.

Use this to bundle multiple related files into a single self-contained deployment unit.

---

## Code of Conduct

- Helper scripts must be focused — each script does one thing.
- Helper scripts must not duplicate engine logic from `Deploy-All.sh`.
- If a helper becomes complex enough to need its own tests, document it here.
