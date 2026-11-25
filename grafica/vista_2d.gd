## (decisione 3 del README). Disegna il tavolo dagli STESSI numeri della fisica, per ora a forme semplici: le
## Legge solo posizioni ed eventi: non tocca mai la fisica né le regole (architettura a tre livelli, doc. 03 §3.5).
##
##   _statico  piano, muri, fionde, bumper, buche, Palco: disegnato UNA volta
##   _inserti  luci del piano: un Polygon2D per luce, si cambia solo il colore, un terzo per aggiornamento, 12 al secondo
##   _dinamico bersagli, pezzi mobili, palette, molla, palline sul piano: ogni fotogramma
##   _rampe    rampe (plastica bassa e fili alti) semitrasparenti: disegnate una volta, SOPRA le palline del piano
##   _sopra    palline sulle rampe e spinner: ogni fotogramma
##   _lampi    bagliori additivi degli eventi
class_name Vista2D
extends Node

const VISUALI := ["fissa"]
const NOMI_VISUALI := {"fissa": "Tavolo intero"}
const ALTEZZA_HUD := 150.0             # px (schermo 720 di larghezza) in alto per il tabellone
const MARGINE := 8.0                   # mm di bordo intorno al tavolo
const RAMPA_SOLIDA := 32.0             # mm: sotto questa quota la rampa è un tratto solido (plastica), sopra filo
## facce di spinner e bersagli) sono IMMAGINI PRONTE in <cartella_grafica>/pronte/, fatte una volta con
## `godot --path . -- --prerendi` (stesso disegno di questo file). Il gioco le mostra e basta: 1 disegno per pezzo.
const PX_STRATI := 2.0                 # pixel per mm degli strati grandi (come la tavola)
const PX_PEZZI := 6.0                  # pixel per mm dei pezzi piccoli
const PEZZI_PRONTI := ["spinner_rosso", "spinner_azzurro", "bersaglio", "bersaglio_giu", "paletta",
	"paletta_mini", "fionda_sx", "fionda_dx"]

const C_FONDO := Color(0.05, 0.05, 0.07)
const C_LEGNO := Color(0.45, 0.3, 0.17)
const C_METALLO := Color(0.72, 0.74, 0.78)
const C_GOMMA := Color(0.1, 0.1, 0.1)
const C_CREMA := Color(0.93, 0.86, 0.7)

var visuale := "fissa"
# colori e cartella grafica del tavolo (desc["colori"], desc["cartella_grafica"])
var C_ROSSO := Color(0.86, 0.0, 0.1)
var C_AZZURRO := Color(0.12, 0.6, 0.92)
var C_PIANO := Color(0.19, 0.18, 0.2)
var C_PIANO_2 := Color(0.23, 0.22, 0.24)
var C_PALCO := Color(0.42, 0.18, 0.2)
var CARTELLA := "res://grafica/"
var PRONTE := "res://grafica/pronte/"
var regia: RegiaLuci2D
var desc: Dictionary
var tavolo: TavoloFisico
var regole: RegoleBase

var _mondo: Node2D
var _cam: Camera2D
var _statico: Node2D
var _inserti: Node2D
var _dinamico: Node2D
var _rampe: Node2D
var _giochi_sotto: Node2D             # v0.18.1: giocattoli (immagini che si muovono) sotto e sopra i pezzi
var _giochi_sopra: Node2D
var _giochi: Array = []               # [Sprite2D, decorazione, tempo che resta della reazione]
var _sopra: Node2D
var _lampi_n: Node2D
var _font: Font
var _ins := {}                         # id inserto -> [Polygon2D, colore base]
var _cappelli := {}                    # id bumper -> Polygon2D del cappello (si accende con la regia)
var _flash := {}                       # id pezzo colpito -> secondi di lampo rimasti (bumper, fionde, bersagli)
var guida: GuidaTiro2D
var _scritta_anim: Sprite2D
var _ambiente_k := 1.0
var elementi := {}                     # <cartella_grafica>/elementi.json: immagini del tavolo per id (in mm)
var _immagini := {}                    # id -> Sprite2D
var _posti_prigione: Array = []        # posti disegnati nell'immagine del castello (mm)
var _t := 0.0
var _scossa := Vector2.ZERO
var _spinner_ang := {}
var _forme_palette := {}
var _lampi: Array = []                 # [posizione, colore, raggio, tempo rimasto, durata]
var _sfumata: Texture2D
var _colore_rampa := {}                # id rampa -> colore
var _mobili_x := {}                    # id bersaglio mobile -> x del fotogramma prima (per sapere dove va)
var _mobili_verso := {}
var _pronte := {}                      # nome -> Texture2D dei pezzi pronti
var _accesi: Node2D                    # palette e fionde: mai scurite dalla luce d'ambiente
var _cotte := {}                       # id fionda -> [immagine cotta all'avvio, riquadro in mm] (v0.5)

func prepara(d: Dictionary, t: TavoloFisico, r: RegoleBase) -> void:
	desc = d
	tavolo = t
	regole = r
	var cc: Dictionary = desc.get("colori", {})
	C_ROSSO = cc.get("primario", C_ROSSO)
	C_AZZURRO = cc.get("secondario", C_AZZURRO)
	C_PIANO = cc.get("piano", C_PIANO)
	C_PIANO_2 = cc.get("piano_2", C_PIANO_2)
	C_PALCO = cc.get("livello", C_PALCO)
	CARTELLA = str(desc.get("cartella_grafica", CARTELLA))
	PRONTE = CARTELLA + "pronte/"
	_font = load("res://interfaccia/font/NotoSansDisplay-Bold.ttf")
	RenderingServer.set_default_clear_color(C_FONDO)
	var colori: Dictionary = desc.get("colori", {}).get("rampe", {}) if desc.get("colori", {}) is Dictionary else {}
	for ra in desc["rampe"]:
		_colore_rampa[ra["id"]] = ra.get("colore", colori.get(ra["id"], C_AZZURRO))
	_mondo = Node2D.new()
	add_child(_mondo)
	_carica_elementi()
	if not Parametri.argomenti.has("prerendi"):
		for nome in PEZZI_PRONTI:
			if ResourceLoader.exists(PRONTE + nome + ".png"):
				_pronte[nome] = load(PRONTE + nome + ".png")
	_crea_fondo()
	_statico = _strato("statico", _disegna_statico)
	_giochi_sotto = Node2D.new()
	_mondo.add_child(_giochi_sotto)
	_crea_immagini()
	var buche_n := _nodo(_disegna_buche)
	_crea_scritte()
	_inserti = Node2D.new()
	_mondo.add_child(_inserti)
	_crea_inserti()
	_crea_cappelli()
	var cfg_luci: Script = load(desc["luci"])
	regia = RegiaLuci2D.new()
	_mondo.add_child(regia)
	guida = GuidaTiro2D.new()
	_mondo.add_child(guida)
	# strato che la luce d'ambiente NON scurisce (Notte in città, spettacoli): restano sempre accese
	_accesi = _nodo(_disegna_accesi)
	_dinamico = _nodo(_disegna_dinamico)
	_rampe = _strato("rampe", _disegna_rampe)
	_giochi_sopra = Node2D.new()
	_mondo.add_child(_giochi_sopra)
	_crea_giocattoli()
	_sopra = _nodo(_disegna_sopra)
	_lampi_n = _nodo(_disegna_lampi)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lampi_n.material = add
	_cam = Camera2D.new()
	_mondo.add_child(_cam)
	_cam.make_current()
	var gt := GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	_sfumata = gt
	regia.prepara(self, cfg_luci)
	guida.prepara(self, cfg_luci)
	tavolo.evento.connect(_evento)
	regole.effetto.connect(_effetto)
	_aggiorna_camera()
	if Parametri.argomenti.has("prerendi"):
		_prerendi.call_deferred()
	else:
		# v0.5 (24/11): il disegno 3D dei pezzi è ricco (migliaia di forme). Le parti FISSE si «cuociono» in immagini
		# all'avvio (bake, regola della grafica prerenderizzata): dopo costano come una sola immagine per strato.
		_cuoci.call_deferred([_statico, buche_n, _rampe], [_disegna_statico, _disegna_buche, _disegna_rampe])

func _nodo(f: Callable) -> Node2D:
	var n := Node2D.new()
	n.draw.connect(f.bind(n))
	_mondo.add_child(n)
	return n

## Strato fisso: le 2 metà dell'immagine pronta (limite del Pi: 2048 px per lato); senza immagini, disegnato dal codice.
func _strato(nome: String, f: Callable) -> Node2D:
	if Parametri.argomenti.has("prerendi") or not ResourceLoader.exists(PRONTE + nome + "_alto.png"):
		return _nodo(f)
	var n := Node2D.new()
	_mondo.add_child(n)
	var y := -MARGINE
	for parte in ["alto", "basso"]:
		var tex: Texture2D = load(PRONTE + nome + "_" + parte + ".png")
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.position = Vector2(-MARGINE, y)
		sp.scale = Vector2.ONE / PX_STRATI
		n.add_child(sp)
		y += tex.get_height() / PX_STRATI
	return n

## --prerendi: disegna strati e pezzi in una SubViewport e li salva in <cartella_grafica>/pronte/ (poi si chiude).
func _prerendi() -> void:
	await get_tree().process_frame
	# v0.6 (RENDERIZZA dell'editor): --rendi_in=CARTELLA salva gli strati lì e anche il tavolo intero in una immagine
	var rendi_in := Parametri.arg("rendi_in")
	var cartella := ProjectSettings.globalize_path(PRONTE) if rendi_in == "" else rendi_in.path_join("")
	DirAccess.make_dir_recursive_absolute(cartella)
	var dim: Vector2 = desc["dimensioni"] + Vector2(2, 2) * MARGINE
	var intero: Image = null
	var strati := [["statico", _disegna_statico], ["rampe", _disegna_rampe]]
	if rendi_in != "":
		# tavolo intero: anche i pezzi che si muovono, nella posizione di partenza
		strati = [["statico", _disegna_statico], ["buche", _disegna_buche], ["accesi", _disegna_accesi],
			["dinamico", _disegna_dinamico], ["rampe", _disegna_rampe], ["sopra", _disegna_sopra]]
	for s in strati:
		var img: Image = await _rendi(s[1], dim, PX_STRATI, Vector2(-MARGINE, -MARGINE))
		if rendi_in != "":
			if intero == null:
				intero = img
			else:
				intero.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
			continue
		var meta := img.get_height() / 2
		img.get_region(Rect2i(0, 0, img.get_width(), meta)).save_png(cartella + s[0] + "_alto.png")
		img.get_region(Rect2i(0, meta, img.get_width(), img.get_height() - meta)).save_png(cartella + s[0] + "_basso.png")
		print("PRONTA ", s[0], " ", img.get_size())
	if rendi_in != "":
		intero.save_png(cartella + "tavolo_intero.png")
		print("PRONTO tavolo_intero ", intero.get_size())
		get_tree().quit()
		return
	var pezzi := {
		"spinner_rosso": [func(n): _faccia_spinner(n, C_ROSSO), Vector2(36, 12)],
		"spinner_azzurro": [func(n): _faccia_spinner(n, C_AZZURRO), Vector2(36, 12)],
		"bersaglio": [func(n): _faccia_bersaglio(n, false), Vector2(24, 10)],
		"bersaglio_giu": [func(n): _faccia_bersaglio(n, true), Vector2(24, 10)],
	}
	var angoli := {}
	for pa in desc["palette"]:
		var nome := "paletta" if float(pa["lunghezza"]) > 50.0 else "paletta_mini"
		var sp := float(pa.get("spessore", 11.6))
		var lung := float(pa["lunghezza"])
		var r := _riquadro_paletta(lung, sp)
		pezzi[nome] = [func(n): _disegna_paletta(n, lung, sp), r.size]
		angoli[nome] = r.position
	for f in desc["fionde"]:
		var r := _riquadro_fionda(f)
		pezzi[f["id"]] = [func(n): _disegna_fionda(n, f), r.size]
		angoli[f["id"]] = r.position
	for nome in pezzi:
		var mm: Vector2 = pezzi[nome][1]
		var img: Image = await _rendi(pezzi[nome][0], mm, PX_PEZZI, angoli.get(nome, -mm * 0.5))
		img.save_png(cartella + nome + ".png")
		print("PRONTO ", nome, " ", img.get_size())
	get_tree().quit()

## Bake all'avvio: ogni strato fisso ancora disegnato dal codice diventa 2 immagini (metà alta e bassa, ≤ 2048 px per
## il Raspberry Pi) e smette di ridisegnarsi. Gli strati che hanno già le immagini pronte restano come sono.
## includere negli strati cotti: il margine più la parte della parete 3D che sale sopra il tavolo.
func _bordo_su() -> float:
	if _sporge < 0.0:
		_sporge = _quanto_sporge()
	return MARGINE + ceilf(_sporge) + 2.0

func _cuoci(nodi: Array, funzioni: Array) -> void:
	var su := _bordo_su()
	var dim: Vector2 = desc["dimensioni"] + Vector2(2.0 * MARGINE, MARGINE + su)
	for i in nodi.size():
		var n: Node2D = nodi[i]
		if n == null or not n.draw.is_connected(funzioni[i].bind(n)):
			continue
		var img: Image = await _rendi(funzioni[i], dim, PX_STRATI, Vector2(-MARGINE, -su))
		var meta := img.get_height() / 2
		var y := -su
		for parte in [Rect2i(0, 0, img.get_width(), meta), Rect2i(0, meta, img.get_width(), img.get_height() - meta)]:
			var sp := Sprite2D.new()
			sp.texture = ImageTexture.create_from_image(img.get_region(parte))
			sp.centered = false
			sp.position = Vector2(-MARGINE, y)
			sp.scale = Vector2.ONE / PX_STRATI
			n.add_child(sp)
			y += parte.size.y / PX_STRATI
		n.draw.disconnect(funzioni[i].bind(n))
		n.queue_redraw()
	# fionde a prisma: un'immagine per fionda (si disegna 1 volta per fotogramma invece di centinaia di forme)
	for f in desc["fionde"]:
		if _pronte.has(f["id"]):
			continue
		var r := _riquadro_fionda_3d(f)
		var img2: Image = await _rendi(func(nn): PittorePezzi.disegna(nn, "fionde", f, desc, Transform2D.IDENTITY), r.size, PX_PEZZI, r.position)
		_cotte[f["id"]] = [ImageTexture.create_from_image(img2), r]

## Riquadro della fionda 3D: anche la cima (più in alto) e l'ombra (in basso a destra).
func _riquadro_fionda_3d(f: Dictionary) -> Rect2:
	var r := Rect2(f["punti"][0], Vector2.ZERO)
	for q in f["punti"]:
		r = r.expand(q)
	r = Rect2(r.position - Vector2(18, 22), r.size + Vector2(44, 46))      # margine anche per l'alone del neon
	if PittorePezzi.ha_immagine(f):
		# l'immagine propria può uscire dal triangolo: il riquadro la comprende
		var im: Dictionary = f["immagine"]
		var dim: Vector2 = im.get("dim", Vector2(40, 40))
		var c: Vector2 = PittorePezzi.ancora("fionde", f, desc) + Vector2(im.get("pos", Vector2.ZERO))
		var mezza := Vector2.ONE * dim.length() * 0.5
		r = r.merge(Rect2(c - mezza, mezza * 2.0))
	return r

func _rendi(f: Callable, mm: Vector2, k: float, origine: Vector2) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(mm.x * k), ceili(mm.y * k))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var n := Node2D.new()
	n.scale = Vector2(k, k)
	n.position = -origine * k
	n.draw.connect(f.bind(n))
	vp.add_child(n)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img

# ================================================================ visuale (una sola, fissa)
func imposta_visuale(_nome: String) -> void:
	visuale = "fissa"
	_aggiorna_camera()

func cambia_visuale() -> void:
	imposta_visuale("fissa")

## Scossa (nudge): la tavola sobbalza un attimo.
func scossa(dir: Vector2) -> void:
	_scossa = dir.normalized() * 6.0

## Tutto il tavolo sullo schermo, sotto il tabellone. Sul telefono 20:9 lo schermo logico è 720×1600: ~1,35 px/mm
## (pallina ~36 px logici, ~54 px veri su 1080×2400).
func _aggiorna_camera() -> void:
	var schermo := get_viewport().get_visible_rect().size
	var dim: Vector2 = desc["dimensioni"]
	var hud := Hud.altezza_di(desc)        # v0.21: altezza del tabellone scelta nell'editor
	var area_h := schermo.y - hud
	# schermo; la parte che sporge sopra il tavolo si inquadra anche lei, così non finisce sotto il tabellone.
	if _sporge < 0.0:
		_sporge = _quanto_sporge()
	var alto_tot := dim.y + _sporge + 2.0 * MARGINE
	var z := minf(schermo.x / (dim.x + 2.0 * MARGINE), area_h / alto_tot)
	_cam.zoom = Vector2(z, z)
	if Parametri.argomenti.has("debug_cam"):
		print("CAM schermo ", schermo, " zoom ", z, " sporge ", _sporge)
	_cam.position = Vector2(dim.x * 0.5, (dim.y - _sporge) * 0.5 - hud * 0.5 / z) + _scossa

var _sporge := -1.0
## Quanti mm la cima dei muri (e dei piani) sale sopra il bordo alto del tavolo nel disegno 3D.
func _quanto_sporge() -> float:
	return Vista2D.sporge_di(desc)

## (v0.25: anche per l'anteprima telefono dell'editor)
static func sporge_di(desc: Dictionary) -> float:
	var minimo := 0.0
	for k in ["muri", "piani"]:
		for e in desc.get(k, []):
			if not e is Dictionary or PittorePezzi.piatto(e, desc):
				continue
			var h := PittorePezzi.altezza(k, e) * PittorePezzi.K
			for q in e.get("punti", []):
				minimo = minf(minimo, float(q.y) - h)
	return -minimo

func _process(delta: float) -> void:
	_t += delta
	_scossa = _scossa.lerp(Vector2.ZERO, minf(1.0, delta * 12.0))
	_aggiorna_camera()
	for sp in desc["spinner"]:
		var id: String = sp["id"]
		var v: float = float(tavolo.spinner_vel.get(id, 0.0)) * float(tavolo.spinner_verso.get(id, 1))
		_spinner_ang[id] = fmod(float(_spinner_ang.get(id, 0.0)) + v * TAU * delta, TAU)
	for l in _lampi:
		l[3] -= delta
	_lampi = _lampi.filter(func(l): return l[3] > 0.0)
	for id in _flash.keys():
		_flash[id] -= delta
		if _flash[id] <= 0.0:
			_flash.erase(id)
	if _scritta_anim:
		_scritta_anim.frame = int(_t * 12.0) % 24
	_muovi_giocattoli(delta)
	_dinamico.queue_redraw()
	_accesi.queue_redraw()
	_sopra.queue_redraw()
	if not _lampi.is_empty() or _lampi_n.get_meta("pieno", false):
		_lampi_n.set_meta("pieno", not _lampi.is_empty())
		_lampi_n.queue_redraw()

# ================================================================ GIOCATTOLI (v0.18.1, Fase 9)
## Un'immagine sul piano con «sempre» (gira, ondeggia, pulsa) o «reagisce» (evento) + «anim» (gira, salta, trema,
## pulsa, lampeggia). È UNA immagine pronta (Sprite2D) che si sposta/ruota: niente disegni a ogni fotogramma.
const DURATA_REAZIONE := 0.8

static func giocattolo(de: Dictionary) -> bool:
	return PittorePezzi.ha_immagine(de) and (str(de.get("sempre", "")) != "" or str(de.get("reagisce", "")) != "")

func _crea_giocattoli() -> void:
	for de in desc.get("decorazioni", []):
		if not giocattolo(de):
			continue
		var tex := PittorePezzi.texture(desc, str(de["immagine"]["nome"]))
		if tex == null:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.modulate.a = clampf(float(de.get("opacita", 1.0)), 0.0, 1.0)
		(_giochi_sopra if bool(de.get("sopra", false)) else _giochi_sotto).add_child(sp)
		_giochi.append([sp, de, 0.0])
	_muovi_giocattoli(0.0)

func _muovi_giocattoli(delta: float) -> void:
	for g in _giochi:
		var sp: Sprite2D = g[0]
		var de: Dictionary = g[1]
		g[2] = maxf(0.0, float(g[2]) - delta)
		var dim: Vector2 = de.get("dim", Vector2(100, 100))
		var sc := dim / sp.texture.get_size()
		if bool(de.get("specchiata", false)):
			sc.x = -sc.x
		var rot := float(de.get("angolo", 0.0))
		var pos: Vector2 = de["pos"]
		var luce := 1.0
		match str(de.get("sempre", "")):
			"gira":
				rot += _t * 1.2
			"ondeggia":
				rot += sin(_t * 2.0) * 0.15
			"pulsa":
				sc *= 1.0 + 0.05 * sin(_t * 4.0)
		if float(g[2]) > 0.0:
			var k := 1.0 - float(g[2]) / DURATA_REAZIONE      # 0 → 1 durante la reazione
			match str(de.get("anim", "salta")):
				"gira":
					rot += k * TAU
				"salta":
					pos += Vector2(0, -sin(k * PI) * 14.0)
					sc *= 1.0 + 0.12 * sin(k * PI)
				"trema":
					pos += Vector2(sin(_t * 70.0), cos(_t * 53.0)) * 3.5 * (1.0 - k)
				"pulsa":
					sc *= 1.0 + 0.3 * sin(k * PI)
				"lampeggia":
					luce = 1.0 + 0.9 * (1.0 if fmod(k * 6.0, 1.0) < 0.5 else 0.0)
		sp.position = pos
		sp.rotation = rot
		sp.scale = sc
		sp.modulate = Color(luce, luce, luce, sp.modulate.a)

## Fa partire la reazione dei giocattoli che aspettano questo evento.
func _reagisci(tipo: String, id: String) -> void:
	for g in _giochi:
		var de: Dictionary = g[1]
		if str(de.get("reagisce", "")) == tipo and (str(de.get("reagisce_id", "")) == "" or str(de["reagisce_id"]) == id):
			g[2] = DURATA_REAZIONE

## Quanti giocattoli stanno reagendo adesso (per le prove).
func giocattoli_in_moto() -> int:
	return _giochi.filter(func(g): return float(g[2]) > 0.0).size()

# ================================================================ eventi (solo grafica)
func _evento(tipo: String, id: String, pos: Vector2) -> void:
	_reagisci(tipo, id)
	# v0.11: effetto di luce scelto nell'editor per i colpi sui pezzi (solo se scelto: i tavoli finiti non cambiano)
	if regia != null and RegiaDati.effetto_luce(desc, tipo) != null:
		regia.evento(tipo, pos)
	if tipo in ["bumper", "fionda", "bersaglio"]:
		_flash[id] = 0.12
	match tipo:
		"bumper": _lampo(pos, Color(0.6, 0.85, 1.0), 55.0, 0.25)
		"fionda": _lampo(pos, Color(1.0, 1.0, 0.9), 45.0, 0.18)
		"bersaglio": _lampo(pos, Color(1.0, 0.72, 0.42), 40.0, 0.3)
		"kickback": _lampo(pos, Color(1.0, 0.45, 0.15), 60.0, 0.4)
		"rampa_entrata": _lampo(pos, Color(1.0, 0.78, 0.25), 45.0, 0.35)
		"captive": _lampo(pos, Color(1.0, 0.85, 0.4), 50.0, 0.35)
		"elastico": _lampo(pos, Color(1.0, 1.0, 0.9), 30.0, 0.15)
		"portale", "portale_uscita": _lampo(pos, Color(0.35, 1.0, 0.6), 70.0, 0.5)

func _effetto(nome: String, pos: Vector2) -> void:
	_reagisci(nome, "")
	if pos != Vector2.ZERO and nome in ["buco_nero", "kicker", "multiball", "extra", "jackpot"]:
		_lampo(pos, Color(1.0, 0.78, 0.25), 80.0, 0.6)

func _lampo(pos: Vector2, col: Color, raggio: float, durata: float) -> void:
	_lampi.append([pos, col, raggio, durata, durata])
	_lampi_n.set_meta("pieno", true)

# ================================================================ luci del piano (inserti)
func _crea_inserti() -> void:
	for i in desc["inserti"]:
		# v0.8: la sagoma viene dal PittorePezzi (stessa dell'editor; 7 forme)
		var forma := PittorePezzi.forma_luce(i)
		var p := Polygon2D.new()
		p.polygon = forma
		var c: Color = i.get("colore", Color(1, 0.8, 0.3))
		p.color = c.darkened(0.8)
		_inserti.add_child(p)
		_ins[i["id"]] = [p, c]

## Lampo del pezzo appena colpito (0..1), per la regia delle luci.
func lampo(id: String) -> float:
	return clampf(_flash.get(id, 0.0) / 0.12, 0.0, 1.0)

## La regia delle luci accende il pezzo vero: inserto del piano o cappello del bumper.
func accendi(id: String, acc: float, col: Color) -> void:
	if _ins.has(id):
		var e: Array = _ins[id]
		var c := (e[1] as Color).darkened(0.8).lerp(col.lightened(0.15), clampf(acc, 0.0, 1.0))
		c.a = 1.0
		(e[0] as Polygon2D).color = c
	elif _cappelli.has(id):
		var a := clampf(acc, 0.0, 1.0)
		if _cappelli[id] is Sprite2D:
			(_cappelli[id] as Sprite2D).modulate = Color.WHITE.lerp(col.lightened(0.2), a * 0.3) * (0.85 + 0.3 * a)
		else:
			var lc := col.lightened(0.3) * (a * 0.75)
			lc.a = 1.0
			(_cappelli[id] as Polygon2D).color = lc

## Luce d'ambiente (1 = normale): si abbassa negli spettacoli e di Notte. Scurisce piano, pezzi e rampe; luci, aloni e
## guida al tiro restano accesi (come nel 3D, dove gli aloni non sentono il sole).
func ambiente(k: float) -> void:
	if Parametri.arg("ambiente") != "":
		k = float(Parametri.arg("ambiente"))      # prova (sviluppo): --ambiente=0.35 come di Notte
	if absf(k - _ambiente_k) < 0.01:
		return
	_ambiente_k = k
	var c := Color(k, k, k)
	for n in [_statico, _dinamico, _rampe, _scritta_anim]:
		if n:
			n.modulate = c

## Immagine sfumata unica per tutti gli aloni (regia e guida al tiro).
func tex_alone() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = g
	return tex

## Cappelli dei bumper: un pezzo che la regia illumina (il resto del bumper è nella parte fissa).
func _crea_cappelli() -> void:
	var cap: Dictionary = elementi.get("cappelli_bumper", {})
	var tex: Texture2D = load(cap["file"]) if cap.has("file") and ResourceLoader.exists(cap["file"]) else null
	for b in desc["bumper"]:
		if tex and b.get("zona", "") == str(cap.get("zona", "")):
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.position = b["pos"]
			sp.rotation = float(cap.get("rot", {}).get(b["id"], 0.0))
			sp.scale = Vector2.ONE * float(cap.get("dim", 46.0)) / float(tex.get_width())
			_mondo.add_child(sp)
			_cappelli[b["id"]] = sp
			continue
		# v0.5: luce della regia sulla CUPOLA del bumper (dove la disegna il PittorePezzi), sommata al disegno:
		# spenta = invisibile, accesa = la cupola si illumina del colore della regia
		var forma := PackedVector2Array()
		var cima := PittorePezzi.cima_bumper(b, desc)
		for k in 20:
			var a := TAU * k / 20.0
			forma.append(cima + Vector2(cos(a), sin(a)) * float(b["raggio"]) * 0.5)
		var p := Polygon2D.new()
		p.polygon = forma
		p.color = Color.BLACK
		var somma := CanvasItemMaterial.new()
		somma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = somma
		_mondo.add_child(p)
		_cappelli[b["id"]] = p

## Elenco delle immagini del tavolo 2D (<cartella_grafica>/elementi.json). Senza il file: tavolo a forme semplici.
func _carica_elementi() -> void:
	var p := CARTELLA + "elementi.json"
	if FileAccess.file_exists(p) and not Parametri.senza("grafica"):
		var j = JSON.parse_string(FileAccess.get_file_as_string(p))
		if j is Dictionary:
			elementi = j
	for q in elementi.get("posti_prigione", {}).get("posti", []):
		_posti_prigione.append(Vector2(q[0], q[1]))

## Sotto tutto il resto: muri, guide e fionde si disegnano sopra.
func _crea_fondo() -> void:
	for e in elementi.get("fondo", []):
		if not ResourceLoader.exists(e["file"]):
			continue
		var tex: Texture2D = load(e["file"])
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.position = Vector2(e["pos"][0], e["pos"][1])
		sp.scale = Vector2(float(e["dim"][0]) / tex.get_width(), float(e["dim"][1]) / tex.get_height())
		_mondo.add_child(sp)
		_immagini[e["id"]] = sp

## dalla scheda video (1 disegno per immagine). Sopra ci vanno buche, luci, pezzi mobili e rampe.
func _crea_immagini() -> void:
	for e in elementi.get("piano", []):
		if not ResourceLoader.exists(e["file"]):
			continue
		var tex: Texture2D = load(e["file"])
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.position = Vector2(e["pos"][0], e["pos"][1])
		sp.rotation = float(e.get("rot", 0.0))
		sp.scale = Vector2(float(e["dim"][0]) / tex.get_width(), float(e["dim"][1]) / tex.get_height())
		_mondo.add_child(sp)
		_immagini[e["id"]] = sp

## Buche: sopra le immagini (il buco vero è quello della fisica). Nel castello i posti sono già nell'immagine.
## Qui anche i pezzi fissi del Palco (sopra il suo dipinto): bordo e corsie delle mini palette, bumper piccolo.
func _disegna_buche(n: Node2D) -> void:
	var palco := not desc.has("piani")       # vecchio «Palco» dei tavoli di partenza (i piani dell'editor si disegnano a parte)
	for m in desc["muri"]:
		if palco and int(m.get("livello", 0)) == 1:
			var pts: PackedVector2Array = m["punti"]
			n.draw_polyline(pts, Color(0.12, 0.07, 0.03), 4.0, true)
			n.draw_polyline(pts, Color(0.9, 0.72, 0.38), 2.4, true)
			n.draw_polyline(pts, Color(1, 0.95, 0.8, 0.7), 0.8, true)
	for b in desc["bumper"]:
		if not palco or int(b.get("livello", 0)) != 1:
			continue
		var p: Vector2 = b["pos"]
		var r := float(b["raggio"])
		n.draw_circle(p + Vector2(2, 4), r + 3.5, Color(0, 0, 0, 0.45))
		n.draw_circle(p, r + 3.5, Color(0.95, 0.95, 0.95))
		n.draw_circle(p, r + 1.0, C_AZZURRO)
		n.draw_circle(p, r * 0.8, C_ROSSO)
	for b in desc["buche"]:
		PittorePezzi.disegna(n, "buche", b, desc)
		if b.get("tipo", "") == "prigione" and not _immagini.has("castello"):
			for q in b.get("posti", []):
				n.draw_arc(q, 14.0, 0, TAU, 20, Color(0.5, 0.5, 0.55), 1.5, true)

## lampo, cuore che batte) e CUORE DI LAVA, negli stessi posti del 3D (y 670 e 768), libere da luci e frecce.
## Costo: 2 disegni per fotogramma; il foglio è 1620x992 px (limite del Pi 4: 4096, meglio 2048).
func _crea_scritte() -> void:
	if not ResourceLoader.exists(CARTELLA + "scritta_anim.png"):
		return
	var tex_a: Texture2D = load(CARTELLA + "scritta_anim.png")
	if tex_a:
		_scritta_anim = Sprite2D.new()
		_scritta_anim.texture = tex_a
		_scritta_anim.hframes = 3
		_scritta_anim.vframes = 8
		_scritta_anim.position = Vector2(240, 670)
		_scritta_anim.scale = Vector2(250.0 / 540.0, 57.0 / 124.0)
		_mondo.add_child(_scritta_anim)
	if not ResourceLoader.exists(CARTELLA + "scritta_sotto.png"):
		return
	var tex_c: Texture2D = load(CARTELLA + "scritta_sotto.png")
	if tex_c:
		var sc := Sprite2D.new()
		sc.texture = tex_c
		sc.position = Vector2(240, 768)
		sc.scale = Vector2(166.0, 23.0) / Vector2(tex_c.get_size())
		_mondo.add_child(sc)

# ================================================================ disegno: parte fissa
func _disegna_statico(n: Node2D) -> void:
	var dim: Vector2 = desc["dimensioni"]
	var campo := float(desc["campo"])
	# piano: la sponda (primo muro) chiude il campo; si riempie con il suo contorno
	var sponda: PackedVector2Array = desc["muri"][0]["punti"]
	var contorno := PackedVector2Array(sponda)
	var con_piano := _immagini.has("piano_alto")
	if not con_piano:
		n.draw_rect(Rect2(Vector2(-MARGINE, -_bordo_su()), dim + Vector2(2.0 * MARGINE, MARGINE + _bordo_su())), Color(0.1, 0.07, 0.05))
	if con_piano:
		pass
	elif Geometry2D.triangulate_polygon(contorno).size() > 0:
		n.draw_colored_polygon(contorno, C_PIANO)
	else:
		n.draw_rect(Rect2(Vector2.ZERO, dim), C_PIANO)
	# v0.6: fondo dipinto dell'editor (copre tutto il tavolo) e immagini sul piano
	var con_fondo := PittorePezzi.fondo(n, desc)
	for de in desc.get("decorazioni", []):
		if not bool(de.get("sopra", false)) and not giocattolo(de):
			PittorePezzi.decorazione(n, de, desc)
	# v0.8: luce ambientale colorata sul piano
	PittorePezzi.ambiente_sul_piano(n, desc)
	# piastrelle di pietra lavica (leggere, solo per dare misura al piano)
	if not con_piano and not con_fondo:
		for y in range(40, int(dim.y), 80):
			n.draw_line(Vector2(0, y), Vector2(campo, y), C_PIANO_2, 1.0)
	# corsia di lancio
	var lx := float(desc["lancio"]["corsia_x"])
	n.draw_rect(Rect2(lx, 300, dim.x - lx, dim.y - 300), Color(0.12, 0.12, 0.14))
	# zona dei livelli rialzati (Palco): ombra + piano
	for k in desc.get("livelli", {}):
		var z: Dictionary = desc["livelli"][k]
		if z.has("da_piano"):
			continue                      # piano rialzato dell'editor: disegnato dal PittorePezzi (sotto)
		var zona := PackedVector2Array(z["zona"])
		var ombra := PackedVector2Array()
		for p in zona:
			ombra.append(p + Vector2(6, 9))
		n.draw_colored_polygon(ombra, Color(0, 0, 0, 0.45))
		if not elementi.get("piano", []).any(func(e): return e["id"] == "livello_%d" % k or e["id"] == "palco"):
			n.draw_colored_polygon(zona, C_PALCO)
			n.draw_polyline(_chiudi(zona), C_PALCO.lightened(0.5), 2.0, true)
			_scritta(n, str(z.get("nome", "")), _centro(zona) + Vector2(0, 40), 11, Color(1, 1, 1, 0.45))
	# kickback e sensori delle corsie (solo un segno chiaro)
	var kbs = desc.get("kickback", [])
	for kb in (kbs if kbs is Array else [kbs]):
		PittorePezzi.disegna(n, "kickback", kb, desc)
	# campi del tavolo v2 (23/11): pozzo di gravità (anelli che si stringono) e magnete (disco con bobina)
	for cp in desc.get("campi", []):
		var c: Vector2 = cp["pos"]
		var r: float = cp["raggio"]
		if cp["tipo"] == "pozzo":
			for k in 4:
				var rr := r * (1.0 - k * 0.22)
				n.draw_arc(c, rr, 0, TAU, 48, Color(0.3, 0.55, 1.0, 0.18 + k * 0.1), 2.0, true)
			n.draw_circle(c, r * 0.3, Color(0.05, 0.1, 0.3, 0.8))
		else:
			n.draw_circle(c, r * 0.55, Color(0.25, 0.08, 0.3))
			for k in 3:
				n.draw_arc(c, r * (0.25 + k * 0.12), 0, TAU, 32, Color(1.0, 0.45, 1.0, 0.5), 1.5, true)
	# Pinball Editor 2D: NASTRI a terra (corsie larghe semi-3D: fondo, pareti in luce e in ombra)
	for nn in desc.get("nastri", []):
		if not CurveEditor.nastro_alto(nn):
			CurveEditor.disegna_nastro(n, nn, func(q): return q, 1.0)
	# muri (sponda, guide, orbite): legno, metallo, gomma
	for m in desc["muri"]:
		if m.has("da_nastro") or m.has("da_piano"):
			continue                      # pareti dei nastri e bordi dei piani: già disegnati in semi-3D
		if int(m.get("livello", 0)) == 1 and not desc.has("piani"):
			var st: Dictionary = m.duplicate()
			st["colore"] = m.get("colore", Color(0.95, 0.75, 0.5))
			PittorePezzi.disegna(n, "muri", st, desc)
		else:
			PittorePezzi.disegna(n, "muri", m, desc)
	# v0.9: piani rialzati dell'editor (sopra il tavolo, sotto i pezzi che ci stanno sopra)
	for pr in desc.get("piani", []):
		PittorePezzi.disegna(n, "piani", pr, desc)
	# (fionde: strato sempre acceso, vedi _disegna_accesi)
	for b in desc["bumper"]:
		if int(b.get("livello", 0)) == 1 and not desc.has("piani"):
			continue                      # (Palco: disegnato sopra il dipinto del Palco, in _disegna_buche)
		# (il centro lo disegna la regia luci: cappello che si accende, vedi _crea_cappelli)
		PittorePezzi.disegna(n, "bumper", b, desc, Transform2D.IDENTITY, {"senza_centro": true})
	# Bilancia (pallina prigioniera): canale e fermo
	for c in desc.get("captive", []):
		var fe: Array = c["fermo"]
		n.draw_line(fe[0], fe[1], C_METALLO, 4.0, true)
		_scritta(n, str(c.get("nome", "")), Vector2(c["casa"]) + Vector2(0, 30), 9, Color(C_CREMA, 0.7))
	# elastici: paletti di gomma (anello chiaro sul perno cromato)
	for e in desc.get("elastici", []):
		PittorePezzi.disegna(n, "elastici", e, desc)
	# fermo palette (gomma alla base) e perni
	for pa in desc["palette"]:
		n.draw_circle(pa["perno"], 6.0, Color(0.3, 0.3, 0.33))

# ================================================================ strato sempre acceso: fionde e palette
## Ogni fotogramma (le palette si muovono): immagini pronte, 1 disegno per fionda, 2 per paletta (ombra + immagine).
func _disegna_accesi(n: Node2D) -> void:
	# Pinball Editor 2D: gomme dei tratti-fionda dei muri. Quando scatta, la gomma si TENDE verso il muro e torna
	# (la «gomma che si muove», come la fionda di VPE: due pose, 70-120 ms)
	for m in desc["muri"]:
		var tratti: Array = m.get("fionde_tratti", [])
		if tratti.is_empty():
			continue
		var tira: Array = []
		for k in tratti.size():
			tira.append(clampf(float(_flash.get("%s#%d" % [m.get("id", "muro"), k], 0.0)) / 0.12, 0.0, 1.0))
		PittorePezzi.gomme_tratti(n, m, PittorePezzi.piatto(m, desc), tira)
	for f in desc["fionde"]:
		var tex: Texture2D = _pronte.get(f["id"])
		if tex:
			var r := _riquadro_fionda(f)
			n.draw_texture_rect(tex, r, false)
		elif _cotte.has(f["id"]):
			var fl := clampf(float(_flash.get(f["id"], 0.0)) / 0.12, 0.0, 1.0)
			n.draw_texture_rect(_cotte[f["id"]][0], _cotte[f["id"]][1], false, Color(1, 1, 1).lerp(Color(1.3, 1.3, 1.3), fl))
		else:
			PittorePezzi.disegna(n, "fionde", f, desc, Transform2D.IDENTITY, {"flash": clampf(float(_flash.get(f["id"], 0.0)) / 0.12, 0.0, 1.0) * 0.7})
	for id in tavolo.palette:
		var pa: Node2D = tavolo.palette[id]
		var info: Dictionary = pa.get_meta("info")
		var lung := float(info["lunghezza"])
		var verso := float(info["verso"])
		var sp := float(info.get("spessore", 11.6))
		if not _forme_palette.has(id):
			_forme_palette[id] = _forma_paletta(lung * verso, sp)
		var dati := _dati_pezzo("palette", id)
		var piatta := PittorePezzi.piatto(dati, desc)
		if not piatta:
			PittorePezzi.ombra_paletta(n, pa.transform, lung * verso, sp, pa.transform.get_rotation(), PittorePezzi.altezza("palette", dati))
		var tex: Texture2D = _pronte.get("paletta" if lung > 50.0 else "paletta_mini")
		if tex:
			n.draw_set_transform_matrix(pa.transform * Transform2D(0.0, Vector2(verso, 1.0), 0.0, Vector2.ZERO))
			n.draw_texture_rect(tex, _riquadro_paletta(lung, sp), false)
		else:
			n.draw_set_transform_matrix(pa.transform)
			PittorePezzi.bordo_paletta(n, dati, desc, lung * verso, sp, "sotto")
			if not PittorePezzi.sostituisce(dati):
				PittorePezzi.paletta(n, lung * verso, sp, PittorePezzi.colore("palette", dati, desc), piatta, pa.transform.get_rotation(), PittorePezzi.altezza("palette", dati))
			PittorePezzi.bordo_paletta(n, dati, desc, lung * verso, sp, "sopra")
			PittorePezzi.immagine_paletta(n, dati, desc, pa.transform, lung * verso, pa.transform.get_rotation(), piatta, PittorePezzi.altezza("palette", dati))
		n.draw_set_transform_matrix(Transform2D.IDENTITY)

## Dati del pezzo con quell'id nella descrizione del tavolo ({} se non c'è).
func _dati_pezzo(chiave: String, id: String) -> Dictionary:
	for e in desc.get(chiave, []):
		if str(e.get("id", "")) == id:
			return e
	return {}

func _forma_paletta(L: float, sp: float) -> PackedVector2Array:
	var punta := sp * 0.6
	return Geometry2D.convex_hull(PackedVector2Array([Vector2(0, -sp), Vector2(0, sp), Vector2(-sp * signf(L), 0),
		Vector2(L, -punta), Vector2(L, punta), Vector2(L + punta * signf(L), 0)]))

func _riquadro_paletta(lung: float, sp: float) -> Rect2:
	return Rect2(Vector2(-sp - 1.0, -sp - 1.0), Vector2(lung + sp * 1.6 + 2.0, sp * 2.0 + 2.0))

## Paletta (per l'immagine pronta, verso destra): corpo rosso, contorno bianco, striscia chiara, perno.
func _disegna_paletta(n: Node2D, L: float, sp: float) -> void:
	var forma := _forma_paletta(L, sp)
	n.draw_colored_polygon(forma, C_ROSSO)
	n.draw_polyline(_chiudi(forma), Color(1, 1, 1, 0.95), 2.2 if sp > 9.0 else 1.6, true)
	n.draw_line(Vector2(sp * 0.3 * signf(L), -sp * 0.3), Vector2(L * 0.82, -sp * 0.16), Color(1, 0.75, 0.75, 0.7), 1.6, true)
	n.draw_circle(Vector2.ZERO, sp * 0.4, Color(0.95, 0.95, 0.95))
	n.draw_circle(Vector2.ZERO, sp * 0.18, Color(0.55, 0.56, 0.6))

func _riquadro_fionda(f: Dictionary) -> Rect2:
	var r := Rect2(f["punti"][0], Vector2.ZERO)
	for q in f["punti"]:
		r = r.expand(q)
	return Rect2(r.position - Vector2(6, 6), r.size + Vector2(14, 16))

	# azzurra tutto intorno e sulla faccia che spara (la «molla»), 3 paletti cromati agli angoli
func _disegna_fionda(n: Node2D, f: Dictionary) -> void:
	if true:
		var pts := PackedVector2Array(f["punti"])
		var ombra := PackedVector2Array()
		for q in pts:
			ombra.append(q + Vector2(3, 5))
		n.draw_colored_polygon(ombra, Color(0, 0, 0, 0.35))
		n.draw_polyline(_chiudi(pts), C_AZZURRO.darkened(0.3), 7.0, true)
		n.draw_polyline(_chiudi(pts), C_AZZURRO, 5.0, true)
		var dentro := PackedVector2Array()
		var cen := _centro(pts)
		for q in pts:
			dentro.append(cen + (q - cen) * 0.72)
		n.draw_colored_polygon(dentro, C_ROSSO)
		n.draw_polyline(_chiudi(dentro), Color(1, 1, 1, 0.9), 1.5, true)
		n.draw_line(pts[0], pts[pts.size() - 1], C_AZZURRO.lightened(0.35), 6.5, true)
		n.draw_line(pts[0], pts[pts.size() - 1], Color(1, 1, 1, 0.55), 1.4, true)
		for q in pts:
			n.draw_circle(q, 3.6, Color(0.08, 0.08, 0.1))
			n.draw_circle(q, 2.6, C_METALLO)
			n.draw_circle(q + Vector2(-0.7, -0.7), 1.0, Color(1, 1, 1, 0.9))

# ================================================================ disegno: parti che cambiano
func _disegna_dinamico(n: Node2D) -> void:
	# bersagli (abbattibili: giù = solo un segno sul piano)
	for b in desc["bersagli"]:
		var giu: bool = tavolo.bersagli_giu.get(b["id"], false)
		var col: Color = PittorePezzi.colore("bersagli", b, desc)
		# bersaglio da colpire secondo le regole (come nel 3D): 1 = acceso, 2 = lampeggia forte
		match int(regia.luci_regole.get(b["id"], 0)):
			1:
				col = col.lightened(0.45)
			2:
				col = col.lightened(0.6) if fmod(_t * 4.0, 1.0) < 0.55 else col.darkened(0.3)
		if _pronte.has("bersaglio"):
			_bersaglio(n, b["pos"], b["dim"], float(b.get("angolo", 0.0)), col, giu, lampo(b["id"]))
		else:
			PittorePezzi.disegna(n, "bersagli", b, desc, Transform2D.IDENTITY, {"col": col, "giu": giu, "flash": lampo(b["id"])})
	# v0.7: cancelletti (la lamina si alza per 0,4 s quando la pallina passa)
	for cg in desc.get("cancelli", []):
		var ap := clampf(1.0 - (tavolo.t_gioco - float(tavolo.cancelli_t.get(cg["id"], -9.0))) / 0.4, 0.0, 1.0)
		PittorePezzi.disegna(n, "cancelli", cg, desc, Transform2D.IDENTITY, {"apertura": ap})
	for id in tavolo.mobili:
		var corpo: Node2D = tavolo.mobili[id]
		var info: Dictionary = corpo.get_meta("info")
		var px := corpo.position.x
		var verso := signf(px - float(_mobili_x.get(id, px))) if absf(px - float(_mobili_x.get(id, px))) > 0.01 else float(_mobili_verso.get(id, 1.0))
		_mobili_verso[id] = verso
		_mobili_x[id] = px
		if not tavolo.mobile_visibile(id):
			continue
		_rett(n, corpo.position, Vector2(info["dim"]), corpo.rotation, C_CREMA)
	# porte (saracinesca del castello, sipario del Palco): chiuse = barra piena
	for p in desc["porte"]:
		var pts: Array = p["punti"]
		if p["id"] == "perno":
			# perno centrale retrattile: alzato = paletto acceso, abbassato = solo il foro
			var cp: Vector2 = (Vector2(pts[0]) + Vector2(pts[1])) * 0.5
			if tavolo.porte_aperte.get("perno", true):
				n.draw_circle(cp, 5.0, Color(0.1, 0.1, 0.12))
			else:
				n.draw_circle(cp + Vector2(2, 3), 8.0, Color(0, 0, 0, 0.4))
				n.draw_circle(cp, 8.0, C_AZZURRO)
				n.draw_circle(cp, 4.0, Color(1, 1, 1))
			continue
		if tavolo.porte_aperte.get(p["id"], false):
			n.draw_line(pts[0], pts[1], Color(1, 0.3, 0.3, 0.25), 2.0)
		else:
			n.draw_line(pts[0], pts[1], Color(0.85, 0.1, 0.1), 6.0, true)
	# v0.15: deviatori sul piano (lama di metallo cromato sul suo perno)
	for la in desc.get("lame", []):
		var pp: Vector2 = la["perno"]
		var ang := float(la.get("angolo_b" if tavolo.lame_in_b.get(la["id"], false) else "angolo_a", 0.0))
		var punta := pp + Vector2(float(la.get("lunghezza", 55.0)), 0).rotated(ang)
		n.draw_line(pp + Vector2(1.5, 2.5), punta + Vector2(1.5, 2.5), Color(0, 0, 0, 0.35), 5.0, true)
		n.draw_line(pp, punta, Color(0.25, 0.27, 0.3), 5.0, true)
		n.draw_line(pp, punta, C_METALLO, 3.2, true)
		n.draw_line(pp + Vector2(-0.6, -0.8), punta + Vector2(-0.6, -0.8), Color(1, 1, 1, 0.6), 1.0, true)
		n.draw_circle(pp, 4.5, Color(0.15, 0.15, 0.17))
		n.draw_circle(pp, 2.6, Color(0.95, 0.8, 0.35))
	# Bilancia: la pallina prigioniera
	for cid in tavolo.captive:
		var cb: Node2D = tavolo.captive[cid]
		_pallina_in(n, cb.position, 13.5, Color(0.85, 0.72, 0.4))
	# (palette: strato sempre acceso, vedi _disegna_accesi)
	# molla di lancio
	var lp: Vector2 = desc["lancio"]["pos"]
	var y0 := lp.y + 15.0 + tavolo.carica * 25.0
	var fondo_m := float(desc["dimensioni"].y) - 2.0
	n.draw_line(Vector2(lp.x, y0 + 7), Vector2(lp.x, fondo_m), C_METALLO, 3.0)
	var spire := 7
	var a0 := y0 + 9.0
	var passo := (fondo_m - a0) / float(spire * 2)
	var molla := PackedVector2Array()
	for i in spire * 2 + 1:
		molla.append(Vector2(lp.x + (7.0 if i % 2 == 0 else -7.0), a0 + passo * i))
	n.draw_polyline(molla, C_AZZURRO, 2.5, true)
	n.draw_rect(Rect2(lp.x - 10, y0, 20, 8), C_ROSSO)
	n.draw_rect(Rect2(lp.x - 10, y0, 20, 2.5), Color(1, 0.6, 0.6))
	# palline sul piano (sotto le rampe). Quelle chiuse nella prigione si vedono nei posti dell'immagine del castello,
	var chiuse := {}
	if not _posti_prigione.is_empty():
		for pid in tavolo.prigionieri:
			var lista: Array = tavolo.prigionieri[pid]
			for i in lista.size():
				if is_instance_valid(lista[i]) and i < _posti_prigione.size():
					chiuse[lista[i]] = _posti_prigione[i]
	var r_chiusa := float(elementi.get("posti_prigione", {}).get("raggio_pallina", 4.6))
	for b in chiuse:
		_pallina_in(n, chiuse[b], r_chiusa, Color(0.85, 0.86, 0.9))
	for b in tavolo.palline:
		if is_instance_valid(b) and not b.nascosta and not b.sul_binario() and not chiuse.has(b):
			_pallina_in(n, b.global_position + PittorePezzi.su(maxf(0.0, b.altezza - b.quota)), 13.5 * (1.0 + b.quota / 300.0), Color(0.85, 0.86, 0.9))

## sponde rialzate, staffe cromate con le viti, lamiera d'imbocco e ombra sul piano (più lontana dove la rampa è alta:
## Disegnate UNA volta (nodo fisso): costo zero a ogni fotogramma.
func _disegna_rampe(n: Node2D) -> void:
	# v0.6: immagini «sopra i pezzi»
	for de in desc.get("decorazioni", []):
		if bool(de.get("sopra", false)) and not giocattolo(de):
			PittorePezzi.decorazione(n, de, desc)
	# Pinball Editor 2D: i nastri SOLLEVATI si disegnano qui (sopra le palline del piano), con ombra e fianchi
	for nn in desc.get("nastri", []):
		if CurveEditor.nastro_alto(nn):
			CurveEditor.disegna_nastro(n, nn, func(q): return q, 1.0)
	# v0.30: con gli incroci la rampa che passa sopra si disegna dopo quella che passa sotto
	var rampe_in_ordine: Array = desc["rampe"]
	if desc.get("ordine_rampe") is Array:
		var per_id := {}
		for ra0 in desc["rampe"]:
			per_id[str(ra0.get("id", ""))] = ra0
		rampe_in_ordine = []
		for id0 in desc["ordine_rampe"]:
			if per_id.has(str(id0)):
				rampe_in_ordine.append(per_id[str(id0)])
				per_id.erase(str(id0))
		rampe_in_ordine.append_array(per_id.values())
	for ra in rampe_in_ordine:
		if ra.has("da_nastro"):
			continue
		if PittorePezzi.ha_immagine(ra):
			PittorePezzi.disegna_immagine(n, ra, desc, PittorePezzi.ancora("rampe", ra, desc))
			if PittorePezzi.sostituisce(ra):
				continue
		var col: Color = _colore_rampa.get(ra["id"], C_AZZURRO)
		var grezzi: Array = []
		for p in (ra["punti_gioco"] if ra.get("punti_gioco") is Array and not ra["punti_gioco"].is_empty() else ra["punti"]):
			grezzi.append(_v3(p))
		var pts: Array = Binario.levigato(grezzi)
		var c := PackedVector2Array()
		var nor := PackedVector2Array()
		var z := PackedFloat32Array()
		for i in pts.size():
			var prima: Vector3 = pts[maxi(i - 1, 0)]
			var dopo: Vector3 = pts[mini(i + 1, pts.size() - 1)]
			var d := Vector2(dopo.x - prima.x, dopo.y - prima.y).normalized()
			# v0.5: vista inclinata come i pezzi: la rampa alta si vede più su (l'ombra resta sul piano, sotto)
			c.append(Vector2(pts[i].x, pts[i].y) + PittorePezzi.su(maxf(float(pts[i].z), 0.0)))
			nor.append(Vector2(-d.y, d.x))
			z.append(maxf(float(pts[i].z), 0.0))
		var filo: bool = ra.get("stile", "") == "filo"
		var m := 19.0
		# ombra sul piano
		var om_sx := PackedVector2Array()
		var om_dx := PackedVector2Array()
		for i in c.size():
			var off := Vector2(2.0 + z[i] * 0.09, 3.0 + z[i] * 0.14) - PittorePezzi.su(z[i])
			om_sx.append(c[i] + nor[i] * m + off)
			om_dx.append(c[i] - nor[i] * m + off)
		if filo:
			# ombra morbida dei fili sul piano (due passate: larga e chiara, stretta e più scura)
			for o in [om_sx, om_dx]:
				n.draw_polyline(o, Color(0, 0, 0, 0.10), 6.0, true)
				n.draw_polyline(o, Color(0, 0, 0, 0.20), 2.4, true)
			_binario_cromato(n, c, nor, m, col)
			continue
		_striscia(n, om_sx, om_dx, Color(0, 0, 0, 0.22))
		var sx := PackedVector2Array()
		var dx := PackedVector2Array()
		var sx_in := PackedVector2Array()
		var dx_in := PackedVector2Array()
		for i in c.size():
			sx.append(c[i] + nor[i] * m)
			dx.append(c[i] - nor[i] * m)
			sx_in.append(c[i] + nor[i] * (m - 4.0))
			dx_in.append(c[i] - nor[i] * (m - 4.0))
		# fondo di plastica trasparente (le palline sotto si vedono) e riflesso lungo il centro
		_striscia(n, sx, dx, Color(col, 0.34))
		var rifl := PackedVector2Array()
		for i in c.size():
			rifl.append(c[i] + nor[i] * m * 0.35 * signf(nor[i].dot(Vector2(-0.6, -0.8)) + 0.001))
		n.draw_polyline(rifl, Color(1, 1, 1, 0.1), 6.0, true)
		# 24/11: frecce sul fondo (opzione della rampa, come il nastro)
		if bool(ra.get("frecce", false)):
			var accf := 0.0
			for i in range(1, c.size()):
				accf += c[i].distance_to(c[i - 1])
				if accf >= 70.0:
					accf = 0.0
					var dz := (c[i] - c[i - 1]).normalized()
					var lat := Vector2(-dz.y, dz.x) * 7.0
					n.draw_colored_polygon(PackedVector2Array([c[i] + dz * 8.0, c[i] - dz * 5.0 + lat, c[i] - dz * 5.0 - lat]), Color(1, 1, 1, 0.8))
		# sponde rialzate: plastica piena, bordo scuro fuori, filo di luce dentro
		_striscia(n, sx, sx_in, Color(col.darkened(0.05), 0.88))
		_striscia(n, dx_in, dx, Color(col.darkened(0.25), 0.88))
		n.draw_polyline(sx, Color(col.darkened(0.6), 0.9), 1.2, true)
		n.draw_polyline(dx, Color(col.darkened(0.6), 0.9), 1.2, true)
		n.draw_polyline(sx_in, Color(1, 1, 1, 0.55), 0.9, true)
		n.draw_polyline(dx_in, Color(1, 1, 1, 0.3), 0.9, true)
		# staffe cromate a traverso con 2 viti, ogni ~70 mm dove la rampa è sollevata
		var lung := 0.0
		var prossima := 45.0
		for i in range(1, c.size()):
			lung += c[i].distance_to(c[i - 1])
			if lung >= prossima and z[i] > 12.0:
				prossima = lung + 70.0
				var a: Vector2 = c[i] + nor[i] * (m + 2.5)
				var b: Vector2 = c[i] - nor[i] * (m + 2.5)
				n.draw_line(a, b, Color(0.05, 0.05, 0.07, 0.9), 3.6, true)
				n.draw_line(a, b, C_METALLO, 2.2, true)
				n.draw_line(a + Vector2(-0.4, -0.4), b + Vector2(-0.4, -0.4), Color(1, 1, 1, 0.6), 0.7, true)
				for v in [a.lerp(b, 0.06), a.lerp(b, 0.94)]:
					n.draw_circle(v, 1.6, Color(0.15, 0.15, 0.17))
					n.draw_circle(v + Vector2(-0.3, -0.3), 0.8, Color(0.95, 0.95, 1.0))
		# 24/11: imbocco più largo (opzione della rampa): due lamiere a invito che si stringono in 30 mm, come nel motore
		if ra.has("invito") and z[0] < 2.0 and c.size() > 1:
			var inv := float(ra["invito"])
			var acc_i := 0.0
			var k_i := 1
			while k_i < c.size() - 1 and acc_i + c[k_i].distance_to(c[k_i - 1]) < 30.0:
				acc_i += c[k_i].distance_to(c[k_i - 1])
				k_i += 1
			for lato in [1.0, -1.0]:
				var a_i: Vector2 = c[0] + nor[0] * inv * lato
				var b_i: Vector2 = c[k_i] + nor[k_i] * m * lato
				n.draw_line(a_i, b_i, Color(0.05, 0.05, 0.07, 0.9), 3.4, true)
				n.draw_line(a_i, b_i, C_METALLO, 2.0, true)
		# lamiera d'imbocco cromata dove la rampa parte dal piano
		if z[0] < 2.0 and c.size() > 1:
			var d0 := (c[1] - c[0]).normalized()
			var q := PackedVector2Array([c[0] + nor[0] * m - d0 * 9.0, c[0] - nor[0] * m - d0 * 9.0,
				c[0] - nor[0] * (m - 2.0) + d0 * 7.0, c[0] + nor[0] * (m - 2.0) + d0 * 7.0])
			n.draw_colored_polygon(q, Color(0.36, 0.38, 0.42))
			n.draw_line(q[0], q[1], Color(0.92, 0.93, 0.96), 1.6, true)
			n.draw_polyline(_chiudi(q), Color(0.05, 0.05, 0.07, 0.9), 1.0, true)
		_scritta(n, str(ra.get("nome", "")).to_upper(), c[0] + Vector2(0, 26), 8, Color(1, 1, 1, 0.75))
	# staffe cromate e perno degli spinner (fissi: nello strato delle rampe; la piastra che gira è a parte)
	for sp in desc["spinner"]:
		if not PittorePezzi.sostituisce(sp):
			PittorePezzi.spinner(n, sp, PittorePezzi.colore("spinner", sp, desc), PittorePezzi.piatto(sp, desc), Transform2D.IDENTITY, false, PittorePezzi.altezza("spinner", sp))
		PittorePezzi.disegna_immagine(n, sp, desc, PittorePezzi.ancora("spinner", sp, desc))

## sottili e lucidi, niente contorni neri, poche
## staffe trasversali ben distanziate (ogni 64 mm, più una all'inizio e una alla fine) con le viti alle punte.
## Il colore della rampa tinge appena le staffe. Disegnato una volta sola (strato fisso).
func _binario_cromato(n: Node2D, c: PackedVector2Array, nor: PackedVector2Array, m: float, col: Color) -> void:
	if c.size() < 2:
		return
	var luce_dir := Vector2(-0.6, -0.8)
	var acciaio := Color(0.66, 0.68, 0.72)
	var bordo := Color(0.18, 0.19, 0.22, 0.55)
	# staffe: dove cadono lungo il binario (prima e ultima comprese)
	var lung_tot := 0.0
	for i in range(1, c.size()):
		lung_tot += c[i].distance_to(c[i - 1])
	var passi := maxi(1, int(round(lung_tot / 64.0)))
	var passo := lung_tot / float(passi)
	var dove: Array = [0]
	var acc := 0.0
	var prossima := passo
	for i in range(1, c.size()):
		acc += c[i].distance_to(c[i - 1])
		if acc >= prossima - 0.5 and i < c.size() - 1:
			dove.append(i)
			prossima += passo
	dove.append(c.size() - 1)
	# 1) fili sotto la pallina (più bassi: più scuri e sottili), poi staffe, poi sponde sopra
	_filo_acciaio(n, c, nor, 0.0, 1.9, acciaio.darkened(0.22), bordo, luce_dir)
	var staffa := acciaio.lerp(col, 0.18).darkened(0.08)
	for i in dove:
		var a: Vector2 = c[i] + nor[i] * m * 1.16
		var b: Vector2 = c[i] - nor[i] * m * 1.16
		n.draw_line(a, b, bordo, 3.6, true)
		n.draw_line(a, b, staffa, 2.6, true)
		n.draw_line(a + Vector2(0, -0.5), b + Vector2(0, -0.5), Color(1, 1, 1, 0.45), 0.8, true)
		for v in [a, b]:
			n.draw_circle(v, 2.1, bordo)
			n.draw_circle(v, 1.6, staffa.lightened(0.15))
			n.draw_circle(v + Vector2(-0.4, -0.4), 0.6, Color(1, 1, 1, 0.8))
	_filo_acciaio(n, c, nor, m, 2.3, acciaio, bordo, luce_dir)
	_filo_acciaio(n, c, nor, -m, 2.3, acciaio, bordo, luce_dir)

## Un filo d'acciaio a distanza `off` dal centro: bordo leggero, corpo, riflesso dal lato della luce.
func _filo_acciaio(n: Node2D, c: PackedVector2Array, nor: PackedVector2Array, off: float, sp: float, corpo: Color, bordo: Color, luce_dir: Vector2) -> void:
	var f := PackedVector2Array()
	var luce := PackedVector2Array()
	for i in c.size():
		f.append(c[i] + nor[i] * off)
		var verso := signf(nor[i].dot(luce_dir) + 0.001)
		luce.append(c[i] + nor[i] * (off + verso * sp * 0.22))
	n.draw_polyline(f, bordo, sp + 1.0, true)
	n.draw_polyline(f, corpo, sp, true)
	n.draw_polyline(luce, Color(1, 1, 1, 0.85), sp * 0.38, true)

## Striscia piena tra due bordi (un poligono; se si incrocia nei tornanti, un quadrilatero per tratto).
func _striscia(n: Node2D, a: PackedVector2Array, b: PackedVector2Array, col: Color) -> void:
	var poli := PackedVector2Array(a)
	var r := b.duplicate()
	r.reverse()
	poli.append_array(r)
	if Geometry2D.triangulate_polygon(poli).size() > 0:
		n.draw_colored_polygon(poli, col)
	else:
		# quadrilateri disegnati senza triangolazione (nei tornanti stretti un quadrilatero può essere storto)
		var cc := PackedColorArray([col, col, col, col])
		for k in a.size() - 1:
			n.draw_primitive(PackedVector2Array([a[k], a[k + 1], b[k + 1], b[k]]), cc, PackedVector2Array())

func _disegna_sopra(n: Node2D) -> void:
	# palline sulle rampe: più grandi quanto più sono in alto (si vede che passano sopra)
	for b in tavolo.palline:
		if is_instance_valid(b) and not b.nascosta and b.sul_binario():
			# v0.5: la pallina in alto si vede più su (stessa vista inclinata dei pezzi e delle rampe)
			_pallina_in(n, b.global_position + PittorePezzi.su(b.altezza), 13.5 * (1.0 + b.altezza * 0.004 + b.quota / 300.0), Color(0.92, 0.93, 0.96))
	# spinner (22/11 sera): la piastra che gira è un'immagine pronta (faccia rossa davanti, azzurra dietro),
	# schiacciata quando è di taglio: 1 disegno per spinner. Staffe e perno sono nello strato delle rampe.
	for sp in desc["spinner"]:
		if PittorePezzi.sostituisce(sp):
			continue                      # spinner con la sua immagine al posto del disegno (strato delle rampe)
		var a: float = _spinner_ang.get(sp["id"], 0.0)
		var lw: float = float(sp["larghezza"]) * 0.5
		var ca := cos(a)
		var spess := 1.2 + 9.0 * absf(ca)
		var tex: Texture2D = _pronte.get("spinner_rosso" if ca >= 0.0 else "spinner_azzurro")
		n.draw_set_transform(PittorePezzi.cima_spinner(sp, desc), float(sp.get("angolo", 0.0)))
		var r := Rect2(Vector2(-lw - 1.0, -spess * 0.5 - 1.0), Vector2(lw * 2.0 + 2.0, spess + 2.0))
		var luce := Color.WHITE.darkened(0.25 * (1.0 - absf(ca)))
		if tex:
			n.draw_texture_rect(tex, r, false, luce)
		else:
			var cs := PittorePezzi.colore("spinner", sp, desc)
			PittorePezzi.piastra_spinner(n, r, cs if ca >= 0.0 else cs.darkened(0.35), PittorePezzi.piatto(sp, desc))
		n.draw_set_transform(Vector2.ZERO)

func _disegna_lampi(n: Node2D) -> void:
	for l in _lampi:
		var k: float = l[3] / l[4]
		var r: float = l[2] * (1.2 - 0.2 * k)
		var c: Color = l[1]
		c.a = k * 0.8 * regia.intensita
		n.draw_texture_rect(_sfumata, Rect2(l[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, c)

# ================================================================ pezzi disegnati (22/11 sera: niente più rettangoli)
## (giù) resta solo la fessura nel piano. Colpito: un lampo bianco.
## A ogni fotogramma: la faccia pronta (bianca) colorata col colore del gruppo; 1 disegno (2 con l'ombra).
func _bersaglio(n: Node2D, c: Vector2, dim: Vector2, ang: float, col: Color, giu: bool, flash: float) -> void:
	n.draw_set_transform(c, ang)
	var r := Rect2(-dim * 0.5 - Vector2(1, 1), dim + Vector2(2, 2))
	var tex: Texture2D = _pronte.get("bersaglio_giu" if giu else "bersaglio")
	if tex:
		if not giu:
			n.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.4))
		n.draw_texture_rect(tex, r, false, col.lerp(Color.WHITE, flash * 0.7))
	else:
		_faccia_bersaglio(n, giu, r, col)
	n.draw_set_transform(Vector2.ZERO)

## Faccia di un bersaglio (per l'immagine pronta: bianca, il colore lo dà il gioco): plastica con riflesso in alto,
## bordo scuro, bollino. Abbattuto: la fessura nel piano.
func _faccia_bersaglio(n: Node2D, giu: bool, r := Rect2(-12, -5, 24, 10), col := Color.WHITE) -> void:
	if giu:
		n.draw_rect(r, Color(0.02, 0.02, 0.03, 0.9))
		n.draw_rect(r, Color(col, 0.6), false, 1.0)
		return
	n.draw_rect(r, col)
	n.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color(1, 1, 1, 0.45))
	n.draw_rect(r, col.darkened(0.6), false, 1.0)
	n.draw_circle(r.get_center() + Vector2(0, r.size.y * 0.1), minf(r.size.y * 0.25, 3.0), Color(1, 1, 1, 0.85))

## Piastra di uno spinner (per le immagini pronte): faccia colorata, striscia bianca, bordo scuro e filo di luce.
func _faccia_spinner(n: Node2D, col: Color, r := Rect2(-18, -6, 36, 12)) -> void:
	n.draw_rect(r, col)
	n.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.38), Vector2(r.size.x, r.size.y * 0.24)), Color(1, 1, 1, 0.85))
	n.draw_rect(r, Color(0.05, 0.05, 0.07, 0.9), false, 1.0)
	n.draw_line(r.position + Vector2(1, 1), r.position + Vector2(r.size.x - 1, 1), Color(1, 1, 1, 0.5), 0.8)

# ================================================================ aiuti
func _pallina_in(n: Node2D, p: Vector2, r: float, col: Color) -> void:
	n.draw_circle(p + Vector2(3, 5), r, Color(0, 0, 0, 0.35))
	n.draw_circle(p, r, col.darkened(0.35))
	n.draw_circle(p - Vector2(r, r) * 0.12, r * 0.8, col)
	n.draw_circle(p - Vector2(r, r) * 0.35, r * 0.28, Color(1, 1, 1, 0.9))

func _rett(n: Node2D, centro: Vector2, dim: Vector2, ang: float, col: Color) -> void:
	n.draw_set_transform(centro, ang)
	n.draw_rect(Rect2(-dim * 0.5, dim), col)
	n.draw_set_transform(Vector2.ZERO)

func _scritta(n: Node2D, testo: String, centro: Vector2, corpo: int, col: Color) -> void:
	# v0.30: senza il font del tavolo (copia pubblica) si usa quello di base di Godot (prima: errore e niente scritta)
	if _font == null:
		_font = ThemeDB.fallback_font
	var w := _font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, corpo).x
	n.draw_string(_font, centro - Vector2(w * 0.5, -corpo * 0.35), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, corpo, col)

func _chiudi(pts: PackedVector2Array) -> PackedVector2Array:
	var c := PackedVector2Array(pts)
	if c.size() > 0:
		c.append(c[0])
	return c

func _centro(pts: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for p in pts:
		s += p
	return s / maxf(1.0, pts.size())

func _v3(p) -> Vector3:
	if p is Vector3:
		return p
	return Vector3(p[0], p[1], p[2] if p.size() > 2 else 0.0)
