## ESPORTAZIONE (Pinball Editor 2D v0.20, Fase 8): dal tavolo dell'editor al GIOCO VERO, con il motore vero.
## Il tavolo (e le sue musiche) va dentro il gioco in res://gioco/ (il gioco lo carica da solo, motore/main.gd), poi
## Godot esporta con i preset del progetto. Accanto al gioco: i file legali (closed source) e il registro licenze.
## "conferma_utente"); chiavi, keystore e ID della pubblicità MAI nel progetto; sui telefoni solo pubblicità di prova.
class_name Esportazione

const PIATTAFORME := {
	"linux": {"nome": "PC (Linux)", "preset": "Linux x86_64", "est": ".x86_64"},
	"windows": {"nome": "PC (Windows)", "preset": "Windows x86_64", "est": ".exe"},
	"pi": {"nome": "Raspberry Pi 4 (Linux ARM64)", "preset": "Linux ARM64 (Raspberry Pi 4)", "est": ".arm64"},
	"android": {"nome": "APK Android di PROVA (senza pubblicità)", "preset": "Android (prova telefono)", "est": ".apk"},
	"godot": {"nome": "PROGETTO GODOT completo (da aprire e modificare in Godot)", "preset": "", "est": ""},
}
## Cartelle del motore che NON vanno nel progetto Godot esportato (prove, attrezzi, cache, prove locali).
const FUORI_DAL_PROGETTO := [".godot", ".git", "tests", "tools", "gioco", "build", "foto"]
const FILE_LEGALI := ["LICENSE", "EULA.md", "COPYRIGHT.md", "THIRD_PARTY_LICENSES.md"]
## Testi legali messi accanto ai giochi esportati con ESPORTA (build di prova e progetto Godot): modelli in questa cartella.
const CARTELLA_MODELLI_LEGALI := "res://licenze_giochi"

# ---------------------------------------------------------------- MODELLI DI ESPORTAZIONE di Godot (v0.26.1)
## Servono per creare i giochi (Linux, Windows, Raspberry Pi, Android). Si scaricano UNA volta dal rilascio ufficiale
## di Godot (controllo SHA-512) e si installano dove Godot li cerca; si tengono solo i file usati dall'editor.
const URL_GODOT := "https://github.com/godotengine/godot/releases/download/%s/"
const MODELLI_USATI := ["linux_release.x86_64", "linux_release.arm64", "windows_release_x86_64.exe", "android_debug.apk", "android_release.apk", "version.txt"]

static func versione_godot() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d.%s" % [v["major"], v["minor"], v["patch"], v["status"]]

static func cartella_modelli() -> String:
	# Linux ~/.local/share/godot, Windows %APPDATA%/Godot, macOS ~/Library/Application Support/Godot
	return OS.get_data_dir().path_join("godot" if OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"] else "Godot").path_join("export_templates").path_join(versione_godot())

static func modelli_presenti(dir := "") -> bool:
	var d := dir if dir != "" else cartella_modelli()
	for f in ["linux_release.x86_64", "windows_release_x86_64.exe", "linux_release.arm64"]:
		if not FileAccess.file_exists(d.path_join(f)):
			return false
	return true

static func nome_tpz() -> String:
	var v := Engine.get_version_info()
	return "Godot_v%d.%d.%d-%s_export_templates.tpz" % [v["major"], v["minor"], v["patch"], v["status"]]

static func url_rilascio_godot() -> String:
	var v := Engine.get_version_info()
	return URL_GODOT % ("%d.%d.%d-%s" % [v["major"], v["minor"], v["patch"], v["status"]])

## Installa i modelli dal file .tpz scaricato (controlla l'SHA-512 se `somme` è dato). Ritorna {ok, messaggio}.
static func installa_modelli(tpz: String, somme := "", dest_prova := "") -> Dictionary:
	if somme != "":
		var atteso := ""
		for r in somme.split("\n"):
			if r.strip_edges().ends_with(nome_tpz()):
				atteso = r.split(" ")[0].strip_edges()
		var calcolato := _sha512_file(tpz)
		if atteso == "" or calcolato != atteso:
			return {"ok": false, "messaggio": "Il file scaricato non corrisponde a quello ufficiale di Godot (controllo SHA-512): riprova"}
	var z := ZIPReader.new()
	if z.open(tpz) != OK:
		return {"ok": false, "messaggio": "Non riesco ad aprire i modelli scaricati"}
	var dest := dest_prova if dest_prova != "" else cartella_modelli()
	DirAccess.make_dir_recursive_absolute(dest)
	var n := 0
	for f in z.get_files():
		var nome := f.get_file()
		if nome in MODELLI_USATI:
			var fa := FileAccess.open(dest.path_join(nome), FileAccess.WRITE)
			if fa != null:
				fa.store_buffer(z.read_file(f))
				fa.close()
				n += 1
	z.close()
	if OS.get_name() != "Windows":
		for f in ["linux_release.x86_64", "linux_release.arm64"]:
			OS.execute("chmod", ["+x", dest.path_join(f)])
	return {"ok": modelli_presenti(dest), "messaggio": "Modelli di esportazione installati (%d file) in %s" % [n, dest] if modelli_presenti(dest) else "Installazione incompleta"}

static func _sha512_file(f: String) -> String:
	# SHA-512 senza caricare tutto il file in memoria (il .tpz pesa più di 1 GB)
	var out: Array = []
	if OS.get_name() == "Windows":
		OS.execute("certutil", ["-hashfile", f, "SHA512"], out, true)
		var righe := "\n".join(out).split("\n")
		return righe[1].strip_edges().replace(" ", "").to_lower() if righe.size() > 1 else ""
	OS.execute("sha512sum", [f], out, true)
	return "\n".join(out).split(" ")[0].strip_edges()

static func cartella_gioco() -> String:
	return ProjectSettings.globalize_path("res://gioco")

## Nome del file del gioco (senza spazi né caratteri strani).
static func nome_file(p: ProgettoEditor) -> String:
	var n := str(p.desc.get("titolo", p.desc.get("nome", "tavolo"))).strip_edges().to_lower().validate_filename().replace(" ", "_")
	return n if n != "" else "tavolo"

## Esporta (bloccante: da chiamare in un thread dall'editor). Ritorna {ok, messaggio, file}.
static func esporta(p: ProgettoEditor, piattaforma: String, conferma_utente := false) -> Dictionary:
	if not PIATTAFORME.has(piattaforma):
		return {"ok": false, "messaggio": "Piattaforma sconosciuta: " + piattaforma}
	if piattaforma == "android" and not conferma_utente:
		return {"ok": false, "messaggio": "L'APK si crea solo con la conferma dell'utente"}
	if p.cartella == "":
		return {"ok": false, "messaggio": "Salva prima il tavolo: il gioco va nella sua cartella «esportati»"}
	if piattaforma == "godot":
		return esporta_progetto(p)
	var pf: Dictionary = PIATTAFORME[piattaforma]
	# 1) il tavolo e le musiche dentro il gioco
	var gioco := cartella_gioco()
	_svuota(gioco)
	DirAccess.make_dir_recursive_absolute(gioco.path_join("musica"))
	var d := p.desc.duplicate(false)
	d.erase("cartella_musica")
	d.erase("tiri_riferimento")
	if FileTavolo.salva(d, gioco.path_join("tavolo.tavolo")) != OK:
		return {"ok": false, "messaggio": "Non riesco a preparare il tavolo per il gioco"}
	var mus := p.cartella.path_join("musica")
	if DirAccess.dir_exists_absolute(mus):
		for f in DirAccess.get_files_at(mus):
			DirAccess.copy_absolute(mus.path_join(f), gioco.path_join("musica").path_join(f))
	# 2) esportazione con Godot
	var out_dir := p.cartella.path_join("esportati").path_join(piattaforma)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out := out_dir.path_join(nome_file(p) + str(pf["est"]))
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var uscita: Array = []
	var cod := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--export-release" if piattaforma != "android" else "--export-debug", str(pf["preset"]), out], uscita, true)
	_svuota(gioco)
	DirAccess.remove_absolute(gioco)
	if not FileAccess.file_exists(out):
		var testo := "\n".join(uscita)
		var perche := "mancano i «modelli di esportazione» di Godot per questa piattaforma" if testo.contains("template") else "vedi il Diario"
		return {"ok": false, "messaggio": "Esportazione NON riuscita (%s, codice %d)" % [perche, cod], "dettagli": testo.right(1500)}
	# 3) file legali (closed source) col NOME DEL TAVOLO al posto di quello del modello, e registro licenze
	var titolo := str(p.desc.get("titolo", p.desc.get("nome", "tavolo"))).strip_edges()
	for f in FILE_LEGALI:
		var src := ProjectSettings.globalize_path(CARTELLA_MODELLI_LEGALI).path_join(f)
		if FileAccess.file_exists(src):
			var testo := FileAccess.get_file_as_string(src).replace("{TITOLO}", titolo.to_upper()).replace("{Titolo}", titolo.capitalize())
			var fw := FileAccess.open(out_dir.path_join(f), FileAccess.WRITE)
			if fw != null:
				fw.store_string(testo)
				fw.close()
	var lg := FileAccess.open(out_dir.path_join("LEGGIMI_ESPORTAZIONE.md"), FileAccess.WRITE)
	if lg != null:
		lg.store_string("# %s – gioco esportato dal Pinball Editor 2D (%s)\n\n" % [titolo.capitalize(), Time.get_date_string_from_system()]
			+ "- Gioco: `%s` (%s). Si avvia con un doppio clic (su Linux: renderlo eseguibile).\n" % [out.get_file(), pf["nome"]]
			+ "- Testi legali accanto al gioco: presi dai modelli della cartella `licenze_giochi` dell'editor (con il nome del tavolo): **rileggerli prima di pubblicare**.\n"
			+ "- `THIRD_PARTY_LICENSES.md`: licenze di terzi del motore e dei suoni (da controllare che siano quelli usati).\n"
			+ "- `%s`: fonte di ogni immagine e musica del tavolo.\n" % ProgettoEditor.FILE_REGISTRO
			+ "- Questa è una BUILD DI PROVA: per distribuire il pinball usa il Rilascio ufficiale (sorgente pubblico). Niente pubblicità, chiavi o ID dentro.\n")
		lg.close()
	p.esegui({"comando": "registro_licenze"}, "editor")
	var reg := p.cartella.path_join(ProgettoEditor.FILE_REGISTRO)
	if FileAccess.file_exists(reg):
		DirAccess.copy_absolute(reg, out_dir.path_join(ProgettoEditor.FILE_REGISTRO))
	var mb := float(FileAccess.open(out, FileAccess.READ).get_length()) / 1048576.0
	return {"ok": true, "messaggio": "Gioco %s pronto: %s (%.0f MB), con i file legali e il registro licenze" % [pf["nome"], out.get_file(), mb], "file": out}

## PROGETTO GODOT 4.7 completo e indipendente: motore, grafica, menu, il tavolo in res://gioco/tavolo.tavolo (testo
## leggibile), le immagini come file PNG in res://gioco/immagini/, le musiche, i file legali e un LEGGIMI in italiano.
## Si apre con Godot (Importa → project.godot) e si gioca con F5. Nessuna chiave, nessuna pubblicità.
static func esporta_progetto(p: ProgettoEditor, cartella_out := "") -> Dictionary:
	var titolo := str(p.desc.get("titolo", p.desc.get("nome", "tavolo"))).strip_edges()
	var out := cartella_out if cartella_out != "" else p.cartella.path_join("esportati").path_join("progetto_godot").path_join(nome_file(p))
	if DirAccess.dir_exists_absolute(out):
		_svuota(out, [".git"])             # (solo la copia esportata prima: si rifà da capo; la cronologia git resta)
	DirAccess.make_dir_recursive_absolute(out)
	var sorgente := ProjectSettings.globalize_path("res://")
	_copia_cartella(sorgente, out, true)
	# il tavolo, con le immagini anche come file PNG
	var gioco := out.path_join("gioco")
	DirAccess.make_dir_recursive_absolute(gioco.path_join("immagini"))
	DirAccess.make_dir_recursive_absolute(gioco.path_join("musica"))
	var d := p.desc.duplicate(true)
	d.erase("cartella_musica")
	d.erase("tiri_riferimento")
	d.erase("editor_livelli")
	var n_img := 0
	if d.get("immagini") is Dictionary:
		for nome in d["immagini"]:
			var fw := FileAccess.open(gioco.path_join("immagini").path_join(str(nome) + ".png"), FileAccess.WRITE)
			if fw != null:
				fw.store_buffer(Marshalls.base64_to_raw(str(d["immagini"][nome])))
				fw.close()
				n_img += 1
	if FileTavolo.salva(d, gioco.path_join("tavolo.tavolo")) != OK:
		return {"ok": false, "messaggio": "Non riesco a scrivere il tavolo nel progetto Godot"}
	var mus := p.cartella.path_join("musica")
	if DirAccess.dir_exists_absolute(mus):
		for f in DirAccess.get_files_at(mus):
			DirAccess.copy_absolute(mus.path_join(f), gioco.path_join("musica").path_join(f))
	# nome del progetto = nome del tavolo
	var pg := out.path_join("project.godot")
	var testo := FileAccess.get_file_as_string(pg)
	testo = testo.replace('config/name="Pinball Editor 2D"', 'config/name="%s"' % titolo.capitalize().replace('"', ""))
	var fp := FileAccess.open(pg, FileAccess.WRITE)
	if fp != null:
		fp.store_string(testo)
		fp.close()
	# file legali col nome del tavolo e registro licenze
	for f in FILE_LEGALI:
		var src := ProjectSettings.globalize_path(CARTELLA_MODELLI_LEGALI).path_join(f)
		if FileAccess.file_exists(src):
			var tl := FileAccess.get_file_as_string(src).replace("{TITOLO}", titolo.to_upper()).replace("{Titolo}", titolo.capitalize())
			var fl := FileAccess.open(out.path_join(f), FileAccess.WRITE)
			if fl != null:
				fl.store_string(tl)
				fl.close()
	p.esegui({"comando": "registro_licenze"}, "editor")
	var reg := p.cartella.path_join(ProgettoEditor.FILE_REGISTRO)
	if FileAccess.file_exists(reg):
		DirAccess.copy_absolute(reg, out.path_join(ProgettoEditor.FILE_REGISTRO))
	var lg := FileAccess.open(out.path_join("LEGGIMI_GODOT.md"), FileAccess.WRITE)
	if lg != null:
		lg.store_string(LEGGIMI_GODOT.replace("{TITOLO}", titolo.capitalize()).replace("{DATA}", Time.get_date_string_from_system()))
		lg.close()
	return {"ok": true, "messaggio": "Progetto Godot pronto (%d immagini come PNG): cartella «esportati/progetto_godot/%s». Aprilo in Godot con «Apri in Godot» o da Godot → Importa → project.godot" % [n_img, nome_file(p)], "file": out}

## Copia ricorsiva (senza le cartelle di FUORI_DAL_PROGETTO al primo livello e senza i file .tmp).
static func _copia_cartella(da: String, a: String, radice := false) -> void:
	DirAccess.make_dir_recursive_absolute(a)
	for f in DirAccess.get_files_at(da):
		if not f.ends_with(".tmp"):
			DirAccess.copy_absolute(da.path_join(f), a.path_join(f))
	for sub in DirAccess.get_directories_at(da):
		if radice and sub in FUORI_DAL_PROGETTO:
			continue
		_copia_cartella(da.path_join(sub), a.path_join(sub))

const LEGGIMI_GODOT := """# {TITOLO} – progetto Godot (esportato dal Pinball Editor 2D il {DATA})

Questa cartella è un **progetto Godot 4.7 completo**: si apre, si modifica e si esporta come qualunque gioco Godot.

## Aprire
1. Avvia **Godot 4.7.2** (scaricabile gratis da https://godotengine.org).
2. **Importa** → scegli il file `project.godot` di questa cartella → Apri.
3. Premi **F5** (▶ in alto a destra): parte il gioco con il tuo tavolo.

## Dove sta cosa
| Cosa | Dove | Come si modifica |
|---|---|---|
| Il TAVOLO (posizione e misure di ogni pezzo, missioni, luci, suoni, colori) | `gioco/tavolo.tavolo` | è un file di TESTO: si apre in Godot (doppio clic) o con un editor di testo. Misure in millimetri. |
| Le immagini dei pezzi e del fondo | `gioco/immagini/*.png` | ridipingi o sostituisci il PNG (stesso nome): il gioco usa il file nuovo. |
| Le musiche | `gioco/musica/` | sostituisci i file (stesso nome). |
| Fisica (pallina, palette, rampe, urti) | `motore/tavolo_fisico.gd`, `motore/pallina.gd` | codice GDScript. |
| Regole, punti, missioni a mattoncini | `motore/regole_base.gd`, `motore/mattoncini.gd` | codice GDScript. |
| Disegno del tavolo e luci | `grafica/vista_2d.gd`, `grafica/pittore_pezzi.gd`, `grafica/regia_luci_2d.gd` | codice GDScript. |
| Tabellone e menu | `interfaccia/hud.gd`, `interfaccia/menu.gd`, `interfaccia/menu_comune.gd` | codice GDScript. |
| Scena principale | `scenes/main.tscn` (script `motore/main.gd`) | |

Il tavolo si può anche **riaprire nel Pinball Editor 2D**: `gioco/tavolo.tavolo` è lo stesso formato dei progetti
dell'editor (copialo in una cartella `NOME.pinproj/` dentro `progetti/`).

## Esportare il gioco da Godot
Progetto → Esporta: ci sono già i profili Linux, Raspberry Pi 4 e Android di prova. Per Android servono i modelli di
esportazione di Godot. **Chiavi, keystore e ID della pubblicità non sono qui e non vanno messi qui.**

## Prima di pubblicare
- Testi legali: presi dai modelli della cartella `licenze_giochi` dell'editor: rileggerli prima di pubblicare.
- `LICENZE_GRAFICA_E_MUSICA.md`: da dove viene ogni immagine e musica.
- `THIRD_PARTY_LICENSES.md`: licenze del motore Godot e dei suoni.
"""

static func _svuota(dir: String, tieni: Array = []) -> void:
	# v0.26: anche file e cartelle NASCOSTI (es. .git di un rilascio precedente), tranne quelli in `tieni`
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.include_hidden = true
	for sub in da.get_directories():
		if sub in tieni:
			continue
		_svuota(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
	for f in da.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
