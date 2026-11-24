## Canale dei comandi per l'AI (Pinball Editor 2D v0.1, 23/11/2026): esegue una lista di comandi su un progetto,
## SENZA finestra, salva il progetto e scrive un rapporto. Gli stessi comandi dei pulsanti dell'editor.
## Uso:
##   godot --headless --path editor_app res://editor/comandi_ai.tscn -- --progetto=CARTELLA.pinproj --comandi=FILE.json [--rapporto=FILE.json]
## FILE.json = lista di comandi, es. [{"comando":"aggiungi","tipo":"bumper","pos":[300,400]},{"comando":"salva"}]
## Un progetto che non esiste nasce dal modello indicato nel primo comando {"comando":"nuovo","modello":"base","nome":"..."}.
extends Node

func _ready() -> void:
	var dir := Parametri.arg("progetto")
	var file := Parametri.arg("comandi")
	var rapporto_file := Parametri.arg("rapporto")
	var lista = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	var rapporto := {"progetto": dir, "risultati": [], "ok": true}
	if not lista is Array:
		rapporto["ok"] = false
		rapporto["errore"] = "file dei comandi mancante o non valido: " + file
		_fine(rapporto, rapporto_file)
		return
	var p := ProgettoEditor.new()
	if dir != "" and FileAccess.file_exists(dir.path_join(ProgettoEditor.FILE_TAVOLO)):
		p.apri(dir)
	for c in lista:
		if not c is Dictionary:
			continue
		if c.get("comando") == "salva" and not c.has("cartella"):
			c["cartella"] = dir
		var r := p.esegui(c, "ai")
		rapporto["risultati"].append({"comando": c.get("comando"), "ok": r.get("ok", false), "messaggio": r.get("messaggio", ""),
			"dati": _testo(r)})
		if not r.get("ok", false):
			rapporto["ok"] = false
	if p.cartella == "" and dir != "" and not p.desc.is_empty():
		p.salva(dir)
	rapporto["riassunto"] = p.riassunto()
	rapporto["modifiche_non_salvate"] = p.modificato
	_fine(rapporto, rapporto_file)

func _testo(r: Dictionary):
	var d := {}
	for k in r:
		if k not in ["ok", "messaggio"]:
			d[k] = var_to_str(r[k]) if not (r[k] is String or r[k] is int or r[k] is float) else r[k]
	return d

func _fine(rapporto: Dictionary, file: String) -> void:
	var testo := JSON.stringify(rapporto, "\t")
	if file != "":
		var f := FileAccess.open(file, FileAccess.WRITE)
		f.store_string(testo)
		f.close()
	print("RAPPORTO_AI ", JSON.stringify({"ok": rapporto["ok"], "riassunto": rapporto.get("riassunto", ""), "errore": rapporto.get("errore", "")}))
	get_tree().quit(0 if rapporto["ok"] else 1)
