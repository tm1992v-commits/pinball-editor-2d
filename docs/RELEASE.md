# Official release of a pinball

Menu **📦 ESPORTA → 🚀 RILASCIO UFFICIALE** (Export → Official release), in 7 steps:
1. **Information**: name, author, description, version (1.0.0).
2. **Resource check**: every image, music and font must have a licence that allows commercial use and
   modifications (declared in 📜 Licenze: author, source, URL, licence, modifications, limitations). If not, it stops.
3. **Licences**: code GPL-3.0-or-later, content CC BY-SA 4.0, third parties with their own licence.
4. **Public repository**: GitHub through the `gh` program (secure login with `gh auth login`: the editor never sees
   or stores passwords or tokens). **Explicit consent** to publish is required.
5. **Credits**: contributors and what is new in this version (CHANGELOG).
6. **Export**: complete source code in a git repository (one version = one commit + one tag `vX.Y.Z`),
   publication, check that it can be reached **without credentials**, game compiled **from that commit**.
7. **Final check**: required files, valid manifest, hashes of the game and of the source, consistent commit. Only
   then is the release declared official. If publishing fails, the release is **not** official.

## The package (`<project>/rilasci/<name>-<version>/`)
```
GAME/                  the compiled game (Linux, Windows, Raspberry Pi 4, Android if confirmed)
SOURCE/  SOURCE.zip    the complete source code of that commit (also offline)
ASSETS/                editable images, music, fonts, sounds
LICENSES/              licence texts (GPL, CC BY-SA, CC0, OFL, Apache, Godot)
README.md CREDITS.md AI_INSTRUCTIONS.md CHANGELOG.md BUILD_INSTRUCTIONS.md
LICENSE_MANIFEST.json  licence of every component
SOURCE_REPOSITORY.txt  address, commit and tag of the public source
RELEASE_INFO.json      version, date, commit, tag, URL, hashes of game and source, runtime, dependencies
```
**Test builds** (📦 ESPORTA → PC / Raspberry Pi / APK) are for testing and are not releases.
