# Contributing to Pinball Editor 2D

Thank you for wanting to improve the editor! This is the **official repository**: new features and fixes for the
official version are proposed here, tested and reviewed, then merged. Project founder and lead maintainer:
**Carmelo Vadalà** (themeloohgames@gmail.com). Other maintainers may be appointed in the future (see `GOVERNANCE.md`).

## How a change gets into the official version
1. **Open an issue** (bug report or feature proposal) using the templates. For big changes, discuss first.
2. **Prepare the change** in a fork or a branch. Keep it focused: one topic per pull request.
3. **Open a pull request** to `main` using the template.
4. **Automatic tests** run on every pull request (GitHub Actions). They must all pass.
5. **Code review** by a maintainer.
6. **Approval** by a maintainer (the final approval belongs to the lead maintainer).
7. **Merge** into the official version and entry in `CHANGELOG.md`.

Forks that go their own way are allowed by the licence; we just hope you will also send improvements back.

## Rules for code and content
- Language of the code: GDScript (Godot 4.7.2). No new external libraries without discussion.
- **Don't break existing features**: run the tests locally before opening the pull request:
  ```bash
  godot --headless --path . --import
  godot --headless --path . res://tests/test_editor.tscn
  godot --headless --fixed-fps 60 --path . res://tests/test_mattoncini.tscn
  godot --headless --fixed-fps 60 --path . res://tests/test_motore.tscn
  ```
  (`tests/test_collaudo.tscn` needs a window; it also runs in CI with a virtual screen.)
- Add or update tests for what you change.
- **Licences**: your code contribution is licensed under **GPL-3.0-or-later**; contributed creative content
  (images, sounds, texts) under **CC BY-SA 4.0**, unless it is third-party material, which must have a compatible
  licence (no NonCommercial, NoDerivatives, proprietary or unknown licences) and be listed in `CREDITS.md` with
  author, source URL, licence and modifications.
- **Keep the credits and copyright notices.** Add yourself to the contributors in `CREDITS.md` if you wish.
- **Sign off your commits** (Developer Certificate of Origin, https://developercertificate.org/):
  `git commit -s` adds `Signed-off-by: Your Name <email>`, certifying that you have the right to submit the change.
- Never commit passwords, tokens, keys or personal data.
- AI assistants are welcome as tools: they must follow `AI_INSTRUCTIONS.md`, and you remain responsible for what
  you submit.

## Reporting security problems
See `SECURITY.md` (please don't open public issues for vulnerabilities).

## Help wanted: translations
The editor interface and the full manual are in Italian today. Translating the interface (English first) is the
most useful contribution right now: open an issue to agree on the approach before starting.
