## Prove del RILASCIO UFFICIALE (v0.26): sorgente pubblico (repository git locale al posto di GitHub), gioco compilato
## dal commit pubblicato, pacchetto completo e coerente, e i casi in cui il rilascio DEVE fermarsi.
## Uso: godot --headless --path . res://tests/test_rilascio.tscn   (servono git e i modelli di esportazione di Godot)
extends Node

var ok := 0
var falliti := 0

func _prova(nome: String, vero: bool) -> void:
	if vero:
		ok += 1
		print("OK       ", nome)
	else:
		falliti += 1
		print("FALLITO  ", nome)

func _ready() -> void:
	var base := ProjectSettings.globalize_path("user://prova_rilascio")
	Esportazione._svuota(base)
	DirAccess.make_dir_recursive_absolute(base)
	var remoto := base.path_join("remoto.git")
	OS.execute("git", ["init", "-q", "--bare", remoto])
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Prova Rilascio"})
	p.esegui({"comando": "aggiungi_composto", "nome": "bumper_3", "pos": [300, 330]})
	# un'immagine propria (licenza dichiarata) sul fondo
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.8))
	var f_img := base.path_join("fondo.png")
	img.save_png(f_img)
	p.esegui({"comando": "imposta_tavolo", "campo": "fondo", "valore": f_img})
	var cart := base.path_join("Prova.pinproj")
	p.salva(cart)
	var dest := {"tipo": "git", "url": remoto}
	# 1) senza informazioni del gioco: fermo
	var r0 := Rilascio.rilascia(p, {"consenso": true, "dest": dest, "compila": false})
	_prova("senza autore il rilascio si ferma", not r0["ok"])
	p.esegui({"comando": "gioco_info", "nome": "Prova Rilascio", "autore": "Pinco Pallino", "descrizione": "Prova", "versione": "1.0.0"})
	# 2) licenza non libera: fermo
	p.esegui({"comando": "licenza", "chiave": "immagine:fondo_tavolo", "fonte": "licenza", "licenza": "CC-BY-NC-4.0", "autore": "Qualcuno"})
	var r1 := Rilascio.rilascia(p, {"consenso": true, "dest": dest, "compila": false})
	_prova("risorsa NonCommercial: il rilascio si ferma", not r1["ok"] and str(r1["messaggio"]).contains("fondo"))
	p.esegui({"comando": "licenza", "chiave": "immagine:fondo_tavolo", "fonte": "mia", "licenza": "CC-BY-SA-4.0", "autore": "Pinco Pallino"})
	_prova("licenza libera dichiarata: verifica superata", LicenzeProgetto.verifica(p)["ok"])
	# 3) senza consenso: fermo
	_prova("senza consenso alla pubblicazione il rilascio si ferma", not Rilascio.rilascia(p, {"consenso": false, "dest": dest})["ok"])
	# 4) pubblicazione impossibile: NON ufficiale, niente tag rimasto
	var r2 := Rilascio.rilascia(p, {"consenso": true, "dest": {"tipo": "git", "url": base.path_join("non_esiste.git")}, "compila": false})
	var src := cart.path_join("rilasci/sorgente")
	var tag_rimasto: bool = Rilascio._git(src, ["rev-parse", "-q", "--verify", "refs/tags/v1.0.0"])["ok"]
	_prova("pubblicazione fallita: rilascio NON ufficiale e tag tolto", not r2["ok"] and str(r2["messaggio"]).contains("NON ufficiale") and not tag_rimasto)
	# 5) rilascio completo
	# tutte e 4 le versioni chieste, ma Android SENZA conferma: deve saltarlo e dirlo
	var r := Rilascio.rilascia(p, {"consenso": true, "dest": dest, "note": "Prima versione", "piattaforme": ["linux", "windows", "pi", "android"]})
	for ps in r.get("passi", []):
		print("   ", "✔" if ps[1] else "✖", " ", ps[0], " – ", ps[2])
	_prova("rilascio ufficiale completo", r["ok"])
	if not r["ok"]:
		_fine()
		return
	var pk: String = r["pacchetto"]
	_prova("verifica del pacchetto superata", Rilascio.verifica_pacchetto(pk)["ok"])
	var out: Array = []
	OS.execute("git", ["ls-remote", remoto, "refs/tags/v1.0.0"], out, true)
	_prova("il tag pubblicato punta al commit del rilascio", "".join(out).begins_with(str(r["commit"])))
	var ri = JSON.parse_string(FileAccess.get_file_as_string(pk.path_join("RELEASE_INFO.json")))
	_prova("RELEASE_INFO: versione, commit, URL, hash e runtime", ri["versione"] == "1.0.0" and ri["commit"] == r["commit"] and ri["repository"] == remoto and ri["giochi"].size() == 3 and ri["giochi"].all(func(g): return str(g["sha256"]).length() == 64) and str(ri["runtime"]).contains("Godot"))
	var mf = JSON.parse_string(FileAccess.get_file_as_string(pk.path_join("LICENSE_MANIFEST.json")))
	_prova("manifest: codice GPL, contenuti CC BY-SA, immagine con autore", mf["licenza_codice"] == "GPL-3.0-or-later" and mf["licenza_contenuti"] == "CC-BY-SA-4.0" and mf["componenti"].any(func(c): return str(c.get("componente", "")) == "fondo_tavolo" and c["titolari"] == ["Pinco Pallino"]))
	_prova("crediti: autore del pinball e dell'editor, distinti", FileAccess.get_file_as_string(pk.path_join("CREDITS.md")).contains("Pinco Pallino") and FileAccess.get_file_as_string(pk.path_join("CREDITS.md")).contains("Created by " + LicenzeProgetto.AUTORE_EDITOR))
	_prova("istruzioni AI nel sorgente (AI_INSTRUCTIONS, AGENTS, CLAUDE, Copilot)", FileAccess.get_file_as_string(pk.path_join("SOURCE/AI_INSTRUCTIONS.md")).contains("Do not remove credits") and FileAccess.file_exists(pk.path_join("SOURCE/.github/copilot-instructions.md")))
	_prova("sorgente nel pacchetto = sorgente pubblicato (stesso commit)", FileAccess.get_file_as_string(pk.path_join("SOURCE/gioco/rilascio.json")).contains("1.0.0"))
	_prova("sorgente senza prove, strumenti né modelli legali privati", not DirAccess.dir_exists_absolute(pk.path_join("SOURCE/tests")) and not DirAccess.dir_exists_absolute(pk.path_join("SOURCE/licenze_giochi")) and FileAccess.get_file_as_string(pk.path_join("SOURCE/LICENSE")).contains("GNU GENERAL PUBLIC LICENSE"))
	_prova("immagine originale nella cartella ASSETS", FileAccess.file_exists(pk.path_join("ASSETS/immagini/fondo_tavolo.png")))
	# il gioco compilato parte
	_prova("tre versioni: PC Linux, PC Windows, Raspberry Pi (Android solo con conferma)", FileAccess.file_exists(pk.path_join("GAME/linux/prova-rilascio.x86_64")) and FileAccess.file_exists(pk.path_join("GAME/windows/prova-rilascio.exe")) and FileAccess.file_exists(pk.path_join("GAME/raspberry_pi/prova-rilascio.arm64")) and not DirAccess.dir_exists_absolute(pk.path_join("GAME/android")))
	_prova("passo Android: non creato senza conferma", r["passi"].any(func(x): return str(x[0]).contains("Android") and str(x[2]).contains("conferma")))
	var gioco := pk.path_join("GAME/linux/prova-rilascio.x86_64")
	var codice := OS.execute(gioco, ["--headless", "--quit-after", "120"], [], true)
	_prova("il gioco compilato dal sorgente pubblicato si avvia", codice == 0)
	# stessa versione due volte: no
	_prova("la stessa versione non si rilascia due volte", not Rilascio.rilascia(p, {"consenso": true, "dest": dest, "compila": false})["ok"])
	# versione nuova: la cronologia continua
	p.esegui({"comando": "gioco_info", "versione": "1.1.0"})
	var r3 := Rilascio.rilascia(p, {"consenso": true, "dest": dest, "compila": false, "note": "Più bumper"})
	var log: Array = []
	OS.execute("git", ["-C", src, "log", "--oneline"], log, true)
	_prova("versione 1.1.0: secondo commit nella cronologia, CHANGELOG con le due versioni", r3["ok"] and "".join(log).split("\n", false).size() >= 2 and FileAccess.get_file_as_string(src.path_join("CHANGELOG.md")).contains("1.0.0") and FileAccess.get_file_as_string(src.path_join("CHANGELOG.md")).contains("1.1.0"))
	# pacchetto manomesso: la verifica se ne accorge
	var fz := FileAccess.open(gioco, FileAccess.READ_WRITE)
	fz.seek(1000)
	fz.store_8(fz.get_8() ^ 0xFF)
	fz.close()
	_prova("gioco manomesso: la verifica del pacchetto lo scopre", not Rilascio.verifica_pacchetto(pk)["ok"])
	# dai comandi automatici: GitHub vietato
	_prova("i comandi automatici non possono pubblicare su GitHub", not p.esegui({"comando": "rilascio", "consenso": true, "dest": {"tipo": "github", "utente": "x", "repo": "y"}}, "ai")["ok"])
	_modelli()
	_fine()

## Installazione dei modelli di esportazione: un .tpz FINTO in una cartella di prova (i modelli veri non si toccano).
func _modelli() -> void:
	var dir := ProjectSettings.globalize_path("user://prova_modelli")
	Esportazione._svuota(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var tpz := dir.path_join("finto.tpz")
	var zp := ZIPPacker.new()
	zp.open(tpz)
	for f in ["templates/linux_release.x86_64", "templates/linux_release.arm64", "templates/windows_release_x86_64.exe", "templates/version.txt", "templates/web_release.zip"]:
		zp.start_file(f)
		zp.write_file(("contenuto " + f).to_utf8_buffer())
		zp.close_file()
	zp.close()
	var dest := dir.path_join("installati")
	var somma_sbagliata := "0000  " + Esportazione.nome_tpz()
	_prova("modelli: un file diverso da quello ufficiale è rifiutato (SHA-512)", not Esportazione.installa_modelli(tpz, somma_sbagliata, dest)["ok"])
	var out: Array = []
	OS.execute("sha512sum", [tpz], out, true)
	var somma_giusta := "".join(out).split(" ")[0] + "  " + Esportazione.nome_tpz()
	var r := Esportazione.installa_modelli(tpz, somma_giusta, dest)
	_prova("modelli: installati solo i file usati dall'editor", r["ok"] and FileAccess.file_exists(dest.path_join("windows_release_x86_64.exe")) and not FileAccess.file_exists(dest.path_join("web_release.zip")))
	_prova("modelli: percorso giusto per Godot (export_templates/%s)" % Esportazione.versione_godot(), Esportazione.cartella_modelli().ends_with("export_templates/" + Esportazione.versione_godot()))
	Esportazione._svuota(dir)

func _fine() -> void:
	print("==== RILASCIO: %d OK, %d FALLITI ====" % [ok, falliti])
	get_tree().quit(0 if falliti == 0 else 1)
