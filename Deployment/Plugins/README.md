# Plugin System

Plugins define how resources are processed by `Deploy-All.sh`. Each plugin is described in a JSON file inside `Deployment/Plugins/`. The engine dispatches to the correct plugin based on the `type=` field in a file's deployment marker.

---

## Available Plugins

### file

Installs a file to the target directory using `install -m`.

```json
{
  "command": "install -m \"$CHMOD\" -- \"$TMPFILE\" \"$TARGET/$BASENAME\""
}
```

Use for: regular config files, scripts, and any file that should be copied with specific permissions.

---

### symlink

Creates a forced symbolic link pointing at the source file.

```json
{
  "name": "symlink",
  "description": "A format to unpack symlinks",
  "command": "ln -sfn -- \"$(realpath -- \"$SOURCE\")\" \"$TARGET/$BASENAME\""
}
```

Use for: files that must always reflect the repo version without a copy step.

---

### archive

Extracts an archive into the target directory.

```json
{
  "name": "archive",
  "description": "A basic flag for the archives decompressing",
  "command": "tar -xf -- \"$TMPFILE\" -C \"$TARGET\""
}
```

Use for: tar archives (`.tar.gz`, `.tar.xz`, etc.) that should be unpacked in place.

---

### deployable-archive

Extracts an archive and then recursively processes the unpacked contents with the deployment engine, so nested markers are also evaluated.

```json
{
  "name": "deployable-archive",
  "description": "Extract archive into target and recursively process unpacked files.",
  "script": "deployable-archive.sh"
}
```

Use for: self-contained bundles that contain their own markers.

---

### script-dep

Runs a dependency installer script before deploying the file. Useful for files that require packages to be present on the target system first.

Plugin delegates to `script-dep.sh`.

Use for: workaround files that depend on packages not guaranteed to be installed.

---

## Environment Variables Available to Plugins

| Variable | Description |
|----------|-------------|
| `$SOURCE` | Absolute path to the source file |
| `$TARGET` | Target directory |
| `$BASENAME` | Filename without directory |
| `$TMPFILE` | Temp file with marker lines stripped (or `$SOURCE` for archives) |
| `$CHMOD` | Permission bits (e.g., `644`, `755`) |
| `$SCRIPT_DIR` | Repository root directory |

---

## Adding a New Plugin

1. Create a JSON file in `Deployment/Plugins/` named `<type>.json`.
2. Define either a `command` string (evaluated with `bash -c`) or a `script` filename (executed as `bash <script>`).
3. Use the environment variables listed above.
4. Document the new type here.

---

## Plugin Philosophy

- Plugins should be small and do exactly one thing.
- Plugins should not assume hidden state beyond the documented environment variables.
- If a plugin becomes complex, extract logic into a dedicated `.sh` helper and reference it via the `script` field.
