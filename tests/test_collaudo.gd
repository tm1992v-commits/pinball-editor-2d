## della libreria controlla che
##   1) si CREI (comando «aggiungi», lo stesso del clic nell'editor);
##   2) si VEDA davvero, nell'EDITOR e nel GIOCO (disegnato in una finestra vera: si contano i pixel cambiati rispetto
##      al tavolo senza il pezzo), in 3D e piatto, e che ogni BORDO (semplice, rilievo, neon) e l'intensità cambino il
##      disegno; anche la LUCE AMBIENTALE del tavolo;
##   3) FUNZIONI nel motore: una pallina tirata contro il pezzo produce l'effetto giusto (evento, rimbalzo, attrazione,
##      oppure passa sopra senza toccarlo per le immagini e le luci);
##      (aperta e chiusa davvero), senza errori e con il valore applicato.
## Ogni errore è segnalato con il nome del pezzo e la prova. Serve una finestra (non --headless):
##   godot --path . res://tests/test_collaudo.tscn
extends Node

var ok := 0
var falliti: Array[String] = []
var eventi: Array = []
var _img_prova := ""

const POS := Vector2(300, 520)

func _ready() -> void:
	_esegui.call_deferred()

func _prova(cond: bool, nome: String) -> void:
	if cond:
		ok += 1
		print("OK       ", nome)
	else:
		falliti.append(nome)
		print("FALLITO  ", nome)

func _esegui() -> void:
	await get_tree().process_frame
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.2, 0.8))
	_img_prova = ProjectSettings.globalize_path("user://collaudo_immagine.png")
	img.save_png(_img_prova)
	await _creazione_e_vista()
	await _giocattoli()
	await _bordi_e_luci()
	await _funzioni()
	await _pannello()
	print("\n==== COLLAUDO: %d OK, %d FALLITI ====" % [ok, falliti.size()])
	for f in falliti:
		print("  FALLITO: ", f)
	get_tree().quit(0 if falliti.is_empty() else 1)

# ================================================================ aiuti
## Progetto nuovo con un solo pezzo del tipo dato (al centro). Restituisce [progetto, id] (id "" se non creato).
func _progetto_con(k: String, extra := {}) -> Array:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Collaudo"})
	if k == "":
		return [p, ""]
	var c := {"comando": "aggiungi", "tipo": k, "pos": [POS.x, POS.y]}
	match k:
		"muri":
			c["punti"] = [[POS.x - 100, POS.y], [POS.x + 100, POS.y]]
		"rampe":
			c["punti"] = [[POS.x, POS.y + 180], [POS.x, POS.y], [POS.x, POS.y - 150]]
		"nastri":
			c["punti"] = [[POS.x - 30, POS.y + 150], [POS.x - 30, POS.y - 100]]
		"decorazioni":
			c["file"] = _img_prova
	var r := p.esegui(c)
	if not r.get("ok", false):
		return [p, ""]
	for campo in extra:
		p.esegui({"comando": "imposta", "id": r["id"], "campo": campo, "valore": extra[campo]})
	return [p, str(r["id"])]

## Disegno dell'EDITOR in una finestra vera (400 × 800 px, tavolo intero).
func _foto_editor(p: ProgettoEditor) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 800)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var v := VistaTavolo.new()
	v.progetto = p
	v.size = Vector2(400, 800)
	vp.add_child(v)
	v.griglia = false
	v.adatta()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var im := vp.get_texture().get_image()
	vp.queue_free()
	return im

## Disegno del GIOCO (stessa strada di GIOCA: file di prova → motore + regole + grafica), in una finestra vera.
func _foto_gioco(p: ProgettoEditor) -> Image:
	var f := ProjectSettings.globalize_path("user://collaudo.tavolo")
	p.salva_prova(f)
	var d := FileTavolo.leggi(f)
	d["luci"] = FileTavolo.LUCI_BASE
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 760)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var t := TavoloFisico.new(d)
	vp.add_child(t)
	var r: RegoleBase = load(str(d.get("regole", FileTavolo.REGOLE_BASE))).new()
	vp.add_child(r)
	r.salva_record = false
	r.collega(t)
	var vista := Vista2D.new()
	vp.add_child(vista)
	vista.prepara(d, t, r)
	for i in 12:
		await RenderingServer.frame_post_draw
	var im := vp.get_texture().get_image()
	vp.queue_free()
	return im

## v0.18.1: GIOCATTOLI. Un'immagine che reagisce al bumper e una che gira sempre, nel gioco vero.
func _giocattoli() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Giocattoli"})
	var rb := p.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [317, 300]})
	var r1 := p.esegui({"comando": "aggiungi", "tipo": "decorazioni", "pos": [200, 500]})
	var r2 := p.esegui({"comando": "aggiungi", "tipo": "decorazioni", "pos": [430, 500]})
	for r in [r1, r2]:
		p.esegui({"comando": "immagine", "id": r["id"], "file": _img_prova})
	p.esegui({"comando": "imposta", "id": r1["id"], "campo": "reagisce", "valore": "bumper"})
	p.esegui({"comando": "imposta", "id": r1["id"], "campo": "anim", "valore": "salta"})
	p.esegui({"comando": "imposta", "id": r2["id"], "campo": "sempre", "valore": "gira"})
	var f := ProjectSettings.globalize_path("user://collaudo_giochi.tavolo")
	p.salva_prova(f)
	var d := FileTavolo.leggi(f)
	d["luci"] = FileTavolo.LUCI_BASE
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 760)
	add_child(vp)
	var t := TavoloFisico.new(d)
	vp.add_child(t)
	var r: RegoleBase = load(str(d.get("regole", FileTavolo.REGOLE_BASE))).new()
	vp.add_child(r)
	r.salva_record = false
	r.collega(t)
	var vista := Vista2D.new()
	vp.add_child(vista)
	vista.prepara(d, t, r)
	await get_tree().process_frame
	_prova(vista._giochi.size() == 2, "giocattoli: due immagini che si muovono nel gioco")
	var rot0: float = vista._giochi[1][0].rotation
	await get_tree().create_timer(0.3).timeout
	_prova(absf(vista._giochi[1][0].rotation - rot0) > 0.1, "giocattoli: quello «gira piano» gira")
	t.evento.emit("bumper", str(rb["id"]), Vector2(317, 300))
	await get_tree().process_frame
	_prova(vista.giocattoli_in_moto() == 1, "giocattoli: colpito il bumper, salta solo quello che aspetta il bumper")
	vp.queue_free()

## Quanti pixel sono diversi tra due immagini (differenza sensibile in un canale qualsiasi).
func _diversi(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.08:
				n += 1
	return n

# ================================================================ 1 e 2: si crea e si vede
func _creazione_e_vista() -> void:
	var vuoto: ProgettoEditor = _progetto_con("")[0]
	var ed0 := await _foto_editor(vuoto)
	var gi0 := await _foto_gioco(vuoto)
	for k in SchedeEditor.ORDINE:
		var pi := _progetto_con(k)
		var p: ProgettoEditor = pi[0]
		var id: String = pi[1]
		_prova(id != "" and p.trova(id).size() == 2, "%s: si crea" % k)
		if id == "":
			continue
		var de := _diversi(ed0, await _foto_editor(p))
		_prova(de > 6, "%s: si vede nell'editor (%d punti cambiati)" % [k, de])
		var dg := _diversi(gi0, await _foto_gioco(p))
		if k == "sensori":
			_prova(dg >= 0, "%s: nel gioco è invisibile (interruttore sotto il piano), %d punti" % [k, dg])
		else:
			_prova(dg > 6, "%s: si vede nel gioco (%d punti cambiati)" % [k, dg])
		if k in PittorePezzi.TIPI:
			var piatto := _progetto_con(k, {"aspetto": "piatto"})
			var dp := _diversi(await _foto_editor(p), await _foto_editor(piatto[0]))
			_prova(dp > 3, "%s: 3D e piatto si vedono diversi (%d punti)" % [k, dp])

# ================================================================ bordi, intensità, luce ambientale
func _bordi_e_luci() -> void:
	for k in PittorePezzi.TIPI:
		var base_img := await _foto_editor(_progetto_con(k)[0])
		for b in ["semplice", "rilievo", "neon"]:
			var pb := _progetto_con(k, {"bordo": b})
			var e: Dictionary = pb[0].pezzo(pb[1])
			var d := _diversi(base_img, await _foto_editor(pb[0]))
			_prova(str(e.get("bordo", "")) == b and d > 3, "%s: bordo «%s» impostato e visibile (%d punti)" % [k, b, d])
		var n1 := await _foto_editor(_progetto_con(k, {"bordo": "neon"})[0])
		var n2 := await _foto_editor(_progetto_con(k, {"bordo": "neon", "intensita_bordo": 2.5, "colore_bordo": [1, 0.1, 0.1, 1]})[0])
		_prova(_diversi(n1, n2) > 3, "%s: neon, colore e intensità cambiano il disegno" % k)
		var tolto := _progetto_con(k, {"bordo": "neon"})
		tolto[0].esegui({"comando": "imposta", "id": tolto[1], "campo": "bordo", "valore": ""})
		_prova(not tolto[0].pezzo(tolto[1]).has("bordo"), "%s: bordo tolto («nessuno»)" % k)
	# neon lungo la sponda (la parete laterale del flipper), anche nel gioco
	var ps := _progetto_con("")
	var g0 := await _foto_gioco(ps[0])
	ps[0].esegui({"comando": "imposta", "id": "sponda", "campo": "bordo", "valore": "neon"})
	ps[0].esegui({"comando": "imposta", "id": "sponda", "campo": "colore_bordo", "valore": [0.1, 1.0, 0.9, 1]})
	var dn := _diversi(g0, await _foto_gioco(ps[0]))
	_prova(dn > 50, "sponda: striscia neon lungo la parete, visibile nel gioco (%d punti)" % dn)
	# luce ambientale
	var pl := _progetto_con("bumper")
	var e0 := await _foto_editor(pl[0])
	var l0 := await _foto_gioco(pl[0])
	for da in ["alto", "basso", "lati", "ovunque"]:
		pl[0].esegui({"comando": "imposta_tavolo", "campo": "luce_da", "valore": da})
		pl[0].esegui({"comando": "imposta_tavolo", "campo": "luce_colore", "valore": [1.0, 0.3, 0.8, 1]})
		pl[0].esegui({"comando": "imposta_tavolo", "campo": "luce_intensita", "valore": 0.8})
		var de := _diversi(e0, await _foto_editor(pl[0]))
		var dg := _diversi(l0, await _foto_gioco(pl[0]))
		_prova(de > 50 and dg > 50, "luce ambientale «%s»: visibile nell'editor (%d) e nel gioco (%d)" % [da, de, dg])
	pl[0].esegui({"comando": "imposta_tavolo", "campo": "luce_da", "valore": "spenta"})
	_prova(PittorePezzi.luce_ambiente(pl[0].desc).is_empty(), "luce ambientale: si spegne")
	var r_err: Dictionary = pl[0].esegui({"comando": "imposta_tavolo", "campo": "luce_da", "valore": "sbagliato"})
	_prova(not r_err["ok"], "luce ambientale: valore sbagliato rifiutato con un messaggio")
	# luci del piano: ogni forma ha la sua sagoma e si vede diversa dal tondo
	var tondo := await _foto_editor(_progetto_con("inserti", {"dim": [30, 30]})[0])
	for fo in PittorePezzi.FORME_LUCE:
		if fo == "tondo":
			continue
		var df := _diversi(tondo, await _foto_editor(_progetto_con("inserti", {"dim": [30, 30], "forma": fo})[0]))
		_prova(df > 3, "luce «%s»: forma visibile e diversa dal tondo (%d punti)" % [fo, df])

# ================================================================ 3: funziona nel motore
func _funzioni() -> void:
	for k in SchedeEditor.ORDINE:
		var pi := _progetto_con(k)
		if pi[1] == "":
			continue
		var p: ProgettoEditor = pi[0]
		var e: Dictionary = p.pezzo(pi[1])
		var f := ProjectSettings.globalize_path("user://collaudo_f.tavolo")
		p.salva_prova(f)
		var d := FileTavolo.leggi(f)
		var t := TavoloFisico.new(d)
		add_child(t)
		eventi.clear()
		t.evento.connect(func(tipo, id, _q): eventi.append(tipo + ":" + id))
		await get_tree().physics_frame
		var esito := ""
		match k:
			"bumper", "elastici", "bersagli", "spinner", "cancelli":
				t.genera_pallina(POS + Vector2(0, 70), Vector2(0, -1000))
				var nome_ev: String = {"bumper": "bumper", "elastici": "elastico", "bersagli": "bersaglio", "spinner": "spinner", "cancelli": "cancello"}[k]
				esito = "evento «%s»" % nome_ev if await _aspetta(nome_ev + ":" + pi[1]) else "NESSUN evento «%s»" % nome_ev
				_prova(esito.begins_with("evento"), "%s: la pallina lo colpisce → %s" % [k, esito])
			"buche":
				t.genera_pallina(POS + Vector2(0, 40), Vector2(0, -250))
				var presa := await _aspetta("buca:" + pi[1])
				_prova(presa, "buche: la pallina entra nella buca")
			"sensori":
				t.genera_pallina(POS + Vector2(0, -60), Vector2(0, 700))
				_prova(await _aspetta("sensore:" + pi[1]), "sensori: la pallina che passa viene contata")
			"kickback":
				t.genera_pallina(POS + Vector2(0, -60), Vector2(0, 700))
				_prova(await _aspetta("kickback:" + pi[1]), "kickback: la pallina viene rimandata su")
			"fionde":
				var pts: Array = e["punti"]
				var a: Vector2 = pts[0]
				var b: Vector2 = pts[pts.size() - 1]
				var cen := (Vector2(pts[0]) + Vector2(pts[1]) + Vector2(pts[2])) / 3.0
				var nrm := (b - a).orthogonal().normalized()
				if nrm.dot((a + b) * 0.5 - cen) < 0.0:
					nrm = -nrm
				t.genera_pallina((a + b) * 0.5 + nrm * 45.0, -nrm * 900.0)
				_prova(await _aspetta("fionda:" + pi[1]), "fionde: la faccia di gomma spara la pallina")
			"muri":
				var bm := t.genera_pallina(POS + Vector2(0, 70), Vector2(0, -1000))
				await _passi(60)
				_prova(bm.global_position.y > POS.y, "muri: la pallina rimbalza (non passa)")
			"rampe":
				t.genera_pallina(POS + Vector2(0, 230), Vector2(0, -1700))
				_prova(await _aspetta("rampa_entrata:" + pi[1]), "rampe: la pallina entra nella rampa")
				t.queue_free()
				await _scenari_rampe_collegate()
				continue
			"nastri":
				var pareti: Array = d["muri"].filter(func(m): return str(m.get("da_nastro", "")) == pi[1])
				_prova(pareti.size() == 2, "nastri: il nastro a terra ha le sue due pareti nel motore")
			"campi":
				var bc := t.genera_pallina(POS + Vector2(45, 30), Vector2(0, -150))
				await _passi(60)
				_prova(bc.global_position.x < POS.x + 40.0, "campi: il pozzo attira la pallina")
			"palette":
				_prova(t.palette.has(pi[1]), "palette: la paletta esiste nel motore")
			"piani":
				t.queue_free()
				await _scenari_piano(p, pi[1])
				continue
			"inserti", "decorazioni":
				var bp := t.genera_pallina(POS + Vector2(0, 70), Vector2(0, -900))
				await _passi(30)
				_prova(bp.global_position.y < POS.y - 20.0, "%s: la pallina ci passa sopra (non tocca la fisica)" % k)
		t.queue_free()
		await get_tree().physics_frame

## Rampe collegate (v0.9.2): una prosegue nell'altra; due che partono dallo stesso punto = deviatore che alterna.
func _scenari_rampe_collegate() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Rampe"})
	var r1 := p.esegui({"comando": "aggiungi", "tipo": "rampe", "punti": [[300, 900], [300, 700], [300, 500]], "resta_alta": true})
	var r2 := p.esegui({"comando": "aggiungi", "tipo": "rampe", "punti": [[300, 500], [220, 420], [140, 600]]})
	_prova(p.pezzo(r1["id"]).get("prosegue_in", "") == r2["id"] and float(p.pezzo(r2["id"])["punti"][0].z) > 5.0, "rampe collegate: la seconda prosegue la prima (parte in alto)")
	var r3 := p.esegui({"comando": "aggiungi", "tipo": "rampe", "punti": [[300, 500], [380, 420], [460, 600]]})
	_prova(p.desc.get("deviatori", []).size() == 1 and not p.pezzo(r1["id"]).has("prosegue_in"), "rampe collegate: con due rampe nasce il deviatore")
	var f := ProjectSettings.globalize_path("user://collaudo_rampe.tavolo")
	p.salva_prova(f)
	var t := TavoloFisico.new(FileTavolo.leggi(f))
	add_child(t)
	eventi.clear()
	t.evento.connect(func(tipo, eid, _q): eventi.append(tipo + ":" + eid))
	await get_tree().physics_frame
	t.genera_pallina(Vector2(300, 950), Vector2(0, -2300))
	var prima := await _aspetta("rampa:" + r2["id"], 4.0) or await _aspetta("rampa:" + r3["id"], 0.1)
	var strada1 := "r2" if eventi.has("rampa:" + r2["id"]) else "r3"
	t.togli_tutte()
	eventi.clear()
	await _passi(5)
	t.genera_pallina(Vector2(300, 950), Vector2(0, -2300))
	var seconda := await _aspetta("rampa:" + r2["id"], 4.0) or await _aspetta("rampa:" + r3["id"], 0.1)
	var strada2 := "r2" if eventi.has("rampa:" + r2["id"]) else "r3"
	_prova(prima and seconda and strada1 != strada2, "rampe collegate: il deviatore manda la pallina una volta per strada (%s poi %s)" % [strada1, strada2])
	t.queue_free()
	await get_tree().physics_frame
	p.esegui({"comando": "sposta", "id": r3["id"], "di": [0, 200]})
	_prova(p.desc.get("deviatori", []).is_empty() and p.pezzo(r1["id"]).get("prosegue_in", "") == r2["id"] and float(p.pezzo(r3["id"])["punti"][0].z) == 0.0, "rampe collegate: spostando via una rampa il deviatore sparisce e lei torna a terra")

func _scenari_piano(p: ProgettoEditor, id: String) -> void:
	var n := int(p.pezzo(id).get("livello", 0))
	_prova(n > 0 and p.desc.get("livelli", {}).has(n), "piani: il piano diventa un livello del motore (livello %d)" % n)
	# pezzi dentro la forma: sul piano da soli; fuori: sul tavolo
	var rb := p.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [POS.x - 50, POS.y]})
	var rf := p.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [POS.x, POS.y + 300]})
	_prova(int(p.pezzo(rb["id"]).get("livello", 0)) == n and int(p.pezzo(rf["id"]).get("livello", 0)) == 0, "piani: il bumper dentro il piano ci sale da solo, quello fuori resta sul tavolo")
	p.esegui({"comando": "sposta", "id": rb["id"], "pos": [POS.x - 50, POS.y + 250]})
	_prova(int(p.pezzo(rb["id"]).get("livello", 0)) == 0, "piani: spostato fuori dal piano, il bumper torna sul tavolo")
	p.esegui({"comando": "sposta", "id": rb["id"], "pos": [POS.x - 50, POS.y]})
	# rampa che finisce sul piano, buca che manda su, buca sul piano che manda giù
	var rr := p.esegui({"comando": "aggiungi", "tipo": "rampe", "punti": [[POS.x + 60, POS.y + 420], [POS.x + 60, POS.y + 200], [POS.x + 60, POS.y + 30]]})
	var bs := p.esegui({"comando": "aggiungi", "tipo": "buche", "pos": [POS.x - 150, POS.y + 330], "valori": {"tipo": "passaggio", "uscita": [POS.x + 30, POS.y - 20], "uscita_dir": [0, -1], "uscita_vel": 200}})
	var bg := p.esegui({"comando": "aggiungi", "tipo": "buche", "pos": [POS.x + 50, POS.y - 40], "valori": {"tipo": "passaggio", "uscita": [POS.x - 150, POS.y + 380], "uscita_dir": [0, 1], "uscita_vel": 200}})
	_prova(int(p.pezzo(rr["id"]).get("livello_fine", 0)) == n, "piani: la rampa che finisce dentro il piano porta sul piano")
	_prova(int(p.pezzo(bg["id"]).get("livello", 0)) == n, "piani: la buca dentro il piano è sul piano")
	var f := ProjectSettings.globalize_path("user://collaudo_piano.tavolo")
	p.salva_prova(f)
	var d := FileTavolo.leggi(f)
	var t := TavoloFisico.new(d)
	add_child(t)
	eventi.clear()
	t.evento.connect(func(tipo, eid, _q): eventi.append(tipo + ":" + eid))
	await get_tree().physics_frame
	# 1) su dalla rampa
	var b1 := t.genera_pallina(Vector2(POS.x + 60, POS.y + 470), Vector2(0, -2200))
	await _passi(150)
	_prova(b1.livello == n, "piani: la pallina sale dalla RAMPA e arriva sul piano")
	t.togli_tutte()
	await _passi(3)
	# 2) sul piano colpisce il bumper del piano; un bumper del tavolo sotto non lo tocca
	var b2 := t.genera_pallina(Vector2(POS.x - 50, POS.y + 50), Vector2(0, -600))
	b2.imposta_livello(n, t.quota_livello(n))
	_prova(await _aspetta("bumper:" + rb["id"]), "piani: sul piano la pallina colpisce il bumper del piano")
	t.togli_tutte()
	await _passi(3)
	# 3) su dalla buca
	var b3 := t.genera_pallina(Vector2(POS.x - 150, POS.y + 300), Vector2(0, 150))
	var entrata := await _aspetta("passaggio_entrata:" + bs["id"], 2.0)
	var uscita := await _aspetta("passaggio_uscita:" + bs["id"] + "@via", 2.0)
	await _passi(3)
	_prova(entrata and uscita and b3.livello == n, "piani: la pallina sale dalla BUCA e riappare sul piano")
	t.togli_tutte()
	await _passi(3)
	# 4) giù dalla buca del piano
	var b4 := t.genera_pallina(Vector2(POS.x + 50, POS.y - 10), Vector2(0, -150))
	b4.imposta_livello(n, t.quota_livello(n))
	var giu := await _aspetta("passaggio_uscita:" + bg["id"] + "@via", 2.5)
	await _passi(3)
	_prova(giu and b4.livello == 0, "piani: dalla buca del piano la pallina scende sul tavolo")
	t.togli_tutte()
	await _passi(3)
	# 5) bordo chiuso: resta sul piano
	var b5 := t.genera_pallina(Vector2(POS.x - 60, POS.y + 40), Vector2(-900, 300))
	b5.imposta_livello(n, t.quota_livello(n))
	await _passi(90)
	_prova(b5.livello == n and Geometry2D.is_point_in_polygon(b5.global_position, PackedVector2Array(d["livelli"][n]["zona"])), "piani: col bordo chiuso la pallina resta sul piano")
	t.queue_free()
	await get_tree().physics_frame
	# 6) bordo aperto: cade giù
	p.esegui({"comando": "imposta", "id": id, "campo": "bordo_aperto", "valore": true})
	p.salva_prova(f)
	var d2 := FileTavolo.leggi(f)
	var t2 := TavoloFisico.new(d2)
	add_child(t2)
	eventi.clear()
	t2.evento.connect(func(tipo, eid, _q): eventi.append(tipo + ":" + eid))
	await get_tree().physics_frame
	var b6 := t2.genera_pallina(Vector2(POS.x - 60, POS.y + 40), Vector2(-900, 300))
	b6.imposta_livello(n, t2.quota_livello(n))
	await _passi(90)
	_prova(b6.livello == 0 and eventi.any(func(x): return str(x).begins_with("caduta_piano")), "piani: col bordo aperto la pallina cade giù sul tavolo")
	t2.queue_free()
	await get_tree().physics_frame

func _aspetta(ev: String, max_s := 1.5) -> bool:
	for i in int(max_s * 60.0):
		if eventi.has(ev):
			return true
		await get_tree().physics_frame
	return eventi.has(ev)

func _passi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _pannello() -> void:
	var ed: Node = load("res://editor/editor.tscn").instantiate()
	add_child(ed)
	await get_tree().process_frame
	for k in SchedeEditor.ORDINE:
		ed.progetto.esegui({"comando": "nuovo", "modello": "base", "nome": "Collaudo"})
		var pi := _progetto_con(k)
		if pi[1] == "":
			continue
		ed.progetto.desc = pi[0].desc
		var id: String = pi[1]
		ed.vista.seleziona(id)
		ed._ricostruisci_pannello = true
		ed._aggiorna_pannello()
		await get_tree().process_frame
		# ogni scelta: si provano tutte le voci
		var scelte: Array = ed._pannello.find_children("*", "OptionButton", true, false)
		var n_scelte := 0
		for ob in scelte:
			if not is_instance_valid(ob):
				continue
			for i in ob.item_count:
				if is_instance_valid(ob):
					ob.select(i)
					ob.item_selected.emit(i)
					n_scelte += 1
					await get_tree().process_frame
		ed.vista.seleziona(id)
		ed._ricostruisci_pannello = true
		ed._aggiorna_pannello()
		await get_tree().process_frame
		# ogni casella
		for cb in ed._pannello.find_children("*", "CheckBox", true, false):
			if is_instance_valid(cb):
				cb.button_pressed = not cb.button_pressed
				await get_tree().process_frame
		# il bordo neon per far comparire colore e intensità del bordo, poi la tavolozza di ogni colore
		if k in PittorePezzi.TIPI:
			ed.progetto.esegui({"comando": "imposta", "id": id, "campo": "bordo", "valore": "neon"})
		ed.vista.seleziona(id)
		ed._ricostruisci_pannello = true
		ed._aggiorna_pannello()
		await get_tree().process_frame
		var bottoni: Array = ed._pannello.find_children("*", "ColorPickerButton", true, false)
		var n_colori := 0
		var applicati := true
		for i in bottoni.size():
			var tutti: Array = ed._pannello.find_children("*", "ColorPickerButton", true, false)
			if i >= tutti.size():
				break
			var b: ColorPickerButton = tutti[i]
			var nuovo := Color(0.2, 0.9, 0.4) if i % 2 == 0 else Color(0.9, 0.3, 0.1)
			var pop: PopupPanel = b.get_popup()
			pop.popup_centered()
			await get_tree().process_frame
			b.color = nuovo
			pop.hide()
			await get_tree().process_frame
			await get_tree().process_frame
			n_colori += 1
			var e2: Dictionary = ed.progetto.pezzo(id)
			var trovato := false
			for campo in ["colore", "colore_2", "colore_bordo"]:
				if e2.get(campo) is Color and (e2[campo] as Color).is_equal_approx(nuovo):
					trovato = true
			applicati = applicati and trovato
		_prova(is_instance_valid(ed) and ed.progetto.trova(id).size() == 2, "%s: pannello: %d scelte, caselle e %d colori usati senza errori" % [k, n_scelte, n_colori])
		if n_colori > 0:
			_prova(applicati, "%s: ogni colore scelto nella tavolozza è applicato al pezzo" % k)
	# pannello del TAVOLO: colori, luce ambientale
	ed.progetto.esegui({"comando": "nuovo", "modello": "base", "nome": "Collaudo"})
	ed.vista.seleziona("")
	ed._ricostruisci_pannello = true
	ed._aggiorna_pannello()
	await get_tree().process_frame
	for ob in ed._pannello.find_children("*", "OptionButton", true, false):
		if is_instance_valid(ob) and ob.item_count == 5:
			ob.select(1)
			ob.item_selected.emit(1)          # luce ambientale dall'alto
			await get_tree().process_frame
			await get_tree().process_frame
	var cbt: Array = ed._pannello.find_children("*", "ColorPickerButton", true, false)
	for b in cbt:
		if is_instance_valid(b):
			b.get_popup().popup_centered()
			await get_tree().process_frame
			b.color = Color(0.3, 0.3, 0.9)
			b.get_popup().hide()
			await get_tree().process_frame
			await get_tree().process_frame
	_prova(is_instance_valid(ed) and not PittorePezzi.luce_ambiente(ed.progetto.desc).is_empty(), "tavolo: pannello con luce ambientale e %d colori usati senza errori" % cbt.size())
	# v0.17/v0.17.2: scheda Suoni e luci (spettacoli), pannello LICENZE e collezione con evoluzione
	ed.progetto.esegui({"comando": "spettacolo", "azione": "pronto", "da": "Festa"})
	ed._lista_regia.get_parent().get_parent().current_tab = ed._lista_regia.get_parent().get_index()
	ed._aggiorna_regia()
	await get_tree().process_frame
	for b in ed._lista_regia.find_children("*", "Button", true, false):
		if is_instance_valid(b) and b.text == "+ passo":
			b.pressed.emit()
			break
	await get_tree().process_frame
	await get_tree().process_frame
	_prova(is_instance_valid(ed) and ed.progetto.desc["spettacoli"]["Festa"]["passi"].size() == 5, "suoni e luci: spettacolo copiato e passo aggiunto dal pannello")
	ed._apri_licenze(true)
	await get_tree().process_frame
	_prova(is_instance_valid(ed) and ed._pannello.find_children("*", "Button", true, false).any(func(b): return b.text.begins_with("Scrivi il registro")), "licenze: il pannello si apre")
	ed._apri_licenze(false)
	ed.progetto.esegui({"comando": "missione_aggiungi"})
	ed.progetto.esegui({"comando": "missione_aggiungi"})
	ed._apri_schema()
	await get_tree().process_frame
	_prova(is_instance_valid(ed._schema) and ed._schema.visible, "schema delle missioni: si apre")
	ed._schema.queue_free()
	ed._apri_libreria_elementi()
	await get_tree().process_frame
	_prova(is_instance_valid(ed._finestra_lib) and ed._finestra_lib.visible, "I miei elementi: la finestra si apre")
	ed._finestra_lib.queue_free()
	ed.vista.mostra_collisioni = true
	ed.vista.queue_redraw()
	await get_tree().process_frame
	_prova(is_instance_valid(ed), "collisioni: le guide si disegnano senza errori")
	ed._apri_guida("licenze")
	await get_tree().process_frame
	_prova(is_instance_valid(ed._guida) and ed._guida.visible and ed._guida._indice.item_count > 0 and ed._guida._testo.get_parsed_text().contains("LICENZE"), "guida: si apre e trova «licenze»")
	ed._guida.hide()
	ed.progetto.esegui({"comando": "collezione", "azione": "aggiungi", "nome": "Uovo"})
	ed.progetto.esegui({"comando": "collezione", "azione": "aggiungi", "nome": "Drago"})
	ed.progetto.esegui({"comando": "collezione", "azione": "imposta", "indice": 0, "evolve_in": "ogg_2"})
	ed._apri_cz()
	await get_tree().process_frame
	_prova(is_instance_valid(ed) and ed._pannello.find_children("*", "SpinBox", true, false).size() >= 3, "collezione: pannello con l'evoluzione")
	ed.queue_free()
