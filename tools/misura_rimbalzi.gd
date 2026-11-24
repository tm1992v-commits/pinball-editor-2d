## MISURA dei rimbalzi (24/11, prima di decidere il «falloff» come VPX): la pallina va dritta contro una parete
## verticale di ogni materiale (e contro un paletto di gomma) a varie velocità; si stampa quanto torna indietro
## (coefficiente = velocità d'uscita / velocità d'arrivo, perpendicolare alla parete).
## Avvio: godot --headless --fixed-fps 60 --path . res://tools/misura_rimbalzi.tscn
extends Node

func _ready() -> void:
	_esegui.call_deferred()

func _desc() -> Dictionary:
	var d := {"nome": "misura", "dimensioni": Vector2(1400, 1000), "campo": 1390.0, "centro_x": 700.0, "raggio_pallina": 13.5}
	d["muri"] = [
		{"id": "scatola", "punti": PackedVector2Array([Vector2(0, 1060), Vector2(0, 0), Vector2(1400, 0), Vector2(1400, 1060)]), "tipo": "legno"},
		{"id": "m_gomma", "punti": PackedVector2Array([Vector2(600, 100), Vector2(600, 260)]), "tipo": "gomma"},
		{"id": "m_metallo", "punti": PackedVector2Array([Vector2(600, 400), Vector2(600, 560)]), "tipo": "metallo"},
		{"id": "m_legno", "punti": PackedVector2Array([Vector2(600, 700), Vector2(600, 860)]), "tipo": "legno"},
	]
	d["elastici"] = [{"id": "paletto", "pos": Vector2(1100, 500), "raggio": 6.0}]
	d["lancio"] = {"pos": Vector2(1398, 3000), "corsia_x": 1397.0}
	d["cancello"] = [Vector2(1395, 0), Vector2(1395, 1)]
	for k in ["palette", "fionde", "bumper", "bersagli", "buche", "passaggi", "rampe", "sensori"]:
		d[k] = []
	d["paletta_angoli"] = Vector2(0.5, -0.5)
	return d

func _esegui() -> void:
	await get_tree().process_frame
	var t := TavoloFisico.new(_desc())
	add_child(t)
	await get_tree().physics_frame
	var bersagli := {"gomma": [Vector2(600, 180), Vector2(1, 0)], "metallo": [Vector2(600, 480), Vector2(1, 0)],
		"legno": [Vector2(600, 780), Vector2(1, 0)], "paletto": [Vector2(1100, 500), Vector2(1, 0)]}
	for nome in bersagli:
		var riga := "%-8s" % nome
		for v in [200.0, 500.0, 1000.0, 2000.0, 3000.0]:
			t.togli_tutte()
			for i in 3:
				await get_tree().physics_frame
			var punto: Vector2 = bersagli[nome][0]
			var dir: Vector2 = bersagli[nome][1]
			var b := t.genera_pallina(punto - dir * 120.0, dir * v)
			var arrivo := 0.0
			var uscita := 0.0
			for i in 240:
				await get_tree().physics_frame
				var vn := b.linear_velocity.dot(dir)
				if uscita == 0.0:
					arrivo = maxf(arrivo, vn)
				if vn < -1.0 and b.global_position.distance_to(punto) > 30.0:
					uscita = -vn
					break
			riga += "  %4.0f→%.2f" % [v, uscita / maxf(arrivo, 1.0)]
		print(riga)
	get_tree().quit()
