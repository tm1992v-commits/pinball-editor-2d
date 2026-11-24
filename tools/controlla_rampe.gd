## Controllo geometrico (21/11/2026): elementi del tavolo che stanno dentro il tratto basso e solido di una rampa
## (non raggiungibili) o troppo vicini alle sue pareti (fessure tra 20 e 36 mm, dove la pallina si incastra).
## Uso: godot --headless --path . res://tools/controlla_rampe.tscn -- --tavolo=spazio
extends Node
func _ready() -> void:
	var nome := "spazio"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tavolo="):
			nome = a.substr(9)
	var desc: Dictionary = load("res://tavoli/%s/layout_%s.gd" % [nome, nome]).descrizione()
	var t := TavoloFisico.new(desc)
	add_child(t)
	await get_tree().physics_frame
	var problemi := 0
	var punti: Array = []
	for b in desc.get("bersagli", []): punti.append(["bersaglio " + b["id"], b["pos"], _liv(b)])
	for b in desc.get("sensori", []): punti.append(["sensore " + b["id"], b["pos"], _liv(b)])
	for b in desc.get("buche", []): punti.append(["buca " + b["id"], b["pos"], _liv(b)])
	for b in desc.get("bumper", []): punti.append(["bumper " + b["id"], b["pos"], _liv(b)])
	for b in desc.get("spinner", []): punti.append(["spinner " + b["id"], b["pos"], _liv(b)])
	for b in desc.get("bersagli_mobili", []): punti.append(["mobile " + b["id"], (b["da"] + b["a"]) * 0.5, _liv(b)])
	for k in desc.get("kickback", []) if desc.get("kickback") is Array else [desc.get("kickback", {})]:
		if k.has("pos"): punti.append(["kickback", k["pos"], 0])
	for pr in t.pareti_rampe:
		var linee: Array = pr[2]
		var sx: PackedVector2Array = linee[0]
		var dx: PackedVector2Array = linee[1]
		var poly := PackedVector2Array(sx)
		var rov := PackedVector2Array(dx)
		rov.reverse()
		poly.append_array(rov)
		print("RAMPA %s (livello %d): tratto solido da %s a %s" % [pr[0], pr[1], ((sx[0] + dx[0]) * 0.5).round(), ((sx[sx.size() - 1] + dx[dx.size() - 1]) * 0.5).round()])
		for p in punti:
			if p[2] != pr[1]:
				continue
			if Geometry2D.is_point_in_polygon(p[1], poly):
				print("   DENTRO: ", p[0], " ", p[1])
				problemi += 1
	print("CONTROLLO RAMPE %s: %d elementi dentro i tratti solidi" % [nome, problemi])
	get_tree().quit()

func _liv(i: Dictionary) -> int:
	return int(i.get("livello", 0))
