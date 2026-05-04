# Sourced by ../build.sh; deprecated legacy launcher overlay
#
# This stage used to overwrite /usr/local/bin/lolios-exe-launcher.
# The canonical launcher now lives in src/bin/lolios-exe-launcher and is
# installed by stages/17z-install-src-gaming-tools.sh.  Keep this file as a
# compatibility placeholder so older build references do not break, but do not
# generate conflicting binaries here.

log "Skipping deprecated legacy LoliOS EXE launcher overlay; src/bin version is canonical"
