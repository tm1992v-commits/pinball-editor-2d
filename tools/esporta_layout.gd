## Esporta il disegno di un tavolo in JSON (per il disegno dall'alto di controllo, tools/disegna_layout.py).
## Avvio: godot --headless --path . -s res://tools/esporta_layout.gd -- --tavolo=spazio --file=/percorso/layout.json
extends SceneTree

func _converti(v):
	if v is Vector2:
		return [v.x, v.y]
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Color:
		return [v.r, v.g, v.b]
	if v is PackedVector2Array or v is Array:
		var out := []
		for x in v:
			out.append(_converti(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = _converti(v[k])
		return out
	return v

func _init() -> void:
	var tav := "spazio"
	var file := "user://layout.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tavolo="):
			tav = a.split("=")[1]
		if a.begins_with("--file="):
			file = a.split("=")[1]
	var d: Dictionary = load("res://tavoli/%s/layout_%s.gd" % [tav, tav]).descrizione()
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(JSON.stringify(_converti(d)))
	f.close()
	print("ESPORTATO ", file)
	quit()
