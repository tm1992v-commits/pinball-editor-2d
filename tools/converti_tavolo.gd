## Converte un tavolo scritto in GDScript (tavoli/NOME/layout_NOME.gd) in un file JSON del Pinball Editor 2D e
## controlla che, riletto, sia identico. Uso: godot --headless --path . -s res://tools/converti_tavolo.gd -- --tavolo=spazio --file=/percorso/tavolo.json
extends SceneTree

func _init() -> void:
	var tav := "spazio"
	var file := "user://tavolo.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tavolo="):
			tav = a.split("=")[1]
		if a.begins_with("--file="):
			file = a.substr(7)
	var d: Dictionary = load("res://tavoli/%s/layout_%s.gd" % [tav, tav]).descrizione()
	if not d.has("regole"):
		d["regole"] = "res://tavoli/%s/regole_%s.gd" % [tav, tav]
	var err := FileTavolo.salva(d, file)
	var r := FileTavolo.leggi(file)
	print("CONVERTITO ", file, " errore=", err, " identico=", var_to_str(r) == var_to_str(d))
	quit()
