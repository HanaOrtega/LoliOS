# LoliOS Builder — wersja podzielona

Ten katalog zawiera podzieloną wersję skryptu budującego LoliOS ArchISO. Logika została zachowana w tej samej kolejności co w wersji monolitycznej, ale każdy większy etap jest w osobnym pliku w `stages/`.

## Jak uruchomić

```bash
chmod +x build.sh scripts/check-project.sh
./scripts/check-project.sh
./build.sh
```

Typowe zmienne środowiskowe działają tak jak wcześniej, np.:

```bash
WORKROOT="$HOME/lolios-build-v2" USE_AUR_FALLBACK=1 ./build.sh
BUILD_ISO=0 ./build.sh
ISO_STAGE=0 ./build.sh
PREBUILT_REPO_DIR=/srv/lolios-repo ./build.sh
```

## Co jest do czego

| Plik / katalog | Opis |
|---|---|
| `build.sh` | Główny wrapper. Ustala `PROJECT_ROOT`, sprawdza obecność etapów i źródłuje pliki z `stages/` w ustalonej kolejności. |
| `stages/00-global-config.sh` | Zmienne globalne: nazwa ISO, `WORKROOT`, `PROFILE`, repo lokalne, tryby AUR/repo/ISO, QEMU smoke test. |
| `stages/01-common-helpers.sh` | Funkcje wspólne: logowanie, błędy, wymagane komendy/pliki, dodawanie/usuwanie pakietów, czyszczenie mountów i katalogów builda. |
| `stages/01b-runtime-repo-helpers.sh` | Lockfile, logi, snapshot Arch Linux Archive, helpery repo v2 i budowanie AUR. |
| `stages/02-preflight.sh` | Start runtime, trap cleanup, walidacja użytkownika, sudo, zależności hosta. |
| `stages/03-fresh-profile.sh` | Tworzenie świeżego profilu ArchISO z `/usr/share/archiso/configs/releng`. |
| `stages/04-profiledef.sh` | Generowanie `profiledef.sh`, bootmodes, kompresja squashfs, uprawnienia plików. |
| `stages/05-pacman-conf.sh` | Generowanie `pacman.conf` dla profilu, repo `core/extra/multilib` i lokalne repo LoliOS. |
| `stages/06-local-repo-aur.sh` | Import/budowa repo lokalnego, AUR fallback, `lolios-game-devices-udev`, odświeżanie bazy repo i osadzanie repo w ISO. |
| `stages/07-packages.sh` | Główna lista `packages.x86_64` oraz usuwanie znanych złych/konfliktowych nazw. |
| `stages/07b-feature-packages.sh` | Dodatkowe pakiety “10/10”, ponowna deduplikacja i czyszczenie. |
| `stages/08-identity.sh` | `os-release`, hostname, motd, marker live ISO. |
| `stages/09-mkinitcpio.sh` | Konfiguracja mkinitcpio dla ArchISO. |
| `stages/10-live-user.sh` | Tworzenie użytkownika live, sysusers/tmpfiles i usługa systemd przed SDDM. |
| `stages/11-live-sudo-polkit.sh` | Live-only sudoers/polkit oraz reguła GameMode. |
| `stages/12-sddm-services.sh` | SDDM autologin, Plasma X11 session, enable usług systemd w live ISO. |
| `stages/13-calamares.sh` | Konfiguracja Calamares: sekwencja modułów, branding, users, displaymanager, shellprocess. |
| `stages/14-postinstall.sh` | Skrypt `/root/postinstall.sh` wykonywany po instalacji przez Calamares. |
| `stages/15-wallpaper-kde-defaults.sh` | Tapeta, domyślne ustawienia KDE/Plasma i konfiguracja użytkownika live. |
| `stages/16-installer-launcher.sh` | Launcher instalatora LoliOS. |
| `stages/17-gaming-tools.sh` | Narzędzia LoliOS: EXE runner, Gaming Center, update, GPU profile, repair tools. |
| `stages/17b-extra-feature-tools.sh` | Dodatkowe narzędzia diagnostyczne/funkcje “10/10”. |
| `stages/18-gaming-system-config.sh` | Limity, sysctl, moduły i konfiguracja systemowa pod gaming. |
| `stages/19-boot-menu.sh` | Nazwy boot menu, wpisy UEFI, safe graphics/recovery. |
| `stages/20-cleanup-hooks.sh` | Usuwanie duplikatów, przestarzałych autostartów i hooków. |
| `stages/21-audit.sh` | Audyt profilu przed buildem. |
| `stages/22-qemu-smoke-test.sh` | Helper opcjonalnego smoke testu QEMU. |
| `stages/23-build-iso.sh` | Finalne przygotowanie, walidacja pakietów, `mkarchiso`, checksum i podpis ISO. |
| `scripts/check-project.sh` | Lokalny check: `bash -n`, sprawdzenie source targetów i kilku krytycznych invariantów ścieżek. |
| `docs/` | Kopia wersji monolitycznej, patch z poprzedniego kroku i informacja o sposobie podziału. |

## Ważne uwagi

- Podział jest konserwatywny: kolejność wykonywania została zachowana, żeby nie zmieniać zachowania builda.
- Pliki w `stages/` są źródłowane przez `build.sh`. Nie uruchamiaj ich bezpośrednio.
- `WORKROOT`, `PROFILE`, `REPO_DIR`, `CUSTOMREPO` nadal są generowane tak jak w poprawionej wersji monolitycznej.
- Pełnego `mkarchiso` nie da się wiarygodnie przetestować poza hostem Arch z `pacman`, `sudo`, `archiso` i dostępem do repozytoriów.
