# Project licences and legal checks

*Technical document meant to be reviewed by a legal professional. It is not legal advice and gives no guarantees.*

## 1. Licence structure
| Component | Holders | Licence | Text |
|---|---|---|---|
| Editor code and game runtime (`motore/`, `grafica/`, `interfaccia/`, `editor/`, `tavoli/base/`, `scenes/`, `tests/`, `tools/`) | Carmelo Vadalà and contributors | GPL-3.0-or-later | `LICENSE`, `LICENSES/GPL-3.0-or-later.txt` |
| Data of the template lower area (`tavoli/base/zona_bassa.tavolo`) and example tables (`tavoli/modelli/`) | Carmelo Vadalà | GPL-3.0-or-later (program data) | as above |
| Original creative content of a pinball (graphics, music, texts, table design) | author of the pinball | CC-BY-SA-4.0 | `LICENSES/CC-BY-SA-4.0.txt` |
| Godot Engine 4.7.2 | Godot Engine contributors | MIT (+ components with their own licences) | `LICENSES/Godot-MIT.txt`, `Godot-componenti.txt` |
| Noto Sans/Serif Display fonts | The Noto Project Authors | OFL-1.1 | `LICENSES/OFL-1.1.txt` |
| Freesound sounds (schafferdavid, NeatoEnt) | their authors | CC0-1.0 | `LICENSES/CC0-1.0.txt` |
| AndroidX libraries inside APKs | Google / AOSP | Apache-2.0 | `LICENSES/Apache-2.0.txt` |

Licence texts are the official ones, downloaded from their publishers and **unmodified**.

## 2. Checks done
1. **GPL ↔ dependencies.** MIT (Godot), Apache-2.0 (AndroidX, Android builds only), OFL-1.1 (fonts, distributed as
   separate files) and CC0 (sounds) are compatible with distribution together with GPL-3.0 code.
2. **GPL ↔ CC BY-SA.** The two cover different components (code / creative content) placed in the same package as
   separate works. Since 2015 CC BY-SA 4.0 is declared one-way compatible with GPLv3 (adaptations of BY-SA 4.0
   material may be licensed under GPLv3). Creative Commons is not applied to code.
3. **Code ownership.** The existing code was written for the author (Carmelo Vadalà), also with AI tools; no line is
   copied from third-party projects. Visual Pinball X and Visual Pinball Engine were studied for ideas and
   measurements only.
4. **Runtime and exported games.** An exported pinball contains the GPL runtime of the editor + the table file
   (data) + the resources. The runtime stays GPL; the table file and original content belong to the pinball author
   and the official flow releases them under CC BY-SA 4.0. Third-party resources keep their licence and are checked
   (unknown, NonCommercial, NoDerivatives, proprietary: the free release stops).
5. **Source distribution.** The official release puts the complete source in the package (`SOURCE/`, `SOURCE.zip`)
   and in a public repository, linked to the binary by commit, tag and hash (`RELEASE_INFO.json`).
6. **Cabinets.** No keys, signatures, DRM or locks: the game can be rebuilt and reinstalled following
   `BUILD_INSTRUCTIONS.md`.

## 3. Points that need professional legal review
1. **Publishing the source.** The GPL requires giving the corresponding source to whoever receives the program
   (section 6), not always publishing it online. Public publication is a rule of the editor's **official flow** (a
   feature of the program), not an additional condition of the licence: GPL sections 7 and 10 forbid adding
   restrictions for recipients. To confirm that this is correct and that the public texts do not present it as a
   legal obligation.
2. **Nature of the table file.** Whether the `.tavolo` file (descriptive data interpreted by the runtime) is a work
   separate from the program or a derivative of the runtime: it affects which licence can apply to it.
3. **AI-generated content.** Ownership of images or music generated with AI services, and the possibility of
   licensing them under CC BY-SA, depend on the applicable law and the terms of the service used.
4. **Community contributions.** With the DCO alone (commit sign-off) every contributor keeps the copyright of their
   code, licensed GPL-3.0-or-later.
5. **Personal data** in game repositories (author name, email in commits): notice and use of "noreply" addresses.
6. **Trademarks.** "Pinball Editor 2D" and game names are not registered; software licences give no trademark rights.
7. **Advertising.** The public code contains no advertising SDK. Whoever adds one to a GPL game must check that the
   GPL and the SDK licence are compatible (in general a licence exception from the copyright holders is needed).
8. **Installation on sold devices (GPLv3 section 6, "Installation Information").** For cabinets sold as "User
   Products" the information to install modified versions must be provided: the instructions exist
   (`BUILD_INSTRUCTIONS.md`); to confirm that they are enough.
