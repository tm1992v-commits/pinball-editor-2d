# Platforms

## The editor (ready-to-use packages)
| System | Package | How to start |
|---|---|---|
| **Windows** (64 bit) | `PinballEditor2D-<version>-windows.zip` | unzip, double-click `Pinball Editor 2D.bat` |
| **Linux** (x86_64) | `PinballEditor2D-<version>-linux.zip` | unzip, run `Pinball Editor 2D.sh` |

Each package contains the official Godot 4.7.2 binary (MIT), the editor and its full source code (`progetto/`).
They are built by `tools/pacchetto_editor.py` and attached automatically to every GitHub release (tag `v*`).
From source, on any system with Godot 4.7.2: `godot --path . res://editor/editor.tscn`.

## Pinball games made with the editor
| Platform | Test build (📦 ESPORTA) | Official release (🚀) |
|---|---|---|
| PC Linux (x86_64) | yes | yes |
| PC Windows (x86_64) | yes | yes |
| Raspberry Pi 4 (Linux ARM64) | yes | yes |
| Android (APK) | yes, with confirmation | yes, with confirmation (test-signed: for stores, sign with your own key) |
| macOS, iPhone/iPad | not yet | not yet |

The export templates of Godot are needed once: 📦 ESPORTA → *Installa i modelli di esportazione* (official
download, checked with SHA-512).

**Android for stores:** the editor never stores keys. Godot reads your release keystore from the environment
variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`,
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.

## Want to add macOS or iPhone? (contributions welcome)
Godot can export to macOS and iOS; what is needed in this project:
1. an export preset in `export_presets.cfg` (`macOS`, `iOS`) with the textures and icons required;
2. the matching templates in `MODELLI_USATI` (`editor/esportazione.gd`) and an entry in `PIATTAFORME` (test build)
   and `Rilascio.PIATTAFORME_RILASCIO` (official release);
3. tests in `tests/test_rilascio.gd`;
4. documentation: Apple requires code signing and notarization (paid Apple developer account) for apps that open
   without warnings, and iOS builds need a Mac with Xcode. Explain this clearly to users.
Open an issue first to discuss the approach.
