# Changelog

All notable changes to the official Pinball Editor 2D. Versions follow `MAJOR.MINOR.PATCH`.

## 0.30.0
- **Crossings between ramps, wire ramps and belts**: every path can pass OVER, pass UNDER or cross at the SAME
  HEIGHT when it meets another one; the editor builds smooth climbs and descents automatically (the heights you drew
  are never changed: the game uses an extra play profile). Every crossing has a marker on the table and its own
  panel: choose who passes over or under, same height, or **connected** (the ball can change path, with a diverter:
  alternate, always, never or controlled by missions). Manual choices always win and survive rule changes and moves;
  "back to automatic" restores them. Conflicts are shown, never decided by the editor.
- Raised playfields: when a ramp crosses the closed edge, the editor proposes the gap.
- CHECK shows problems in three levels (error, warning, information); clicking a line opens the crossing.
- Engine: mid-ramp junctions (the ball can switch to another ramp at a crossing).

## 0.29.0
- **Mouse handles for every piece**: rotate (Ctrl = 15° steps), scale, widen and lengthen gates, targets, spinners,
  sensors, lights, walls and ramps directly on the table (one undo step per drag).
- **Gap in a wall** (✂): remove a stretch of a wall where you click, also on curved stretches, and put a gate, a
  spinner or a target in it, already turned like the wall.
- **Gap in the edge of a raised playfield**: draw the playfield closed, then open a gap and attach a ramp or a
  belt going up or down; the ball really leaves the playfield through the gap in the game.
- Lights: a new light takes shape, size and colour of the last one you changed.
- Colour picker: can be moved (title bar), reopens where you left it and shows the recent colours.
- The table view no longer jumps back when you select another piece; scroll bars on the table view.
- Very large images on the table (larger than the playfield) keep their handles inside the view.
- Window title shows the right version.

## 0.28.0
- The Finish/Cancel bar for walls, ramps and belts stays still in the free space beside the table.
- Images: side handles change only the width or only the height; locked items can be selected again.
- Wire ramps: three steel wires, spaced brackets with bolts, soft shadow.

## 0.26.2
- Release packages fixed: the 0.26.1 packages contained by mistake a copy of the Godot download used by the
  build machine (about 78 MB more, nothing else changed).

## 0.26.1
- All public texts in English (repository documents, and the README, credits, build and AI instructions
  written by the editor into every released pinball).
- English quick-start guide (`docs/USER_GUIDE.md`).

## 0.26.0 – first public version
- Ready-to-use editor packages for **Windows** and **Linux** (official Godot binary + editor + launcher), built
  automatically for every release.
- Games exported and released for **Windows, Linux, Raspberry Pi and Android** (Android only with confirmation).
- Export templates installed from the editor (official download, SHA-512 check).
- Official open source release: code under GPL-3.0-or-later, pinball content under CC BY-SA 4.0.
- **Official release** of pinballs: game + public source repository + licences + credits + licence manifest +
  build instructions + AI instructions, with the game compiled from the exact published commit.
- Licence registry for every resource (author, source URL, licence, modifications, limitations) with compatibility
  check.
- Community files: contributing guide, code of conduct, security policy, issue and pull request templates,
  automatic tests on every pull request.
- Everything from the earlier internal versions (0.1–0.25): editor, physics, missions, lights, sounds, images,
  checks, guided first pinball, themes, phone preview, promo video, Godot project export.
