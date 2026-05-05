# LoliOS Compatibility Suite

This directory is the standalone application boundary for LoliOS Windows compatibility tools.

It owns the user-facing compatibility stack:

- `lolios-exe-launcher`
- `lolios-profile`
- `lolios-gaming-center`
- `lolios-app-center`
- `lolios-guard-status`
- desktop launchers for Game Center and App Center
- LoliOS product marker used by the guard

The base system should not hard-code these tools directly. The ISO build installs this suite as a separate program through `install-to-airootfs.sh`. The same source layout can later be turned into a normal pacman package using the included `PKGBUILD`.

Current transition note:

- canonical application packaging lives here;
- source files are still read from the repository `src/` tree during the transition;
- future cleanup should move the actual source files into `programs/lolios-compat-suite/src/` and remove the legacy top-level `src/` copy.

This keeps Game Center, App Center, EXE launching, profile management and related compatibility UI isolated from the operating-system build logic.
