## LICENZE, CREDITI e MANIFEST dei pinball (Pinball Editor 2D v0.26).
## - Codice (editor e runtime del gioco): GPL-3.0-or-later.
## - Contenuti creativi originali del gioco (grafica, musica, testi, disegno del tavolo): CC-BY-SA-4.0.
## - Risorse di terzi: ognuna con la SUA licenza, registrata (autore, fonte, URL, modifiche, limitazioni) e controllata:
##   quelle sconosciute, non commerciali, «non opere derivate» o proprietarie NON entrano in un rilascio libero.
## I testi ufficiali delle licenze sono in res://LICENSES/ (scaricati dai siti di chi le pubblica, non modificati).
class_name LicenzeProgetto

const AUTORE_EDITOR := "Carmelo Vadalà"
const EMAIL_EDITOR := "themeloohgames@gmail.com"
const FILOSOFIA := "An open source 2D pinball editor, built by the community, for the community."
const LICENZA_CODICE := "GPL-3.0-or-later"
const LICENZA_CONTENUTI := "CC-BY-SA-4.0"

## SPDX → nome, file del testo, se è ammessa in un rilascio libero (uso commerciale, modifiche, ridistribuzione).
const LICENZE := {
	"GPL-3.0-or-later": {"nome": "GNU General Public License v3.0 o successiva", "file": "GPL-3.0-or-later.txt", "libera": true, "tipo": "codice"},
	"CC-BY-SA-4.0": {"nome": "Creative Commons Attribution-ShareAlike 4.0 International", "file": "CC-BY-SA-4.0.txt", "libera": true, "tipo": "contenuti"},
	"CC-BY-4.0": {"nome": "Creative Commons Attribution 4.0 International", "file": "", "libera": true, "tipo": "contenuti"},
	"CC0-1.0": {"nome": "Creative Commons Zero 1.0 (pubblico dominio)", "file": "CC0-1.0.txt", "libera": true, "tipo": "contenuti"},
	"OFL-1.1": {"nome": "SIL Open Font License 1.1", "file": "OFL-1.1.txt", "libera": true, "tipo": "font"},
	"MIT": {"nome": "MIT License", "file": "", "libera": true, "tipo": "codice"},
	"Apache-2.0": {"nome": "Apache License 2.0", "file": "Apache-2.0.txt", "libera": true, "tipo": "codice"},
	"CC-BY-NC-4.0": {"nome": "Creative Commons NonCommercial (vieta l'uso commerciale)", "file": "", "libera": false, "tipo": "contenuti"},
	"CC-BY-ND-4.0": {"nome": "Creative Commons NoDerivatives (vieta le modifiche)", "file": "", "libera": false, "tipo": "contenuti"},
	"proprietaria": {"nome": "Licenza proprietaria / tutti i diritti riservati", "file": "", "libera": false, "tipo": "altro"},
	"sconosciuta": {"nome": "Licenza sconosciuta", "file": "", "libera": false, "tipo": "altro"},
}

## Licenza predefinita per la «fonte» già dichiarata nel registro dell'editor (v0.17.2).
const LICENZA_DA_FONTE := {"mia": "CC-BY-SA-4.0", "ai": "CC-BY-SA-4.0", "catalogo": "CC-BY-SA-4.0", "cc0": "CC0-1.0", "licenza": "sconosciuta", "": "sconosciuta"}

## Suoni e font dell'editor (risorse di terzi già verificate, vedi THIRD_PARTY_LICENSES.md del progetto).
const RISORSE_EDITOR := [
	{"nome": "Pinball sounds (flipper, bumper, slingshot, plunger, target)", "file": "audio/effects/*.ogg", "autore": "schafferdavid", "fonte": "Freesound.org", "url": "https://freesound.org/people/schafferdavid/", "licenza": "CC0-1.0", "modifiche": "cut, normalised, converted to OGG"},
	{"nome": "Ball in hole sound (passaggio, lock)", "file": "audio/effects/passaggio.ogg, lock.ogg", "autore": "NeatoEnt", "fonte": "Freesound.org", "url": "https://freesound.org/s/458136/", "licenza": "CC0-1.0", "modifiche": "cut, normalised, converted to OGG"},
	{"nome": "Noto Sans Display Bold, Noto Serif Display Bold", "file": "interfaccia/font/*.ttf", "autore": "The Noto Project Authors (Google)", "fonte": "Noto fonts", "url": "https://github.com/notofonts/latin-greek-cyrillic", "licenza": "OFL-1.1", "modifiche": "none"},
]

# ---------------------------------------------------------------- informazioni del gioco
## desc["gioco_info"] = {nome, autore, descrizione, versione, collaboratori: [..], repository}
static func info(desc: Dictionary) -> Dictionary:
	var i: Dictionary = desc.get("gioco_info", {}) if desc.get("gioco_info") is Dictionary else {}
	return {"nome": str(i.get("nome", str(desc.get("titolo", "")).capitalize())), "autore": str(i.get("autore", "")),
		"descrizione": str(i.get("descrizione", desc.get("descrizione", ""))), "versione": str(i.get("versione", "1.0.0")),
		"collaboratori": i.get("collaboratori", []), "repository": str(i.get("repository", ""))}

static func slug(nome: String) -> String:
	var s := nome.strip_edges().to_lower().replace(" ", "-").validate_filename()
	var out := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-":
			out += ch
	return out.trim_prefix("-").trim_suffix("-") if out != "" else "pinball"

# ---------------------------------------------------------------- registro delle risorse
## Tutte le risorse del gioco con la loro licenza: [{chiave, tipo, nome, dove, fonte, autore, url, licenza, modifiche,
## limitazioni, libera}]. Le licenze vengono dal registro dell'editor (comando «licenza»).
static func risorse(p: ProgettoEditor) -> Array:
	var out: Array = []
	var reg: Dictionary = p.desc.get("licenze", {}) if p.desc.get("licenze") is Dictionary else {}
	for a in p.asset_usati():
		var r: Dictionary = reg.get(a["chiave"], {}) if reg.get(a["chiave"]) is Dictionary else {}
		var fonte := str(r.get("fonte", ""))
		var lic := str(r.get("licenza", LICENZA_DA_FONTE.get(fonte, "sconosciuta")))
		var autore := str(r.get("autore", ""))
		if autore == "" and fonte in ["mia", "ai", "catalogo"]:
			autore = info(p.desc)["autore"] if fonte != "catalogo" else AUTORE_EDITOR
		out.append({"chiave": a["chiave"], "tipo": a["tipo"], "nome": a["nome"], "dove": a["dove"], "fonte": fonte,
			"autore": autore, "url": str(r.get("url", "")), "licenza": lic, "modifiche": str(r.get("modifiche", "")),
			"limitazioni": str(r.get("limitazioni", "")), "nota": str(r.get("nota", "")),
			"libera": bool(LICENZE.get(lic, LICENZE["sconosciuta"])["libera"])})
	return out

## Controllo prima di un rilascio libero: {ok, problemi: [testi], avvisi: [testi]}.
static func verifica(p: ProgettoEditor) -> Dictionary:
	var problemi: Array = []
	var avvisi: Array = []
	var i := info(p.desc)
	if i["nome"].strip_edges() == "":
		problemi.append("Manca il NOME del pinball")
	if i["autore"].strip_edges() == "":
		problemi.append("Manca l'AUTORE del pinball (chi lo ha creato)")
	if not RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$").search(i["versione"]):
		problemi.append("La VERSIONE deve essere del tipo 1.0.0 (ora: «%s»)" % i["versione"])
	for r in risorse(p):
		if not r["libera"]:
			problemi.append("«%s» (%s): licenza %s — non si può ridistribuire con le stesse libertà. Dichiarala in 📜 Licenze o toglila." % [r["nome"], ", ".join(r["dove"]), LICENZE.get(r["licenza"], {"nome": r["licenza"]})["nome"]])
		elif r["licenza"] in ["CC-BY-4.0", "CC-BY-SA-4.0"] and r["autore"] == "":
			problemi.append("«%s»: manca l'AUTORE (la licenza %s chiede di citarlo)" % [r["nome"], r["licenza"]])
		if r["fonte"] == "ai":
			avvisi.append("«%s» è generata con un'intelligenza artificiale: va rilasciata come contenuto dell'autore; verificare i termini del servizio usato." % r["nome"])
	return {"ok": problemi.is_empty(), "problemi": problemi, "avvisi": avvisi}

# ---------------------------------------------------------------- manifest e documenti
static func runtime() -> String:
	return "Godot Engine " + str(Engine.get_version_info()["string"])

static func manifest(p: ProgettoEditor, rilascio := {}) -> Dictionary:
	var i := info(p.desc)
	var comp: Array = []
	comp.append({"componente": "Runtime del gioco e codice generato (motore/, grafica/, interfaccia/, editor/, tavoli/base/, scenes/)",
		"titolari": [AUTORE_EDITOR, "Pinball Editor 2D contributors"], "licenza": LICENZA_CODICE, "file_licenza": "LICENSES/GPL-3.0-or-later.txt"})
	comp.append({"componente": "Disegno del tavolo (gioco/tavolo.tavolo: forma, pezzi, missioni, luci, suoni scelti)",
		"titolari": [i["autore"]] + Array(i["collaboratori"]), "licenza": LICENZA_CONTENUTI, "file_licenza": "LICENSES/CC-BY-SA-4.0.txt"})
	for r in RISORSE_EDITOR:
		comp.append({"componente": r["nome"], "file": r["file"], "titolari": [r["autore"]], "fonte": r["url"], "licenza": r["licenza"],
			"modifiche": r["modifiche"], "file_licenza": "LICENSES/" + str(LICENZE[r["licenza"]]["file"])})
	for r in risorse(p):
		comp.append({"componente": r["nome"], "tipo": r["tipo"], "usato_in": r["dove"], "titolari": [r["autore"]], "fonte": r["url"] if r["url"] != "" else r["fonte"],
			"licenza": r["licenza"], "modifiche": r["modifiche"], "limitazioni": r["limitazioni"], "libera": r["libera"]})
	comp.append({"componente": runtime(), "titolari": ["Godot Engine contributors", "Juan Linietsky, Ariel Manzur"], "licenza": "MIT",
		"file_licenza": "LICENSES/Godot-MIT.txt", "note": "componenti di terzi del motore: LICENSES/Godot-componenti.txt"})
	return {"formato": "pinball-editor-2d/license-manifest/1", "gioco": i["nome"], "versione": i["versione"], "autore_gioco": i["autore"],
		"editor": {"nome": "Pinball Editor 2D", "autore": AUTORE_EDITOR, "licenza": LICENZA_CODICE},
		"licenza_codice": LICENZA_CODICE, "licenza_contenuti": LICENZA_CONTENUTI, "componenti": comp, "rilascio": rilascio}

## Scrive in `dir/LICENSES/` i testi ufficiali e quelli del motore Godot (presi dal motore stesso).
static func scrivi_licenze(dir: String) -> void:
	var dl := dir.path_join("LICENSES")
	DirAccess.make_dir_recursive_absolute(dl)
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path("res://LICENSES")):
		if f.ends_with(".txt"):
			DirAccess.copy_absolute(ProjectSettings.globalize_path("res://LICENSES").path_join(f), dl.path_join(f))
	_scrivi(dl.path_join("Godot-MIT.txt"), Engine.get_license_text())
	var t := PackedStringArray(["Third-party components of the %s engine (from the engine itself: Engine.get_copyright_info / get_license_info)" % runtime(), ""])
	for c in Engine.get_copyright_info():
		t.append("- %s" % str(c["name"]))
		for parte in c["parts"]:
			t.append("    %s — %s" % [", ".join(parte["copyright"]), str(parte["license"])])
	t.append("")
	var li := Engine.get_license_info()
	for k in li:
		t.append("==== " + str(k) + " ====")
		t.append(str(li[k]))
	_scrivi(dl.path_join("Godot-componenti.txt"), "\n".join(t))

static func credits_md(p: ProgettoEditor) -> String:
	var i := info(p.desc)
	var t := PackedStringArray()
	t.append("# Credits – %s %s" % [i["nome"], i["versione"]])
	t.append("")
	t.append("## The pinball")
	t.append("- **Pinball author:** %s" % i["autore"])
	if not Array(i["collaboratori"]).is_empty():
		t.append("- **Contributors:** %s" % ", ".join(i["collaboratori"]))
	t.append("- Original content (graphics, music, texts, table design): **%s**." % LICENZE[LICENZA_CONTENUTI]["nome"])
	t.append("")
	t.append("## The tool it was made with")
	t.append("- Made with **Pinball Editor 2D** – Created by %s. Open Source Community Project." % AUTORE_EDITOR)
	t.append("- Game code (the editor runtime): **%s**." % LICENZE[LICENZA_CODICE]["nome"])
	t.append("- The author of the editor is not the author of this pinball and does not endorse or sponsor it: the tool is free and everyone is responsible for their own games.")
	t.append("")
	t.append("## Third-party resources")
	t.append("| Resource | Author | Source | Licence | Modifications |")
	t.append("|---|---|---|---|---|")
	for r in RISORSE_EDITOR:
		t.append("| %s | %s | %s | %s | %s |" % [r["nome"], r["autore"], r["url"], r["licenza"], r["modifiche"]])
	for r in risorse(p):
		t.append("| %s (%s) | %s | %s | %s | %s |" % [r["nome"], ", ".join(r["dove"]), r["autore"] if r["autore"] != "" else "?", r["url"] if r["url"] != "" else r["fonte"], r["licenza"], r["modifiche"] if r["modifiche"] != "" else "-"])
	t.append("| %s | Godot Engine contributors, Juan Linietsky, Ariel Manzur | https://godotengine.org | MIT (components: LICENSES/Godot-componenti.txt) | none |" % runtime())
	t.append("")
	t.append("Licence texts: folder `LICENSES/`. Complete list, file by file: `LICENSE_MANIFEST.json`.")
	t.append("Credits and copyright notices **must not be removed** in modified versions (the licences require it).")
	return "\n".join(t) + "\n"

static func _scrivi(f: String, testo: String) -> bool:
	var fa := FileAccess.open(f, FileAccess.WRITE)
	if fa == null:
		return false
	fa.store_string(testo)
	fa.close()
	return true
