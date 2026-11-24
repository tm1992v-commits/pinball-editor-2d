# Development – how Pinball Editor 2D is built

A **Godot 4.7.2** project (GDScript), no external libraries. Measurements in **millimetres**.
File and function names are in Italian (the project was born in Italian); comments are being translated over time.

| Folder | What |
|---|---|
| `motore/` | game runtime: `tavolo_fisico.gd` (physics, 240 steps/s), `pallina.gd` (ball), `binario.gd` (ramps), `regole_base.gd` (rules), `mattoncini.gd` (data-driven missions), `segreti.gd` (secrets), `classifica.gd` (high scores), `regia_dati.gd` (light/sound direction), `audio.gd`, `main.gd`, `file_tavolo.gd` (table file), `misura_velocita.gd` (speed test) |
| `grafica/` | table drawing with 3D effect, baked into images at startup (`vista_2d.gd`, `pittore_pezzi.gd`, `regia_luci_2d.gd`) |
| `interfaccia/` | score display (`hud.gd`) and menus (`menu_comune.gd`, `menu.gd`) |
| `editor/` | the editor: `editor.gd` (interface), `progetto_editor.gd` (ALL commands, also for AI: `comandi_ai.tscn`), `vista_tavolo.gd`, `schede.gd`, `controlli_editor.gd`, `curve_editor.gd`, `piani.gd`, `esportazione.gd` (export), `rilascio.gd` (official release), `licenze_progetto.gd` (licences), `guida.gd` (built-in guide) |
| `tavoli/base/` | template table: shapes (`forma_tavolo.gd`), tested lower area (`zona_bassa.tavolo`), rules of editor tables |
| `tavoli/modelli/` | ready-made tables (rebuilt by `tools/crea_modelli` from the commands in `sorgenti/`) |
| `tests/` | automatic tests (see `CONTRIBUTING.md`) |
| `tools/` | tools: stuck-ball hunt, shot tracer, measurements, editor packages |

**The table file** (`.tavolo`, a `var_to_str` text dictionary) is the single source for physics, graphics, rules and
tests. The editor changes data only through commands (`ProgettoEditor.esegui`), with undo/redo.

**Start:** editor `godot --path . res://editor/editor.tscn`; game with a table
`godot --path . res://scenes/main.tscn -- --tavolo_file=FILE --finestra`.
Useful game options: `--gioca` (automatic play), `--foto=FILE --dopo=S` (screenshot), `--velocita=S --rapporto=FILE`
(speed test), `--registra=FILE.mp4 --durata=S` (video).
