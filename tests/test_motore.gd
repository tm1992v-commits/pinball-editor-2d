## Collaudo dei MECCANISMI del motore su un tavolo di prova semplice (non legato a nessun tema):
## livelli (piano rialzato), passaggio che risale su un livello, binari concatenati con deviatore, porte mobili,
## spinner, captive ball, bersagli mobili, prigione con palline visibili, sicurezza dei livelli.
## Avvio: godot --headless --fixed-fps 60 --path . res://tests/test_motore.tscn
extends Node

var tavolo: TavoloFisico
var eventi: Array = []
var ok := 0
var falliti: Array[String] = []

const ZONA := [Vector2(50, 50), Vector2(350, 50), Vector2(350, 250), Vector2(50, 250)]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_esegui.call_deferred()

static func descrizione() -> Dictionary:
	var d := {}
	d["nome"] = "prova"
	d["dimensioni"] = Vector2(600, 1000)
	d["campo"] = 590.0
	d["centro_x"] = 300.0
	d["raggio_pallina"] = 13.5
	var z := PackedVector2Array(ZONA)
	z.append(ZONA[0])
	d["muri"] = [
		{"id": "scatola", "punti": PackedVector2Array([Vector2(0, 1060), Vector2(0, 0), Vector2(600, 0), Vector2(600, 1060)]), "tipo": "legno"},
		{"id": "palco", "punti": z, "tipo": "metallo", "livello": 1},
		# canale della captive ball
		{"id": "canale_sx", "punti": PackedVector2Array([Vector2(470, 470), Vector2(470, 300), Vector2(504, 300), Vector2(504, 470)]), "tipo": "metallo"},
	]
	d["livelli"] = {1: {"altezza": 40.0, "zona": PackedVector2Array(ZONA)}}
	d["cancello"] = [Vector2(595, 0), Vector2(595, 1)]
	d["lancio"] = {"pos": Vector2(598, 2000), "corsia_x": 597.0}
	d["palette"] = [{"id": "mini", "perno": Vector2(300, 225), "verso": -1.0, "lunghezza": 45.0, "comando": "paletta_sx", "livello": 1, "spessore": 8.0}]
	d["paletta_angoli"] = Vector2(0.5, -0.5)
	d["fionde"] = []
	d["bumper"] = [{"id": "bumper_palco", "pos": Vector2(200, 130), "raggio": 25.0, "livello": 1}]
	d["bersagli"] = []
	for i in 3:
		d["bersagli"].append({"id": "fila_t%d" % i, "pos": Vector2(150 + 40 * i, 950), "angolo": 0.0, "dim": Vector2(24, 8), "abbattibile": true, "gruppo": "fila_t"})
	d["bersagli_mobili"] = [{"id": "barca", "gruppo": "barca", "da": Vector2(100, 420), "a": Vector2(220, 420), "periodo": 2.0, "dim": Vector2(40, 10), "sparisce": 1.0}]
	d["buche"] = [
		{"id": "vuk", "pos": Vector2(100, 760), "raggio": 15.0, "tipo": "passaggio", "passaggio": "sotto"},
		{"id": "prigione", "pos": Vector2(550, 700), "raggio": 15.0, "tipo": "prigione", "posti": [Vector2(550, 640), Vector2(550, 610)],
			"uscita": Vector2(550, 760), "uscita_dir": Vector2(0, 1), "uscita_vel": 300.0},
	]
	d["passaggi"] = [{"id": "sotto", "percorso": PackedVector2Array([Vector2(100, 760), Vector2(100, 200)]), "vel_interna": 800.0,
		"uscita": Vector2(120, 200), "uscita_dir": Vector2(0, -1), "uscita_vel": 300.0, "variazione": 0.0, "uscita_livello": 1}]
	d["rampe"] = [
		{"id": "r1", "punti": [Vector3(300, 760, 0), Vector3(300, 650, 30), Vector3(300, 560, 50)]},
		{"id": "r2", "punti": [Vector3(300, 560, 50), Vector3(300, 400, 45), Vector3(300, 160, 40)], "livello_fine": 1},
		{"id": "r3", "punti": [Vector3(300, 560, 50), Vector3(380, 640, 25), Vector3(400, 760, 0)]},
	]
	d["deviatori"] = [{"id": "D", "rampa": "r1", "aperto_verso": "r2", "chiuso_verso": "r3"}]
	d["bocca_rampa"] = 30.0
	d["porte"] = [{"id": "porta", "punti": PackedVector2Array([Vector2(150, 560), Vector2(250, 560)])}]
	d["spinner"] = [{"id": "spinner", "pos": Vector2(60, 600), "larghezza": 40.0}]
	d["captive"] = [{"id": "bilancia", "casa": Vector2(487, 440), "fermo": [Vector2(470, 462), Vector2(504, 462)], "bersaglio": Vector2(487, 318), "corsa": 125.0}]
	d["sensori"] = []
	d["cancelli"] = [{"id": "cg", "pos": Vector2(450, 900), "larghezza": 60.0, "angolo": 0.0}]
	return d

func _esegui() -> void:
	await get_tree().process_frame
	tavolo = TavoloFisico.new(descrizione())
	add_child(tavolo)
	tavolo.evento.connect(func(t, id, _p): eventi.append(t + ":" + id))
	await passi(2)
	await _test_livelli()
	await _test_vuk()
	await _test_deviatore()
	await _test_porta()
	await _test_spinner()
	await _test_captive()
	await _test_mobile()
	await _test_prigione()
	await _test_sicurezza_livello()
	await _test_cancello()
	await _test_fila()
	await _test_calo()
	print("\n==== MOTORE: %d OK, %d FALLITI ====" % [ok, falliti.size()])
	for f in falliti:
		print("  FALLITO: ", f)
	get_tree().quit(0 if falliti.is_empty() else 1)

func controlla(cond: bool, nome: String) -> void:
	if cond:
		ok += 1
		print("OK       ", nome)
	else:
		falliti.append(nome)
		print("FALLITO  ", nome)

func passi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func pulisci() -> void:
	tavolo.togli_tutte()
	eventi.clear()
	await passi(4)

func aspetta(ev: String, max_s: float) -> bool:
	for i in int(max_s * 240.0):
		if eventi.has(ev):
			return true
		await get_tree().physics_frame
	return false

func _pallina(pos: Vector2, vel: Vector2, liv := 0) -> Pallina:
	var b := tavolo.genera_pallina(pos, vel)
	if liv > 0:
		b.imposta_livello(liv, tavolo.quota_livello(liv))
	return b

# ---------------------------------------------------------------- prove
## Calo del rimbalzo sulla gomma (falloff come VPX, 24/11): colpo forte = rimbalzo in proporzione minore;
## metallo invariato. Tavolo a parte con le pareti di tools/misura_rimbalzi.gd.
func _rimbalzo(t: TavoloFisico, punto: Vector2, v: float) -> float:
	t.togli_tutte()
	await passi(3)
	var b := t.genera_pallina(punto - Vector2(120, 0), Vector2(v, 0))
	var arrivo := 0.0
	for i in 240:
		await get_tree().physics_frame
		var vn := b.linear_velocity.x
		arrivo = maxf(arrivo, vn)
		if vn < -1.0 and b.global_position.distance_to(punto) > 30.0:
			return -vn / maxf(arrivo, 1.0)
	return 0.0

func _test_calo() -> void:
	tavolo.togli_tutte()
	tavolo.queue_free()
	await passi(2)
	var m := preload("res://tools/misura_rimbalzi.gd").new()
	var t := TavoloFisico.new(m._desc())
	m.free()
	add_child(t)
	await passi(2)
	var lento := await _rimbalzo(t, Vector2(600, 180), 500.0)
	var forte := await _rimbalzo(t, Vector2(600, 180), 3000.0)
	var met_l := await _rimbalzo(t, Vector2(600, 480), 500.0)
	var met_f := await _rimbalzo(t, Vector2(600, 480), 3000.0)
	controlla(lento > 0.6 and forte > 0.3 and forte < 0.5, "gomma: rimbalzo che cala col colpo (%.2f a 0,5 m/s, %.2f a 3 m/s; VPX 0,70 e 0,42)" % [lento, forte])
	controlla(absf(met_l - met_f) < 0.05, "metallo: rimbalzo uguale a ogni velocità (%.2f / %.2f)" % [met_l, met_f])
	t.queue_free()

func _test_fila() -> void:
	await pulisci()
	var regole: RegoleBase = load("res://tavoli/base/regole_tavolo.gd").new()
	add_child(regole)
	regole.collega(tavolo)
	regole.stato = RegoleBase.GIOCO
	var prima := regole.punti
	for i in 3:
		_pallina(Vector2(150 + 40 * i, 1000), Vector2(0, -700))
		await aspetta("bersaglio:fila_t%d" % i, 1.0)
		await passi(10)
	var giu: bool = tavolo.bersagli_giu["fila_t0"] and tavolo.bersagli_giu["fila_t2"]
	controlla(regole.punti - prima >= 5000, "fila di abbattibili: tutti giù = premio")
	await pulisci()
	await passi(400)
	controlla(giu and not tavolo.bersagli_giu["fila_t0"] and not tavolo.bersagli_giu["fila_t2"], "fila di abbattibili: poi si rialzano")
	regole.queue_free()

func _test_cancello() -> void:
	await pulisci()
	var b := _pallina(Vector2(450, 960), Vector2(0, -900))
	var passata := await aspetta("cancello:cg", 1.0)
	await passi(30)
	controlla(passata and b.global_position.y < 880.0, "cancelletto: la pallina che sale passa (e lo segnala)")
	await pulisci()
	var c := _pallina(Vector2(450, 830), Vector2(0, 1200))
	await passi(40)
	controlla(c.global_position.y < 895.0, "cancelletto: la pallina che scende si ferma (senso unico)")
	await pulisci()
	var veloce := _pallina(Vector2(450, 850), Vector2(0, 3200))
	await passi(20)
	controlla(veloce.global_position.y < 895.0, "cancelletto: tiene anche a 3200 mm/s")

func _test_livelli() -> void:
	await pulisci()
	var b := _pallina(Vector2(200, 230), Vector2(0, -700), 1)
	controlla(await aspetta("bumper:bumper_palco", 1.5), "livelli: pallina sul Palco colpisce il bumper del Palco")
	await passi(240)
	controlla(Geometry2D.is_point_in_polygon(b.global_position, PackedVector2Array(ZONA)), "livelli: pallina sul Palco resta dentro i muri del Palco")
	controlla(b.quota == 40.0 and b.altezza == 40.0, "livelli: altezza grafica della pallina = altezza del Palco")
	await pulisci()
	var c := _pallina(Vector2(200, 330), Vector2(0, -1100), 0)
	await passi(150)
	controlla(not eventi.has("bumper:bumper_palco"), "livelli: pallina del piano principale passa SOTTO il Palco senza toccarlo")
	controlla(c.global_position.y < 200 or c.linear_velocity.y > 0, "livelli: attraversa la zona del Palco")
	controlla(tavolo.palette["mini"].collision_layer == 2, "livelli: la mini paletta sta sul livello del Palco")

func _test_vuk() -> void:
	await pulisci()
	var b := _pallina(Vector2(100, 700), Vector2(0, 300), 0)
	var entrata := await aspetta("passaggio_entrata:vuk", 1.0)
	var uscita := await aspetta("passaggio_uscita:sotto", 2.0)
	controlla(entrata and uscita, "VUK: la pallina entra nella buca e riappare")
	await passi(2)
	controlla(b.livello == 1 and b.collision_mask == 2, "VUK: riappare sul livello del Palco")

func _test_deviatore() -> void:
	await pulisci()
	tavolo.imposta_deviatore("D", false)
	var b := _pallina(Vector2(300, 800), Vector2(0, -1600))
	controlla(await aspetta("rampa:r3", 3.0), "deviatore chiuso: binario r1 prosegue su r3")
	controlla(not eventi.has("rampa:r2"), "deviatore chiuso: non va su r2")
	await passi(30)
	controlla(b.livello == 0, "deviatore chiuso: scende sul piano principale")
	await pulisci()
	tavolo.imposta_deviatore("D", true)
	var c := _pallina(Vector2(300, 800), Vector2(0, -1600))
	controlla(await aspetta("rampa:r2", 3.0), "deviatore aperto: binario r1 prosegue su r2")
	await passi(10)
	controlla(c.livello == 1, "deviatore aperto: r2 porta la pallina sul Palco")
	await pulisci()
	tavolo.imposta_deviatore("D", false)
	var e := _pallina(Vector2(300, 800), Vector2(0, -500))
	controlla(await aspetta("rampa_fallita:r1", 3.0), "binario: tiro debole torna indietro")
	await passi(20)
	controlla(e.livello == 0 and not e.sul_binario(), "binario: dopo il tiro debole resta sul piano principale")

func _test_porta() -> void:
	await pulisci()
	var b := _pallina(Vector2(200, 640), Vector2(0, -900))
	var minimo := 9999.0
	for i in 240:
		if is_instance_valid(b):
			minimo = minf(minimo, b.global_position.y)
		await get_tree().physics_frame
	controlla(minimo > 540.0, "porta chiusa: la pallina rimbalza")
	await pulisci()
	tavolo.apri_porta("porta", true)
	await passi(2)
	var c := _pallina(Vector2(200, 640), Vector2(0, -900))
	minimo = 9999.0
	for i in 240:
		if is_instance_valid(c):
			minimo = minf(minimo, c.global_position.y)
		await get_tree().physics_frame
	controlla(minimo < 480.0, "porta aperta: la pallina passa")
	# chiusura con la pallina sulla linea: aspetta che si liberi
	await pulisci()
	var d2 := _pallina(Vector2(200, 560), Vector2.ZERO)
	d2.tieni(Vector2(200, 560))
	tavolo.apri_porta("porta", false)
	await passi(30)
	var ancora_aperta: bool = tavolo._porte["porta"].get_child(0).disabled
	d2.rilascia(Vector2(0, 400))
	await passi(120)
	controlla(ancora_aperta and not tavolo._porte["porta"].get_child(0).disabled, "porta: si chiude solo quando la pallina se n'è andata")

func _test_spinner() -> void:
	await pulisci()
	_pallina(Vector2(60, 700), Vector2(0, -1100))
	controlla(await aspetta("spinner:spinner", 1.0), "spinner: la pallina lo fa girare")
	controlla(tavolo.spinner_giri["spinner"] >= 5, "spinner: tiro veloce = molti giri (%d)" % tavolo.spinner_giri["spinner"])
	controlla(tavolo.spinner_vel["spinner"] > 0.0, "spinner: velocità di rotazione per la grafica")

func _test_captive() -> void:
	await pulisci()
	await passi(240)
	var cb: RigidBody2D = tavolo.captive["bilancia"]
	controlla(cb.global_position.distance_to(Vector2(487, 440)) < 15.0, "captive: a riposo sta a casa, sul fermo")
	_pallina(Vector2(487, 640), Vector2(0, -1500))
	controlla(await aspetta("captive:bilancia", 1.5), "captive: la pallina di gioco la colpisce e lei tocca il bersaglio")
	await passi(720)
	controlla(cb.global_position.distance_to(Vector2(487, 440)) < 15.0, "captive: torna a casa da sola e non esce dal canale")

func _test_mobile() -> void:
	await pulisci()
	var p0: Vector2 = tavolo.mobili["barca"].position
	await passi(120)
	controlla(tavolo.mobili["barca"].position.distance_to(p0) > 20.0, "bersaglio mobile: si muove")
	# tiro sotto la posizione attuale: lo colpisce
	var colpito := false
	for k in 4:
		await pulisci()
		var x: float = tavolo.mobili["barca"].position.x
		_pallina(Vector2(x, 520), Vector2(0, -1200))
		if await aspetta("bersaglio:barca", 0.4):
			colpito = true
			break
	controlla(colpito, "bersaglio mobile: si colpisce mirando dove si trova")
	# 19/11: colpito sparisce (la pallina ci passa attraverso) e torna dopo "sparisce" secondi
	await passi(2)
	controlla(not tavolo.mobile_visibile("barca") and tavolo.mobili["barca"].collision_layer == 0, "bersaglio mobile: colpito sparisce")
	await pulisci()
	await passi(int(1.3 * 240))
	controlla(tavolo.mobile_visibile("barca") and tavolo.mobili["barca"].collision_layer != 0, "bersaglio mobile: torna dopo qualche secondo")

func _test_prigione() -> void:
	await pulisci()
	var a := _pallina(Vector2(550, 790), Vector2(0, -420))
	controlla(await aspetta("prigione:prigione", 1.0), "prigione: la prima pallina entra")
	await passi(6)
	controlla(a.tenuta and a.global_position.distance_to(Vector2(550, 640)) < 2.0, "prigione: la pallina resta visibile nel primo posto")
	eventi.clear()
	var b := _pallina(Vector2(550, 790), Vector2(0, -420))
	controlla(await aspetta("prigione:prigione", 1.0), "prigione: la seconda pallina entra")
	await passi(6)
	controlla(b.global_position.distance_to(Vector2(550, 610)) < 2.0, "prigione: seconda pallina nel secondo posto")
	tavolo.libera_prigione("prigione", 0.3)
	await passi(360)
	controlla((not is_instance_valid(a) or not a.tenuta) and (not is_instance_valid(b) or not b.tenuta) and tavolo.prigionieri["prigione"].is_empty(), "prigione: libera tutte le palline (multiball)")

func _test_sicurezza_livello() -> void:
	await pulisci()
	var prima := tavolo.incastri
	var b := _pallina(Vector2(200, 275), Vector2.ZERO, 1)
	await passi(10)
	controlla(b.livello == 1 and Geometry2D.is_point_in_polygon(b.global_position, PackedVector2Array(ZONA)) and tavolo.incastri > prima,
		"sicurezza: pallina del Palco uscita dal bordo viene rimessa sul Palco")
