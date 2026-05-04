# LoliOS

**Sweet. Simple. Yours.**

LoliOS is an Arch Linux based desktop and gaming system built around KDE Plasma, a custom LoliOS visual identity, and tools for running Windows games and applications through Wine/Proton.

> **Project status:** LoliOS is currently **in development**. Public builds should be treated as experimental preview releases. Features, default applications, compatibility tools, and visual design may change before a stable release.

---

## English

### About

LoliOS aims to provide a friendly desktop system for everyday use, gaming, and Windows compatibility. It combines a KDE Plasma desktop with LoliOS tools for managing game and application profiles, Wine/Proton prefixes, compatibility fixes, snapshots, logs, and recovery actions.

The system is being developed.

### Current goals

- A polished KDE Plasma desktop with LoliOS styling.
- Separate centers for Windows games and Windows applications.
- Wine/Proton profile management for `.exe` installers and programs.
- Offline-aware repair and diagnostic tools.
- A simple public ISO build process for testers and contributors.

### Development status

LoliOS is not yet a final stable release. Some parts are still being tested and refined, including:

- first boot after installation;
- Game Center and App Center workflows;
- Wine/Proton compatibility presets;
- offline package and runtime handling;
- hardware compatibility across different machines.

Use it for testing, development, and feedback. Do not rely on preview builds as the only operating system on important machines without backups.

### Preparing an ISO

Builds are intended to be created on Arch Linux or an Arch-compatible environment.

Install the required build tools on the host system, then clone the repository:

```bash
git clone https://github.com/HanaOrtega/LoliOS.git
cd LoliOS
```

Run the project check:

```bash
chmod +x build.sh scripts/check-project.sh
./scripts/check-project.sh
```

Build the ISO:

```bash
./build.sh
```

The generated ISO is written to the build output directory under the LoliOS build workspace.

For development builds that need AUR packages, use:

```bash
USE_AUR_FALLBACK=1 ./build.sh
```

A prebuilt local package repository can also be provided:

```bash
PREBUILT_REPO_DIR=/path/to/repo ./build.sh
```

### Notes for users

LoliOS is designed to make Windows game and application setup easier, but compatibility still depends on Wine, Proton, drivers, hardware, and the specific software being run. Some applications may need custom profiles, 32-bit prefixes, additional runtimes, or manual fixes.

### Contributing

Testing, bug reports, logs, documentation improvements, and compatibility feedback are welcome. When reporting issues, include:

- whether the issue happened in Live ISO or installed system;
- hardware or virtual machine details;
- steps to reproduce;
- relevant logs or screenshots;
- whether internet access was available.

---

## Polski

### O systemie

LoliOS to system desktopowo-gamingowy oparty na Arch Linux. Łączy KDE Plasma, własny styl LoliOS oraz narzędzia do uruchamiania gier i programów Windows przez Wine/Proton.

System jest rozwijany.

### Status projektu

LoliOS jest obecnie **w budowie**. Publiczne obrazy ISO należy traktować jako wersje testowe / preview, a nie jako finalne wydanie stabilne.

W trakcie dopracowania są między innymi:

- pierwszy start po instalacji;
- Game Center i App Center;
- profile kompatybilności Wine/Proton;
- działanie offline;
- obsługa różnych konfiguracji sprzętowych.

System można testować, rozwijać i zgłaszać błędy, ale nie należy traktować wersji preview jako jedynego systemu na ważnym komputerze bez kopii zapasowej.

### Cele projektu

- Dopracowany pulpit KDE Plasma ze stylem LoliOS.
- Oddzielne centrum dla gier Windows i programów Windows.
- Zarządzanie profilami Wine/Proton dla instalatorów i plików `.exe`.
- Narzędzia diagnostyczne i naprawcze działające także offline.
- Prosty proces budowy ISO dla testerów i osób rozwijających projekt.

### Przygotowanie ISO

ISO najlepiej budować na Arch Linux albo środowisku zgodnym z Arch.

Sklonuj repozytorium:

```bash
git clone https://github.com/HanaOrtega/LoliOS.git
cd LoliOS
```

Uruchom sprawdzenie projektu:

```bash
chmod +x build.sh scripts/check-project.sh
./scripts/check-project.sh
```

Zbuduj ISO:

```bash
./build.sh
```

Gotowy obraz ISO zostanie zapisany w katalogu wyjściowym workspace builda LoliOS.

Dla buildów developerskich wymagających paczek z AUR można użyć:

```bash
USE_AUR_FALLBACK=1 ./build.sh
```

Można też wskazać gotowe lokalne repo paczek:

```bash
PREBUILT_REPO_DIR=/ścieżka/do/repo ./build.sh
```

### Informacje dla użytkowników

LoliOS ma ułatwiać uruchamianie gier i programów Windows, ale kompatybilność nadal zależy od Wine, Protona, sterowników, sprzętu i konkretnej aplikacji. Część programów może wymagać osobnego profilu, prefixu 32-bit, dodatkowych runtime albo ręcznych poprawek.

### Współpraca

Mile widziane są testy, zgłoszenia błędów, logi, poprawki dokumentacji i informacje o kompatybilności. Przy zgłoszeniu problemu warto podać:

- czy problem wystąpił w Live ISO czy po instalacji;
- dane sprzętu albo maszyny wirtualnej;
- kroki do odtworzenia błędu;
- logi albo zrzuty ekranu;
- czy system miał dostęp do internetu.
