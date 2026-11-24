## Caccia alle palline incastrate (21/11/2026): N palline casuali (posizione e velocità) su tutto il tavolo, 5 palline
## alla volta per 8 s. Conta palline ferme (sotto 8 mm/s per oltre 2 s, non tenute in una buca) e palline uscite dal tavolo.
## Uso: godot --headless --fixed-fps 60 --path . res://tools/caccia_incastri.tscn -- --tavolo=spazio --palline=300
extends Node
func _ready() -> void:
	await get_tree().process_frame
	var nome := Parametri.arg("tavolo") if Parametri.arg("tavolo") != "" else str(Parametri.valore("sistema", "tavolo", "spazio"))
	var n := int(Parametri.arg("palline")) if Parametri.arg("palline") != "" else 300
	var desc: Dictionary
	if Parametri.arg("tavolo_file") != "":
		desc = FileTavolo.leggi(Parametri.arg("tavolo_file"))   # Pinball Editor 2D
		nome = "file"
	else:
		desc = load("res://tavoli/%s/layout_%s.gd" % [nome, nome]).descrizione()
	var dim: Vector2 = desc["dimensioni"]
	var ferme := {}
	var fuori := 0
	var interventi := 0
	var fatte := 0
	seed(21112026)
	# v0.13 (Pinball Editor 2D): sui tavoli dell'editor prima si gioca da soli (lancio e palette automatiche) e si
	# segnano le zone dove la pallina ARRIVA DAVVERO; poi le palline di prova nascono solo lì. Così non ci sono più
	# falsi allarmi nelle zone chiuse (es. una corsia dove la pallina entra solo da un kicker).
	var raggiunte := {}
	if nome == "file" and not Parametri.argomenti.has("ovunque"):
		raggiunte = await _zone_raggiunte(desc, 30.0 + n * 0.1)
		print("CACCIA_RAGGIUNTE %d" % raggiunte.size())
		if raggiunte.size() < 30:
			raggiunte = {}               # troppo poco giocato: si torna al metodo di prima
	while fatte < n:
		var t := TavoloFisico.new(desc)
		add_child(t)
		await get_tree().physics_frame
		var palline: Array = []
		var spazio := get_viewport().world_2d.direct_space_state
		for k in 5:
			var p := Vector2.ZERO
			for tentativo in 200:
				p = Vector2(randf_range(20, float(desc["campo"]) - 20), randf_range(40, dim.y * 0.85))
				var q := PhysicsShapeQueryParameters2D.new()
				var c := CircleShape2D.new()
				c.radius = 15.0
				q.shape = c
				q.transform = Transform2D(0, p)
				q.collision_mask = 1
				# fuori dai solidi e fuori dai recinti chiusi (cortile/corpo del castello, zona del Palco rialzato)
				if spazio.intersect_shape(q, 1).is_empty() and not _in_recinto(nome, p) and not _dentro_muro_chiuso(desc, p) \
						and (raggiunte.is_empty() or raggiunte.has(Vector2i((p / 20.0).floor()))):
					break
			var b := t.genera_pallina(p, Vector2.from_angle(randf() * TAU) * randf_range(200, 2400))
			b.dal_lancio = 9.0
			palline.append([b, 0.0, p])
			fatte += 1
		for f in int(8.0 * 240):
			await get_tree().physics_frame
			for e in palline:
				var b = e[0]
				if not is_instance_valid(b):
					continue
				if b.global_position.x < -30 or b.global_position.x > dim.x + 30 or b.global_position.y < -30:
					fuori += 1
					b.queue_free()
					continue
				if not b.tenuta and not b.nascosta and not b.sul_binario() and b.linear_velocity.length() < 8.0:
					e[1] += 1.0 / 240.0
					if e[1] > 2.0:
						var k := str((b.global_position / 10.0).round() * 10.0)
						ferme[k] = int(ferme.get(k, 0)) + 1
						print("CACCIA_FERMA %.0f %.0f" % [b.global_position.x, b.global_position.y])
						e[1] = -999.0
				else:
					e[1] = maxf(e[1], 0.0) if e[1] >= 0.0 else e[1]
					if e[1] >= 0.0:
						e[1] = 0.0
		interventi += int(t.get("incastri")) if t.get("incastri") != null else 0
		for r in t.registro_incastri:
			print("CACCIA_INTERVENTO %s %.0f %.0f" % [r[0], r[1].x, r[1].y])
		t.queue_free()
		await get_tree().process_frame
	print("CACCIA_FINE %d %d %d" % [n, fuori, interventi])
	print("CACCIA %s: %d palline, ferme %s, fuori dal tavolo %d, interventi delle sicurezze %d" % [nome, n, str(ferme), fuori, interventi])
	get_tree().quit()

## Zone chiuse fatte di sole linee (la pallina non può nascerci dentro in gioco).
func _in_recinto(nome: String, p: Vector2) -> bool:
	if nome == "spazio":
		var d: Dictionary = load("res://tavoli/spazio/layout_spazio.gd").descrizione()
		for m in d["muri"]:
			var pts: PackedVector2Array = m["punti"]
			if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.5 and Geometry2D.is_point_in_polygon(p, pts):
				return true
		if p.x < 104.0 and p.y > 590.0 and p.y < 812.0:
			return true
		if p.x < 120.0 and p.y < 120.0 and p.distance_to(Vector2(120, 120)) > 105.0:
			return true
		if p.x > 401.0 and p.y < 230.0 and p.distance_to(Vector2(401, 230)) > 170.0:
			return true
	return false

## Zone raggiunte giocando da soli per `secondi` (tempo di gioco): celle di 20 mm (con le vicine) del piano principale.
func _zone_raggiunte(desc: Dictionary, secondi: float) -> Dictionary:
	var t := TavoloFisico.new(desc)
	add_child(t)
	t.autoplay = true
	await get_tree().physics_frame
	var celle := {}
	for f in int(secondi * 240.0):
		if f % 240 == 0 and t.palline_totali() == 0:
			t.aggiungi_palline(1, true)
		await get_tree().physics_frame
		if f % 4 != 0:
			continue
		for b in t.palline:
			if is_instance_valid(b) and not b.sul_binario() and not b.nascosta and b.livello == 0:
				var c := Vector2i((b.global_position / 20.0).floor())
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						celle[c + Vector2i(dx, dy)] = true
	t.queue_free()
	await get_tree().process_frame
	return celle

## Tavoli dell'editor: dentro un muro chiuso (primo punto = ultimo) la pallina non può nascere.
func _dentro_muro_chiuso(desc: Dictionary, p: Vector2) -> bool:
	for m in desc.get("muri", []):
		var pts: PackedVector2Array = m["punti"]
		if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.5 and Geometry2D.is_point_in_polygon(p, pts):
			return true
	return false
