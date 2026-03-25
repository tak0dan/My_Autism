# Documentation Summary

Overview of all documentation in this repository.

---

## Repository Documentation Map

```
WtfOS/
├── README.md                                    ← Project overview, design philosophy, quick start
├── [README]Deploy-All                           ← Deploy-All.sh engine reference
├── NixOS/
│   ├── INSTALL.md                               ← Full NixOS installation guide
│   └── nixos-build/
│       ├── README.md                            ← nixos-build directory structure and feature flags
│       ├── modules/
│       │   └── README.md                        ← System modules reference
│       └── nixorcist/
│           ├── README.md                        ← Nixorcist overview and command reference
│           ├── INSTALL.md                       ← Nixorcist installation into any NixOS config
│           ├── README_cli.md / README_CLI.md    ← TUI engine and visual output API
│           ├── README_lock.md / README_LOCK.md  ← Transaction engine and pipeline
│           ├── README_gen.md / README_GEN.md    ← Module generation pipeline
│           ├── README_hub.md / README_HUB.md    ← Hub file aggregation
│           ├── README_REBUILD.md                ← Smart rebuild and error resolver
│           └── README_utils.md / README_UTILS.md← Validation cache and package search
├── Configs/
│   └── Readme.md                                ← Dotfile deployment and Hyprland config guide
├── Files/
│   └── Readme.md                                ← Files directory purpose and marker format
├── Scripts/
│   └── Readme.md                                ← Standalone scripts reference
├── Apps-Workarounds/
│   └── README.md                                ← Application workarounds and desktop overrides
└── Deployment/
    ├── Plugins/
    │   └── README.md                            ← Plugin types and environment variables
    └── Scripts/
        └── README.md                            ← Deployment helper scripts
```

---

## Quick Navigation

| Need | Document |
|------|----------|
| Fresh NixOS install | [NixOS/INSTALL.md](NixOS/INSTALL.md) |
| Project overview | [README.md](README.md) |
| nixos-build structure | [NixOS/nixos-build/README.md](NixOS/nixos-build/README.md) |
| System modules reference | [NixOS/nixos-build/modules/README.md](NixOS/nixos-build/modules/README.md) |
| Nixorcist overview | [NixOS/nixos-build/nixorcist/README.md](NixOS/nixos-build/nixorcist/README.md) |
| Nixorcist install only | [NixOS/nixos-build/nixorcist/INSTALL.md](NixOS/nixos-build/nixorcist/INSTALL.md) |
| CLI / TUI reference | [NixOS/nixos-build/nixorcist/README_cli.md](NixOS/nixos-build/nixorcist/README_cli.md) |
| Package management | [NixOS/nixos-build/nixorcist/README_lock.md](NixOS/nixos-build/nixorcist/README_lock.md) |
| Module generation | [NixOS/nixos-build/nixorcist/README_gen.md](NixOS/nixos-build/nixorcist/README_gen.md) |
| Hub aggregation | [NixOS/nixos-build/nixorcist/README_hub.md](NixOS/nixos-build/nixorcist/README_hub.md) |
| Smart rebuild | [NixOS/nixos-build/nixorcist/README_REBUILD.md](NixOS/nixos-build/nixorcist/README_REBUILD.md) |
| Validation cache | [NixOS/nixos-build/nixorcist/README_utils.md](NixOS/nixos-build/nixorcist/README_utils.md) |
| Dotfile deployment | [Configs/Readme.md](Configs/Readme.md) |
| Deploy-All engine | [[README]Deploy-All]([README]Deploy-All) |
| Plugin types | [Deployment/Plugins/README.md](Deployment/Plugins/README.md) |
| Standalone scripts | [Scripts/Readme.md](Scripts/Readme.md) |
| App workarounds | [Apps-Workarounds/README.md](Apps-Workarounds/README.md) |

---

## Documentation Standards

All documentation in this repository follows these conventions:

- Each directory has a README describing its contents and purpose.
- Code examples use fenced code blocks with language identifiers.
- Potentially destructive operations include a warning notice.
- Security-sensitive tools include a notice about authorized use.
- Cross-references use relative markdown links.
- Placeholder values (usernames, hostnames) are clearly marked for customization.
