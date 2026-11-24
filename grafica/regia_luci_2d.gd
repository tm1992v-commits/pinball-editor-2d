## guida al tiro); cambia solo l'uscita, disegnata in 2D.
## Nessuna regola di gioco qui: legge lo stato delle regole (stato_luci) e riceve gli effetti (segnale `effetto`).
##
## Le luci lavorano a LIVELLI:
##  1. base       luce decisa dalle regole (0 spenta, 1 accesa, 2 lampeggia) + luci d'atmosfera che «respirano»
##  2. lampi      il pezzo appena colpito (bumper, fionde, bersagli) si accende di colpo e si spegne
##  3. effetti    sequenze che si muovono sul tavolo: onda, spazzata, girandola, lampeggio, stroboscopio, flash
##  4. spettacoli effetti «grandi» (jackpot, multiball, missioni): abbassano per un attimo le altre luci e la luce
##                d'ambiente, così lo spettacolo si legge bene (contrasto), poi tutto torna normale.
## Costo (Raspberry Pi 4): tutti gli aloni sono UN solo MultiMesh2D (un colore per lampada) e tutti i LED un altro:
## 2 disegni per fotogramma. Niente luci di Godot; stati a 30 Hz.
class_name RegiaLuci2D
extends Node2D

var vista: Vista2D
var tavolo: TavoloFisico
var regole: RegoleBase
var cfg: Script
var t := 0.0
var _lampade: Array = []              # Dictionary: nome, pos (mm), r, col, stile, i_alone
var _acc := {}                        # nome -> 0..1
var _col := {}                        # nome -> colore attuale
var _effetti: Array = []
var _grande := 0.0
var _t_stati := 0.0
var _t_attesa := 0.0
var _i_attesa := 0
var spettacoli := 0                   # quanti effetti «grandi» sono partiti (per i test)
var spettacoli_partiti := 0           # v0.17: spettacoli di luce del tavolo partiti (eventi e attesa; per i test)
var intensita := 1.0                  # forza degli aloni ([grafica] luci_intensita)
var luci_regole := {}                 # ultimo stato delle luci deciso dalle regole (anche per i bersagli della vista)
var _aloni: MultiMesh
var _led: MultiMesh
var _pos_aloni: Array = []            # [centro, lato]
var _pos_led: Array = []
var _nodo_aloni: MultiMeshInstance2D

func prepara(v: Vista2D, script_luci: Script) -> void:
	vista = v
	tavolo = v.tavolo
	regole = v.regole
	cfg = script_luci
	intensita = float(Parametri.valore("grafica", "luci_intensita", 1.0))
	var d: Dictionary = vista.desc
	var basso := Parametri.qualita() == "bassa"
	for a in cfg.atmosfera():
		_lampada(a[0], a[1], float(a[2]) * (0.7 if basso else 1.0), a[3], "morbida")
	for info in d["inserti"]:
		var dim: Vector2 = info["dim"]
		_lampada(info["id"], info["pos"], maxf(dim.x, dim.y) * 0.5, info["colore"], "lente")
	for b in d["bumper"]:
		_lampada(b["id"], b["pos"], float(b["raggio"]), cfg.colore_pezzo(b["id"]), "bumper")
	for f in d["fionde"]:
		var c: Vector2 = (Vector2(f["punti"][0]) + Vector2(f["punti"][1]) + Vector2(f["punti"][2])) / 3.0
		_lampada(f["id"], c, 26.0, Color(0.5, 0.95, 1.0), "fionda")
	if cfg.has_method("led"):
		var leds: Array = led_2d()
		for i in leds.size():
			_pos_led.append(leds[i])
			_lampade.append({"nome": "led_%d" % i, "pos": leds[i], "r": 6.0, "col": Color.WHITE, "stile": "led",
				"i_led": i, "i_alone": _nuovo_alone(leds[i], 20.0), "frazione": float(i) / leds.size()})
	_crea_multimesh()
	regole.effetto.connect(evento)

## LED del mobile in 2D: le stesse file del 3D (su a sinistra, in alto, giù a destra, nello stesso ordine), portate
## sul bordo di legno che si vede intorno al piano.
func led_2d() -> Array:
	var out: Array = []
	var largo: float = Vector2(vista.desc["dimensioni"]).x
	for l in cfg.led():
		var p: Vector2 = l[0]
		if p.x < 0.0:
			p.x = -4.0
		elif p.x > largo:
			p.x = largo + 4.0
		if p.y < 0.0:
			p.y = -4.0
		out.append(p)
	return out

func _lampada(nome: String, pos: Vector2, r: float, col: Color, stile: String) -> void:
	var scala: float = {"morbida": 2.0, "lente": 4.4, "bumper": 4.2, "fionda": 3.2}[stile]
	_lampade.append({"nome": nome, "pos": pos, "r": r, "col": col, "stile": stile, "i_alone": _nuovo_alone(pos, r * scala)})

func _nuovo_alone(pos: Vector2, lato: float) -> int:
	_pos_aloni.append([pos, lato])
	return _pos_aloni.size() - 1

func _crea_multimesh() -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	_aloni = MultiMesh.new()
	_aloni.transform_format = MultiMesh.TRANSFORM_2D
	_aloni.use_colors = true
	_aloni.mesh = qm
	_aloni.instance_count = _pos_aloni.size()
	for i in _pos_aloni.size():
		var lato: float = _pos_aloni[i][1]
		_aloni.set_instance_transform_2d(i, Transform2D(0.0, Vector2(lato, lato), 0.0, _pos_aloni[i][0]))
		_aloni.set_instance_color(i, Color(0, 0, 0, 0))
	_nodo_aloni = MultiMeshInstance2D.new()
	_nodo_aloni.multimesh = _aloni
	_nodo_aloni.texture = vista.tex_alone()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_nodo_aloni.material = add
	add_child(_nodo_aloni)
	if _pos_led.is_empty():
		return
	var lm := QuadMesh.new()
	lm.size = Vector2(5, 7)
	_led = MultiMesh.new()
	_led.transform_format = MultiMesh.TRANSFORM_2D
	_led.use_colors = true
	_led.mesh = lm
	_led.instance_count = _pos_led.size()
	for i in _pos_led.size():
		var p: Vector2 = _pos_led[i]
		# LED delle file in alto: coricati
		_led.set_instance_transform_2d(i, Transform2D(PI * 0.5 if p.y < 0.0 else 0.0, p))
		_led.set_instance_color(i, Color(0.1, 0.1, 0.1))
	var mi := MultiMeshInstance2D.new()
	mi.multimesh = _led
	add_child(mi)

# ================================================================ eventi
## Ogni effetto delle regole avvia gli effetti di luce della tabella EVENTI del tavolo.
func evento(nome: String, pos: Vector2) -> void:
	var eventi: Dictionary = cfg.EVENTI
	# v0.11: effetto scelto nell'editor per questo tavolo (desc["luci_eventi"])
	var scelto = RegiaDati.effetto_luce(vista.desc, nome)
	# v0.17: spettacolo chiamato direttamente (azione di una missione: evento «spettacolo:NOME»)
	if nome.begins_with("spettacolo:"):
		scelto = RegiaDati.spettacolo(vista.desc, nome.substr(11))
		if not scelto.is_empty():
			spettacoli_partiti += 1
	if scelto == null and not eventi.has(nome):
		return
	for spec in (scelto if scelto != null else eventi[nome]):
		var e: Dictionary = (spec as Dictionary).duplicate()
		if typeof(e.get("col")) == TYPE_STRING:
			e["col"] = cfg.colore_missione_attiva(regole)
		if not e.has("c"):
			e["c"] = pos if pos != Vector2.ZERO else (_centro_tavolo() if nome.begins_with("spettacolo:") or scelto != null else cfg.CENTRO)
		e["t0"] = t + float(e.get("dopo", 0.0))
		if e.get("grande", false):
			spettacoli += 1
		_effetti.append(e)
	if _effetti.size() > 24:
		_effetti = _effetti.slice(_effetti.size() - 24)

## v0.17: centro del tavolo vero (i tavoli dell'editor hanno misure diverse da quelle di base).
func _centro_tavolo() -> Vector2:
	return Vector2(vista.desc.get("dimensioni", Vector2(634, 1240))) * 0.5

## Quanto un effetto accende una lampada (0..1) in questo istante.
func _contributo(e: Dictionary, l: Dictionary) -> float:
	var tt: float = t - float(e["t0"])
	var dur: float = e["dur"]
	if tt < 0.0 or tt > dur:
		return 0.0
	if e.has("zona"):
		var dentro := false
		for z in e["zona"]:
			if (l["nome"] as String).begins_with(z):
				dentro = true
				break
		if not dentro:
			return 0.0
	var k := tt / dur
	var c: Vector2 = l["pos"]
	match e["tipo"]:
		"flash":
			return (1.0 - k) * (1.0 - k)
		"onda":
			var dd := c.distance_to(e["c"])
			if e.has("max") and dd > float(e["max"]):
				return 0.0
			var x := (dd - float(e["vel"]) * tt) / float(e["larg"])
			return exp(-x * x) * (1.0 - k * 0.6)
		"spazzata":
			var y0 := lerpf(1100.0, -60.0, k) if float(e["verso"]) < 0.0 else lerpf(-60.0, 1100.0, k)
			var x := (c.y - y0) / 80.0
			return exp(-x * x)
		"girandola":
			var a := (c - (e["c"] as Vector2)).angle()
			var s := k * TAU * float(e["giri"])
			var diff := minf(absf(wrapf(a - s, -PI, PI)), absf(wrapf(a - s - PI, -PI, PI)))
			return exp(-(diff / 0.45) * (diff / 0.45)) * (1.0 - k * 0.3)
		"lampeggio", "strobo":
			return 1.0 if fmod(tt * float(e["freq"]), 1.0) < 0.45 else 0.0
	return 0.0

# ================================================================ stato di base
func _base(l: Dictionary, luci: Dictionary) -> float:
	var nome: String = l["nome"]
	if tavolo.tilt:
		return 0.0
	var attesa := regole.stato == RegoleBase.ATTESA or regole.stato == RegoleBase.GAME_OVER
	match l["stile"]:
		"led":
			var c: Array = cfg.colore_led(regole, t, float(l["frazione"]), attesa)
			l["col"] = c[0]
			return float(c[1])
		"morbida":
			return (0.22 if attesa else 0.32) + 0.06 * sin(t * 0.9 + float(nome.hash() % 7) * 1.7)
		"bumper":
			return 0.0 if attesa else (0.75 if regole.multiball else 0.4)
		"fionda":
			return 0.0 if attesa else 0.15
	if attesa:
		return 0.0
	match int(luci.get(nome, 0)):
		1:
			return 1.0
		2:
			return 1.0 if fmod(t * 4.0, 1.0) < 0.55 else 0.12
	return 0.0

## Luce d'ambiente: si abbassa durante gli spettacoli; il tavolo può cambiarla per le sue modalità (es. la Notte).
func _ambiente() -> float:
	return (1.0 - 0.38 * _grande) * float(cfg.ambiente_tavolo(regole))

# ================================================================ ciclo
func _process(delta: float) -> void:
	t += delta
	if regole.stato == RegoleBase.ATTESA or regole.stato == RegoleBase.GAME_OVER:
		_t_attesa -= delta
		if _t_attesa <= 0.0:
			# v0.17: attesa in sala personalizzata dal tavolo (spettacolo scelto + pausa)
			var att := RegiaDati.attesa(vista.desc)
			var sp: Array = RegiaDati.spettacolo(vista.desc, str(att.get("spettacolo", ""))) if str(att.get("spettacolo", "")) != "" else []
			if not sp.is_empty():
				var fine := 0.0
				for e0 in sp:
					var e: Dictionary = (e0 as Dictionary).duplicate()
					e["t0"] = t + float(e.get("dopo", 0.0))
					e["c"] = _centro_tavolo()
					e.erase("grande")      # fuori partita niente luce d'ambiente abbassata
					fine = maxf(fine, float(e.get("dopo", 0.0)) + float(e["dur"]))
					_effetti.append(e)
				_t_attesa = fine + clampf(float(att.get("pausa", 1.0)), 0.0, 30.0)
				spettacoli_partiti += 1
			else:
				_t_attesa = 2.4
				var e: Dictionary = (cfg.ATTESA[_i_attesa % cfg.ATTESA.size()] as Dictionary).duplicate()
				e["t0"] = t
				_effetti.append(e)
			_i_attesa += 1
	_t_stati -= delta
	if _t_stati <= 0.0:
		_t_stati = 1.0 / 30.0
		_aggiorna()

func _aggiorna() -> void:
	var vivi: Array = []
	var g := 0.0
	for e in _effetti:
		var tt: float = t - float(e["t0"])
		if tt <= float(e["dur"]):
			vivi.append(e)
			if e.get("grande", false) and tt >= 0.0:
				g = maxf(g, 1.0 - 0.5 * tt / float(e["dur"]))
	_effetti = vivi
	_grande = move_toward(_grande, g, 0.25)
	var scuro := 1.0 - 0.75 * _grande
	luci_regole = regole.stato_luci()
	for l in _lampade:
		var nome: String = l["nome"]
		var base := _base(l, luci_regole) * scuro
		var meglio := 0.0
		# bumper che cambiano colore col livello (Flipper Spazio): il tavolo dà il colore di adesso
		if l["stile"] == "bumper" and cfg.has_method("colore_pezzo_vivo"):
			l["col"] = cfg.colore_pezzo_vivo(regole, nome)
		var col: Color = l["col"]
		for e in _effetti:
			var v := _contributo(e, l)
			if v > meglio:
				meglio = v
				if v > base:
					col = e["col"]
		if l["stile"] == "morbida":
			meglio *= 0.6
		var lampo: float = vista.lampo(nome)
		if lampo > maxf(base, meglio):
			col = l["col"]
		var acc := maxf(maxf(base, meglio), lampo)
		_acc[nome] = acc
		_col[nome] = col
		if l["stile"] == "led":
			var c: Color = col * (0.15 + 0.5 * acc + 1.2 * acc * intensita)
			_led.set_instance_color(l["i_led"], Color(maxf(c.r, 0.1 * (1.0 - acc)), maxf(c.g, 0.1 * (1.0 - acc)), maxf(c.b, 0.1 * (1.0 - acc)), 1.0))
			_aloni.set_instance_color(l["i_alone"], Color(col, 0.55 * acc * intensita))
			continue
		var forza: float = {"morbida": 0.75, "lente": 1.0, "bumper": 1.0, "fionda": 0.8}[l["stile"]] * intensita
		_aloni.set_instance_color(l["i_alone"], Color(col, forza * acc if acc > 0.02 else 0.0))
		# la lampada accende anche il suo pezzo vero (inserto del piano, cappello del bumper)
		vista.accendi(nome, acc, col)
	vista.ambiente(_ambiente())

## Accensione attuale di una lampada (0..1): per i test e per la grafica.
func accensione(nome: String) -> float:
	return float(_acc.get(nome, 0.0))
