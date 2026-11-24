# Pinball Editor 2D – Quick start guide

The editor interface is in **Italian** for now (an English interface is welcome as a contribution). This guide gives
every button its Italian label in *italics*, so you can find it on screen. The complete manual, in Italian, is
[`MANUALE.md`](MANUALE.md) and inside the editor (*❓ Guida*, F1).

## 1. Start
- Ready-to-use package: unzip it and double-click *Pinball Editor 2D* (`.bat` on Windows, `.sh` on Linux).
- From source: `godot --path . res://editor/editor.tscn` (Godot 4.7.2) or `./avvia_editor.sh`.
- Tables are saved in the `progetti/` folder next to the project.

## 2. The screen
| Where | Italian label | What it does |
|---|---|---|
| Top bar | *Nuovo · Apri · Salva · Salva con nome* | new table · open · save · save as |
| Top bar | *Annulla · Ripristina* | undo · redo |
| Top bar | *Importa flipper* | import a compatible 2D pinball table |
| Top bar | *Modalità SEMPLICE / PRO* | simple mode (fewer options) or full mode |
| Top bar | *Griglia e aggancio* · *Collisioni* | grid and snapping · show collision shapes |
| Top bar | *RENDERIZZA* · *🎨 Aspetto* | rebuild the 3D-effect graphics · colours, fonts, score display |
| Top bar | *📦 ESPORTA* · *▶ GIOCA* | export / official release · play the table now |
| Second bar | *✔ CONTROLLA* | checks: dangerous gaps, stuck balls, ramp crossings |
| Second bar | *🔧 Sistema tu* | fixes the dangerous gaps for you |
| Second bar | *📱 Telefono* | phone preview |
| Second bar | *🪄 Primo flipper* | guided wizard for your first pinball (5 steps) |
| Left | *Strumenti*: *Seleziona*, *Traccia tiro*, *Righello* | select · trace where a shot goes · ruler |
| Left | *Pezzi* | pieces: bumper (*Bumper*), slingshot (*Fionda*), flipper (*Paletta*), spinner, gate (*Cancello*), sensor (*Sensore*), lane (*Corsia*), target (*Bersaglio*), drop targets (*abbattibili*), hole (*Buca*), ramps, walls… |
| Left | *Da immagine…* · *I miei elementi* | make a piece from your own image · your saved pieces |
| Right | *TAVOLO* / piece panel | properties of the table or of the selected piece |
| Bottom tabs | *Problemi · Pezzi · Livelli · Suoni e luci · Simulatore · Missioni · Diario* | problems · piece list · layers · sounds and lights · rule simulator · missions · log |

## 3. Your first table in 5 minutes
1. *🪄 Primo flipper*: choose a shape, a theme, the pieces, missions and a name. The editor places everything and
   checks the gaps.
2. Or start from *Nuovo*: the template table already has a tested lower area (flippers, slingshots, outlanes).
3. Pick a piece on the left and click on the table. Drag it to move it; its properties are on the right.
4. Walls and ramps are drawn by points: click to add points, *FINE* to finish (Shift+click = curve).
5. *✔ CONTROLLA* (or *🔧 Sistema tu*), then *▶ GIOCA* to play with the real physics.
6. *Missioni* tab: build missions from ready-made "bricks" (hit all, sequence, combo, hurry-up…).
7. *Salva*.

## 4. Export and release
- *📦 ESPORTA*: test builds for Linux, Windows, Raspberry Pi 4 and Android (Android asks for confirmation), a complete
  Godot project, or a promo video. The first time: *Installa i modelli di esportazione* (official Godot download,
  checked with SHA-512).
- *🚀 RILASCIO UFFICIALE*: the official release with public source code, licences and credits — see
  [`RELEASE.md`](RELEASE.md). Every image, music and font needs a free licence declared in *📜 Licenze*.

## 5. More
- Platforms: [`PLATFORMS.md`](PLATFORMS.md) · Licences: [`LICENSING.md`](LICENSING.md) · Code: [`DEVELOPMENT.md`](DEVELOPMENT.md)
