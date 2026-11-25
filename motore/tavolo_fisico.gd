## Tavolo fisico 2D GENERICO: costruisce sponde, palette, bumper, fionde, bersagli, buche, passaggi sotterranei,
## Nessuna grafica e nessuna regola: segnala gli eventi con `evento` e obbedisce ai comandi delle regole.
class_name TavoloFisico
extends Node2D

## tipo: "bumper", "fionda", "bersaglio", "buca", "passaggio_entrata", "passaggio_uscita", "rampa_entrata",
## "rampa", "rampa_fallita", "sensore", "kickback", "lancio", "ricaduta", "spinner", "porta", "captive", "prigione",
## "deviatore"; id = nome del pezzo nel disegno.
signal evento(tipo: String, id: String, posizione: Vector2)
signal pallina_creata(p: Pallina)
signal pallina_persa(p: Pallina, rimaste: int)

var d: Dictionary                     # descrizione del tavolo
var r_pallina := 13.5

# --- stato impostato dalle regole
var tilt := false
var kickback_accesi := {}           # id kicker di recupero -> true se acceso (più kicker: Flipper Spazio, 22/11)
var autoplay := false
var buche_aperte := {}               # id buca -> false per disattivarla (di base tutte attive)

# --- stato letto da grafica e test
var palline: Array[Pallina] = []
var pallina_in_corsia: Pallina = null
var carica := 0.0
var caricando := false
var palette := {}                    # id -> AnimatableBody2D
var bersagli_giu := {}               # id -> true se abbattuto
var rampe := {}                      # id -> Binario
var passaggi := {}                   # id -> descrizione
var in_passaggio := {}               # Pallina -> [id passaggio, tempo trascorso, durata]
var in_portale := {}                 # Pallina -> [id portale d'ingresso, secondi rimasti]
var portale_dest := {}               # id portale -> id portale da cui esce la pallina (lo decidono le regole)
var _buche := {}                     # id buca -> descrizione
var _ultimo_elastico := {}
var collisioni := 0
var incastri := 0                    # interventi delle sicurezze (obiettivo: 0)
var registro_incastri: Array = []    # posizioni degli interventi (per correggere la geometria)
var deviatori := {}                  # id -> true se aperto (la pallina prende il ramo "aperto")
var porte_aperte := {}               # id -> true se aperta
var lame_in_b := {}                  # deviatori sul piano: id -> true se nella posizione «b»
var spinner_giri := {}               # id -> giri dell'ultimo passaggio
var spinner_vel := {}                # id -> velocità di rotazione attuale (giri/s, per la grafica)
var spinner_verso := {}              # id -> +1 / -1: verso di rotazione (dipende da dove arriva la pallina, 22/11)
var prigionieri := {}                # id prigione -> Array[Pallina] tenute nei posti
var captive := {}                    # id -> RigidBody2D della pallina prigioniera
var mobili := {}                     # id -> AnimatableBody2D dei bersagli mobili
var mobili_via := {}                 # id -> tempo di ritorno dei bersagli mobili spariti dopo un colpo (19/11)
var t_gioco := 0.0
var cancelli_t := {}                   # id cancelletto -> istante dell'ultimo passaggio (per la lamina che si apre)

var _coda: Array = []
var _auto_lancio := -1.0
var _cancello: StaticBody2D
var _forme_bersagli := {}
var _tenute := {}                    # Pallina -> [secondi, buca]
var _auto := {}
var _contatti := 0
var _t_contatti := 0.0
var _materiali := {}
var _info_rampe := {}
var pareti_rampe: Array = []          # [nome rampa, livello, linee] dei tratti bassi solidi (per test e disegno dall'alto)
var _lancio_pos := Vector2.ZERO
var _corsia_x := 0.0
var _angoli := Vector2(0.5, -0.5)
var _porte := {}                     # id -> StaticBody2D
var _info_porte := {}
var _mat_paletta: PhysicsMaterial      # gomma della paletta (in movimento / ferma in alto)
var _mat_paletta_ferma: PhysicsMaterial
var _ultimo_colpo := {}              # id bersaglio mobile/captive -> tempo dell'ultimo colpo
var _in_rilascio := {}               # id prigione -> true mentre libera le palline
## CAMPI (23/11, studio: Space Cadet «FieldEffect» + magneti MPF): zone che spingono la pallina verso un centro.
## tipo "pozzo" = pozzo di gravità (curva le traiettorie); tipo "magnete" = prende, trattiene, lancia (Magna-Save).
var campi := {}                      # id -> descrizione
var campi_accesi := {}               # id -> true se acceso (lo decidono le regole)
var _magnete_stato := {}             # id magnete -> [fase, secondi rimasti, Pallina]  fase: "prendi" | "lascia"
var _canale := {}                    # canale di lancio curvo (centro, raggi, angoli): la pallina lì dentro è «in corsia»

func _init(descrizione: Dictionary) -> void:
	d = descrizione

func _ready() -> void:
	r_pallina = d["raggio_pallina"]
	_lancio_pos = d["lancio"]["pos"]
	_corsia_x = d["lancio"]["corsia_x"]
	_angoli = d["paletta_angoli"]
	# gravità lungo il piano inclinato, dal file dei parametri
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, Parametri.f("gravita", 950.0))
	_materiali = {
		"legno": _materiale(Parametri.f("rimbalzo_legno", 0.35), 0.1),
		"metallo": _materiale(Parametri.f("rimbalzo_metallo", 0.22), 0.05),
		"gomma": _materiale(Parametri.f("rimbalzo_gomma", 0.62), Parametri.f("attrito_gomma", 0.5), Parametri.f("calo_gomma", 0.3)),
		"elastico": _materiale(Parametri.f("rimbalzo_elastico", 0.88), Parametri.f("attrito_gomma", 0.5), Parametri.f("calo_gomma", 0.3)),
	}
	for m in d["muri"]:
		_crea_muro(m)
	_cancello = StaticBody2D.new()
	_cancello.physics_material_override = _materiali["metallo"]
	var sc := SegmentShape2D.new()
	sc.a = d["cancello"][0]
	sc.b = d["cancello"][1]
	var csc := CollisionShape2D.new()
	csc.shape = sc
	_cancello.add_child(csc)
	add_child(_cancello)
	for b in d["bumper"]:
		_crea_bumper(b)
	for f in d["fionde"]:
		_crea_fionda(f)
	for e in d.get("elastici", []):
		_crea_elastico(e)
	for t in d["bersagli"]:
		_crea_bersaglio(t)
	for p in d["passaggi"]:
		passaggi[p["id"]] = p
	for b in d["buche"]:
		_crea_buca(b)
	for r in d["rampe"]:
		# Pinball Editor 2D v0.30: «punti_gioco» = la rampa con le salite e discese degli incroci (se ci sono)
		var bin := Binario.new(r["id"], r["punti_gioco"] if r.get("punti_gioco") is Array and not r["punti_gioco"].is_empty() else r["punti"])
		bin.livello = _liv(r)
		bin.quota_inizio = quota_livello(bin.livello)
		bin.livello_fine = int(r.get("livello_fine", 0))
		bin.quota_fine = quota_livello(bin.livello_fine)
		if r.get("mezze") is Array:
			bin.imposta_mezze(r["mezze"])
		elif float(r.get("larghezza", 0.0)) > 0.0:
			# v0.19: rampa da immagine: pareti larghe come il disegno
			bin.imposta_mezze([[0.0, float(r["larghezza"]) * 0.5], [1.0, float(r["larghezza"]) * 0.5]])
		rampe[r["id"]] = bin
		_info_rampe[r["id"]] = r
		# Imbocco solo dove la rampa parte DAL PIANO del suo livello (come in Visual Pinball / VPE: la pallina sale su
		# una rampa solo rotolando sul suo pavimento, che comincia a quota zero). Le rampe che proseguono da una cima
		# precedente: prima avevano un imbocco anche sul piano e una pallina che passava SOTTO il tetto del Castello o
		if absf(float(r["punti"][0].z) - bin.quota_inizio) < 1.0:
			_crea_ingresso_rampa(bin)
		# segnata "due_sensi" si può prendere anche dall'uscita, e la pallina la percorre al contrario. Prima entrava a
		# terra nel corridoio aperto dell'uscita e restava sul piano, sotto il disegno della rampa.
		if bool(r.get("due_sensi", false)) and absf(float(r["punti"][r["punti"].size() - 1].z) - bin.quota_fine) < 1.0:
			_crea_ingresso_rampa(bin, true)
		_crea_solido_rampa(bin, r)
	# chi torna indietro da un binario concatenato risale nel binario da cui arrivava
	for r in d["rampe"]:
		if r.get("prosegue_in", "") != "" and rampe.has(r["prosegue_in"]):
			rampe[r["prosegue_in"]].precedente = rampe[r["id"]]
	for s in d["sensori"]:
		_crea_sensore(s)
	for dv in d.get("deviatori", []):
		deviatori[dv["id"]] = bool(dv.get("aperto", false))
	# Pinball Editor 2D v0.30: incroci COMUNICANTI (innesti a metà binario) con il loro deviatore
	for inn in d.get("innesti", []):
		if rampe.has(inn["a"]) and rampe.has(inn["b"]):
			rampe[inn["a"]].innesti.append({"s": float(inn["sa"]), "verso": inn["b"], "s_dest": float(inn["sb"]), "id": inn["id"], "devia": str(inn.get("devia", "alterna"))})
			rampe[inn["b"]].innesti.append({"s": float(inn["sb"]), "verso": inn["a"], "s_dest": float(inn["sa"]), "id": inn["id"], "devia": str(inn.get("devia", "alterna"))})
			deviatori[inn["id"]] = str(inn.get("devia", "alterna")) == "sempre"
	for po in d.get("porte", []):
		_crea_porta(po)
	for la in d.get("lame", []):
		_crea_lama(la)
	for sp in d.get("spinner", []):
		_crea_spinner(sp)
	for cg in d.get("cancelli", []):
		_crea_cancello(cg)
	for cb in d.get("captive", []):
		_crea_captive(cb)
	for bm in d.get("bersagli_mobili", []):
		_crea_bersaglio_mobile(bm)
	var kb = d.get("kickback", [])
	for k in (kb if kb is Array else [kb]):
		_crea_kickback(k)
	for p in d["palette"]:
		palette[p["id"]] = _crea_paletta(p)
		_auto[p["id"]] = 0.0
	for cp in d.get("campi", []):
		campi[cp["id"]] = cp
		campi_accesi[cp["id"]] = bool(cp.get("acceso", false))
	_canale = d["lancio"].get("canale", {})
	var dim: Vector2 = d["dimensioni"]
	var scarico := _area(Vector2(_corsia_x * 0.5, dim.y + 45), _rett(Vector2(_corsia_x + 40, 40)))
	scarico.body_entered.connect(func(b):
		if _e_pallina(b):
			_scarica(b))

# ================================================================ costruzione
static func _liv(info: Dictionary) -> int:
	return int(info.get("livello", 0))

## Altezza grafica (mm) del piano di un livello: 0 = piano principale.
func quota_livello(l: int) -> float:
	if l == 0:
		return 0.0
	return float(d.get("livelli", {}).get(l, {}).get("altezza", 0.0))

func _crea_muro(m: Dictionary) -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = Pallina.bit(_liv(m))
	corpo.physics_material_override = _materiali[m["tipo"]]
	corpo.set_meta("id", m.get("id", ""))
	var linea: PackedVector2Array = m["punti"]
	# Pinball Editor 2D v0.17: muro PIENO = tutta la forma è un blocco (fianco di un piano rialzato visto dal tavolo)
	if m.get("pieno", false) and linea.size() >= 3:
		var cp := CollisionPolygon2D.new()
		cp.polygon = linea
		corpo.add_child(cp)
		add_child(corpo)
		return
	for i in range(linea.size() - 1):
		if m["tipo"] == "legno":
			# sponda esterna: blocco pieno spesso 80 mm verso l'esterno, 6 mm DIETRO la linea di contatto (lezione dei
			# pirati: con la sola linea una pallina velocissima poteva finire oltre). La pallina tocca la linea liscia;
			# il blocco serve solo se la sfonda (se fosse a filo, i suoi spigoli rimandavano indietro la pallina).
			corpo.add_child(_spessore(linea[i], linea[i + 1]))
		elif m.has("centro"):
			# muro "pieno" (es. bordo di un piano rialzato): blocco spesso verso l'esterno, dietro la linea di contatto
			corpo.add_child(_spessore(linea[i], linea[i + 1], m["centro"]))
		# 23/11 (studio, difetto D4): le guide sottili isolate (metallo, gomma) hanno uno SPESSORE di 3 mm invece della
		# sola linea: alla velocità massima una pallina attraversava una guida corta colpita di testa.
		if m["tipo"] in ["metallo", "gomma"] and not m.get("senso_unico", false) and not m.has("centro"):
			_lamina(corpo, linea[i], linea[i + 1], 1.5)
			continue
		var seg := SegmentShape2D.new()
		seg.a = linea[i]
		seg.b = linea[i + 1]
		var cs := CollisionShape2D.new()
		cs.shape = seg
		# senso unico: ferma solo la pallina che scende (verso il giocatore), lascia passare chi sale
		cs.one_way_collision = m.get("senso_unico", false)
		corpo.add_child(cs)
	add_child(corpo)
	# Pinball Editor 2D (24/11): tratti-FIONDA su qualunque muro (come lo «slingshot» per tratto di VPX)
	var tratti: Array = m.get("fionde_tratti", [])
	for k in tratti.size():
		_crea_tratto_fionda(m, k, tratti[k][0], tratti[k][1])

## Tratto-fionda di un muro: la pallina che lo tocca riceve una spinta lungo la normale (verso l'esterno del muro),
## più forte al CENTRO del tratto e debole agli estremi (profilo a parabola, come lo slingshot di VPX:
## forza × (1 − d²), d = −1…+1 lungo il tratto; qui con un minimo del 20 % perché la gomma spinge comunque un po').
## Evento: tipo "fionda", id "<id muro>#<n>" (per punti, luci e la gomma che si muove nella grafica).
func _crea_tratto_fionda(m: Dictionary, k: int, a: Vector2, b: Vector2) -> void:
	var lungo := a.distance_to(b)
	if lungo < 20.0:
		return
	var n := (b - a).orthogonal().normalized()
	var pts: PackedVector2Array = m["punti"]
	var centro := Vector2.ZERO
	for q in pts:
		centro += q
	centro /= maxf(1.0, float(pts.size()))
	if n.dot((a + b) * 0.5 - centro) < 0.0:
		n = -n
	var id := "%s#%d" % [m.get("id", "muro"), k]
	var forza_base := float(m.get("forza_fionda", Parametri.f("spinta_fionda", 680.0)))
	var area := _area((a + b) * 0.5 + n * (r_pallina + 1.0), _rett(Vector2(maxf(10.0, lungo - 12.0), 6.0)), (b - a).angle(), _liv(m))
	area.body_entered.connect(func(bb):
		if _e_pallina(bb) and not tilt:
			bb.fionde_fila = bb.fionde_fila + 1 if bb.dal_lancio - bb.ultima_fionda < 1.2 else 1
			bb.ultima_fionda = bb.dal_lancio
			var t := clampf((bb.global_position - a).dot(b - a) / (lungo * lungo), 0.0, 1.0)
			var dd := t * 2.0 - 1.0
			var forza := forza_base * maxf(0.2, 1.0 - dd * dd) * randf_range(0.92, 1.04)
			if bb.fionde_fila >= 4:
				forza *= 0.5
			bb.respingi(n.rotated(randf_range(-0.08, 0.08)), forza)
			_segnala("fionda", id, a.lerp(b, t)))

## Lamina: rettangolo sottile attorno al segmento a-b (mezzo spessore `m` mm), con le punte arrotondate da due cerchi.
## Le forme vanno direttamente nel corpo (Godot non vede le forme dentro un nodo intermedio).
func _lamina(nodo: CollisionObject2D, a: Vector2, b: Vector2, m: float) -> void:
	var n := (b - a).orthogonal().normalized() * m
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([a + n, b + n, b - n, a - n])
	nodo.add_child(poly)
	for p in [a, b]:
		var cs := CollisionShape2D.new()
		cs.shape = _cerchio(m)
		cs.position = p
		nodo.add_child(cs)

func _spessore(a: Vector2, b: Vector2, centro := Vector2(-1, -1)) -> CollisionPolygon2D:
	var n := (b - a).orthogonal().normalized()
	if centro.x < 0.0:
		centro = Vector2(d["centro_x"], 600.0)
	if n.dot((a + b) * 0.5 - centro) < 0.0:
		n = -n
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([a + n * 6.0, b + n * 6.0, b + n * 80.0, a + n * 80.0])
	return poly

## calo = «falloff» del rimbalzo come VPX (Pinball Editor 2D, 24/11): più forte è il colpo, meno la gomma restituisce
## in proporzione. Lo applica la pallina (Pallina._calo_rimbalzo) leggendo il valore dal materiale; 0 = rimbalzo fisso.
func _materiale(rimbalzo: float, attrito: float, calo := 0.0) -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = rimbalzo
	m.friction = attrito
	if calo > 0.0:
		m.set_meta("calo", calo)
	return m

func _area(pos: Vector2, forma: Shape2D, rot := 0.0, liv := 0) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = Pallina.bit(liv)
	a.position = pos
	a.rotation = rot
	var cs := CollisionShape2D.new()
	cs.shape = forma
	a.add_child(cs)
	add_child(a)
	return a

func _rett(dim: Vector2) -> RectangleShape2D:
	var r := RectangleShape2D.new()
	r.size = dim
	return r

func _cerchio(r: float) -> CircleShape2D:
	var c := CircleShape2D.new()
	c.radius = r
	return c

func _statico(pos: Vector2, forma: Shape2D, mat: PhysicsMaterial, rot := 0.0, liv := 0) -> CollisionShape2D:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = Pallina.bit(liv)
	corpo.position = pos
	corpo.rotation = rot
	corpo.physics_material_override = mat
	var cs := CollisionShape2D.new()
	cs.shape = forma
	corpo.add_child(cs)
	add_child(corpo)
	return cs

func _e_pallina(b) -> bool:
	return b is Pallina

func _segnala(tipo: String, id: String, pos: Vector2) -> void:
	evento.emit(tipo, id, pos)

## CANCELLETTO (Pinball Editor 2D v0.7, 24/11): lamina a senso unico, come il «gate» dei flipper veri e di VPX.
## La pallina passa solo nel verso della freccia (con rotazione 0: verso l'alto del tavolo), dall'altra parte trova un
## muro. Una zona sottile sulla lamina segnala il passaggio (evento "cancello") e la grafica fa alzare la lamina.
## Fisica: segmento a collisione «a senso unico» di Godot (blocca chi si muove lungo +y locale), margine largo perché
## alla velocità massima (3200 mm/s a 240 passi) la pallina fa 13 mm per passo.
func _crea_cancello(info: Dictionary) -> void:
	var id: String = info["id"]
	var mezza := float(info.get("larghezza", 40.0)) * 0.5
	var ang := float(info.get("angolo", 0.0))
	var corpo := StaticBody2D.new()
	corpo.collision_layer = Pallina.bit(_liv(info))
	corpo.physics_material_override = _materiale(0.3, 0.1)
	corpo.set_meta("id", id)
	var seg := SegmentShape2D.new()
	seg.a = Vector2(-mezza, 0)
	seg.b = Vector2(mezza, 0)
	var cs := CollisionShape2D.new()
	cs.shape = seg
	cs.one_way_collision = true
	cs.one_way_collision_margin = 16.0
	cs.position = info["pos"]
	cs.rotation = ang
	corpo.add_child(cs)
	add_child(corpo)
	cancelli_t[id] = -9.0
	var zona := _area(info["pos"], _rett(Vector2(mezza * 2.0, 10.0)), ang, _liv(info))
	zona.body_entered.connect(func(b):
		if _e_pallina(b) and not b.sul_binario():
			if t_gioco - float(cancelli_t[id]) > 0.25:
				_segnala("cancello", id, info["pos"])
			cancelli_t[id] = t_gioco)

## Pinball Editor 2D v0.19 (elementi da immagine): un bumper può essere OVALE ("raggio" = mezzo asse x, "raggio_y" =
## mezzo asse y, "angolo_coll" = rotazione) e avere la sua FORZA e il suo RIMBALZO; senza questi campi è il bumper di
## sempre (cerchio, forza del tavolo).
static func _ovale(rx: float, ry: float, n := 28) -> ConvexPolygonShape2D:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	var f := ConvexPolygonShape2D.new()
	f.points = pts
	return f

func _crea_bumper(info: Dictionary) -> void:
	var c: Vector2 = info["pos"]
	var r: float = info["raggio"]
	var ry := float(info.get("raggio_y", r))
	var ovale := absf(ry - r) > 0.5
	var rot := float(info.get("angolo_coll", 0.0)) if ovale else 0.0
	var mat := _materiale(float(info.get("rimbalzo", 0.85)), 0.1)     # 23/11: valore vero (prima 0,6 + 0,25 della pallina)
	_statico(c, _ovale(r, ry) if ovale else _cerchio(r), mat, rot, _liv(info))
	var area := _area(c, _ovale(r + r_pallina + 3.0, ry + r_pallina + 3.0) if ovale else _cerchio(r + r_pallina + 3.0), rot, _liv(info))
	area.body_entered.connect(func(b):
		if _e_pallina(b) and not tilt and not b.sul_binario():
			# anti giro infinito (lezione del Molo dei pirati): dal 8° colpo di fila la spinta cala e va verso il basso
			b.barili_fila = b.barili_fila + 1 if b.dal_lancio - b.ultimo_barile < 1.0 else 1
			b.ultimo_barile = b.dal_lancio
			var dir: Vector2 = (b.global_position - c).normalized()
			if ovale:
				# normale dell'ovale nel punto più vicino alla pallina (spinge «fuori dalla superficie»)
				var q: Vector2 = (b.global_position - c).rotated(-rot)
				dir = Vector2(q.x / (r * r), q.y / (ry * ry)).normalized().rotated(rot)
			var forza := float(info.get("forza", Parametri.f("spinta_bumper", 760.0)))
			if b.barili_fila >= 8:
				dir = dir.lerp(Vector2(0, 1), 0.6).normalized()
				forza *= 0.5
			b.respingi(dir, forza)
			_segnala("bumper", info["id"], c))

func _crea_fionda(info: Dictionary) -> void:
	var fi: Array = info["punti"]
	var corpo := StaticBody2D.new()
	corpo.collision_layer = Pallina.bit(_liv(info))
	corpo.physics_material_override = _materiale(Parametri.f("rimbalzo_fionda", 0.2), Parametri.f("attrito_gomma", 0.5))
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array(fi)
	corpo.add_child(poly)
	add_child(corpo)
	var n := normale_fionda(fi)
	var a: Vector2 = fi[0]
	var b2: Vector2 = fi[2]
	var area := _area((a + b2) * 0.5 + n * (r_pallina + 1.0), _rett(Vector2(a.distance_to(b2) - 30.0, 6.0)), (b2 - a).angle(), _liv(info))
	var meta := (a + b2) * 0.5
	area.body_entered.connect(func(b):
		if _e_pallina(b) and not tilt:
			# piccola variazione e, dal 4° colpo di fila, spinta dimezzata (niente ping-pong infinito tra le fionde)
			b.fionde_fila = b.fionde_fila + 1 if b.dal_lancio - b.ultima_fionda < 1.2 else 1
			b.ultima_fionda = b.dal_lancio
			var forza := Parametri.f("spinta_fionda", 680.0) * randf_range(0.88, 1.05)
			if b.fionde_fila >= 4:
				forza *= 0.5
			b.respingi(n.rotated(randf_range(-0.12, 0.12)), forza)
			_segnala("fionda", info["id"], meta))

static func normale_fionda(fi: Array) -> Vector2:
	var dd: Vector2 = fi[2] - fi[0]
	var n := Vector2(dd.y, -dd.x).normalized()
	var centro: Vector2 = (fi[0] + fi[1] + fi[2]) / 3.0
	if n.dot((fi[0] + fi[2]) * 0.5 - centro) < 0:
		n = -n
	return n

## Normale di un bersaglio: la faccia che guarda verso le palette (asse +y ruotato dell'angolo).
static func normale_bersaglio(info: Dictionary) -> Vector2:
	return Vector2(0, 1).rotated(info["angolo"])

func _crea_bersaglio(info: Dictionary) -> void:
	var id: String = info["id"]
	var cs := _statico(info["pos"], _rett(info["dim"]), _materiale(float(info.get("rimbalzo", 0.5)), 0.2), info["angolo"], _liv(info))
	_forme_bersagli[id] = cs
	bersagli_giu[id] = false
	_ultimo_colpo[id] = -9.0
	# 23/11 (studio, difetto D2): il colpo si legge dal CONTATTO della pallina con il bersaglio (come l'interruttore
	# vero), con una finestra di 0,1 s per non contarlo due volte. Prima si leggeva entrando in un'area e guardando la
	# velocità DOPO il rimbalzo: i colpi lenti (150 mm/s) e alcuni veloci (2000 mm/s) non contavano.
	var corpo: StaticBody2D = cs.get_parent()
	corpo.set_meta("bersaglio", id)
	corpo.set_meta("info", info)

## Colpo della pallina su un bersaglio fisso o abbattibile (chiamata dal contatto della pallina).
func _colpo_bersaglio(b: Pallina, corpo: Node) -> void:
	var id: String = corpo.get_meta("bersaglio")
	var info: Dictionary = corpo.get_meta("info")
	if b.sul_binario() or bersagli_giu[id] or t_gioco - float(_ultimo_colpo[id]) < 0.1:
		return
	# conta solo sulla faccia (la pallina sta davanti), non da dietro
	if (b.global_position - Vector2(info["pos"])).dot(normale_bersaglio(info)) <= 0.0:
		return
	_ultimo_colpo[id] = t_gioco
	if info["abbattibile"]:
		bersagli_giu[id] = true
		_forme_bersagli[id].set_deferred("disabled", true)
	# una fionda piccola, spinge la pallina lungo la faccia (meno di un bumper)
	if bool(info.get("molla", false)) and not tilt:
		# spinta punta a quel punto, ma mai dentro il bersaglio (resta sempre dal lato della faccia)
		var n := normale_bersaglio(info)
		var dir := n
		if info.has("molla_verso"):
			var v: Vector2 = (Vector2(info["molla_verso"]) - b.global_position).normalized()
			dir = v if v.dot(n) > 0.25 else (v + n).normalized()
		b.respingi(dir.rotated(randf_range(-0.1, 0.1)), Parametri.f("spinta_molla", 760.0))
	_segnala("bersaglio", id, info["pos"])

## Rialza i bersagli abbattibili di un gruppo (appena nessuna pallina ci sta sopra).
func rialza(gruppo: String) -> void:
	for info in d["bersagli"]:
		if info["gruppo"] == gruppo and info["abbattibile"]:
			_rialza_quando_libero(info)

func _rialza_quando_libero(info: Dictionary) -> void:
	for i in 240:
		var libero := true
		for b in palline:
			if is_instance_valid(b) and b.global_position.distance_to(info["pos"]) < 30.0:
				libero = false
		if libero:
			break
		await get_tree().physics_frame
	bersagli_giu[info["id"]] = false
	_forme_bersagli[info["id"]].set_deferred("disabled", false)

func _crea_buca(info: Dictionary) -> void:
	_buche[info["id"]] = info
	var pos: Vector2 = info["pos"]
	var area := _area(pos, _cerchio(info["raggio"]), 0.0, _liv(info))
	if info["tipo"] == "prigione":
		prigionieri[info["id"]] = []
	area.body_entered.connect(func(b):
		if _e_pallina(b):
			_prova_buca(b, info))

## La pallina sopra una buca ci cade (se la buca è aperta, la pallina è sul suo livello e non va troppo veloce).
## Chiamata all'ingresso nell'area e, per le palline lente, a ogni passo (una pallina entrata quando la buca
## la ignorava restava ferma sopra la buca senza cadere: collaudo del Palco, 18/11).
func _prova_buca(b: Pallina, info: Dictionary) -> void:
	if b.tenuta or b.nascosta or b.ignora_buche > 0.0 or b.sul_binario() or b.livello != _liv(info):
		return
	if not buche_aperte.get(info["id"], true):
		return
	# (21/11) la prigione è un cortile chiuso con una sola porta: la pallina che entra resta dentro a qualunque velocità
	# (prima oltre 1800 mm/s rimbalzava sul fondo e tornava fuori: la porta del castello sembrava non funzionare)
	if b.linear_velocity.length() > 1800.0 and info["tipo"] != "prigione":
		return
	if info["tipo"] == "passaggio":
		_entra_passaggio(b, passaggi[info["passaggio"]], info["id"])
	elif info["tipo"] == "prigione":
		_entra_prigione(b, info)
	elif info["tipo"] == "portale":
		# PORTALE (Flipper Spazio): la pallina sparisce nel portale e dopo un attimo esce da questo o da un altro
		b.nascondi(info["pos"])
		in_portale[b] = [info["id"], float(info.get("tempo", 0.9))]
		_segnala("portale", info["id"], info["pos"])
	else:
		b.metti(info["pos"], Vector2.ZERO)
		b.tieni(info["pos"])
		_tenute[b] = [info["tempo"], info]
		_segnala("buca", info["id"], info["pos"])

## Passaggio sotterraneo: la pallina sparisce, viaggia sotto il piano lungo un percorso (a velocità costante,
## così la grafica e le luci possono seguirla) e riappare dall'uscita con direzione e velocità coerenti.
func _entra_passaggio(b: Pallina, p: Dictionary, buca: String) -> void:
	b.nascondi(b.global_position)
	var lung := 0.0
	var perc: PackedVector2Array = p["percorso"]
	for i in range(1, perc.size()):
		lung += perc[i].distance_to(perc[i - 1])
	in_passaggio[b] = [p["id"], 0.0, lung / float(p["vel_interna"])]
	_segnala("passaggio_entrata", buca, b.global_position)

## Posizione della pallina lungo il percorso sotterraneo (0..1) per la grafica.
func posizione_sotterranea(b: Pallina) -> Vector2:
	if not in_passaggio.has(b):
		return b.global_position
	var v: Array = in_passaggio[b]
	var perc: PackedVector2Array = passaggi[v[0]]["percorso"]
	var t: float = clampf(v[1] / v[2], 0.0, 1.0)
	var tot := 0.0
	for i in range(1, perc.size()):
		tot += perc[i].distance_to(perc[i - 1])
	var s := t * tot
	for i in range(1, perc.size()):
		var l := perc[i].distance_to(perc[i - 1])
		if s <= l:
			return perc[i - 1].lerp(perc[i], s / maxf(l, 0.001))
		s -= l
	return perc[perc.size() - 1]

# ================================================================ rampe solide (21/11/2026, regole VPE)
## Dove la rampa è più bassa di LIBERO_SOTTO_RAMPA mm sopra un piano, la pallina che corre su quel piano non può
## passarci sotto: lì la rampa è un SOLIDO (come in Visual Pinball / VPE), con due pareti larghe come la rampa disegnata
## (MEZZA_RAMPA = 19 mm, vista_3d.gd) e una chiusura dove la rampa diventa abbastanza alta. Restano aperti solo l'imbocco
## (con un invito svasato, come le lamiere all'ingresso delle rampe vere) e l'uscita a terra.
## Prima (fino al 21/11) le rampe non avevano nessuna collisione sul piano: una pallina che le colpiva di lato le
const LIBERO_SOTTO_RAMPA := 32.0     # pallina 27 mm + spessore del fondo della rampa e margine
const MEZZA_RAMPA := 19.0
const INVITO_RAMPA := 25.0           # mezza larghezza all'imbocco (si stringe a MEZZA_RAMPA in INVITO_LUNGO mm)
const INVITO_LUNGO := 30.0

func _crea_solido_rampa(bin: Binario, info: Dictionary) -> void:
	# v0.17.1: "solida" della rampa (editor) vale più dell'impostazione di tutto il tavolo
	if bool(info.get("senza_solido", false)) or not bool(info.get("solida", d.get("rampe_solide", true))):
		return
	var livelli := {}
	for lv in [bin.livello, bin.livello_fine, 0]:
		livelli[lv] = true
	for lv in livelli:
		var q := quota_livello(lv)
		var basso := PackedByteArray()
		for i in bin.punti.size():
			var h := bin.altezze[i] - q
			basso.append(1 if h > -1.0 and h < LIBERO_SOTTO_RAMPA else 0)
		var i := 0
		while i < bin.punti.size():
			if basso[i] == 0:
				i += 1
				continue
			var j := i
			while j + 1 < bin.punti.size() and basso[j + 1] == 1:
				j += 1
			if j > i:
				# imbocco a terra (inizio della rampa) e uscita a terra (fine) restano aperti
				var aperto_inizio := i == 0 and absf(bin.altezze[0] - q) < 1.0
				var aperto_fine := j == bin.punti.size() - 1 and absf(bin.altezze[j] - q) < 1.0
				_pareti_rampa(bin, i, j, lv, aperto_inizio, aperto_fine)
			i = j + 1

func _pareti_rampa(bin: Binario, i0: int, i1: int, lv: int, aperto_inizio: bool, aperto_fine: bool) -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = Pallina.bit(lv)
	corpo.physics_material_override = _materiali["metallo"]
	corpo.set_meta("rampa_solida", bin.nome)
	var invito: float = float(_info_rampe[bin.nome].get("invito", INVITO_RAMPA))
	var lati := {1.0: PackedVector2Array(), -1.0: PackedVector2Array()}
	for k in range(i0, i1 + 1):
		var s := bin.lunghezze[k]
		var n := bin.direzione(minf(s, bin.lunghezza - 0.5)).orthogonal()
		var mezza := MEZZA_RAMPA
		if bin.larga():
			mezza = bin.mezza(s)        # nastro alzato: pareti larghe come il nastro disegnato
		elif aperto_inizio and s - bin.lunghezze[i0] < INVITO_LUNGO:
			mezza = lerpf(invito, MEZZA_RAMPA, (s - bin.lunghezze[i0]) / INVITO_LUNGO)
		for lato in [1.0, -1.0]:
			lati[lato].append(bin.punti[k] + n * mezza * lato)
	var linee: Array = [lati[1.0], lati[-1.0]]
	if not aperto_inizio:
		linee.append_array(_chiusura_rampa(lati[1.0][0], lati[-1.0][0], -bin.direzione(bin.lunghezze[i0]), bin.nome))
	if not aperto_fine:
		linee.append_array(_chiusura_rampa(lati[1.0][lati[1.0].size() - 1], lati[-1.0][lati[-1.0].size() - 1], bin.direzione(minf(bin.lunghezze[i1], bin.lunghezza - 0.5)), bin.nome))
	for linea in linee:
		for k in range(linea.size() - 1):
			var seg := SegmentShape2D.new()
			seg.a = linea[k]
			seg.b = linea[k + 1]
			var cs := CollisionShape2D.new()
			cs.shape = seg
			corpo.add_child(cs)
	add_child(corpo)
	pareti_rampe.append([bin.nome, lv, linee])

## Chiusura del tratto solido dove la rampa diventa alta: INCLINATA verso il centro del tavolo, così la pallina che
## scende sotto la parte alta della rampa scivola via invece di fermarsi sopra (caccia agli incastri, 21/11).
## fuori = direzione verso la parte alta della rampa (da dove arriva la pallina che passa sotto).
## Con "chiusura": "fuori" nel disegno della rampa scende invece verso il bordo (quando verso il centro c'è un altro pezzo).
func _chiusura_rampa(a: Vector2, b: Vector2, fuori: Vector2, nome := "") -> Array:
	var cx: float = d["centro_x"]
	var vicino := a if absf(a.x - cx) < absf(b.x - cx) else b
	if str(_info_rampe.get(nome, {}).get("chiusura", "centro")) == "fuori":
		vicino = b if vicino == a else a
	var lontano := b if vicino == a else a
	var punta := lontano + fuori * 30.0
	return [PackedVector2Array([vicino, punta]), PackedVector2Array([lontano, punta])]

func _crea_ingresso_rampa(r: Binario, dall_uscita := false) -> void:
	var dir := r.direzione(0.0)
	var bocca := r.punti[0]
	if dall_uscita:
		dir = -r.direzione(r.lunghezza - 1.0)
		bocca = r.punti[r.punti.size() - 1]
	# bocca della rampa: entra solo la pallina che passa davvero nell'imbocco e sale (non quella che lo sfiora)
	var largo_bocca: float = d["bocca_rampa"]
	if r.larga():
		largo_bocca = maxf(largo_bocca, 2.0 * r.mezza(r.lunghezza if dall_uscita else 0.0) - 6.0)   # nastro: tutta la bocca
	var area := _area(bocca + dir * 4.0, _rett(Vector2(largo_bocca, 10)), dir.angle() + PI / 2.0, r.livello_fine if dall_uscita else r.livello)
	area.body_entered.connect(func(b):
		if not _e_pallina(b):
			return
		var lungo: float = b.linear_velocity.dot(dir)
		# "imbocco_min" (Flipper Spazio, 22/11): velocità minima per salire; 0 per gli imbocchi in discesa (uscita della
		# piattaforma), dove anche una pallina lenta deve prendere il filo invece di fermarsi sul bordo
		var minimo := float(_info_rampe[r.nome].get("imbocco_min", 150.0))
		if not b.tenuta and not b.nascosta and lungo > minimo:
			# niente «risucchio» (19/11): la pallina sale da dove è entrata (spostamento laterale conservato, poi le
			# sponde la portano al centro) e con la sola velocità nella direzione della rampa, non con quella totale
			var rel: Vector2 = b.global_position - bocca
			b.catena.clear()
			if dall_uscita:
				b.sali_su(r, -lungo * 0.95, -rel.dot(dir.orthogonal()), r.lunghezza - maxf(rel.dot(dir), 0.0), true)
			else:
				b.sali_su(r, maxf(lungo * 0.95, 80.0), rel.dot(dir.orthogonal()), maxf(rel.dot(dir), 0.0))
			_segnala("rampa_entrata", r.nome, bocca))

func _crea_sensore(info: Dictionary) -> void:
	var a := _area(info["pos"], _rett(info["dim"]), 0.0, _liv(info))
	var dir: Vector2 = info["dir"]
	a.body_entered.connect(func(b):
		if _e_pallina(b) and not b.sul_binario() and not b.nascosta and b.linear_velocity.dot(dir) > 0.0:
			_segnala("sensore", info["id"], info["pos"]))

## Kicker di recupero nella corsia esterna: di base rimanda su la pallina; con "passaggio" la pallina passa sotto il
## piano lungo quel percorso (Flipper Spazio: kicker destro → di nuovo nella corsia di lancio). Si spegne dopo l'uso.
func _crea_kickback(info: Dictionary) -> void:
	var id: String = info.get("id", "kickback")
	kickback_accesi[id] = true
	var a := _area(info["pos"], _rett(info["dim"]))
	a.body_entered.connect(func(b):
		if _e_pallina(b) and kickback_accesi[id] and not tilt and not b.nascosta and b.linear_velocity.y > 0.0:
			kickback_accesi[id] = false
			if info.has("passaggio"):
				_entra_passaggio(b, passaggi[info["passaggio"]], id)
			else:
				b.metti(b.global_position, Vector2(0, -Parametri.f("kickback", 1500.0)))
			_segnala("kickback", id, info["pos"]))

## Accende i kicker di recupero ("" = tutti).
func accendi_kickback(id := "") -> void:
	for k in kickback_accesi:
		if id == "" or k == id:
			kickback_accesi[k] = true

## Elastico: paletto di gomma che restituisce molta energia (non spinge come un bumper). Segnala il colpo.
func _crea_elastico(info: Dictionary) -> void:
	var c: Vector2 = info["pos"]
	var r: float = info["raggio"]
	_statico(c, _cerchio(r), _materiali["elastico"], 0.0, _liv(info))
	_ultimo_elastico[info["id"]] = -9.0
	var area := _area(c, _cerchio(r + r_pallina + 2.0), 0.0, _liv(info))
	area.body_entered.connect(func(b):
		if _e_pallina(b) and not b.sul_binario() and t_gioco - _ultimo_elastico[info["id"]] > 0.15:
			_ultimo_elastico[info["id"]] = t_gioco
			_segnala("elastico", info["id"], c))

func _crea_paletta(info: Dictionary) -> AnimatableBody2D:
	var verso: float = info["verso"]
	var lung: float = info["lunghezza"]
	var p := AnimatableBody2D.new()
	p.collision_layer = Pallina.bit(_liv(info))
	p.sync_to_physics = true
	p.position = info["perno"]
	p.rotation = _angoli.x * verso
	if _mat_paletta == null:
		_mat_paletta = _materiale(Parametri.f("paletta_rimbalzo", 0.15), Parametri.f("paletta_attrito", 0.6))
		_mat_paletta_ferma = _materiale(Parametri.f("paletta_rimbalzo_ferma", 0.0), Parametri.f("paletta_attrito", 0.6))
	p.physics_material_override = _mat_paletta
	var L := lung * verso
	var sp := float(info.get("spessore", 12.0))
	var cs := CollisionPolygon2D.new()
	cs.polygon = PackedVector2Array([Vector2(0, -sp), Vector2(L, -sp * 0.5), Vector2(L, sp * 0.5), Vector2(0, sp)])
	p.add_child(cs)
	var cs2 := CollisionShape2D.new()
	cs2.shape = _cerchio(sp)
	p.add_child(cs2)
	var cs3 := CollisionShape2D.new()
	cs3.shape = _cerchio(sp * 0.5)
	cs3.position = Vector2(L, 0)
	p.add_child(cs3)
	p.set_meta("info", info)
	add_child(p)
	return p

# ================================================================ palline
func aggiungi_palline(n: int, automatico: bool) -> void:
	for k in n:
		_coda.append(automatico)

func _nuova_pallina(pos: Vector2) -> Pallina:
	var b := Pallina.new()
	b.mass = 1.0
	b.physics_material_override = _materiale(Parametri.f("rimbalzo_pallina", 0.25), Parametri.f("attrito_pallina", 0.12))
	var cs := CollisionShape2D.new()
	cs.shape = _cerchio(r_pallina)
	b.add_child(cs)
	b.position = pos
	b.imposta_livello(0)
	add_child(b)
	b.add_collision_exception_with(_cancello)
	b.set_meta("eccezione", true)
	b.body_entered.connect(func(c):
		_contatti += 1
		if c.has_meta("mobile"):
			_contatto_mobile(b, c)
		elif c.has_meta("bersaglio"):
			_colpo_bersaglio(b, c)
		elif c.has_meta("lama"):
			_colpo_lama(c))
	b.binario_finito.connect(_su_binario_finito)
	b.innesto_passato.connect(_su_innesto)
	palline.append(b)
	pallina_creata.emit(b)
	return b

## Pallina di debug o di test in un punto qualsiasi.
func genera_pallina(pos: Vector2, vel: Vector2) -> Pallina:
	var b := _nuova_pallina(pos)
	b.metti(pos, vel)
	b.dal_lancio = 5.0
	if pos.x < _corsia_x:
		b.remove_collision_exception_with(_cancello)
		b.set_meta("eccezione", false)
	return b

func _su_binario_finito(b: Pallina, bin: Binario, completato: bool) -> void:
	if completato:
		# binari concatenati: in fondo la pallina passa sul binario seguente (scelto dal deviatore, se c'è).
		# 22/11: la prima rampa si conta solo quando la pallina finisce tutto il percorso (dal tetto del Castello
		# può ancora tornare indietro, ora che non c'è più la spinta finta in cima)
		var dopo := prossimo_binario(bin.nome)
		if dopo != "":
			b.catena.append(bin.nome)
			# 22/11: con la stessa velocità, senza più il minimo di 260 mm/s (era una spinta finta in cima)
			b.sali_su(rampe[dopo], b.vel_uscita_binario)
			return
		for n in b.catena:
			_segnala("rampa", n, rampe[n].punti[rampe[n].punti.size() - 1])
		b.catena.clear()
		# 22/11: il punto vero in cui la pallina lascia la rampa (anche se l'ha percorsa al contrario)
		_segnala("rampa", bin.nome, b._teletrasporto[0] if b.in_spostamento() else bin.punti[bin.punti.size() - 1])
		# rampa che finisce dentro una buca (es. Giro del Vulcano → Bocca del Cratere): la buca la prende subito
		var dentro: String = _info_rampe[bin.nome].get("finisce_in", "")
		for info in d["buche"]:
			if info["id"] == dentro and info["tipo"] == "prigione":
				_entra_prigione(b, info)
				if not b.tenuta:
					# prigione piena: la pallina esce dalla porta della prigione
					b.metti(info["uscita"], Vector2(info["uscita_dir"]).normalized() * float(info["uscita_vel"]))
			if info["id"] == dentro and info["tipo"] == "tiene":
				b.metti(info["pos"], Vector2.ZERO)
				b.tieni(info["pos"])
				_tenute[b] = [info["tempo"], info]
				_segnala("buca", info["id"], info["pos"])
	else:
		b.catena.clear()
		_segnala("rampa_fallita", bin.nome, b._teletrasporto[0] if b.in_spostamento() else bin.punti[0])

## v0.30: la pallina passa su un incrocio comunicante. Deviatore «aperto» = cambia strada. «alterna»: una pallina
## per strada; «sempre» / «mai»: fisso; «comandato»: lo aprono e chiudono le missioni (imposta_deviatore).
func _su_innesto(b: Pallina, bin: Binario, k: int) -> void:
	var inn: Dictionary = bin.innesti[k]
	var id := str(inn["id"])
	var cambia := bool(deviatori.get(id, false))
	match str(inn.get("devia", "alterna")):
		"sempre":
			cambia = true
		"mai":
			cambia = false
		"alterna":
			imposta_deviatore(id, not cambia)
	if cambia and rampe.has(inn["verso"]):
		b.cambia_binario(rampe[inn["verso"]], float(inn["s_dest"]))
		_segnala("incrocio", id, bin.posizione(float(inn["s"])))

## Binario che segue `nome` (deviatore o "prosegue_in"); "" se la pallina scende sul piano.
## Pinball Editor 2D v0.9.2: un deviatore con "alterna" cambia strada dopo ogni pallina (una a destra, una a sinistra).
func prossimo_binario(nome: String) -> String:
	for dv in d.get("deviatori", []):
		if dv["rampa"] == nome:
			var verso: String = dv["aperto_verso"] if deviatori[dv["id"]] else dv["chiuso_verso"]
			if bool(dv.get("alterna", false)):
				imposta_deviatore(dv["id"], not deviatori[dv["id"]])
			return verso
	return _info_rampe[nome].get("prosegue_in", "")

func imposta_deviatore(id: String, aperto: bool) -> void:
	if deviatori.get(id, not aperto) != aperto:
		deviatori[id] = aperto
		_segnala("deviatore", id, Vector2.ZERO)

# ================================================================ porte mobili
## Porta: un muro che si apre (sparisce) e si chiude (ricompare appena nessuna pallina ci sta sopra).
func _crea_porta(info: Dictionary) -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = Pallina.bit(_liv(info))
	corpo.physics_material_override = _materiali[info.get("tipo", "metallo")]
	var linea: PackedVector2Array = info["punti"]
	for i in range(linea.size() - 1):
		var seg := SegmentShape2D.new()
		seg.a = linea[i]
		seg.b = linea[i + 1]
		var cs := CollisionShape2D.new()
		cs.shape = seg
		cs.disabled = bool(info.get("aperta", false))
		corpo.add_child(cs)
	add_child(corpo)
	_porte[info["id"]] = corpo
	_info_porte[info["id"]] = info
	porte_aperte[info["id"]] = bool(info.get("aperta", false))

## DEVIATORE SUL PIANO («lama», Pinball Editor 2D v0.15, 24/11): lamina di metallo che ruota sul suo perno tra due
## posizioni (angolo_a, angolo_b) e manda la pallina da una parte o dall'altra. "cambia" = "colpo" (cambia lato ogni
## volta che la pallina la tocca, come il flip-flop dei flipper veri) oppure "missioni" (solo con l'azione delle
## regole). Non si sposta mai addosso a una pallina: aspetta che la zona sia libera (come le porte).
var _lame := {}                      # id -> StaticBody2D
var _lame_occupate := {}             # id -> cambio già in attesa

func _crea_lama(info: Dictionary) -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = Pallina.bit(_liv(info))
	corpo.physics_material_override = _materiali["metallo"]
	corpo.position = info["perno"]
	_lamina(corpo, Vector2.ZERO, Vector2(float(info.get("lunghezza", 60.0)), 0.0), 2.0)
	corpo.set_meta("lama", info["id"])
	corpo.set_meta("info", info)
	lame_in_b[info["id"]] = str(info.get("posizione", "a")) == "b"
	corpo.rotation = float(info.get("angolo_b" if lame_in_b[info["id"]] else "angolo_a", 0.0))
	add_child(corpo)
	_lame[info["id"]] = corpo

func _colpo_lama(corpo: Node) -> void:
	var info: Dictionary = corpo.get_meta("info")
	_segnala("lama", info["id"], info["perno"])
	if str(info.get("cambia", "colpo")) == "colpo":
		muovi_lama(info["id"], "alterna")

## verso: "a", "b" oppure "alterna".
func muovi_lama(id: String, verso: String) -> void:
	if not _lame.has(id) or _lame_occupate.has(id):
		return
	var in_b: bool = not lame_in_b[id] if verso == "alterna" else verso == "b"
	if in_b == lame_in_b[id]:
		return
	_lame_occupate[id] = true
	var corpo: StaticBody2D = _lame[id]
	var info: Dictionary = corpo.get_meta("info")
	# zona spazzata dalla lama: le due posizioni e la corda tra le punte
	var pa: Vector2 = Vector2(info["perno"]) + Vector2(float(info.get("lunghezza", 60.0)), 0).rotated(float(info.get("angolo_a", 0.0)))
	var pb: Vector2 = Vector2(info["perno"]) + Vector2(float(info.get("lunghezza", 60.0)), 0).rotated(float(info.get("angolo_b", 0.0)))
	var giro := PackedVector2Array([pa, info["perno"], pb, pa])
	# la pallina che l'ha appena toccata si allontana; se resta lì vicino si aspetta (max 2 s)
	for i in 480:
		await get_tree().physics_frame
		if i > 24 and not _pallina_vicino_a(giro, r_pallina + 4.0, _liv(info)):
			break
	lame_in_b[id] = in_b
	corpo.rotation = float(info.get("angolo_b" if in_b else "angolo_a", 0.0))
	_lame_occupate.erase(id)
	_segnala("lama_mossa", id, info["perno"])

func apri_porta(id: String, aperta: bool) -> void:
	if porte_aperte[id] == aperta:
		return
	porte_aperte[id] = aperta
	_segnala("porta", id, _info_porte[id]["punti"][0])
	if not aperta:
		# chiude solo quando nessuna pallina è sulla linea della porta (mai una pallina dentro un muro)
		for i in 480:
			if not _pallina_vicino_a(_info_porte[id]["punti"], r_pallina + 3.0, _liv(_info_porte[id])):
				break
			await get_tree().physics_frame
		if porte_aperte[id]:
			return
	for cs in _porte[id].get_children():
		cs.set_deferred("disabled", aperta)

func _pallina_vicino_a(linea: PackedVector2Array, dist: float, liv: int) -> bool:
	for b in palline:
		if not is_instance_valid(b) or b.sul_binario() or b.nascosta or b.livello != liv:
			continue
		for i in range(linea.size() - 1):
			if Geometry2D.get_closest_point_to_segment(b.global_position, linea[i], linea[i + 1]).distance_to(b.global_position) < dist:
				return true
	return false

# ================================================================ spinner
## Spinner: lamina che gira quando la pallina passa; più veloce passa, più giri (e punti).
func _crea_spinner(info: Dictionary) -> void:
	var id: String = info["id"]
	spinner_giri[id] = 0
	spinner_vel[id] = 0.0
	spinner_verso[id] = 1.0
	if info.has("rampa"):
		# _spinner_su_rampa, quando una pallina che percorre la rampa passa il punto dello spinner (in salita o in discesa)
		_spinner_rampa[id] = rampe[info["rampa"]].s_vicino(info["pos"])
		return
	var dir := Vector2(0, -1).rotated(float(info.get("angolo", 0.0)))
	var a := _area(info["pos"], _rett(Vector2(info["larghezza"], 8)), float(info.get("angolo", 0.0)), _liv(info))
	a.body_entered.connect(func(b):
		if not _e_pallina(b) or b.sul_binario() or b.nascosta:
			return
		var vd: float = b.linear_velocity.dot(dir)
		var v := absf(vd)
		if v < 60.0:
			return
		spinner_verso[id] = signf(vd)
		# come uno spinner vero: al massimo ~12 giri al secondo, poi rallenta e si ferma in 2-3 secondi
		spinner_giri[id] = clampi(int(v / 140.0), 1, 16)
		spinner_vel[id] = minf(v / 90.0, 12.0)
		_segnala("spinner", id, info["pos"]))

var _spinner_rampa := {}             # id spinner montato su una rampa -> distanza lungo la rampa (mm)
var _s_prec := {}                    # Pallina -> [nome rampa, ultima distanza lungo la rampa]

## Spinner montati sulle rampe: un giro di conti per ogni pallina che passa il punto dello spinner sulla sua rampa.
func _spinner_su_rampa(delta: float) -> void:
	for b in palline:
		if not is_instance_valid(b) or not b.sul_binario():
			_s_prec.erase(b)
			continue
		var nome: String = b.binario.nome
		var s := b.posizione_binario()
		var prec: Array = _s_prec.get(b, [nome, s])
		_s_prec[b] = [nome, s]
		if prec[0] != nome:
			continue
		for sp in d.get("spinner", []):
			if sp.get("rampa", "") != nome:
				continue
			var punto: float = _spinner_rampa[sp["id"]]
			if (prec[1] - punto) * (s - punto) <= 0.0 and prec[1] != s:
				var v := absf(s - float(prec[1])) / maxf(delta, 0.0001)
				if v < 60.0:
					continue
				# 22/11: gira nel verso in cui passa la pallina (in salita o in discesa)
				spinner_verso[sp["id"]] = signf(s - float(prec[1]))
				spinner_giri[sp["id"]] = clampi(int(v / 140.0), 1, 16)
				spinner_vel[sp["id"]] = minf(v / 90.0, 12.0)
				_segnala("spinner", sp["id"], sp["pos"])

# ================================================================ captive ball
## Pallina prigioniera in un canale: la pallina di gioco la colpisce, lei corre verso il bersaglio in fondo al canale.
## Un fermo (strato 128, che la pallina di gioco non vede) le impedisce di uscire dall'imbocco.
func _crea_captive(info: Dictionary) -> void:
	var id: String = info["id"]
	var cb := RigidBody2D.new()
	cb.mass = 1.0
	cb.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	cb.can_sleep = false
	cb.collision_layer = 1
	cb.collision_mask = 1 | 128
	cb.physics_material_override = _materiale(0.3, 0.1)
	var cs := CollisionShape2D.new()
	cs.shape = _cerchio(r_pallina)
	cb.add_child(cs)
	cb.position = info["casa"]
	add_child(cb)
	captive[id] = cb
	var fermo := StaticBody2D.new()
	fermo.collision_layer = 128
	fermo.collision_mask = 0
	var seg := SegmentShape2D.new()
	seg.a = info["fermo"][0]
	seg.b = info["fermo"][1]
	var csf := CollisionShape2D.new()
	csf.shape = seg
	fermo.add_child(csf)
	add_child(fermo)
	_ultimo_colpo[id] = -9.0
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 1
	a.position = info["bersaglio"]
	var csa := CollisionShape2D.new()
	csa.shape = _cerchio(r_pallina + 4.0)
	a.add_child(csa)
	add_child(a)
	a.body_entered.connect(func(b):
		if b == cb and t_gioco - _ultimo_colpo[id] > 0.4:
			_ultimo_colpo[id] = t_gioco
			_segnala("captive", id, info["bersaglio"]))

# ================================================================ bersagli mobili
## Bersaglio che scorre avanti e indietro tra "da" e "a" (periodo in secondi). Conta il colpo sulla faccia.
func _crea_bersaglio_mobile(info: Dictionary) -> void:
	var id: String = info["id"]
	var corpo := AnimatableBody2D.new()
	corpo.sync_to_physics = true
	corpo.collision_layer = Pallina.bit(_liv(info))
	corpo.physics_material_override = _materiale(0.6, 0.2)
	corpo.position = info["da"]
	corpo.rotation = float(info.get("angolo", 0.0))
	var cs := CollisionShape2D.new()
	cs.shape = _rett(info["dim"])
	corpo.add_child(cs)
	corpo.set_meta("info", info)
	corpo.set_meta("mobile", id)
	add_child(corpo)
	mobili[id] = corpo
	_ultimo_colpo[id] = -9.0

## Colpo su un bersaglio mobile: si legge dal contatto della pallina (un'area che si muove perdeva i colpi veloci).
## Conta solo se la pallina sta davanti alla faccia.
func _contatto_mobile(b: Pallina, corpo: Node) -> void:
	var id: String = corpo.get_meta("mobile")
	var n := Vector2(0, 1).rotated(corpo.rotation)
	var info0: Dictionary = corpo.get_meta("info")
	var davanti: bool = bool(info0.get("due_facce", false)) or (b.global_position - corpo.position).dot(n) > 0.0
	if not davanti or t_gioco - _ultimo_colpo[id] < 0.3:
		return
	_ultimo_colpo[id] = t_gioco
	_segnala("bersaglio", id, corpo.position)
	# "sparisce" secondi (solo se il disegno del tavolo lo chiede)
	var info: Dictionary = corpo.get_meta("info")
	if float(info.get("sparisce", 0.0)) > 0.0:
		mobili_via[id] = t_gioco + float(info["sparisce"])
		corpo.set_deferred("collision_layer", 0)

## Il bersaglio mobile è in campo (false = colpito, sparito per qualche secondo).
func mobile_visibile(id: String) -> bool:
	return not mobili_via.has(id)

## Torna in campo solo quando nessuna pallina è sulla sua strada (non ricompare addosso a una pallina).
func _ritorno_mobili() -> void:
	for id in mobili_via.keys():
		if t_gioco < float(mobili_via[id]):
			continue
		var info: Dictionary = mobili[id].get_meta("info")
		var a: Vector2 = info["da"]
		var b: Vector2 = info["a"]
		var libero := true
		for p in palline:
			if is_instance_valid(p) and Geometry2D.get_closest_point_to_segment(p.global_position, a, b).distance_to(p.global_position) < 30.0:
				libero = false
		if libero:
			mobili_via.erase(id)
			mobili[id].collision_layer = Pallina.bit(_liv(info))

# ================================================================ prigione (ball lock con palline visibili)
func _entra_prigione(b: Pallina, info: Dictionary) -> void:
	var id: String = info["id"]
	var posti: Array = info["posti"]
	if _in_rilascio.get(id, false) or prigionieri[id].size() >= posti.size():
		return
	var p: Vector2 = posti[prigionieri[id].size()]
	prigionieri[id].append(b)
	b.metti(p, Vector2.ZERO)
	b.tieni(p)
	# nel cortile la pallina non urta niente (i posti possono stare dentro i muri del castello)
	b.collision_layer = 0
	b.collision_mask = 0
	_segnala("prigione", id, p)

## Libera le palline della prigione, una ogni `intervallo` secondi, dall'uscita indicata nel disegno.
func libera_prigione(id: String, intervallo := 0.5) -> void:
	var info: Dictionary = {}
	for x in d["buche"]:
		if x["id"] == id:
			info = x
	_in_rilascio[id] = true
	while not prigionieri[id].is_empty():
		var b: Pallina = prigionieri[id].pop_back()
		if is_instance_valid(b):
			var dir: Vector2 = Vector2(info["uscita_dir"]).normalized().rotated(randf_range(-0.1, 0.1))
			b.punto_tenuta = info["uscita"]
			b.imposta_livello(b.livello, b.quota)
			b.rilascia(dir * float(info["uscita_vel"]))
			b.ignora_buche = 1.0
		await get_tree().create_timer(intervallo, false).timeout
	_in_rilascio[id] = false

func _scarica(b: Pallina) -> void:
	palline.erase(b)
	_tenute.erase(b)
	in_passaggio.erase(b)
	in_portale.erase(b)
	for id in prigionieri:
		prigionieri[id].erase(b)
	if pallina_in_corsia == b:
		pallina_in_corsia = null
	b.queue_free()
	pallina_persa.emit(b, palline.size() + _coda.size())

func togli_tutte() -> void:
	for b: Pallina in palline.duplicate():
		b.queue_free()
	palline.clear()
	_coda.clear()
	_tenute.clear()
	in_passaggio.clear()
	in_portale.clear()
	for id in prigionieri:
		prigionieri[id].clear()
	pallina_in_corsia = null
	caricando = false
	carica = 0.0

func palline_totali() -> int:
	return palline.size() + _coda.size()

func lancia(forza: float) -> void:
	if pallina_in_corsia == null:
		return
	var b := pallina_in_corsia
	pallina_in_corsia = null
	caricando = false
	carica = 0.0
	# 23/11: carica progressiva (più fine all'inizio, dove ci sono bumper e skill shot)
	var c := pow(clampf(forza, 0.0, 1.0), Parametri.f("lancio_curva", 1.0))
	var v := lerpf(Parametri.f("lancio_min", 1450.0), Parametri.f("lancio_max", 2300.0), c)
	b.metti(_lancio_pos, Vector2(0, -v))
	b.dal_lancio = 0.0
	_segnala("lancio", "lancio", _lancio_pos)

func spingi(direzione: Vector2) -> void:
	for b in palline:
		if not b.tenuta and not b.sul_binario():
			b.aggiungi_vel(direzione * Parametri.f("spinta_nudge", 160.0))

## C'è una pallina nella corsia di lancio che aspetta la molla del GIOCATORE? (21/11: nel multiball le palline
## partono da sole: in quel momento il tocco in basso a destra deve restare la paletta destra, non la molla.)
func aspetta_molla() -> bool:
	return pallina_in_corsia != null and _auto_lancio <= 0.0

func inizia_carica() -> void:
	if pallina_in_corsia != null:
		caricando = true

func rilascia_carica() -> void:
	if caricando:
		lancia(carica)

func _corsia_libera() -> bool:
	for b in palline:
		if b.global_position.x > _corsia_x and b.global_position.y > 850:
			return false
	return true

func _intervento(b: Pallina, tipo: String) -> void:
	incastri += 1
	registro_incastri.append([tipo, b.global_position.round(), "palline:%d" % palline.size()])
	if Parametri.argomenti.has("traccia"):
		print(tipo, " ", b.global_position.round())

# ================================================================ passo fisico
func _physics_process(delta: float) -> void:
	t_gioco += delta
	for id in mobili:
		var info: Dictionary = mobili[id].get_meta("info")
		var fase := 0.5 - 0.5 * cos(TAU * t_gioco / float(info["periodo"]))
		mobili[id].position = Vector2(info["da"]).lerp(info["a"], fase)
	_ritorno_mobili()
	for id in spinner_vel:
		spinner_vel[id] = move_toward(spinner_vel[id] * exp(-1.2 * delta), 0.0, delta * 1.5)
	if not _spinner_rampa.is_empty():
		_spinner_su_rampa(delta)
	for cinfo in d.get("captive", []):
		var cb: RigidBody2D = captive[cinfo["id"]]
		# rete di sicurezza: se mai uscisse dal canale torna a casa
		if cb.global_position.distance_to(cinfo["casa"]) > float(cinfo.get("corsa", 120.0)) + 30.0:
			cb.linear_velocity = Vector2.ZERO
			cb.global_position = cinfo["casa"]
			incastri += 1
			registro_incastri.append(["CAPTIVE", cinfo["casa"], ""])
	_t_contatti += delta
	if _t_contatti >= 1.0:
		collisioni = _contatti
		_contatti = 0
		_t_contatti = 0.0
	if pallina_in_corsia == null and not _coda.is_empty() and _corsia_libera():
		var auto: bool = _coda.pop_front()
		pallina_in_corsia = _nuova_pallina(_lancio_pos)
		_auto_lancio = 0.6 if (auto or autoplay) else -1.0
	if pallina_in_corsia != null:
		if autoplay and _auto_lancio < 0.0:
			_auto_lancio = 0.8
		if _auto_lancio > 0.0:
			_auto_lancio -= delta
			if _auto_lancio <= 0.0:
				_auto_lancio = -1.0
				lancia(randf_range(0.4, 1.0) if autoplay else 0.9)
		elif caricando:
			carica = minf(1.0, carica + delta / Parametri.f("lancio_tempo_carica", 0.9))
	_campi_passo(delta)
	# buche che tengono la pallina: espulsione
	for b: Pallina in _tenute.keys():
		# la pallina non è più tenuta (tolta, salita su una rampa...): la buca la dimentica, non la richiama (18/11)
		if not is_instance_valid(b) or not b.tenuta:
			_tenute.erase(b)
			continue
		_tenute[b][0] -= delta
		if _tenute[b][0] <= 0.0:
			var info: Dictionary = _tenute[b][1]
			_tenute.erase(b)
			var dir: Vector2 = Vector2(info["uscita_dir"]).normalized().rotated(randf_range(-0.12, 0.12))
			b.rilascia(dir * float(info["uscita_vel"]))
	# portali: dopo il tempo la pallina esce dal portale scelto dalle regole (di base lo stesso)
	for b: Pallina in in_portale.keys():
		if not is_instance_valid(b):
			in_portale.erase(b)
			continue
		in_portale[b][1] -= delta
		if in_portale[b][1] <= 0.0:
			var da: String = in_portale[b][0]
			in_portale.erase(b)
			var info_p: Dictionary = _buche.get(str(portale_dest.get(da, da)), _buche[da])
			var dir_p: Vector2 = Vector2(info_p["uscita_dir"]).normalized().rotated(randf_range(-0.1, 0.1))
			b.riappari(info_p["pos"], dir_p * float(info_p["uscita_vel"]))
			b.ignora_buche = 1.0
			_segnala("portale_uscita", info_p["id"], info_p["pos"])
	# passaggi sotterranei: avanzamento e uscita
	for b: Pallina in in_passaggio.keys():
		if not is_instance_valid(b):
			in_passaggio.erase(b)
			continue
		in_passaggio[b][1] += delta
		if in_passaggio[b][1] >= in_passaggio[b][2]:
			var p: Dictionary = passaggi[in_passaggio[b][0]]
			in_passaggio.erase(b)
			var var_ang: float = p["variazione"]
			var dir: Vector2 = Vector2(p["uscita_dir"]).normalized().rotated(randf_range(-var_ang, var_ang))
			var lu := int(p.get("uscita_livello", 0))
			b.riappari(p["uscita"], dir * float(p["uscita_vel"]) * randf_range(0.92, 1.08), lu, quota_livello(lu))
			b.ignora_buche = 0.8
			_segnala("passaggio_uscita", p["id"], p["uscita"])
	# palette tenute alzate (dal giocatore o dal pilota automatico): le palline ferme SU QUELLE palette non sono
	# incastrate. Solo vicino alla paletta: prima bastava tenere premuto per spegnere le sicurezze su tutto il tavolo
	var alzate: Array = []
	for id in palette:
		var inf: Dictionary = palette[id].get_meta("info")
		if Comandi.premuto(inf["comando"]) or palette[id].get_meta("su", false):
			alzate.append([Vector2(inf["perno"]), float(inf["lunghezza"]) + 25.0, int(inf.get("livello", 0))])
	var dim: Vector2 = d["dimensioni"]
	for b in palline.duplicate():
		if not is_instance_valid(b):
			palline.erase(b)
			continue
		var pp: Vector2 = b.global_position
		var tiene := false
		for al in alzate:
			tiene = tiene or (pp.distance_to(al[0]) < al[1] and b.livello == al[2])
		b.dal_lancio += delta
		if b.ignora_buche > 0.0:
			b.ignora_buche -= delta
		if b.sul_binario() or b.tenuta or b.nascosta:
			b.ferma_da = 0.0
			b.ancora_t = 0.0
			continue
		# 23/11: la pallina può attraversare il cancelletto solo se arriva dalla corsia di lancio (lo attraversa nel
		# senso del lancio); con il canale curvo lo perde solo dopo essere uscita del tutto (margine nel_canale).
		var in_corsia := pp.x > _corsia_x or nel_canale(pp, 0.14)
		var ecc: bool = b.get_meta("eccezione")
		if pp.x > _corsia_x and not ecc:
			b.add_collision_exception_with(_cancello)
			b.set_meta("eccezione", true)
		elif not in_corsia and ecc and (pp.x < _corsia_x - 20.0 or not _canale.is_empty()):
			b.remove_collision_exception_with(_cancello)
			b.set_meta("eccezione", false)
		if b != pallina_in_corsia and pp.x > _corsia_x and pp.y > 980 and b.dal_lancio > 0.6 \
				and b.linear_velocity.length() < 40 and pallina_in_corsia == null:
			pallina_in_corsia = b
			_auto_lancio = 0.5 if autoplay else -1.0
			_segnala("ricaduta", "lancio", pp)
		# sicurezza 1: pallina ferma (non sulle palette tenute alzate)
		if b != pallina_in_corsia and not tiene and b.linear_velocity.length() < 8.0:
			b.ferma_da += delta
			if b.ferma_da > 2.5:
				b.ferma_da = 0.0
				_intervento(b, "FERMA")
				b.aggiungi_vel(Vector2(randf_range(-250, 250), -320))
		else:
			b.ferma_da = 0.0
		# sicurezza 2: ping-pong (resta 3,5 s in un cerchio di 35 mm pur muovendosi)
		if pp.distance_to(b.ancora) > 35.0 or tiene or in_corsia:
			b.ancora = pp
			b.ancora_t = 0.0
		else:
			b.ancora_t += delta
			if b.ancora_t > 3.5:
				b.ancora_t = 0.0
				_intervento(b, "PING-PONG")
				b.aggiungi_vel(Vector2(signf(float(d["centro_x"]) - pp.x) * 220.0, -320))
		# palline lente sopra una buca: ci cadono
		if b.ignora_buche <= 0.0 and b.linear_velocity.length() < 300.0:
			for info in d["buche"]:
				if pp.distance_to(info["pos"]) < float(info["raggio"]) + r_pallina * 0.5:
					_prova_buca(b, info)
					break
		# sicurezza 4: pallina di un piano rialzato uscita dalla sua zona → rimessa dentro, verso il centro del piano
		if b.livello > 0 and not b.in_spostamento():
			var zona = d.get("livelli", {}).get(b.livello, {}).get("zona", null)
			if zona != null and not Geometry2D.is_point_in_polygon(pp, zona) and (bool(d["livelli"][b.livello].get("bordo_aperto", false)) or _da_un_varco(pp, d["livelli"][b.livello])):
				# Pinball Editor 2D v0.9: piano col BORDO APERTO: la pallina che ne esce cade giù sul tavolo
				var nome_piano := str(d["livelli"][b.livello].get("nome", ""))
				b.imposta_livello(0)
				_segnala("caduta_piano", nome_piano, pp)
			elif zona != null and not Geometry2D.is_point_in_polygon(pp, zona):
				_intervento(b, "LIVELLO")
				var centro := Vector2.ZERO
				for q in zona:
					centro += q
				centro /= float(zona.size())
				b.metti(pp.lerp(centro, 0.35), Vector2.ZERO)
		# sicurezza 3: pallina fuori dal tavolo → rimessa nella bocca del cratere (prima buca "tiene")
		if pp.y > dim.y + 200 or pp.x < -50 or pp.x > dim.x + 50 or pp.y < -150:
			_intervento(b, "FUORI")
			b.imposta_livello(0)
			for info in d["buche"]:
				if info["tipo"] == "tiene":
					b.metti(info["pos"], Vector2.ZERO)
					b.tieni(info["pos"])
					_tenute[b] = [0.8, info]
					break
	# palette
	for id in palette:
		var p: AnimatableBody2D = palette[id]
		var info: Dictionary = p.get_meta("info")
		var su := Comandi.premuto(info["comando"])
		if autoplay:
			su = _decidi(id, info, delta)
		if tilt:
			su = false
		p.set_meta("su", su)
		_muovi(p, su, delta)

func paletta_alzata(id: String) -> bool:
	return palette[id].get_meta("su", false)

## Giocatore automatico (prove e partite di collaudo): alza la paletta quando la pallina arriva sulla sua parte utile.
func _decidi(id: String, info: Dictionary, delta: float) -> bool:
	_auto[id] -= delta
	if _auto[id] > 0.0:
		return _auto[id] > 0.15
	var verso: float = info["verso"]
	var lung: float = info["lunghezza"]
	var punta: Vector2 = info["perno"] + Vector2(lung * 0.6 * verso, minf(22.0, lung * 0.3))   # (mini paletta: più vicino)
	for b in palline:
		if not b.sul_binario() and not b.nascosta and b.livello == _liv(info) and b.global_position.distance_to(punta) < lung * 0.7 and b.linear_velocity.y > -50:
			_auto[id] = 0.45 + randf_range(-0.12, 0.12)
			return true
	return false

func _muovi(p: AnimatableBody2D, su: bool, delta: float) -> void:
	var verso: float = p.get_meta("info")["verso"]
	var obiettivo := (_angoli.y if su else _angoli.x) * verso
	var vel := Parametri.f("paletta_vel_su", 26.0) if su else Parametri.f("paletta_vel_giu", 13.0)
	p.rotation = move_toward(p.rotation, obiettivo, vel * delta)
	# paletta ferma in alto e tenuta (la bobina la blocca): la gomma rimbalza meno, così la pallina che arriva dalle
	# corsie non salta via (18/11). Mentre si muove resta la gomma normale: i tiri non cambiano.
	var ferma: bool = su and is_equal_approx(p.rotation, obiettivo)
	if ferma != p.get_meta("ferma", false):
		p.set_meta("ferma", ferma)
		p.physics_material_override = _mat_paletta_ferma if ferma else _mat_paletta


# ================================================================ canale di lancio curvo (23/11)
## La pallina è dentro il canale curvo che porta la corsia di lancio lungo l'arco (fino all'uscita col cancelletto)?
func nel_canale(p: Vector2, margine := 0.0) -> bool:
	if _canale.is_empty():
		return false
	var v: Vector2 = p - Vector2(_canale["centro"])
	var r := v.length()
	var a := v.angle()
	return r > float(_canale["r_dentro"]) - 2.0 and r < float(_canale["r_fuori"]) + 2.0 \
		and a >= float(_canale["angolo_uscita"]) - 0.02 - margine and a <= 0.02

# ================================================================ campi: pozzo di gravità e magnete (23/11)
func accendi_campo(id: String, acceso: bool) -> void:
	if campi_accesi.get(id, not acceso) != acceso:
		campi_accesi[id] = acceso
		_segnala("campo_acceso" if acceso else "campo_spento", id, campi[id]["pos"])

## Magnete (pulsante «speciale», Magna-Save): prende la pallina vicina e LENTA, la tiene, poi la rilancia.
## Tempi da MPF (studio 3b): presa 1,5 s, rilascio 0,5 s. Restituisce false se non c'è una pallina da prendere.
func attiva_magnete(id: String) -> bool:
	var cp: Dictionary = campi[id]
	for b in palline:
		if is_instance_valid(b) and not b.tenuta and not b.nascosta and not b.sul_binario() and b.livello == _liv(cp) \
				and b.global_position.distance_to(cp["pos"]) < float(cp["raggio"]) \
				and b.linear_velocity.length() < float(cp.get("vel_max_presa", 900.0)):
			_magnete_stato[id] = ["prendi", float(cp.get("tempo_presa", 1.5)), b]
			_segnala("magnete_presa", id, cp["pos"])
			return true
	_segnala("magnete_vuoto", id, cp["pos"])
	return false

func _campi_passo(delta: float) -> void:
	for id in campi:
		var cp: Dictionary = campi[id]
		var c: Vector2 = cp["pos"]
		var r: float = cp["raggio"]
		if cp["tipo"] == "pozzo" and campi_accesi[id] and not tilt:
			# pozzo di gravità: accelerazione verso il centro, più forte vicino (limite per non «sparare» la pallina)
			for b in palline:
				if not is_instance_valid(b) or b.tenuta or b.nascosta or b.sul_binario() or b.livello != _liv(cp):
					continue
				var v: Vector2 = c - b.global_position
				var dist := v.length()
				if dist < r and dist > 2.0:
					var forza := float(cp.get("forza", 2400.0)) * clampf(r / maxf(dist, 1.0), 1.0, 3.0) * (1.0 - dist / r * 0.5)
					b.aggiungi_vel(v / dist * forza * delta)
		elif cp["tipo"] == "magnete" and _magnete_stato.has(id):
			var st: Array = _magnete_stato[id]
			var b = st[2]
			if not is_instance_valid(b) or b.nascosta or b.sul_binario():
				_magnete_stato.erase(id)
				continue
			st[1] -= delta
			if st[0] == "prendi":
				# attira e frena: la pallina si ferma sul magnete
				var v: Vector2 = c - b.global_position
				if v.length() < 4.0 and b.linear_velocity.length() < 80.0:
					if not b.tenuta:
						b.metti(c, Vector2.ZERO)
						b.tieni(c)
				else:
					b.aggiungi_vel(v.normalized() * float(cp.get("forza", 6000.0)) * delta - b.linear_velocity * minf(1.0, 8.0 * delta))
				if st[1] <= 0.0:
					st[0] = "lascia"
					st[1] = float(cp.get("tempo_rilascio", 0.5))
			elif st[1] <= 0.0:
				_magnete_stato.erase(id)
				var dir := Vector2(cp.get("lancio_dir", Vector2(0, -1))).normalized()
				if b.tenuta:
					b.rilascia(dir * float(cp.get("lancio_vel", 900.0)))
				else:
					b.aggiungi_vel(dir * float(cp.get("lancio_vel", 900.0)))
				_segnala("magnete_lancio", id, c)

## Pinball Editor 2D v0.29: la pallina uscita dal piano è passata da un VARCO del bordo? (entro 30 mm dal varco)
static func _da_un_varco(pp: Vector2, livello: Dictionary) -> bool:
	for v in livello.get("varchi", []):
		if Geometry2D.get_closest_point_to_segment(pp, v[0], v[1]).distance_to(pp) < 30.0:
			return true
	return false
