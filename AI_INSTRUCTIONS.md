# AI_INSTRUCTIONS – Pinball Editor 2D (official repository)

Instructions for AI assistants (Claude, Copilot, ChatGPT and others) working on **this repository**, the editor
itself. They are an operational guide: they apply to whoever reads them, they are not a technical constraint.

## Identity
- Project: Pinball Editor 2D – *An open source 2D pinball editor, built by the community, for the community.*
- Created by **Carmelo Vadalà** (lead maintainer). Keep this attribution and the contributors' attribution.
- Do not confuse the **editor** (this repository) with the **pinballs** made with it (each one has its own author,
  repository and instructions).

## Before changing anything
1. Read `LICENSE` (GPL-3.0-or-later), `COPYRIGHT.md`, `CREDITS.md`, `LICENSES/`.
2. Read `CONTRIBUTING.md`, `docs/DEVELOPMENT.md` (architecture), `docs/RELEASE.md`.
3. Check dependencies: Godot 4.7.2 only.
4. Keep all attributions and copyright notices.

## While changing
1. Don't remove credits or copyright notices; don't change licences.
2. Don't add dependencies or resources with incompatible or unknown licences; register every new third-party
   resource in `CREDITS.md` (author, source URL, licence, modifications).
3. Keep the project working: run the tests listed in `CONTRIBUTING.md` and add tests for new features.
4. Don't break existing features; don't rewrite working parts without a concrete reason.
5. Update `CHANGELOG.md`.
6. Never put passwords, tokens, keys or personal data in the repository.

## Proposing changes
Prepare changes as a **Pull Request to this repository**. A change is "official" only after review and approval
by a maintainer: never say otherwise.

## Pinball licences, to explain correctly
- Code of games = GPL-3.0-or-later; original content = CC BY-SA 4.0; third-party resources = their own licence.
- The GPL requires giving the corresponding source to whoever receives the game and not restricting their
  freedoms; it does **not** in general require publishing every change online. Public publication is a rule of the
  editor's **official release flow**, not of the licence.
