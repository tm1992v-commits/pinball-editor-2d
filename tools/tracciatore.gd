## delle traiettorie da qualsiasi punto, con velocità e forza scelte»). Senza finestra e più veloce del tempo reale:
## lancia la pallina dal punto scelto con la velocità scelta (anche N tiri con una piccola variazione d'angolo) sul
## motore VERO e scrive il percorso, la velocità, l'altezza e cosa ha colpito.
## Uso: godot --headless --fixed-fps 60 --path . res://tools/tracciatore.tscn -- --tavolo_file=F --da=X,Y --vel=VX,VY
##      [--tiri=1] [--variazione=GRADI] [--secondi=4] [--livello=0] [--uscita=FILE.json]
extends Node

func _v(testo: String, pred: Vector2) -> Vector2:
	var p := testo.split(",")
	return Vector2(float(p[0]), float(p[1])) if p.size() == 2 else pred

func _ready() -> void:
	_esegui.call_deferred()

func _esegui() -> void:
	await get_tree().process_frame
	var desc := FileTavolo.leggi(Parametri.arg("tavolo_file"))
	var uscita := Parametri.arg("uscita")
	var risultato := {"ok": false, "tiri": []}
	if desc.is_empty():
		risultato["errore"] = "tavolo non leggibile"
		_fine(risultato, uscita)
		return
	var da := _v(Parametri.arg("da"), Vector2(317, 600))
	var vel := _v(Parametri.arg("vel"), Vector2(0, -1500))
	var tiri := maxi(1, int(Parametri.arg("tiri")) if Parametri.arg("tiri") != "" else 1)
	var variazione := deg_to_rad(float(Parametri.arg("variazione")) if Parametri.arg("variazione") != "" else 0.0)
	var secondi := clampf(float(Parametri.arg("secondi")) if Parametri.arg("secondi") != "" else 4.0, 0.5, 20.0)
	var livello := int(Parametri.arg("livello")) if Parametri.arg("livello") != "" else 0
	var t := TavoloFisico.new(desc)
	add_child(t)
	if Parametri.arg("calore") != "":
		await _calore(t, desc, clampf(float(Parametri.arg("calore")), 5.0, 300.0), uscita)
		return
	var eventi: Array = []
	var tempo := [0.0]
	t.evento.connect(func(tipo, id, p): eventi.append([snappedf(tempo[0], 0.01), str(tipo), str(id), snappedf(p.x, 0.1), snappedf(p.y, 0.1)]))
	await get_tree().physics_frame
	var dim: Vector2 = desc.get("dimensioni", Vector2(635, 1240))
	if Parametri.arg("paletta") != "":
		await _ventaglio(t, desc, Parametri.arg("paletta"), maxi(2, int(Parametri.arg("colpi")) if Parametri.arg("colpi") != "" else 5), eventi, tempo, uscita)
		return
	for k in tiri:
		t.togli_tutte()
		for i in 3:
			await get_tree().physics_frame
		eventi.clear()
		tempo[0] = 0.0
		var ang := 0.0 if tiri == 1 else lerpf(-variazione, variazione, float(k) / float(tiri - 1))
		var b := t.genera_pallina(da, vel.rotated(ang))
		b.dal_lancio = 9.0
		if livello > 0:
			b.imposta_livello(livello, t.quota_livello(livello))
		var punti: Array = []
		var fine := "tempo"
		var ferma := 0.0
		var tenuta := 0.0
		for f in int(secondi * 240.0):
			await get_tree().physics_frame
			tempo[0] += 1.0 / 240.0
			if not is_instance_valid(b) or b.is_queued_for_deletion():
				fine = "scarico"
				break
			var pos := b.global_position
			if f % 2 == 0:
				var vv := b.linear_velocity.length() if not b.sul_binario() else absf(b._v)
				punti.append([snappedf(pos.x, 0.1), snappedf(pos.y, 0.1), roundf(vv), snappedf(b.altezza, 0.1)])
			if pos.y > dim.y + 20.0 or pos.x < -30.0 or pos.x > dim.x + 30.0:
				fine = "scarico" if pos.y > dim.y else "fuori"
				break
			if b.tenuta or b.nascosta:
				tenuta += 1.0 / 240.0
				if tenuta > 0.5:
					fine = "buca"
					break
			if not b.sul_binario() and not b.tenuta and b.linear_velocity.length() < 8.0:
				ferma += 1.0 / 240.0
				if ferma > 1.5:
					fine = "ferma"
					break
			else:
				ferma = 0.0
		risultato["tiri"].append({"angolo": snappedf(rad_to_deg(ang), 0.1), "punti": punti, "eventi": eventi.duplicate(), "fine": fine,
			"durata": snappedf(tempo[0], 0.01)})
	risultato["ok"] = true
	_fine(risultato, uscita)

## VENTAGLIO (v0.16): la pallina ferma sulla paletta in N punti (dalla base alla punta), la paletta scatta: dove va
## ogni tiro. Serve a vedere quali bersagli e rampe si prendono dalla paletta.
func _ventaglio(t: TavoloFisico, desc: Dictionary, pid: String, colpi: int, eventi: Array, tempo: Array, uscita: String) -> void:
	var pal: Dictionary = {}
	for p in desc.get("palette", []):
		if str(p.get("id", "")) == pid:
			pal = p
	if pal.is_empty():
		_fine({"ok": false, "errore": "paletta sconosciuta: " + pid}, uscita)
		return
	var r := {"ok": true, "tiri": [], "ventaglio": pid}
	for k in colpi:
		var frac := lerpf(0.2, 0.92, float(k) / float(colpi - 1))
		t.togli_tutte()
		Input.action_release(pal["comando"])
		for i in 30:
			await get_tree().physics_frame
		eventi.clear()
		tempo[0] = 0.0
		var ang: float = t._angoli.x * float(pal["verso"])
		var sp := float(pal.get("spessore", 12.0))
		var L := float(pal["lunghezza"])
		var punto: Vector2 = Vector2(pal["perno"]) + Vector2(L * frac * float(pal["verso"]), 0).rotated(ang) + Vector2(0, -(lerpf(sp, sp * 0.5, frac) + 13.6))
		var b := t.genera_pallina(punto, Vector2.ZERO)
		b.dal_lancio = 9.0
		if int(pal.get("livello", 0)) > 0:
			b.imposta_livello(int(pal["livello"]), t.quota_livello(int(pal["livello"])))
		await get_tree().physics_frame
		Input.action_press(pal["comando"])
		var punti: Array = []
		var fine := "tempo"
		for f in int(2.5 * 240.0):
			await get_tree().physics_frame
			tempo[0] += 1.0 / 240.0
			if f == 72:
				Input.action_release(pal["comando"])
			if not is_instance_valid(b) or b.is_queued_for_deletion():
				fine = "scarico"
				break
			if f % 2 == 0:
				var vv := b.linear_velocity.length() if not b.sul_binario() else absf(b._v)
				punti.append([snappedf(b.global_position.x, 0.1), snappedf(b.global_position.y, 0.1), roundf(vv), snappedf(b.altezza, 0.1)])
			if b.tenuta or b.nascosta:
				fine = "buca"
				break
		Input.action_release(pal["comando"])
		r["tiri"].append({"angolo": snappedf(frac * 100.0, 1.0), "frazione": frac, "punti": punti, "eventi": eventi.duplicate(), "fine": fine, "durata": snappedf(tempo[0], 0.01)})
	_fine(r, uscita)

## MAPPA DI CALORE (v0.16): il tavolo gioca da solo (lancio e palette automatiche) per N secondi; si conta quante
## volte la pallina passa in ogni quadretto di 20 mm (piano principale).
func _calore(t: TavoloFisico, desc: Dictionary, secondi: float, uscita: String) -> void:
	t.autoplay = true
	var celle := {}
	var palline := 0
	for f in int(secondi * 240.0):
		if f % 240 == 0 and t.palline_totali() == 0:
			t.aggiungi_palline(1, true)
			palline += 1
		await get_tree().physics_frame
		if f % 4 != 0:
			continue
		for b in t.palline:
			if is_instance_valid(b) and not b.sul_binario() and not b.nascosta and b.livello == 0:
				var c := Vector2i((b.global_position / 20.0).floor())
				var k := "%d,%d" % [c.x, c.y]
				celle[k] = int(celle.get(k, 0)) + 1
	_fine({"ok": true, "calore": celle, "cella": 20.0, "secondi": secondi, "palline": palline, "tiri": []}, uscita)

func _fine(r: Dictionary, uscita: String) -> void:
	var testo := JSON.stringify(r)
	if uscita != "":
		var f := FileAccess.open(uscita, FileAccess.WRITE)
		if f:
			f.store_string(testo)
	else:
		print("TRACCIA ", testo)
	get_tree().quit()
