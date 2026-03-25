# Files

Miscellaneous files managed by the `Deploy-All.sh` deployment engine.

This directory holds files that do not belong in `Configs/` or `Apps-Workarounds/` but still need to be deployed to specific locations on the system.

---

## Purpose

`Files/` is a catch-all for:

- Static assets that need to land in a specific path
- Configuration snippets that don't belong to a named application
- One-off files needed by system services or tools

---

## Deployment

Files here use the same marker system as `Configs/`:

```bash
#<--[/target/path|chmod=644|type=file]-->#
```

Run `./Deploy-All.sh` from the repo root to deploy all marked files.

---

## Code of Conduct

- Every file in this directory should have a marker or an explanation of why it's here.
- Prefer placing application-specific configs in `Configs/` and application workarounds in `Apps-Workarounds/`.
- Do not store secrets or credentials in this directory.