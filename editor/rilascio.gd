## RILASCIO UFFICIALE di un pinball (Pinball Editor 2D v0.26).
## Un pinball distribuito con il sistema ufficiale ha SEMPRE il suo codice sorgente completo e pubblico:
##   1. controllo di licenze, crediti e informazioni del gioco (LicenzeProgetto.verifica);
##   2. sorgente completo (progetto Godot modificabile) in un repository git del gioco, una versione = un commit + un tag;
##   3. pubblicazione del repository (GitHub pubblico; oppure un repository indicato a mano) SOLO con il consenso
##      dell'utente, poi verifica che sia davvero raggiungibile;
##   4. il gioco si compila DA QUEL COMMIT (estratto con git archive): il binario corrisponde esattamente al sorgente;
##   5. pacchetto completo: GAME/, SOURCE/ + SOURCE.zip, ASSETS/, LICENSES/, CREDITS.md, README.md, AI_INSTRUCTIONS.md,
##      CHANGELOG.md, LICENSE_MANIFEST.json, BUILD_INSTRUCTIONS.md, SOURCE_REPOSITORY.txt, RELEASE_INFO.json;
##   6. verifica finale del pacchetto. Se la pubblicazione non riesce, il rilascio NON è dichiarato ufficiale.
## Le build di prova restano nell'ESPORTA normale (non sono rilasci).
## Nota legale (documentata in docs/LICENSING.md): la GPL chiede di dare il sorgente a chi riceve il gioco,
## non di pubblicarlo sempre online; la pubblicazione pubblica è una regola del FLUSSO UFFICIALE di questo editor.
class_name Rilascio

const PRESET_PC := "Linux x86_64"
## Versioni del gioco nel rilascio (v0.26.1). Android SOLO se confermato a parte (regola: l'APK con conferma
## dell'utente); è firmato con la chiave di PROVA: per Google Play serve la chiave personale di chi pubblica,
## che non entra mai nel progetto (Godot la legge dalle variabili GODOT_ANDROID_KEYSTORE_RELEASE_*).
const PIATTAFORME_RILASCIO := {
	"linux": {"nome": "PC Linux", "preset": "Linux x86_64", "est": ".x86_64", "cartella": "linux"},
	"windows": {"nome": "PC Windows", "preset": "Windows x86_64", "est": ".exe", "cartella": "windows"},
	"pi": {"nome": "Raspberry Pi 4 (Linux ARM64)", "preset": "Linux ARM64 (Raspberry Pi 4)", "est": ".arm64", "cartella": "raspberry_pi"},
	"android": {"nome": "Android (APK con firma di PROVA)", "preset": "Android (prova telefono)", "est": ".apk", "cartella": "android", "debug": true},
}
## Le 4 versioni ufficiali dei tavoli (Mac e iPhone: chi vuole può aggiungerli, vedi docs/PLATFORMS.md).
const PIATTAFORME_PREDEFINITE := ["linux", "windows", "pi", "android"]
## Cose dell'editor che non fanno parte del sorgente di un gioco rilasciato.
const FUORI := ["tests", "tools", "licenze_giochi", "tavoli/spazio", "grafica/spazio_2d", "tavoli/modelli/z_space_esempio.tavolo",
	"EULA.md", "COPYRIGHT.md", "THIRD_PARTY_LICENSES.md", "README.md", "LICENSE"]

# ================================================================ comandi esterni
static func _esegui(cmd: String, args: Array, cartella := "") -> Dictionary:
	var out: Array = []
	var a := args
	if cartella != "" and cmd == "git":
		a = ["-C", cartella] + args
	var codice := OS.execute(cmd, PackedStringArray(a), out, true)
	return {"ok": codice == 0, "codice": codice, "testo": "\n".join(out).strip_edges()}

static func _git(cartella: String, args: Array) -> Dictionary:
	return _esegui("git", args, cartella)

# ================================================================ 2) sorgente del gioco
## Prepara (o aggiorna) il repository git del sorgente del gioco: <progetto>/rilasci/sorgente/. Ritorna {ok, cartella}.
static func prepara_sorgente(p: ProgettoEditor, repo_url: String, note := "") -> Dictionary:
	var i := LicenzeProgetto.info(p.desc)
	var src := p.cartella.path_join("rilasci").path_join("sorgente")
	DirAccess.make_dir_recursive_absolute(src)
	# svuota tutto tranne .git (la cronologia resta: una versione = un commit)
	for d in DirAccess.get_directories_at(src):
		if d != ".git":
			Esportazione._svuota(src.path_join(d))
			DirAccess.remove_absolute(src.path_join(d))
	for f in DirAccess.get_files_at(src):
		DirAccess.remove_absolute(src.path_join(f))
	var tmp := src.get_base_dir().path_join("_progetto_tmp")
	Esportazione._svuota(tmp)
	var re := Esportazione.esporta_progetto(p, tmp)
	if not re.get("ok", false):
		return re
	Esportazione._copia_cartella(tmp, src)
	Esportazione._svuota(tmp)
	DirAccess.remove_absolute(tmp)
	pulisci_per_pubblico(src)
	# il gioco sa chi è e dove sta il suo sorgente (crediti nel gioco)
	LicenzeProgetto._scrivi(src.path_join("gioco/rilascio.json"), JSON.stringify({"nome": i["nome"], "versione": i["versione"], "autore": i["autore"],
		"repository": repo_url, "editor": "Pinball Editor 2D – Created by " + LicenzeProgetto.AUTORE_EDITOR}, "  "))
	var pg := src.path_join("project.godot")
	LicenzeProgetto._scrivi(pg, FileAccess.get_file_as_string(pg).replace('config/name="%s"' % str(p.desc.get("titolo", "")).capitalize().replace('"', ""), 'config/name="%s"' % i["nome"].replace('"', "")))
	scrivi_documenti(p, src, repo_url, note)
	if not DirAccess.dir_exists_absolute(src.path_join(".git")):
		var gi := _git(src, ["init", "-q", "-b", "main"])
		if not gi["ok"]:
			return {"ok": false, "messaggio": "Serve il programma git per i rilasci ufficiali (%s)" % gi["testo"]}
	return {"ok": true, "cartella": src}

## Toglie dal sorgente ciò che non è del gioco (prove, strumenti, tavoli d'esempio con diritti propri, pubblicità) e
## mette i testi legali del rilascio libero. Usata anche per il repository pubblico dell'editor.
static func pulisci_per_pubblico(dir: String) -> void:
	for x in FUORI:
		var q := dir.path_join(x)
		if DirAccess.dir_exists_absolute(q):
			Esportazione._svuota(q)
			DirAccess.remove_absolute(q)
		elif FileAccess.file_exists(q):
			DirAccess.remove_absolute(q)
	# pubblicità: al posto del ponte verso un SDK proprietario, un modulo vuoto con gli stessi comandi (mai attivo)
	LicenzeProgetto._scrivi(dir.path_join("motore/pubblicita.gd"), STUB_PUBBLICITA)
	var cfg := dir.path_join("config/gioco.cfg")
	if FileAccess.file_exists(cfg):
		var tc := RegEx.create_from_string('(?m)^tavolo="[^"]*"').sub(FileAccess.get_file_as_string(cfg), 'tavolo="base"', true)
		tc = RegEx.create_from_string('(?m)^fonte_musica="[^"]*"').sub(tc, 'fonte_musica=""', true)
		tc = RegEx.create_from_string('(?m)^fornitore="[^"]*"').sub(tc, 'fornitore=""', true)
		var righe_c := PackedStringArray()
		for r in tc.split("\n"):
			var kk := r.find(";")
			if kk >= 0 and _ha_nota_privata(r.substr(kk)):
				if r.substr(0, kk).strip_edges() == "":
					continue
				r = r.substr(0, kk).rstrip(" \t")
			righe_c.append(r)
		LicenzeProgetto._scrivi(cfg, "\n".join(righe_c))
	pulisci_commenti(dir)
	LicenzeProgetto._scrivi(dir.path_join("LICENSE"), FileAccess.get_file_as_string("res://LICENSES/GPL-3.0-or-later.txt"))
	LicenzeProgetto.scrivi_licenze(dir)

## Note di lavoro private nei COMMENTI (copia privata dell'editor): l'elenco delle parole sta in
## licenze_giochi/note_private.txt (una per riga) e c'è solo dove serve; senza file non si toglie niente.
static var _note: PackedStringArray = []
static func _parole_private() -> PackedStringArray:
	if _note.is_empty() and FileAccess.file_exists("res://licenze_giochi/note_private.txt"):
		for r in FileAccess.get_file_as_string("res://licenze_giochi/note_private.txt").split("\n"):
			if r.strip_edges() != "":
				_note.append(r.strip_edges().to_lower())
	return _note

static func _ha_nota_privata(t: String) -> bool:
	var b := t.to_lower()
	for k in _parole_private():
		if b.contains(k):
			return true
	return false

## Toglie dai file .gd i commenti con note private (righe di solo commento; e la parte di commento in fondo a una riga
## di codice, solo se le virgolette prima sono chiuse). Ritorna quante righe ha cambiato.
static func pulisci_commenti(dir: String) -> int:
	var n := 0
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			n += pulisci_commenti(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var righe := FileAccess.get_file_as_string(dir.path_join(f)).split("\n")
		var out := PackedStringArray()
		var cambiato := false
		var in_testo := false             # dentro un testo tra virgolette triple: non si tocca niente
		for r in righe:
			var nuda := r.strip_edges()
			var era_in_testo := in_testo
			if r.count("\"\"\"") % 2 == 1:
				in_testo = not in_testo
			if era_in_testo or r.contains("\"\"\""):
				out.append(r)
				continue
			if nuda.begins_with("#") and _ha_nota_privata(nuda):
				cambiato = true
				n += 1
				continue
			var k := r.find(" # ")
			if k < 0:
				k = r.find("\t# ")
			if k > 0 and _ha_nota_privata(r.substr(k)) and r.substr(0, k).count("\"") % 2 == 0 and not r.substr(0, k).contains("\"\"\""):
				out.append(r.substr(0, k).rstrip(" \t"))
				cambiato = true
				n += 1
				continue
			out.append(r)
		if cambiato:
			LicenzeProgetto._scrivi(dir.path_join(f), "\n".join(out))
	return n

const STUB_PUBBLICITA := """## Pubblicità: in questa versione libera non c'è nessuna pubblicità né SDK di terzi (modulo vuoto, mai attivo).
## Chi vuole aggiungerla può farlo nel proprio gioco rispettando le licenze (vedi AI_INSTRUCTIONS.md).
class_name Pubblicita
extends Node

signal chiusa()
var attiva := false

static func disponibile() -> bool:
	return false

static func consenso_scelto():
	return null

func avvia(_consenso: bool) -> void:
	pass

func cambia_consenso(_si: bool) -> void:
	pass

func fine_partita() -> void:
	pass

func premio_pronto() -> bool:
	return false

func mostra_premio(fatto: Callable) -> void:
	fatto.call(false)
"""

# ================================================================ documenti del gioco
static func scrivi_documenti(p: ProgettoEditor, dir: String, repo_url: String, note := "") -> void:
	var i := LicenzeProgetto.info(p.desc)
	LicenzeProgetto._scrivi(dir.path_join("README.md"), readme_md(i, repo_url))
	LicenzeProgetto._scrivi(dir.path_join("CREDITS.md"), LicenzeProgetto.credits_md(p))
	LicenzeProgetto._scrivi(dir.path_join("BUILD_INSTRUCTIONS.md"), build_md(i, repo_url))
	LicenzeProgetto._scrivi(dir.path_join("AI_INSTRUCTIONS.md"), ai_md(i, repo_url))
	LicenzeProgetto._scrivi(dir.path_join("AGENTS.md"), "# Agent instructions\n\nRead and follow **AI_INSTRUCTIONS.md** before changing this project.\n")
	LicenzeProgetto._scrivi(dir.path_join("CLAUDE.md"), "# Instructions for Claude\n\nRead and follow **AI_INSTRUCTIONS.md** before changing this project.\n")
	DirAccess.make_dir_recursive_absolute(dir.path_join(".github"))
	LicenzeProgetto._scrivi(dir.path_join(".github/copilot-instructions.md"), "# Instructions for GitHub Copilot\n\nRead and follow **AI_INSTRUCTIONS.md** (in the root folder) before suggesting changes.\n")
	LicenzeProgetto._scrivi(dir.path_join("LICENSE_MANIFEST.json"), JSON.stringify(LicenzeProgetto.manifest(p), "  "))
	LicenzeProgetto._scrivi(dir.path_join(".gitignore"), ".godot/\nbuild/\n*.tmp\n")
	# CHANGELOG: si aggiunge la versione nuova in cima (la storia resta)
	var ch := dir.path_join("CHANGELOG.md")
	var vecchio := FileAccess.get_file_as_string(p.cartella.path_join("rilasci/CHANGELOG.md")) if FileAccess.file_exists(p.cartella.path_join("rilasci/CHANGELOG.md")) else "# Changelog – %s\n" % i["nome"]
	var voce := "\n## %s – %s\n- %s\n" % [i["versione"], Time.get_date_string_from_system(), note if note != "" else "Released with Pinball Editor 2D."]
	if not vecchio.contains("\n## %s –" % i["versione"]):
		var testa := vecchio.find("\n")
		vecchio = vecchio.substr(0, testa + 1) + voce + vecchio.substr(testa + 1)
	LicenzeProgetto._scrivi(ch, vecchio)
	LicenzeProgetto._scrivi(p.cartella.path_join("rilasci/CHANGELOG.md"), vecchio)

static func readme_md(i: Dictionary, repo_url: String) -> String:
	return """# %s

%s

**Version:** %s · **Pinball author:** %s
Made with **Pinball Editor 2D** – Created by %s. Open Source Community Project.

## Play
Download the game from the release (folder `GAME/`) and start it. Controls: left/right flippers, launch with the
right lane (hold and release), START to begin; on a phone, touch the left and right side of the screen.

## Modify
This repository IS the complete project: open it with **Godot %s** (Import → `project.godot`) and press F5.
- The table: `gioco/tavolo.tavolo` (text file, measurements in millimetres; it also opens in Pinball Editor 2D).
- Images: `gioco/immagini/*.png` · music: `gioco/musica/`.
- Game code: `motore/`, `grafica/`, `interfaccia/`.
To rebuild it: `BUILD_INSTRUCTIONS.md`.

## Your freedoms
- Code: **GNU GPL v3 or later** (`LICENSE`). Original content: **CC BY-SA 4.0** (`LICENSES/`).
- You may play, study, modify, redistribute and **sell** it (modified too, inside a cabinet too), under the same
  terms: whoever receives the game must be able to get its source code and keep the same rights; credits and
  copyright notices must be kept. Details for every component: `LICENSE_MANIFEST.json`, `CREDITS.md`.

## Source code of this version
%s
""" % [i["nome"], i["descrizione"], i["versione"], i["autore"], LicenzeProgetto.AUTORE_EDITOR, str(Engine.get_version_info()["string"]), repo_url]

static func build_md(i: Dictionary, repo_url: String) -> String:
	return """# Rebuilding %s %s

1. Download **Godot %s** from https://godotengine.org (the same version: the project is made for it) and its
   **export templates** (Editor → Manage Export Templates).
2. Get the source code of this version: `git clone %s` then `git checkout v%s`
   (or use `SOURCE.zip` from the release package: it is the same commit).
3. Open Godot → Import → `project.godot`. F5 = test.
4. Project → Export → choose the platform (Linux, Windows, Raspberry Pi 4, Android test build) → Export Project.
   Android for stores: you need YOUR OWN signing key, given to Godot with the environment variables
   GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD (never inside the project).
   From the command line: `godot --headless --path . --export-release "%s" build/%s.x86_64`
5. To install it on a cabinet: copy the exported file and start it (Linux: make it executable).
   A modified version installs the same way: there are no keys, signatures or locks.

The exact commit of every release and the hash of the compiled game are in `RELEASE_INFO.json` in the package.
""" % [i["nome"], i["versione"], str(Engine.get_version_info()["string"]), repo_url, i["versione"], PRESET_PC, LicenzeProgetto.slug(i["nome"])]

static func ai_md(i: Dictionary, repo_url: String) -> String:
	return """# AI_INSTRUCTIONS – %s

Instructions for AI assistants (Claude, Copilot, ChatGPT and others) working on this project.
They are an operating guide for whoever reads them, not a technical restriction.

## Who is who
- **Pinball:** "%s", author **%s**. **Editor** it was made with: Pinball Editor 2D, Created by %s (Open Source
  Community Project). Do not confuse the author of the pinball with the author of the editor.
- Reference public source code: %s

## Before changing anything
1. Read the licences: `LICENSE` (GPL-3.0-or-later for the code), `LICENSES/` (CC BY-SA 4.0 for original content
   and third-party licences).
2. Read `CREDITS.md` and `LICENSE_MANIFEST.json`: identify the original authors of every component.
3. Read `README.md` and `BUILD_INSTRUCTIONS.md`.
4. Check the dependencies (Godot %s; no other external library).
5. Keep every attribution.

## While changing
1. Do not remove credits or copyright notices.
2. Do not change licences arbitrarily.
3. Do not add dependencies or resources with incompatible licences (no NonCommercial, NoDerivatives, proprietary or
   unknown); for every new resource record author, source, URL, licence and modifications in the manifest.
4. Keep the project buildable (test with F5 and with an export).
5. Update `CHANGELOG.md`.
6. Update `LICENSE_MANIFEST.json` and `CREDITS.md` when you add or change resources.
7. Keep all sources (including the editable sources of images).

## If the user wants to distribute the pinball
- Explain that the **official flow** of Pinball Editor 2D publishes the source code in a public repository and links
  it to the compiled game (Official release in the editor).
- Help them: prepare the GitHub repository, upload the source, publish only authorised assets, update the credits,
  prepare the release, link the source to the compiled game (commit, tag, hash).
- Explain the licence obligations: the GPL requires giving the corresponding source code to whoever receives the
  game and not taking away their freedoms; CC BY-SA requires attribution and the same licence for modified content.
- **Do not say** that the GPL always requires publishing online: the editor's official flow asks for it, not the
  licence.
- Selling the game, or a cabinet with the game, is allowed; do not add DRM, locks or licences that take rights away.

## If the user wants to change the EDITOR (not the pinball)
- The editor is a separate project: read the instructions of its official repository and prepare the changes as a
  Pull Request to that repository. Do not call a change "official" before it is approved.
""" % [i["nome"], i["nome"], i["autore"], LicenzeProgetto.AUTORE_EDITOR, repo_url, str(Engine.get_version_info()["string"])]

# ================================================================ 3) pubblicazione
## Guida se GitHub non è pronto (testo per l'utente).
const GUIDA_GITHUB := """Per pubblicare su GitHub serve:
1. un account GitHub gratuito (github.com);
2. il programma «gh» (GitHub CLI, gratuito): https://cli.github.com
3. una volta sola, in un terminale: gh auth login  (accesso sicuro dal browser: l'editor non vede né salva password o token).
Poi riprova il rilascio."""

## Stato di GitHub: {pronto, utente, messaggio}.
static func stato_github() -> Dictionary:
	if _esegui("gh", ["--version"])["codice"] == -1 or not _esegui("gh", ["--version"])["ok"]:
		return {"pronto": false, "messaggio": "Manca il programma gh.\n" + GUIDA_GITHUB}
	var u := _esegui("gh", ["api", "user", "--jq", ".login"])
	if not u["ok"] or u["testo"] == "":
		return {"pronto": false, "messaggio": "gh non è collegato al tuo account.\n" + GUIDA_GITHUB}
	return {"pronto": true, "utente": u["testo"], "messaggio": "GitHub pronto (utente %s)" % u["testo"]}

## Pubblica il commit `tag` del sorgente. dest = {"tipo": "github", "utente", "repo"} oppure {"tipo": "git", "url"}.
## Ritorna {ok, url, messaggio}. Mai senza consenso (lo controlla chi chiama).
static func pubblica(src: String, tag: String, dest: Dictionary) -> Dictionary:
	var url := ""
	if str(dest.get("tipo", "")) == "github":
		var nome := "%s/%s" % [dest["utente"], dest["repo"]]
		url = "https://github.com/" + nome
		if not _esegui("gh", ["repo", "view", nome, "--json", "name"])["ok"]:
			var cr := _esegui("gh", ["repo", "create", nome, "--public", "--description", str(dest.get("descrizione", "Pinball fatto con Pinball Editor 2D")).substr(0, 300)])
			if not cr["ok"]:
				return {"ok": false, "messaggio": "Non riesco a creare il repository su GitHub: " + cr["testo"]}
		_git(src, ["remote", "remove", "origin"])
		_git(src, ["remote", "add", "origin", url + ".git"])
		_esegui("gh", ["auth", "setup-git"])
	else:
		url = str(dest.get("url", ""))
		_git(src, ["remote", "remove", "origin"])
		_git(src, ["remote", "add", "origin", url])
	var pu := _git(src, ["push", "-q", "origin", "main", "refs/tags/" + tag])
	if not pu["ok"]:
		return {"ok": false, "messaggio": "Invio del sorgente non riuscito: " + pu["testo"], "url": url}
	return {"ok": true, "url": url, "messaggio": "Sorgente inviato"}

## Verifica che il sorgente pubblicato sia raggiungibile da CHIUNQUE e che il tag punti al commit giusto.
static func verifica_pubblicazione(url: String, tag: String, commit: String, dest: Dictionary) -> Dictionary:
	if str(dest.get("tipo", "")) == "github":
		var api := "https://api.github.com/repos/%s/%s" % [dest["utente"], dest["repo"]]
		var cu := _esegui("curl", ["-s", "-o", "/dev/null", "-w", "%{http_code}", api])      # senza credenziali: come un visitatore
		if cu["testo"] != "200":
			return {"ok": false, "messaggio": "Il repository non risulta pubblico (risposta %s)" % cu["testo"]}
	var lr := _esegui("git", ["-c", "credential.helper=", "ls-remote", url, "refs/tags/" + tag])
	if not lr["ok"] or not lr["testo"].begins_with(commit):
		return {"ok": false, "messaggio": "Il tag %s pubblicato non corrisponde al commit %s" % [tag, commit.substr(0, 10)]}
	return {"ok": true, "messaggio": "Sorgente pubblico raggiungibile, tag %s = commit %s" % [tag, commit.substr(0, 10)]}

# ================================================================ 4-6) compilazione dal commit, pacchetto, verifica
## Esegue tutto il rilascio (bloccante: da un thread). opz = {consenso: bool, dest: {...}, note: testo, compila: bool}.
static func rilascia(p: ProgettoEditor, opz: Dictionary) -> Dictionary:
	var passi: Array = []
	if p.cartella == "":
		return {"ok": false, "messaggio": "Salva prima il tavolo", "passi": passi}
	var v := LicenzeProgetto.verifica(p)
	passi.append(["Licenze e crediti", v["ok"], "ok" if v["ok"] else "; ".join(v["problemi"])])
	if not v["ok"]:
		return {"ok": false, "messaggio": "Rilascio fermato: " + "; ".join(v["problemi"]), "passi": passi}
	if not bool(opz.get("consenso", false)):
		return {"ok": false, "messaggio": "Serve il tuo consenso alla pubblicazione del sorgente", "passi": passi}
	var i := LicenzeProgetto.info(p.desc)
	var dest: Dictionary = opz.get("dest", {})
	var repo_url := "https://github.com/%s/%s" % [dest.get("utente", ""), dest.get("repo", "")] if str(dest.get("tipo", "")) == "github" else str(dest.get("url", ""))
	var ps := prepara_sorgente(p, repo_url, str(opz.get("note", "")))
	passi.append(["Sorgente completo", ps.get("ok", false), str(ps.get("messaggio", ps.get("cartella", "")))])
	if not ps.get("ok", false):
		return {"ok": false, "messaggio": str(ps["messaggio"]), "passi": passi}
	var src: String = ps["cartella"]
	var tag: String = "v" + str(i["versione"])
	_git(src, ["add", "-A"])
	var autore := "%s <%s>" % [i["autore"], str(opz.get("email", "pinball@users.noreply.github.com"))]
	var cm := _git(src, ["-c", "user.name=" + i["autore"], "-c", "user.email=" + str(opz.get("email", "pinball@users.noreply.github.com")), "commit", "-q", "--allow-empty", "--author", autore, "-m", "%s %s" % [i["nome"], i["versione"]]])
	if _git(src, ["rev-parse", "-q", "--verify", "refs/tags/" + tag])["ok"]:
		return {"ok": false, "messaggio": "La versione %s è già stata rilasciata: cambia il numero di versione" % i["versione"], "passi": passi}
	_git(src, ["tag", tag])
	var commit: String = str(_git(src, ["rev-parse", "HEAD"])["testo"])
	passi.append(["Commit e tag", cm["ok"], "%s = %s" % [tag, commit.substr(0, 10)]])
	var pb := pubblica(src, tag, dest)
	var vp := verifica_pubblicazione(pb.get("url", repo_url), tag, commit, dest) if pb["ok"] else {"ok": false, "messaggio": pb["messaggio"]}
	passi.append(["Pubblicazione del sorgente", vp["ok"], vp["messaggio"]])
	if not vp["ok"]:
		_git(src, ["tag", "-d", tag])        # niente tag di un rilascio non avvenuto
		return {"ok": false, "messaggio": "Rilascio NON ufficiale: " + vp["messaggio"], "passi": passi}
	# pacchetto
	var pk := p.cartella.path_join("rilasci").path_join("%s-%s" % [LicenzeProgetto.slug(i["nome"]), i["versione"]])
	Esportazione._svuota(pk)
	for d in ["GAME", "SOURCE", "ASSETS"]:
		DirAccess.make_dir_recursive_absolute(pk.path_join(d))
	# (v0.26.1: senza bash né tar, così funziona anche su Windows: git crea lo ZIP, Godot lo estrae)
	var ar := _git(src, ["archive", "--format=zip", "-o", pk.path_join("SOURCE.zip"), commit])
	if ar["ok"]:
		ar["ok"] = estrai_zip(pk.path_join("SOURCE.zip"), pk.path_join("SOURCE"))
	passi.append(["Sorgente nel pacchetto (dal commit)", ar["ok"], "SOURCE/ e SOURCE.zip"])
	var giochi: Array = []
	if bool(opz.get("compila", true)):
		var scelte: Array = opz.get("piattaforme", PIATTAFORME_PREDEFINITE)
		var sorg_pk := pk.path_join("SOURCE")
		_esegui(OS.get_executable_path(), ["--headless", "--path", sorg_pk, "--import"])
		for k in PIATTAFORME_RILASCIO:
			if not k in scelte:
				continue
			var pf: Dictionary = PIATTAFORME_RILASCIO[k]
			if k == "android" and not bool(opz.get("android_confermato", false)):
				passi.append(["Gioco per " + pf["nome"], true, "non creato: l'APK si crea solo con una conferma a parte"])
				continue
			var out := pk.path_join("GAME").path_join(pf["cartella"]).path_join(LicenzeProgetto.slug(i["nome"]) + pf["est"])
			DirAccess.make_dir_recursive_absolute(out.get_base_dir())
			var cmp := compila(sorg_pk, out, pf["preset"], bool(pf.get("debug", false)), false)
			passi.append(["Gioco per %s compilato dal sorgente pubblicato" % pf["nome"], cmp["ok"], cmp["messaggio"]])
			if not cmp["ok"]:
				_pulisci_import(sorg_pk)
				return {"ok": false, "messaggio": "Compilazione per %s non riuscita: %s" % [pf["nome"], cmp["messaggio"]], "passi": passi}
			giochi.append({"file": "GAME/%s/%s" % [pf["cartella"], out.get_file()], "sha256": FileAccess.get_sha256(out), "piattaforma": pf["nome"], "preset": pf["preset"]})
		_pulisci_import(sorg_pk)
	_copia_assets(pk.path_join("SOURCE"), pk.path_join("ASSETS"))
	for f in ["README.md", "CREDITS.md", "AI_INSTRUCTIONS.md", "CHANGELOG.md", "BUILD_INSTRUCTIONS.md", "LICENSE"]:
		DirAccess.copy_absolute(src.path_join(f), pk.path_join(f))
	LicenzeProgetto.scrivi_licenze(pk)
	var info_r := {"nome": i["nome"], "versione": i["versione"], "autore": i["autore"], "data": Time.get_datetime_string_from_system(true),
		"commit": commit, "tag": tag, "repository": pb["url"], "runtime": LicenzeProgetto.runtime(),
		"giochi": giochi,
		"sorgente_zip_sha256": FileAccess.get_sha256(pk.path_join("SOURCE.zip")),
		"dipendenze": [LicenzeProgetto.runtime() + " (MIT)"], "istruzioni": "BUILD_INSTRUCTIONS.md", "editor": "Pinball Editor 2D"}
	LicenzeProgetto._scrivi(pk.path_join("RELEASE_INFO.json"), JSON.stringify(info_r, "  "))
	LicenzeProgetto._scrivi(pk.path_join("LICENSE_MANIFEST.json"), JSON.stringify(LicenzeProgetto.manifest(p, info_r), "  "))
	LicenzeProgetto._scrivi(pk.path_join("SOURCE_REPOSITORY.txt"), "%s\ncommit %s\ntag %s\nIl codice sorgente e la sua disponibilità sono parte integrante della distribuzione di questo pinball.\nIl sorgente di questa versione è anche in SOURCE/ e SOURCE.zip di questo pacchetto.\n" % [pb["url"], commit, tag])
	var fin := verifica_pacchetto(pk, bool(opz.get("compila", true)))
	passi.append(["Verifica finale del pacchetto", fin["ok"], "; ".join(fin["mancano"]) if not fin["ok"] else "tutto presente e coerente"])
	if not fin["ok"]:
		return {"ok": false, "messaggio": "Pacchetto incompleto: " + "; ".join(fin["mancano"]), "passi": passi, "pacchetto": pk}
	return {"ok": true, "messaggio": "RILASCIO UFFICIALE %s %s completato. Sorgente pubblico: %s (commit %s)" % [i["nome"], i["versione"], pb["url"], commit.substr(0, 10)],
		"passi": passi, "pacchetto": pk, "commit": commit, "url": pb["url"]}

## Compila il gioco dal sorgente estratto dal commit (stesso Godot dell'editor; servono i modelli di esportazione).
static func compila(sorgente: String, out_file: String, preset := PRESET_PC, debug := false, importa := true) -> Dictionary:
	var godot := OS.get_executable_path()
	if importa:
		_esegui(godot, ["--headless", "--path", sorgente, "--import"])
	var r := _esegui(godot, ["--headless", "--path", sorgente, "--export-debug" if debug else "--export-release", preset, out_file])
	if importa:
		_pulisci_import(sorgente)
	if not FileAccess.file_exists(out_file):
		return {"ok": false, "messaggio": "mancano i modelli di esportazione di Godot?" if r["testo"].contains("template") else r["testo"].right(300)}
	return {"ok": true, "messaggio": "%s (%.0f MB)" % [out_file.get_file(), float(FileAccess.open(out_file, FileAccess.READ).get_length()) / 1048576.0]}

## Estrae uno ZIP in una cartella (con le sottocartelle). Ritorna true se è andato bene.
static func estrai_zip(zip: String, dest: String) -> bool:
	var z := ZIPReader.new()
	if z.open(zip) != OK:
		return false
	for f in z.get_files():
		var out := dest.path_join(f)
		if f.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out)
			continue
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var fa := FileAccess.open(out, FileAccess.WRITE)
		if fa == null:
			z.close()
			return false
		fa.store_buffer(z.read_file(f))
		fa.close()
	z.close()
	return true

## La cache di Godot (.godot) creata per compilare non fa parte del sorgente.
static func _pulisci_import(sorgente: String) -> void:
	Esportazione._svuota(sorgente.path_join(".godot"))
	DirAccess.remove_absolute(sorgente.path_join(".godot"))

static func _copia_assets(sorgente: String, assets: String) -> void:
	for x in [["gioco/immagini", "immagini"], ["gioco/musica", "musica"], ["interfaccia/font", "font"], ["audio/effects", "suoni"]]:
		var da := sorgente.path_join(x[0])
		if not DirAccess.dir_exists_absolute(da):
			continue
		DirAccess.make_dir_recursive_absolute(assets.path_join(x[1]))
		for f in DirAccess.get_files_at(da):
			if not f.ends_with(".import"):
				DirAccess.copy_absolute(da.path_join(f), assets.path_join(x[1]).path_join(f))

const FILE_OBBLIGATORI := ["README.md", "CREDITS.md", "AI_INSTRUCTIONS.md", "CHANGELOG.md", "LICENSE_MANIFEST.json", "BUILD_INSTRUCTIONS.md",
	"SOURCE_REPOSITORY.txt", "RELEASE_INFO.json", "LICENSE", "SOURCE.zip", "LICENSES/GPL-3.0-or-later.txt", "LICENSES/CC-BY-SA-4.0.txt",
	"LICENSES/OFL-1.1.txt", "LICENSES/Godot-MIT.txt", "SOURCE/project.godot", "SOURCE/gioco/tavolo.tavolo", "SOURCE/LICENSE",
	"SOURCE/AI_INSTRUCTIONS.md", "SOURCE/AGENTS.md", "SOURCE/CLAUDE.md", "SOURCE/.github/copilot-instructions.md", "SOURCE/CREDITS.md"]

## Verifica del pacchetto: file obbligatori, manifest valido, hash del gioco, commit coerente. {ok, mancano: []}
static func verifica_pacchetto(pk: String, con_gioco := true) -> Dictionary:
	var mancano: Array = []
	for f in FILE_OBBLIGATORI:
		if not FileAccess.file_exists(pk.path_join(f)):
			mancano.append("manca " + f)
	var ri = JSON.parse_string(FileAccess.get_file_as_string(pk.path_join("RELEASE_INFO.json"))) if FileAccess.file_exists(pk.path_join("RELEASE_INFO.json")) else null
	var mf = JSON.parse_string(FileAccess.get_file_as_string(pk.path_join("LICENSE_MANIFEST.json"))) if FileAccess.file_exists(pk.path_join("LICENSE_MANIFEST.json")) else null
	if not mf is Dictionary or not mf.has("componenti") or mf["componenti"].is_empty():
		mancano.append("LICENSE_MANIFEST.json non valido")
	elif mf["componenti"].any(func(c): return c.has("libera") and not bool(c["libera"])):
		mancano.append("il manifest contiene risorse non libere")
	if not ri is Dictionary:
		mancano.append("RELEASE_INFO.json non valido")
	else:
		if con_gioco:
			if ri.get("giochi", []).is_empty():
				mancano.append("nessun gioco compilato nel pacchetto")
			for gi in ri.get("giochi", []):
				var g := pk.path_join(str(gi["file"]))
				if not FileAccess.file_exists(g) or FileAccess.get_sha256(g) != str(gi["sha256"]):
					mancano.append("l'hash del gioco %s non corrisponde" % str(gi["piattaforma"]))
		if FileAccess.get_sha256(pk.path_join("SOURCE.zip")) != str(ri.get("sorgente_zip_sha256", "")):
			mancano.append("l'hash di SOURCE.zip non corrisponde")
		if not FileAccess.get_file_as_string(pk.path_join("SOURCE_REPOSITORY.txt")).contains(str(ri["commit"])):
			mancano.append("SOURCE_REPOSITORY.txt non indica il commit del rilascio")
		var rj = JSON.parse_string(FileAccess.get_file_as_string(pk.path_join("SOURCE/gioco/rilascio.json"))) if FileAccess.file_exists(pk.path_join("SOURCE/gioco/rilascio.json")) else null
		if not rj is Dictionary or str(rj.get("versione", "")) != str(ri["versione"]):
			mancano.append("il sorgente nel pacchetto non è della stessa versione")
	return {"ok": mancano.is_empty(), "mancano": mancano}
