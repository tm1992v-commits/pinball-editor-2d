## SONDA DEI DIFETTI D2, D3, D4 (Pinball Editor 2D, 24/11/2026), rifatta dallo studio del 23/11 sul motore unico.
##  D2: ogni bersaglio colpito di fronte a 8 velocità × 5 punti della faccia: quanti colpi contano.
##  D4: ogni tratto di muro lungo almeno 30 mm colpito a 3200 mm/s da entrambi i lati × 5 angoli: attraversamenti.
##  D3: paletta sinistra, pallina ferma al 25/50/75/90 % della lunghezza, colpo premuto in 6 istanti diversi:
##      velocità d'uscita (ripetibilità).
## Uso: godot --headless --fixed-fps 60 --path . res://tools/sonda_difetti.tscn [-- --tavolo_file=F] [--solo=d2,d3,d4]
extends Node

var t: TavoloFisico
var desc: Dictionary
var eventi: Array = []

func _ready() -> void:
	_corri.call_deferred()

func _nuovo() -> void:
	if t != null:
		t.togli_tutte()
		t.queue_free()
		await get_tree().process_frame
	t = TavoloFisico.new(desc)
	add_child(t)
	t.evento.connect(func(tipo, id, _p): eventi.append("%s:%s" % [tipo, id]))
	await _passi(2)

func _passi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _corri() -> void:
	await get_tree().process_frame
	desc = FileTavolo.leggi(Parametri.arg("tavolo_file")) if Parametri.arg("tavolo_file") != "" else load("res://tavoli/spazio/layout_spazio.gd").descrizione()
	var solo := Parametri.arg("solo")
	await _nuovo()
	if solo == "" or "d2" in solo:
		await _d2()
	if solo == "" or "d4" in solo:
		await _d4()
	if solo == "" or "d3" in solo:
		await _d3()
	get_tree().quit()

func _d2() -> void:
	var velocita := [100.0, 150.0, 300.0, 500.0, 800.0, 1200.0, 2000.0, 3200.0]
	var contati := {}
	var toccati := {}
	var mancati: Array = []
	for info in desc.get("bersagli", []):
		await _nuovo()
		var n := TavoloFisico.normale_bersaglio(info)
		var lungo := n.orthogonal()
		var mezza := float(Vector2(info["dim"]).x) * 0.5 - 4.0
		for v in velocita:
			for k in 5:
				var off := lungo * lerpf(-mezza, mezza, k / 4.0) * 0.8
				eventi.clear()
				t.bersagli_giu[info["id"]] = false
				t._forme_bersagli[info["id"]].set_deferred("disabled", false)
				t._ultimo_colpo[info["id"]] = -9.0
				await _passi(2)
				var p := t.genera_pallina(Vector2(info["pos"]) + off + n * 45.0, -n * v)
				p.dal_lancio = 9.0
				var tocca := false
				for i in int(240.0 * 0.6):
					await get_tree().physics_frame
					if not is_instance_valid(p):
						break
					# tocca davvero: il bordo della pallina arriva a 1,5 mm dalla faccia del bersaglio (non basta che torni
					# indietro: a 100-150 mm/s la pendenza del tavolo la fa ricadere prima di arrivare)
					var loc: Vector2 = (p.global_position - Vector2(info["pos"])).rotated(-float(info["angolo"]))
					var mezzo: Vector2 = Vector2(info["dim"]) * 0.5
					var dx := maxf(absf(loc.x) - mezzo.x, 0.0)
					var dy := maxf(absf(loc.y) - mezzo.y, 0.0)
					if Vector2(dx, dy).length() < 13.5 + 0.3:
						tocca = true
					if tocca and p.global_position.distance_to(Vector2(info["pos"])) > 60.0:
						break
				var conta := eventi.has("bersaglio:" + str(info["id"]))
				if tocca or conta:
					toccati[v] = int(toccati.get(v, 0)) + 1
					if conta:
						contati[v] = int(contati.get(v, 0)) + 1
					elif mancati.size() < 8:
						mancati.append("%s a %d" % [info["id"], v])
				if is_instance_valid(p):
					t._scarica(p)
	var righe: Array = []
	for v in velocita:
		righe.append("%d mm/s: %d/%d" % [v, int(contati.get(v, 0)), int(toccati.get(v, 0))])
	print("D2 BERSAGLI (colpi che contano / colpi che toccano): ", ", ".join(righe), "  mancati: ", mancati)

func _d4() -> void:
	await _nuovo()
	var prove := 0
	var passate := 0
	var dove: Array = []
	var dim: Vector2 = desc["dimensioni"]
	for m in desc.get("muri", []):
		if bool(m.get("senso_unico", false)):
			continue
		var pts: PackedVector2Array = m["punti"]
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			if a.distance_to(b) < 30.0:
				continue
			var mid := (a + b) * 0.5
			var n := (b - a).orthogonal().normalized()
			for lato in [1.0, -1.0]:
				for ang in [-40.0, -20.0, 0.0, 20.0, 40.0]:
					var dirv: Vector2 = (-n * lato).rotated(deg_to_rad(ang))
					var start: Vector2 = mid - dirv * 45.0
					if start.x < 5 or start.y < 5 or start.x > dim.x - 5 or start.y > dim.y - 5:
						continue
					if _dentro_solido(start, int(m.get("livello", 0))):
						continue                # partirebbe dentro un blocco pieno: non è un tiro possibile
					var p := t.genera_pallina(start, dirv * 3200.0)
					p.dal_lancio = 9.0
					if int(m.get("livello", 0)) > 0:
						p.imposta_livello(int(m["livello"]), t.quota_livello(int(m["livello"])))
					# attraversamento VERO: il percorso della pallina taglia il segmento del muro (non basta finire dall'altra
					# parte della retta: oltre l'estremo di una guida corta si passa davvero)
					var taglia := false
					var prima := start
					for f in 10:
						await get_tree().physics_frame
						if not is_instance_valid(p) or p.sul_binario() or p.nascosta:
							break
						if Geometry2D.segment_intersects_segment(prima, p.global_position, a, b) != null:
							taglia = true
						prima = p.global_position
					if is_instance_valid(p) and not p.sul_binario() and not p.nascosta and not p.tenuta:
						var lato_ora: float = signf((p.global_position - mid).dot(n))
						var dist_seg: float = Geometry2D.get_closest_point_to_segment(p.global_position, a, b).distance_to(p.global_position)
						if taglia and lato_ora != lato and p.livello == int(m.get("livello", 0)):
							passate += 1
							dove.append([str(m.get("id", m["tipo"])), str(m["tipo"]), mid.round(), "da", start.round(), "a", p.global_position.round(), "dist", roundf(dist_seg)])
					prove += 1
					if is_instance_valid(p):
						t._scarica(p)
					await _passi(1)
	print("D4 TUNNEL a 3200 mm/s: %d prove, %d attraversamenti %s" % [prove, passate, str(dove.slice(0, 10))])

func _dentro_solido(p: Vector2, liv: int) -> bool:
	for m in desc.get("muri", []):
		var pts: PackedVector2Array = m["punti"]
		if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.5 and Geometry2D.is_point_in_polygon(p, pts):
			return true
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	q.shape = c
	q.transform = Transform2D(0, p)
	q.collision_mask = Pallina.bit(liv)
	return not get_viewport().world_2d.direct_space_state.intersect_shape(q, 1).is_empty()

func _d3() -> void:
	var pal: Dictionary = {}
	for pi in desc["palette"]:
		if float(pi["verso"]) > 0.0 and int(pi.get("livello", 0)) == 0 and pal.is_empty():
			pal = pi
	if pal.is_empty():
		return
	for frac in [0.25, 0.5, 0.75, 0.9]:
		var vals: Array = []
		for rip in 6:
			await _nuovo()
			var perno: Vector2 = pal["perno"]
			var ang: float = t._angoli.x * float(pal["verso"])
			var sp := float(pal.get("spessore", 12.0))
			var L := float(pal["lunghezza"])
			var spess := lerpf(sp, sp * 0.5, frac)
			var punto: Vector2 = perno + Vector2(L * frac, -(spess + 13.6)).rotated(ang)
			var p := t.genera_pallina(punto, Vector2.ZERO)
			p.dal_lancio = 9.0
			await _passi(2 + rip)
			Input.action_press(pal["comando"])
			var vmax := 0.0
			for i in 30:
				await get_tree().physics_frame
				if is_instance_valid(p):
					vmax = maxf(vmax, p.linear_velocity.length())
			Input.action_release(pal["comando"])
			await _passi(20)
			vals.append(int(vmax))
		var mn: int = vals.min()
		var mx: int = vals.max()
		print("D3 PALETTA %d%%: uscite %s  (scarto %.0f%%)" % [int(frac * 100), str(vals), 100.0 * (mx - mn) / maxf(mn, 1.0)])
