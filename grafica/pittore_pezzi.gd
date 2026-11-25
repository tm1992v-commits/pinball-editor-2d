## PITTORE DEI PEZZI (Pinball Editor 2D v0.5, 24/11/2026). Un solo disegno per ogni pezzo, usato SIA dall'editor SIA
##
##        Pinball): il tavolo si guarda un po' inclinato dal basso, quindi ogni pezzo ha la BASE dove sta per la fisica
##        e la CIMA spostata in alto di (altezza × K); in mezzo si vedono i FIANCHI, sfumati come un cilindro o un
##        prisma (luce da sinistra-davanti). Bumper alti con la gonna a strisce e la cupola lucida, paletti di gomma,
##        bersagli in piedi, buche con la parete interna, muri come blocchi o tubi cromati, fionde a prisma con la
##        gomma a tubo, palette spesse. Ombre morbide sul piano in basso a destra.
##  "piatto" colori pieni e contorni netti, senza ombre né fianchi.
## Ogni pezzo: "aspetto" = "" (come il tavolo), "3d" o "piatto"; il tavolo: desc["aspetto"]. "colore" proprio o del tavolo.
## Unità: mm. `base` = trasformazione mm -> schermo (editor: zoom; gioco: nessuna).
## Nel gioco gli strati fissi si disegnano UNA volta (costo zero a ogni fotogramma): regola della grafica prerenderizzata.
class_name PittorePezzi

const K := 0.45                            # quanto sale la cima per ogni mm di altezza (inclinazione della vista)
const OMBRA := Vector2(0.42, 0.55)         # dove cade l'ombra per ogni mm di altezza
const LUCE := Vector2(-0.8, 0.45)          # da dove arriva la luce sui fianchi (sinistra, un po' davanti)
const METALLO := Color(0.72, 0.74, 0.78)
const LEGNO := Color(0.45, 0.3, 0.17)
const GOMMA := Color(0.1, 0.1, 0.1)

const TIPI := ["bumper", "elastici", "bersagli", "buche", "spinner", "muri", "fionde", "palette", "kickback", "cancelli", "piani"]

## Altezze (mm) dei pezzi per il disegno 3D (si potranno cambiare pezzo per pezzo in futuro).
const H_BUMPER := 34.0
const H_PALETTO := 14.0
const H_BERSAGLIO := 18.0
const H_FIONDA := 20.0
const H_PALETTA := 12.0
const H_SPINNER := 24.0
const H_KICKBACK := 5.0

const ALTEZZE := {"bumper": H_BUMPER, "elastici": H_PALETTO, "bersagli": H_BERSAGLIO, "fionde": H_FIONDA,
	"palette": H_PALETTA, "spinner": H_SPINNER, "kickback": H_KICKBACK, "buche": 3.0, "cancelli": 22.0}

static func su(h: float) -> Vector2:
	return Vector2(0.0, -h * K)

## Altezza del pezzo nel disegno 3D (mm): la sua («altezza_3d», v0.6) o quella del tipo. I muri usano «altezza».
static func altezza(chiave: String, e: Dictionary) -> float:
	if chiave == "piani":
		return clampf(float(e.get("altezza", 40.0)), 5.0, 120.0)
	if chiave == "muri":
		var hm = e.get("altezza")
		if hm != null:
			return clampf(float(hm), 4.0, 60.0)
		return {"legno": 26.0, "gomma": 12.0}.get(str(e.get("tipo", "metallo")), 16.0) as float
	var h = e.get("altezza_3d")
	if h != null and float(h) > 0.0:
		return clampf(float(h), 2.0, 120.0)
	return float(ALTEZZE.get(chiave, 10.0))

# ================================================================ immagini proprie (v0.6)
## viaggiano con il tavolo (prova, gioco, esportazione) e non si perdono. Ogni pezzo può averne una:
## e["immagine"] = {"nome", "dim" (mm), "pos" (spostamento dal centro, mm), "rot" (radianti), "modo": "sopra" | "sostituisce"}.
static var _cache := {}                    # nome -> [lunghezza dei dati, Texture2D]

static func texture(desc: Dictionary, nome: String) -> Texture2D:
	var lib = desc.get("immagini", {})
	if not lib is Dictionary or not lib.has(nome):
		return null
	# v0.22: nel PROGETTO GODOT esportato le immagini stanno anche come file PNG in res://gioco/immagini/:
	# se ci sono si usano quelle (si possono ridipingere e sostituire da Godot senza toccare il tavolo)
	var file := "res://gioco/immagini/%s.png" % nome
	if ResourceLoader.exists(file):
		var tf = load(file)
		if tf is Texture2D:
			return tf
	var dati: String = lib[nome]
	var c = _cache.get(nome)
	if c is Array and int(c[0]) == dati.length():
		return c[1]
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(dati)) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_cache[nome] = [dati.length(), t]
	return t

## Prepara un file d'immagine (PNG, JPG, WEBP) per il tavolo: ridotto a max `lato` px, in PNG base64. "" = errore.
static func importa(percorso: String, lato := 1024) -> String:
	var img := Image.load_from_file(percorso)
	if img == null or img.is_empty():
		return ""
	if maxi(img.get_width(), img.get_height()) > lato:
		var f := float(lato) / maxi(img.get_width(), img.get_height())
		img.resize(maxi(1, int(img.get_width() * f)), maxi(1, int(img.get_height() * f)), Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	return Marshalls.raw_to_base64(img.save_png_to_buffer())

static func ha_immagine(e: Dictionary) -> bool:
	return e.get("immagine") is Dictionary and str(e["immagine"].get("nome", "")) != ""

static func sostituisce(e: Dictionary) -> bool:
	return ha_immagine(e) and str(e["immagine"].get("modo", "sopra")) == "sostituisce"

## Grandezza naturale dell'immagine sul pezzo (mm): quanto il pezzo (es. tutto il bumper).
static func misura_pezzo(chiave: String, e: Dictionary) -> Vector2:
	match chiave:
		"bumper":
			return Vector2.ONE * (float(e["raggio"]) + 6.0) * 2.0
		"elastici", "buche":
			return Vector2.ONE * (float(e.get("raggio", 10.0)) + 4.0) * 2.0
		"bersagli", "kickback":
			return e.get("dim", Vector2(24, 8))
		"spinner", "cancelli":
			return Vector2(float(e["larghezza"]) + 4.0, 14.0)
		"palette":
			return Vector2(float(e["lunghezza"]) + 12.0, 26.0)
	var r := _riquadro(e.get("punti", []))
	return r.size if r.size != Vector2.ZERO else Vector2(40, 40)

static func _riquadro(pts) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var r := Rect2(Vector2(pts[0].x, pts[0].y), Vector2.ZERO)
	for q in pts:
		r = r.expand(Vector2(q.x, q.y))
	return r

## Punto del pezzo su cui sta l'immagine (la sua cima, in 3D).
static func ancora(chiave: String, e: Dictionary, desc: Dictionary) -> Vector2:
	var c: Vector2
	match chiave:
		"palette":
			return Vector2.ZERO
		"bumper":
			return cima_bumper(e, desc)
		"spinner":
			return cima_spinner(e, desc)
		"piani", "rampe":
			return _riquadro(e.get("punti", [])).get_center()
		"fionde", "muri":
			c = _riquadro(e.get("punti", [])).get_center()
		_:
			c = e.get("pos", Vector2.ZERO)
	if piatto(e, desc):
		return c
	return c + su(altezza(chiave, e) * (0.85 if chiave == "fionde" else 1.0))

## Disegna l'immagine del pezzo intorno al punto `c` (già trasformato da chi chiama).
static func disegna_immagine(ci: CanvasItem, e: Dictionary, desc: Dictionary, c: Vector2, base := Transform2D.IDENTITY, giro := 0.0) -> void:
	if not ha_immagine(e):
		return
	var im: Dictionary = e["immagine"]
	var t := texture(desc, str(im["nome"]))
	if t == null:
		return
	var dim: Vector2 = im.get("dim", Vector2(40, 40))
	ci.draw_set_transform_matrix(base * Transform2D(float(im.get("rot", 0.0)) + giro, c + Vector2(im.get("pos", Vector2.ZERO)).rotated(giro)))
	ci.draw_texture_rect(t, Rect2(-dim * 0.5, dim), false)
	ci.draw_set_transform_matrix(base)

# ================================================================ scelte del pezzo
static func piatto(e: Dictionary, desc: Dictionary) -> bool:
	var a := str(e.get("aspetto", ""))
	if a == "":
		a = str(desc.get("aspetto", "3d"))
	return a == "piatto"

static func _col_tavolo(desc: Dictionary, chiave: String, riserva: Color) -> Color:
	var cc = desc.get("colori", {})
	if cc is Dictionary and cc.get(chiave) is Color:
		return cc[chiave]
	return riserva

static func colore(chiave: String, e: Dictionary, desc: Dictionary) -> Color:
	if e.get("colore") is Color:
		return e["colore"]
	var primario := _col_tavolo(desc, "primario", Color(0.86, 0.0, 0.1))
	var secondario := _col_tavolo(desc, "secondario", Color(0.12, 0.6, 0.92))
	match chiave:
		"bumper", "fionde":
			return secondario
		"elastici", "palette", "spinner":
			return primario
		"cancelli":
			return Color(0.86, 0.88, 0.94)
		"piani":
			return Color(0.42, 0.22, 0.62)
		"rampe":
			var cr = desc.get("colori", {}).get("rampe", {}) if desc.get("colori", {}) is Dictionary else {}
			return cr.get(e.get("id", ""), secondario) if cr is Dictionary else secondario
		"bersagli":
			if str(e.get("gruppo", "")) == "missione":
				return Color(0.4, 0.95, 0.35)
			return Color(1.0, 0.82, 0.15) if bool(e.get("abbattibile", false)) else Color(0.9, 0.12, 0.12)
		"buche":
			match str(e.get("tipo", "")):
				"portale":
					return Color(0.35, 1.0, 0.6)
				"tiene":
					return Color(1.0, 0.3, 0.85)
			return METALLO
		"kickback":
			return Color(1.0, 0.45, 0.12)
		"muri":
			match str(e.get("tipo", "metallo")):
				"legno":
					return LEGNO
				"gomma":
					return GOMMA
			return METALLO
	return Color.WHITE

static func colore_interno(e: Dictionary, desc: Dictionary) -> Color:
	if e.get("colore_2") is Color:
		return e["colore_2"]
	return _col_tavolo(desc, "primario", Color(0.86, 0.0, 0.1))

## Dove sta la cupola del bumper (il gioco ci mette la luce della regia).
static func cima_bumper(b: Dictionary, desc: Dictionary) -> Vector2:
	if piatto(b, desc):
		return b["pos"]
	return Vector2(b["pos"]) + su(maxf(altezza("bumper", b), 22.0) + 3.0)

## Dove si vede la piastra dello spinner (appesa al filo in cima alle staffe).
static func cima_spinner(sp: Dictionary, desc: Dictionary) -> Vector2:
	if piatto(sp, desc):
		return sp["pos"]
	return Vector2(sp["pos"]) + su(altezza("spinner", sp) * 0.55)

# ================================================================ BORDI e LUCE AMBIENTALE (v0.8)
## Bordo di un pezzo (e["bordo"]): "" nessuno · "semplice" linea piena (nero o colore scelto) · "rilievo" bordo 3D
## (luce in alto a sinistra, ombra in basso a destra) · "neon" striscia luminosa (alone morbido + anima chiara).
## colore_bordo e intensita_bordo (0,2-3) lo personalizzano. Si disegna intorno alla BASE del pezzo, dove tocca il piano
## (l'alone del neon va «sotto», prima del pezzo; l'anima del neon e gli altri bordi vanno «sopra»).
const BORDI := ["", "semplice", "rilievo", "neon"]

static func colore_bordo(chiave: String, e: Dictionary, desc: Dictionary) -> Color:
	if e.get("colore_bordo") is Color:
		return e["colore_bordo"]
	match str(e.get("bordo", "")):
		"semplice":
			return Color(0.02, 0.02, 0.03)
		"neon":
			if chiave == "muri":
				return Color(0.2, 0.85, 1.0)
			return (colore_interno(e, desc) if chiave == "fionde" else colore(chiave, e, desc)).lightened(0.25)
	return colore(chiave, e, desc)

## Contorno del pezzo sul piano (mm): [punti, chiuso].
static func sagoma(chiave: String, e: Dictionary, desc: Dictionary) -> Array:
	var p := piatto(e, desc)
	match chiave:
		"bumper":
			return [_cerchio(e["pos"], float(e["raggio"]) + (5.5 if p else 7.5)), true]
		"elastici":
			return [_cerchio(e["pos"], float(e["raggio"]) + 2.8), true]
		"buche":
			return [_cerchio(e["pos"], float(e.get("raggio", 15.0)) + (4.5 if p else 5.8)), true]
		"bersagli", "kickback":
			var dim: Vector2 = Vector2(e.get("dim", Vector2(24, 8))) + Vector2(3, 3)
			var t := Transform2D(float(e.get("angolo", 0.0)), e["pos"])
			return [PackedVector2Array([t * (-dim * 0.5), t * Vector2(dim.x * 0.5, -dim.y * 0.5), t * (dim * 0.5), t * Vector2(-dim.x * 0.5, dim.y * 0.5)]), true]
		"spinner", "cancelli":
			var lw := float(e.get("larghezza", 40.0)) * 0.5 + 6.0
			var t2 := Transform2D(float(e.get("angolo", 0.0)), e["pos"])
			return [PackedVector2Array([t2 * Vector2(-lw, -6), t2 * Vector2(lw, -6), t2 * Vector2(lw, 6), t2 * Vector2(-lw, 6)]), true]
		"fionde", "piani":
			return [PackedVector2Array(e.get("punti", PackedVector2Array())), true]
		"muri":
			return [PackedVector2Array(e["punti"]), bool(e.get("chiuso", false))]
	return [PackedVector2Array(), false]

static func _cerchio(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 40:
		out.append(c + Vector2.from_angle(TAU * k / 40.0) * r)
	return out

## Disegna il bordo `tipo` nella `fase` ("sotto" o "sopra") lungo i punti dati.
static func bordo_linea(ci: CanvasItem, pts: PackedVector2Array, chiuso: bool, tipo: String, col: Color, k: float, fase: String) -> void:
	if pts.size() < 2 or tipo == "":
		return
	var linea := PackedVector2Array(pts)
	if chiuso and pts[0].distance_to(pts[pts.size() - 1]) > 0.5:
		linea.append(pts[0])
	k = clampf(k, 0.2, 3.0)
	match tipo:
		"neon":
			if fase == "sotto":
				# alone sul piano: strisce larghe e trasparenti (il colore si «spande» come un tubo al neon vero)
				for s in [[26.0, 0.05], [18.0, 0.09], [12.0, 0.15], [7.5, 0.26], [5.0, 0.4]]:
					ci.draw_polyline(linea, Color(col, clampf(float(s[1]) * k, 0.0, 0.9)), float(s[0]) * sqrt(k), true)
			else:
				ci.draw_polyline(linea, Color(col, clampf(0.9 * k, 0.0, 1.0)), 3.4 * sqrt(k), true)
				ci.draw_polyline(linea, col.lerp(Color.WHITE, 0.7), 1.4 * sqrt(k), true)
		"semplice":
			if fase == "sopra":
				ci.draw_polyline(linea, col, 1.6 * k, true)
		"rilievo":
			if fase == "sopra":
				var giu := PackedVector2Array()
				var su_l := PackedVector2Array()
				for q in linea:
					giu.append(q + Vector2(0.7, 0.9) * k)
					su_l.append(q + Vector2(-0.6, -0.8) * k)
				ci.draw_polyline(giu, Color(0, 0, 0, 0.6), 2.2 * k, true)
				ci.draw_polyline(linea, col, 2.0 * k, true)
				ci.draw_polyline(su_l, Color(1, 1, 1, 0.55), 0.9 * k, true)

static func bordo(ci: CanvasItem, chiave: String, e: Dictionary, desc: Dictionary, fase: String) -> void:
	var tipo := str(e.get("bordo", ""))
	if tipo == "":
		return
	var sg := sagoma(chiave, e, desc)
	var col := colore_bordo(chiave, e, desc)
	var k := float(e.get("intensita_bordo", 1.0))
	if chiave == "muri" and tipo in ["semplice", "rilievo"] and not (bool(e.get("chiuso", false)) and str(e.get("tipo", "")) != "gomma"):
		# muro (guida, sponda): il contorno segue la SAGOMA della guida alla sua altezza (sul piano sarebbe nascosto dal muro)
		var mt := str(e.get("tipo", "metallo"))
		var w := {"legno": 7.0, "gomma": 5.0}.get(mt, 3.0) as float
		var u := Vector2.ZERO if piatto(e, desc) else su(altezza("muri", e) * (1.0 if mt == "legno" else 0.5))
		var linea := PackedVector2Array(sg[0])
		if bool(sg[1]) and linea.size() > 2:
			linea.append(linea[0])
		for pol in Geometry2D.offset_polyline(linea, w * 0.5 + 0.8, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			var su_pol := PackedVector2Array()
			for q in pol:
				su_pol.append(q + u)
			bordo_linea(ci, su_pol, true, tipo, col, k, fase)
		return
	bordo_linea(ci, sg[0], sg[1], tipo, col, k, fase)

## LUCE AMBIENTALE del tavolo (desc["luce_ambiente"] = {colore, intensita 0-1, da: alto | basso | lati | ovunque}):
## una luce colorata che bagna il piano, sfumata dal lato da cui arriva (sotto i pezzi, dentro la sponda).
static func luce_ambiente(desc: Dictionary) -> Dictionary:
	var la = desc.get("luce_ambiente", {})
	if not la is Dictionary or str(la.get("da", "")) in ["", "spenta"] or float(la.get("intensita", 0.0)) <= 0.0:
		return {}
	return la

static func ambiente_sul_piano(ci: CanvasItem, desc: Dictionary, base := Transform2D.IDENTITY) -> void:
	var la := luce_ambiente(desc)
	if la.is_empty():
		return
	var dim: Vector2 = desc.get("dimensioni", Vector2(635, 1240))
	var col: Color = la.get("colore", Color(0.4, 0.6, 1.0))
	var k := clampf(float(la.get("intensita", 0.5)), 0.0, 1.0)
	var muri = desc.get("muri", [])
	var contorno := PackedVector2Array([Vector2.ZERO, Vector2(dim.x, 0), dim, Vector2(0, dim.y)])
	if muri is Array and not muri.is_empty() and Geometry2D.triangulate_polygon(PackedVector2Array(muri[0]["punti"])).size() > 0:
		contorno = PackedVector2Array(muri[0]["punti"])
	var da := str(la.get("da", "alto"))
	var colori := PackedColorArray()
	for q in contorno:
		var t: float
		match da:
			"basso":
				t = q.y / dim.y
			"lati":
				t = absf(q.x / dim.x - 0.5) * 2.0
			"ovunque":
				t = 0.75
			_:
				t = 1.0 - q.y / dim.y
		colori.append(Color(col, clampf(t * t * 0.6 * k, 0.0, 0.8)))
	ci.draw_set_transform_matrix(base)
	ci.draw_polygon(contorno, colori)

# ================================================================ luci del piano (inserti), v0.8
const FORME_LUCE := ["tondo", "freccia", "rettangolo", "rombo", "triangolo", "stella", "esagono"]

## Sagoma di una luce del piano (mm): stessa per editor e gioco. dim = larghezza × lunghezza, dir = verso (la punta
## della freccia/triangolo; per le altre forme è la rotazione).
static func forma_luce(i: Dictionary) -> PackedVector2Array:
	var pos: Vector2 = i["pos"]
	var dim: Vector2 = i.get("dim", Vector2(16, 16))
	var dir: Vector2 = Vector2(i.get("dir", Vector2(0, -1)))
	if i.has("angolo_luce"):
		dir = Vector2(0, -1).rotated(float(i["angolo_luce"]))
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(0, -1)
	var lato := Vector2(-dir.y, dir.x)
	var w := dim.x * 0.5
	var l := dim.y * 0.5
	var loc := PackedVector2Array()
	match str(i.get("forma", "tondo")):
		"freccia":
			loc = PackedVector2Array([Vector2(0, l), Vector2(w, -l), Vector2(0, -l * 0.5), Vector2(-w, -l)])
		"rettangolo":
			loc = PackedVector2Array([Vector2(-w, -l), Vector2(w, -l), Vector2(w, l), Vector2(-w, l)])
		"rombo":
			loc = PackedVector2Array([Vector2(0, l), Vector2(w, 0), Vector2(0, -l), Vector2(-w, 0)])
		"triangolo":
			loc = PackedVector2Array([Vector2(0, l), Vector2(w, -l), Vector2(-w, -l)])
		"stella":
			for k in 10:
				var a := TAU * k / 10.0
				var r := 1.0 if k % 2 == 0 else 0.45
				loc.append(Vector2(sin(a) * w * r, cos(a) * l * r))
		"esagono":
			for k in 6:
				var a := TAU * k / 6.0
				loc.append(Vector2(sin(a) * w, cos(a) * l))
		_:
			for k in 16:
				var a := TAU * k / 16.0
				loc.append(Vector2(sin(a) * w, cos(a) * l))
	# coordinate locali: y = verso della punta, x = di lato
	var out := PackedVector2Array()
	for q in loc:
		out.append(pos + dir * q.y + lato * q.x)
	return out

## Luce del piano come si vede SPENTA nell'editor e nel bake: lente colorata scura, bordo, riflesso. Accesa la fa la regia.
static func luce(ci: CanvasItem, i: Dictionary, desc: Dictionary, accesa := 0.35) -> void:
	var f := forma_luce(i)
	var col: Color = i.get("colore", Color(1, 0.8, 0.3))
	var p := piatto(i, desc)
	if not p:
		var giro := PackedVector2Array(f)
		giro.append(f[0])
		ci.draw_polyline(giro, Color(0, 0, 0, 0.55), 2.4, true)
	ci.draw_colored_polygon(f, col.darkened(0.8).lerp(col, accesa))
	var cc := Vector2.ZERO
	for q in f:
		cc += q
	cc /= float(f.size())
	if not p:
		var rifl := PackedVector2Array()
		for q in f:
			rifl.append(cc + (q - cc) * 0.45 + Vector2(-0.8, -1.0))
		ci.draw_colored_polygon(rifl, Color(1, 1, 1, 0.18))
	var giro2 := PackedVector2Array(f)
	giro2.append(f[0])
	ci.draw_polyline(giro2, col.lightened(0.3), 0.8, true)

# ================================================================ immagini del piano (v0.6)
## Fondo dipinto del tavolo (desc["fondo"] = nome dell'immagine): copre tutto il rettangolo del tavolo.
static func fondo(ci: CanvasItem, desc: Dictionary, base := Transform2D.IDENTITY) -> bool:
	var t := texture(desc, str(desc.get("fondo", "")))
	if t == null:
		return false
	ci.draw_set_transform_matrix(base)
	var dim: Vector2 = desc.get("dimensioni", Vector2(635, 1240))
	# ritagliato sulla forma del tavolo (la sponda è il primo muro): fuori resta il legno del mobile
	var muri = desc.get("muri", [])
	if muri is Array and not muri.is_empty():
		var contorno := PackedVector2Array(muri[0].get("punti", PackedVector2Array()))
		if contorno.size() >= 3 and not Geometry2D.triangulate_polygon(contorno).is_empty():
			var uv := PackedVector2Array()
			for q in contorno:
				uv.append(Vector2(q.x / dim.x, q.y / dim.y))
			ci.draw_colored_polygon(contorno, Color.WHITE, uv, t)
			return true
	ci.draw_texture_rect(t, Rect2(Vector2.ZERO, dim), false)
	return true

## Immagine libera sul piano (pezzo «decorazioni»): centro pos, misura dim, rotazione angolo, trasparenza, a specchio.
## Senza immagine non disegna niente (l'editor mostra un riquadro). Restituisce true se ha disegnato.
static func decorazione(ci: CanvasItem, e: Dictionary, desc: Dictionary, base := Transform2D.IDENTITY) -> bool:
	if not ha_immagine(e):
		return false
	var t := texture(desc, str(e["immagine"]["nome"]))
	if t == null:
		return false
	var dim: Vector2 = e.get("dim", Vector2(100, 100))
	var sc := Vector2(-1.0 if bool(e.get("specchiata", false)) else 1.0, 1.0)
	ci.draw_set_transform_matrix(base * Transform2D(float(e.get("angolo", 0.0)), sc, 0.0, e["pos"]))
	ci.draw_texture_rect(t, Rect2(-dim * 0.5, dim), false, Color(1, 1, 1, clampf(float(e.get("opacita", 1.0)), 0.0, 1.0)))
	ci.draw_set_transform_matrix(base)
	return true

# ================================================================ disegno di un pezzo qualsiasi
## stato (gioco): "giu" (bersaglio abbattuto), "flash" 0-1, "col" (colore della regia), "senza_piastra" (spinner).
static func disegna(ci: CanvasItem, chiave: String, e: Dictionary, desc: Dictionary, base := Transform2D.IDENTITY, stato := {}) -> void:
	var p := piatto(e, desc)
	var col: Color = stato.get("col", colore(chiave, e, desc))
	var fl := float(stato.get("flash", 0.0))
	if fl > 0.0:
		col = col.lerp(Color.WHITE, fl * 0.7)
	ci.draw_set_transform_matrix(base)
	if sostituisce(e) and chiave != "palette":
		# al posto del disegno: resta solo l'ombra sul piano (in 3D), poi l'immagine
		if not p:
			var mp := misura_pezzo(chiave, e)
			ombra_cerchio(ci, ancora(chiave, e, desc) - su(altezza(chiave, e)), minf(mp.x, mp.y) * 0.45, altezza(chiave, e))
		disegna_immagine(ci, e, desc, ancora(chiave, e, desc), base)
		return
	var hh := altezza(chiave, e)
	if chiave != "palette":
		bordo(ci, chiave, e, desc, "sotto")
	match chiave:
		"bumper":
			bumper(ci, e["pos"], float(e["raggio"]), col, colore_interno(e, desc), p, hh)
		"elastici":
			paletto(ci, e["pos"], float(e["raggio"]), col, p, hh)
		"bersagli":
			bersaglio(ci, e["pos"], e.get("dim", Vector2(24, 8)), float(e.get("angolo", 0.0)), col, p, bool(stato.get("giu", false)), base, hh)
		"buche":
			buca(ci, e["pos"], float(e.get("raggio", 15.0)), col, p, str(e.get("tipo", "")))
		"spinner":
			spinner(ci, e, col, p, base, not bool(stato.get("senza_piastra", false)), hh)
		"muri":
			var la := luce_ambiente(desc)
			var rifl := Color.WHITE if la.is_empty() else Color.WHITE.lerp(Color(la.get("colore", Color.WHITE)), clampf(float(la.get("intensita", 0.5)), 0.0, 1.0))
			muro(ci, e, col, p, rifl)
		"fionde":
			fionda(ci, PackedVector2Array(e["punti"]), col, colore_interno(e, desc), p, hh)
		"palette":
			var verso := float(e.get("verso", 1.0))
			var ang: Vector2 = desc.get("paletta_angoli", Vector2(0.5, -0.5))
			var a := ang.x if verso > 0 else -ang.x
			var sp := float(e.get("spessore", 11.6))
			var L := float(e["lunghezza"]) * verso
			if not p:
				ombra_paletta(ci, base * Transform2D(a, e["perno"]), L, sp, a, hh)
			ci.draw_set_transform_matrix(base * Transform2D(a, e["perno"]))
			bordo_paletta(ci, e, desc, L, sp, "sotto")
			if not sostituisce(e):
				paletta(ci, L, sp, col, p, a, hh)
			bordo_paletta(ci, e, desc, L, sp, "sopra")
			immagine_paletta(ci, e, desc, base * Transform2D(a, e["perno"]), L, a, p, hh)
		"kickback":
			kickback(ci, e["pos"], e.get("dim", Vector2(40, 12)), col, p, hh)
		"cancelli":
			cancello(ci, e, col, p, base, float(stato.get("apertura", 0.0)), hh)
		"piani":
			piano(ci, e, col, p, hh)
	ci.draw_set_transform_matrix(base)
	if chiave != "palette":
		bordo(ci, chiave, e, desc, "sopra")
		disegna_immagine(ci, e, desc, ancora(chiave, e, desc), base)

## Bordo della paletta (coordinate della paletta, già impostate da chi chiama).
static func bordo_paletta(ci: CanvasItem, e: Dictionary, desc: Dictionary, L: float, sp: float, fase: String) -> void:
	var tipo := str(e.get("bordo", ""))
	if tipo != "":
		bordo_linea(ci, forma_paletta(L, sp * 1.15), true, tipo, colore_bordo("palette", e, desc), float(e.get("intensita_bordo", 1.0)), fase)

## Immagine della paletta (gira con la paletta: `t` = trasformazione della paletta).
static func immagine_paletta(ci: CanvasItem, e: Dictionary, desc: Dictionary, t: Transform2D, L: float, rot: float, p: bool, h := H_PALETTA) -> void:
	if not ha_immagine(e):
		return
	var u := Vector2.ZERO if p else su(h).rotated(-rot)
	disegna_immagine(ci, e, desc, u + Vector2(L * 0.45, 0.0), t)

# ================================================================ mattoni del 3D
## Luce di un fianco con normale `n` (verso l'esterno, nel piano): 0 = in ombra, 1 = in piena luce.
static func _lum(n: Vector2) -> float:
	return clampf(0.5 + 0.5 * n.normalized().dot(LUCE.normalized()), 0.0, 1.0)

static func _tinta(col: Color, lum: float) -> Color:
	return col.darkened(0.62).lerp(col.lightened(0.22), lum)

## Ombra morbida di un cerchio alto h.
static func ombra_cerchio(ci: CanvasItem, c: Vector2, r: float, h: float) -> void:
	for i in 4:
		var t := 0.45 + 0.2 * i
		ci.draw_circle(c + OMBRA * h * t, r + 1.0 + i * 1.6, Color(0, 0, 0, 0.13))

## Ombra morbida di un poligono alto h.
static func ombra_poligono(ci: CanvasItem, pts: PackedVector2Array, h: float) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	for i in 3:
		var o := OMBRA * h * (0.45 + 0.25 * i)
		var q := PackedVector2Array()
		for v in pts:
			q.append(v + o)
		ci.draw_colored_polygon(q, Color(0, 0, 0, 0.16))

## Cilindro: base (cerchio c, r) sul piano, cima spostata in alto di h. Fianco sfumato come un vero cilindro;
## `strisce` > 0 = fianco a strisce alternate con col2 (la gonna dei bumper della tavola di riferimento).
static func cilindro(ci: CanvasItem, c: Vector2, r: float, h: float, col: Color, strisce := 0, col2 := Color.WHITE) -> void:
	var u := su(h)
	var n := 28
	for i in n:
		var a0 := PI * i / n
		var a1 := PI * (i + 1) / n
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var cb := col
		if strisce > 0 and int(floor((a0 + a1) * 0.5 / PI * strisce * 2.0)) % 2 == 1:
			cb = col2
		var k0 := _tinta(cb, _lum(d0))
		var k1 := _tinta(cb, _lum(d1))
		ci.draw_polygon(PackedVector2Array([c + d0 * r, c + d1 * r, c + d1 * r + u, c + d0 * r + u]),
			PackedColorArray([k0.darkened(0.15), k1.darkened(0.15), k1, k0]))
	# riflesso verticale (la luce sul cilindro) e filo scuro alla base
	var dr := Vector2(cos(PI * 0.78), sin(PI * 0.78)) * r * 0.92
	ci.draw_line(c + dr, c + dr + u * 0.9, Color(1, 1, 1, 0.35), maxf(0.8, r * 0.12), true)
	ci.draw_arc(c, r, 0.0, PI, 24, Color(0, 0, 0, 0.45), 1.0, true)

## Disco lucido (la faccia in alto di un cilindro): sfumato verso la luce, riflesso a mezzaluna.
static func disco(ci: CanvasItem, c: Vector2, r: float, col: Color, lucido := 1.0) -> void:
	ci.draw_circle(c, r, col.darkened(0.25))
	var passi := 7
	for i in passi:
		var t := float(i + 1) / passi
		ci.draw_circle(c + Vector2(-0.22, -0.28) * r * t, r * (1.0 - t * 0.72), col.lerp(col.lightened(0.42 * lucido), t))
	ci.draw_arc(c, r * 0.78, PI * 1.05, PI * 1.55, 14, Color(1, 1, 1, 0.55 * lucido), maxf(0.8, r * 0.1), true)
	ci.draw_circle(c + Vector2(-0.38, -0.42) * r, r * 0.12, Color(1, 1, 1, 0.9 * lucido))

## Prisma: poligono di base sul piano, alto h. Si vedono i fianchi rivolti verso chi guarda (sfumati con la luce) e la
## cima. Restituisce i punti della cima.
static func prisma(ci: CanvasItem, pts: PackedVector2Array, h: float, col_cima: Color, col_fianco: Color, ombra := true) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	if ombra:
		ombra_poligono(ci, pts, h)
	var u := su(h)
	var area := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	var verso := 1.0 if area > 0.0 else -1.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		if a.distance_to(b) < 0.05:
			continue
		var nrm := Vector2(b.y - a.y, a.x - b.x).normalized() * verso   # normale verso l'esterno
		if nrm.y < -0.02:
			continue                     # fianco rivolto dall'altra parte: nascosto dalla cima
		var k := _tinta(col_fianco, _lum(nrm))
		ci.draw_polygon(PackedVector2Array([a, b, b + u, a + u]), PackedColorArray([k.darkened(0.2), k.darkened(0.2), k, k]))
	var cima := PackedVector2Array()
	for v in pts:
		cima.append(v + u)
	if not Geometry2D.triangulate_polygon(cima).is_empty():
		ci.draw_colored_polygon(cima, col_cima)
	return cima

## Bordo di luce sui lati della cima rivolti verso la luce (alto a sinistra) e bordo scuro sugli altri.
static func smusso(ci: CanvasItem, cima: PackedVector2Array, col: Color, w := 1.2, riflesso := Color.WHITE) -> void:
	var area := 0.0
	for i in cima.size():
		var a := cima[i]
		var b := cima[(i + 1) % cima.size()]
		area += a.x * b.y - b.x * a.y
	var verso := 1.0 if area > 0.0 else -1.0
	for i in cima.size():
		var a := cima[i]
		var b := cima[(i + 1) % cima.size()]
		var nrm := Vector2(b.y - a.y, a.x - b.x).normalized() * verso
		var luce := nrm.dot(Vector2(-0.6, -0.8))
		var c := Color(riflesso, 0.6 * luce) if luce > 0.0 else Color(col.darkened(0.6), 0.7 * -luce)
		ci.draw_line(a, b, c, w, true)

## Tubo (gomma, filo cromato): sezione tonda vista dall'alto, sollevata di h (ombra, corpo, riflesso).
static func tubo(ci: CanvasItem, linea: PackedVector2Array, w: float, h: float, col: Color, cromo := false, riflesso := Color.WHITE) -> void:
	var om := PackedVector2Array()
	var mezzo := PackedVector2Array()
	var cima := PackedVector2Array()
	var luce := PackedVector2Array()
	for q in linea:
		om.append(q + OMBRA * h * 0.8)
		mezzo.append(q + su(h * 0.5))
		cima.append(q + su(h))
		luce.append(q + su(h) + Vector2(-0.3, -0.45) * w * 0.35)
	ci.draw_polyline(om, Color(0, 0, 0, 0.32), w + 2.0, true)
	# fianco: dalla base alla cima (striscia piena)
	for i in linea.size() - 1:
		var a := linea[i]
		var b := linea[i + 1]
		var t := (b - a).normalized()
		var nrm := Vector2(t.y, -t.x)
		if nrm.y < 0.0:
			nrm = -nrm
		var o := nrm * w * 0.5
		var k := _tinta(col, _lum(nrm)).darkened(0.2)
		ci.draw_polygon(PackedVector2Array([a + o, b + o, b + o + su(h), a + o + su(h)]), PackedColorArray([k.darkened(0.2), k.darkened(0.2), k, k]))
	ci.draw_polyline(cima, col.darkened(0.45), w + 1.2, true)
	ci.draw_polyline(cima, col, w, true)
	ci.draw_polyline(luce, Color(riflesso, 0.85 if cromo else 0.4), maxf(0.7, w * 0.3), true)

# ================================================================ i pezzi
## Bumper come la tavola di riferimento: base scura, GONNA a strisce (bianco e colore 1), corpo alto col colore del
## bumper, anello cromato in cima e CUPOLA lucida.
static func bumper(ci: CanvasItem, c: Vector2, r: float, col: Color, col_strisce: Color, p: bool, H := H_BUMPER) -> void:
	if p:
		ci.draw_circle(c, r + 5.0, Color(0.92, 0.92, 0.94))
		ci.draw_circle(c, r, col)
		ci.draw_circle(c, r * 0.45, Color(0.97, 0.97, 1.0))
		ci.draw_arc(c, r + 5.0, 0, TAU, 40, col.darkened(0.5), 1.2, true)
		return
	H = maxf(H, 22.0)
	ombra_cerchio(ci, c, r + 6.0, H)
	# piattello alla base (anello di metallo sul piano)
	ci.draw_circle(c, r + 7.0, Color(0.16, 0.16, 0.19))
	cilindro(ci, c, r + 6.0, 3.0, Color(0.78, 0.79, 0.83))
	var c1 := c + su(3.0)
	disco(ci, c1, r + 6.0, Color(0.7, 0.71, 0.75), 0.4)
	# gonna a strisce (plastica bianca e colorata) che si allarga in basso
	cilindro(ci, c1, r + 3.5, 13.0, Color(0.96, 0.95, 0.92), 6, col_strisce)
	var c2 := c1 + su(13.0)
	disco(ci, c2, r + 3.5, Color(0.95, 0.94, 0.9), 0.5)
	# corpo del bumper
	cilindro(ci, c2, r * 0.82, H - 19.0, col)
	var c3 := c2 + su(H - 19.0)
	# cima: anello cromato e cupola
	disco(ci, c3, r * 0.82, Color(0.85, 0.86, 0.9), 0.7)
	ci.draw_arc(c3, r * 0.82, 0, TAU, 40, Color(0.25, 0.26, 0.3), 1.0, true)
	cilindro(ci, c3, r * 0.5, 3.0, col.darkened(0.2))
	disco(ci, c3 + su(3.0), r * 0.5, col.lightened(0.1), 1.0)

## Paletto di gomma: anello di gomma alto (colore 1 dentro, bianco fuori) e perno cromato sopra.
static func paletto(ci: CanvasItem, c: Vector2, r: float, col: Color, p: bool, alto := H_PALETTO) -> void:
	if p:
		ci.draw_circle(c, r + 2.0, Color(0.95, 0.95, 0.9))
		ci.draw_circle(c, r - 1.0, col)
		ci.draw_circle(c, maxf(1.5, r * 0.3), METALLO)
		return
	ombra_cerchio(ci, c, r + 2.0, alto)
	cilindro(ci, c, r + 2.0, alto * 0.6, Color(0.95, 0.95, 0.9))
	var c1 := c + su(alto * 0.6)
	disco(ci, c1, r + 2.0, col, 0.8)
	ci.draw_circle(c1, r * 0.55, Color(0.95, 0.95, 0.9))
	cilindro(ci, c1, maxf(1.6, r * 0.38), alto * 0.4, METALLO)
	disco(ci, c1 + su(alto * 0.4), maxf(1.6, r * 0.38), Color(0.9, 0.91, 0.95), 1.0)

static func bersaglio(ci: CanvasItem, c: Vector2, dim: Vector2, ang: float, col: Color, p: bool, giu := false, base := Transform2D.IDENTITY, alto := H_BERSAGLIO) -> void:
	var r := Rect2(-dim * 0.5, dim)
	var tr := Transform2D(ang, c)
	if giu or p:
		ci.draw_set_transform_matrix(base * tr)
		if giu:
			ci.draw_rect(r, Color(0.02, 0.02, 0.03, 0.9))
			ci.draw_rect(r, Color(col, 0.6), false, 1.0)
		else:
			ci.draw_rect(r, col)
			ci.draw_rect(r, col.darkened(0.6), false, 1.0)
			ci.draw_circle(r.get_center(), minf(r.size.y * 0.24, 3.0), Color(1, 1, 1, 0.85))
		ci.draw_set_transform_matrix(base)
		return
	# angoli nel piano (in mm): il prisma si alza sempre verso l'alto dello schermo, qualunque sia la rotazione
	var pts := PackedVector2Array()
	for v in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		pts.append(tr * v)
	ci.draw_set_transform_matrix(base)
	var cima := prisma(ci, pts, alto, col, col)
	# faccia in alto: plastica lucida
	var cc := (cima[0] + cima[2]) * 0.5
	var lucida := PackedVector2Array()
	for v in cima:
		lucida.append(cc + (v - cc) * 0.7 + Vector2(-0.5, -0.6))
	ci.draw_colored_polygon(lucida, col.lightened(0.25))
	smusso(ci, cima, col)
	ci.draw_circle(cc, minf(dim.y * 0.3, 3.2), Color(1, 1, 1, 0.9))

## Buca: anello cromato rialzato, parete interna in luce in fondo, buio dentro.
static func buca(ci: CanvasItem, c: Vector2, r: float, col: Color, p: bool, tipo := "") -> void:
	match tipo:
		"portale":
			for k in 3:
				ci.draw_arc(c, r + 6.0 + k * 4.0, 0, TAU, 28, Color(col, 0.35 - k * 0.1), 2.0, true)
		"tiene":
			for k in 4:
				ci.draw_arc(c, r + 5.0 + k * 3.5, k * 0.8, k * 0.8 + 2.4, 12, Color(col, 0.5 - k * 0.1), 2.0, true)
	if p:
		ci.draw_circle(c, r + 4.0, col)
		ci.draw_circle(c, r, Color(0.02, 0.02, 0.02))
		return
	ombra_cerchio(ci, c, r + 5.0, 3.0)
	cilindro(ci, c, r + 5.0, 3.0, col)
	var c1 := c + su(3.0)
	disco(ci, c1, r + 5.0, col, 0.6)
	# il buco: si vede la parete lontana (in alto) illuminata e il fondo nero
	ci.draw_circle(c1, r, Color(0.22, 0.2, 0.22))
	ci.draw_circle(c1 + Vector2(0, r * 0.12), r * 0.97, Color(0.12, 0.11, 0.13))
	ci.draw_circle(c1 + Vector2(0, r * 0.38), r * 0.78, Color(0.0, 0.0, 0.0))
	ci.draw_arc(c1, r, PI * 1.1, PI * 1.9, 18, Color(col.lightened(0.3), 0.5), 1.2, true)

## Spinner: due staffe alte (cilindri cromati), filo in cima e la piastra appesa.
static func spinner(ci: CanvasItem, e: Dictionary, col: Color, p: bool, base := Transform2D.IDENTITY, con_piastra := true, H := H_SPINNER) -> void:
	var lw := float(e["larghezza"]) * 0.5
	var ang := float(e.get("angolo", 0.0))
	var c: Vector2 = e["pos"]
	var dir := Vector2.from_angle(ang)
	if p:
		ci.draw_set_transform_matrix(base * Transform2D(ang, c))
		for s in [-1.0, 1.0]:
			var piede := Vector2(s * (lw + 4.0), 0)
			ci.draw_rect(Rect2(piede + Vector2(-2.5, -5.0), Vector2(5, 10)), Color(0.25, 0.26, 0.29))
			ci.draw_circle(piede, 1.3, Color(0.95, 0.95, 1.0))
		ci.draw_line(Vector2(-lw - 4.0, 0), Vector2(lw + 4.0, 0), Color(0.85, 0.86, 0.9), 1.2, true)
		if con_piastra:
			piastra_spinner(ci, Rect2(-lw - 1.0, -6.0, lw * 2.0 + 2.0, 12.0), col, p)
		ci.draw_set_transform_matrix(base)
		return
	ci.draw_set_transform_matrix(base)
	var piedi := [c - dir * (lw + 4.0), c + dir * (lw + 4.0)]
	# ombra del filo e della piastra sul piano
	ci.draw_line(piedi[0] + OMBRA * H * 0.8, piedi[1] + OMBRA * H * 0.8, Color(0, 0, 0, 0.3), 3.0, true)
	for q in piedi:
		ombra_cerchio(ci, q, 3.0, H)
		cilindro(ci, q, 2.6, H, METALLO)
		disco(ci, q + su(H), 2.6, Color(0.9, 0.9, 0.95), 1.0)
	ci.draw_line(piedi[0] + su(H * 0.85), piedi[1] + su(H * 0.85), Color(0.9, 0.9, 0.95), 1.2, true)
	if con_piastra:
		ci.draw_set_transform_matrix(base * Transform2D(ang, Vector2(e["pos"]) + su(H * 0.55)))
		piastra_spinner(ci, Rect2(-lw - 1.0, -6.0, lw * 2.0 + 2.0, 12.0), col, p)
		ci.draw_set_transform_matrix(base)

## CANCELLETTO: due staffe cromate, il filo in cima e la LAMINA appesa che si alza quando la pallina passa
## (`apertura` 0 = chiusa, giù; 1 = alzata del tutto: la lamina si accorcia e si schiarisce, vista dall'alto).
static func cancello(ci: CanvasItem, e: Dictionary, col: Color, p: bool, base := Transform2D.IDENTITY, apertura := 0.0, H := 22.0) -> void:
	var lw := float(e.get("larghezza", 46.0)) * 0.5
	var ang := float(e.get("angolo", 0.0))
	var c: Vector2 = e["pos"]
	var dir := Vector2.from_angle(ang)
	var verso := Vector2(0, -1).rotated(ang)              # dove va la pallina che passa
	if p:
		ci.draw_set_transform_matrix(base)
		ci.draw_line(c - dir * (lw + 3.0), c + dir * (lw + 3.0), Color(0.85, 0.86, 0.9), 1.5, true)
		var spess := 6.0 * (1.0 - apertura * 0.8)
		var r := PackedVector2Array([c - dir * lw, c + dir * lw, c + dir * lw - verso * spess, c - dir * lw - verso * spess])
		ci.draw_colored_polygon(r, col)
		for q in [c - dir * (lw + 3.0), c + dir * (lw + 3.0)]:
			ci.draw_circle(q, 2.5, Color(0.3, 0.3, 0.35))
		return
	ci.draw_set_transform_matrix(base)
	var piedi := [c - dir * (lw + 3.5), c + dir * (lw + 3.5)]
	ci.draw_line(piedi[0] + OMBRA * H * 0.8, piedi[1] + OMBRA * H * 0.8, Color(0, 0, 0, 0.3), 3.0, true)
	for q in piedi:
		ombra_cerchio(ci, q, 2.5, H)
		cilindro(ci, q, 2.3, H, METALLO)
		disco(ci, q + su(H), 2.3, Color(0.9, 0.9, 0.95), 1.0)
	var asse := su(H * 0.9)
	ci.draw_line(piedi[0] + asse, piedi[1] + asse, Color(0.92, 0.93, 0.97), 1.4, true)
	# lamina: appesa al filo, scende verso il piano; alzata = ruota verso chi passa e si vede corta e in luce
	var giu := su(-H * 0.85) * (1.0 - apertura) + (-verso) * (H * 0.45 * apertura) * K
	var a0: Vector2 = piedi[0] + asse + dir * 1.5
	var a1: Vector2 = piedi[1] + asse - dir * 1.5
	var lam := PackedVector2Array([a0, a1, a1 + giu, a0 + giu])
	var tinta := col.darkened(0.25).lerp(col.lightened(0.3), apertura)
	ci.draw_polygon(lam, PackedColorArray([tinta.lightened(0.2), tinta.lightened(0.2), tinta.darkened(0.2), tinta.darkened(0.2)]))
	ci.draw_polyline(PackedVector2Array([a0, a1, a1 + giu, a0 + giu, a0]), Color(0.15, 0.16, 0.2, 0.8), 0.8, true)
	ci.draw_line(a0 + Vector2(0, 0.6), a1 + Vector2(0, 0.6), Color(1, 1, 1, 0.6), 0.8, true)

## PIANO RIALZATO (v0.9): la faccia in alto sta dove la pallina ci rotola (stessa posizione della fisica, così pezzi e
## pallina sul piano restano allineati); sotto si vede lo SPESSORE del piano (fianchi rivolti verso chi guarda, più
## lunghi quanto più è alto), l'ombra sul tavolo, la faccia con una luce morbida e il bordo cromato (se è chiuso).
static func piano(ci: CanvasItem, e: Dictionary, col: Color, p: bool, h: float) -> void:
	var pts := PackedVector2Array(e.get("punti", PackedVector2Array()))
	if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.5:
		pts.remove_at(pts.size() - 1)
	if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		return
	var giro := PackedVector2Array(pts)
	giro.append(pts[0])
	var aperto := bool(e.get("bordo_aperto", false))
	# v0.29: il bordo chiuso si interrompe nei VARCHI
	var pezzi_bordo: Array = PianiRialzati.bordo_spezzato(e) if not (e.get("varchi", []) as Array).is_empty() else [giro]
	if p:
		ci.draw_colored_polygon(pts, col)
		if aperto:
			ci.draw_polyline(giro, col.lightened(0.5), 2.0, true)
		else:
			for pb in pezzi_bordo:
				ci.draw_polyline(pb, Color(0.85, 0.86, 0.9), 2.0, true)
		return
	var giu := Vector2(0.0, h * K)
	# ombra sul tavolo (sotto e a destra del piano)
	for i in 3:
		var o := giu + OMBRA * h * (0.35 + 0.25 * i)
		var q := PackedVector2Array()
		for v in pts:
			q.append(v + o)
		ci.draw_colored_polygon(q, Color(0, 0, 0, 0.16))
	# spessore: fianchi verso chi guarda, dalla faccia in giù
	var area := 0.0
	for i in pts.size():
		area += pts[i].x * pts[(i + 1) % pts.size()].y - pts[(i + 1) % pts.size()].x * pts[i].y
	var verso := 1.0 if area > 0.0 else -1.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var nrm := Vector2(b.y - a.y, a.x - b.x).normalized() * verso
		if nrm.y < -0.02:
			continue
		var k := _tinta(col, _lum(nrm))
		ci.draw_polygon(PackedVector2Array([a, b, b + giu, a + giu]), PackedColorArray([k, k, k.darkened(0.35), k.darkened(0.35)]))
	ci.draw_polyline(PackedVector2Array(Array(giro).map(func(v): return v + giu)), Color(0, 0, 0, 0.35), 1.0, true)
	# faccia: colore pieno, più chiara al centro e verso la luce
	ci.draw_colored_polygon(pts, col)
	var cc := _riquadro(pts).get_center()
	for t in [0.75, 0.5, 0.28]:
		var q2 := PackedVector2Array()
		for v in pts:
			q2.append(cc + (v - cc) * t + Vector2(-0.12, -0.16) * (1.0 - t) * _riquadro(pts).size.length() * 0.2)
		ci.draw_colored_polygon(q2, Color(col.lightened(0.35), 0.18))
	# bordo: cromato e alto se chiuso, filo chiaro se aperto
	if aperto:
		ci.draw_polyline(giro, col.lightened(0.45), 1.6, true)
	else:
		for pb in pezzi_bordo:
			if pb.size() >= 2:
				tubo(ci, pb, 3.2, 12.0, METALLO, true)

## Piastra dello spinner (anche quella che gira nel gioco): faccia colorata con riflesso e striscia.
static func piastra_spinner(ci: CanvasItem, r: Rect2, col: Color, p: bool) -> void:
	if not p:
		ci.draw_rect(Rect2(r.position + Vector2(0, 1.8), r.size), col.darkened(0.6))
	ci.draw_rect(r, col)
	if not p:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), Color(1, 1, 1, 0.25))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.42), Vector2(r.size.x, r.size.y * 0.2)), Color(1, 1, 1, 0.85))
	ci.draw_rect(r, Color(0.05, 0.05, 0.07, 0.9), false, 1.0)

## Muro: legno = blocco alto a prisma; metallo = guida-tubo cromata; gomma = tubo nero. Chiuso = isola piena a prisma.
static func muro(ci: CanvasItem, m: Dictionary, col: Color, p: bool, riflesso := Color.WHITE) -> void:
	var pts: PackedVector2Array = m["punti"]
	if pts.size() < 2:
		return
	var tipo := str(m.get("tipo", "metallo"))
	var w := {"legno": 7.0, "gomma": 5.0}.get(tipo, 3.0) as float
	var chiuso := bool(m.get("chiuso", false)) and pts.size() >= 3
	var giro := PackedVector2Array(pts)
	if chiuso and pts[0].distance_to(pts[pts.size() - 1]) > 0.5:
		giro.append(pts[0])
	var si_riempie := chiuso and Geometry2D.triangulate_polygon(pts).size() > 0
	if p:
		if si_riempie:
			ci.draw_colored_polygon(pts, col.darkened(0.25) if tipo != "gomma" else Color(col, 0.25))
		ci.draw_polyline(giro, col, w, true)
		return
	var h := altezza("muri", m)
	if si_riempie and tipo != "gomma":
		# isola / blocco: prisma pieno con bordo
		var cima := prisma(ci, pts, h, col.darkened(0.1), col)
		smusso(ci, cima, col, 1.6, riflesso)
		return
	if tipo == "legno":
		# blocco di legno: un prisma per ogni tratto (si vedono i fianchi verso chi guarda)
		var poli := Geometry2D.offset_polyline(giro, w * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
		for pol in poli:
			if Geometry2D.is_polygon_clockwise(pol) and poli.size() > 1:
				continue
			var cima := prisma(ci, pol, h, col.lightened(0.08), col)
			smusso(ci, cima, col, 1.0, riflesso)
		return
	tubo(ci, giro, w if tipo == "gomma" else w + 0.6, h * 0.5 if tipo == "metallo" else h * 0.6, col if tipo == "gomma" else col, tipo == "metallo", riflesso)
	if tipo == "metallo":
		# paletti che tengono la guida (ogni ~80 mm)
		var acc := 0.0
		for i in range(1, giro.size()):
			acc += giro[i].distance_to(giro[i - 1])
			if acc > 80.0:
				acc = 0.0
				cilindro(ci, giro[i], 1.6, h * 0.5, Color(0.55, 0.56, 0.6))

## Gomme dei tratti-fionda di un muro: `tira` (0-1 per tratto) = quanto la gomma è tesa.
static func gomme_tratti(ci: CanvasItem, m: Dictionary, p: bool, tira: Array = []) -> void:
	var tratti: Array = m.get("fionde_tratti", [])
	var pts: PackedVector2Array = m["punti"]
	var cc := Vector2.ZERO
	for q in pts:
		cc += q
	cc /= maxf(1.0, float(pts.size()))
	for k in tratti.size():
		var a: Vector2 = tratti[k][0]
		var b: Vector2 = tratti[k][1]
		var t := float(tira[k]) if k < tira.size() else 0.0
		var nn := (b - a).orthogonal().normalized()
		if nn.dot((a + b) * 0.5 - cc) < 0.0:
			nn = -nn
		var meta := (a + b) * 0.5 + nn * (2.0 - 7.0 * t)
		var linea := PackedVector2Array([a, meta, b])
		var col := Color(0.97, 0.96, 0.92).lerp(Color(1, 1, 0.75), t)
		if p:
			ci.draw_polyline(linea, col, 5.0, true)
		else:
			tubo(ci, linea, 5.0, 10.0, col)

## Fionda a triangolo: prisma di plastica (colore 1) con la gomma a tubo tutto intorno (colore della fionda), faccia che
## spara più chiara, 3 paletti cromati alti.
static func fionda(ci: CanvasItem, pts: PackedVector2Array, col: Color, interno: Color, p: bool, H := H_FIONDA) -> void:
	if pts.size() < 3:
		return
	var giro := PackedVector2Array(pts)
	giro.append(pts[0])
	var cen := Vector2.ZERO
	for q in pts:
		cen += q
	cen /= float(pts.size())
	if p:
		var dentro := PackedVector2Array()
		for q in pts:
			dentro.append(cen + (q - cen) * 0.72)
		ci.draw_polyline(giro, col, 5.0, true)
		ci.draw_colored_polygon(dentro, interno)
		ci.draw_line(pts[0], pts[pts.size() - 1], col.lightened(0.35), 6.0, true)
		for q in pts:
			ci.draw_circle(q, 2.6, METALLO)
		return
	# corpo: prisma di plastica un po' più piccolo del contorno di gomma
	var corpo := PackedVector2Array()
	for q in pts:
		corpo.append(cen + (q - cen) * 0.86)
	ombra_poligono(ci, pts, H)
	var cima := prisma(ci, corpo, H * 0.85, interno, interno, false)
	# disegno sulla plastica: triangolo interno lucido e riflesso
	var cc := Vector2.ZERO
	for q in cima:
		cc += q
	cc /= float(cima.size())
	var dentro := PackedVector2Array()
	for q in cima:
		dentro.append(cc + (q - cc) * 0.6)
	ci.draw_colored_polygon(dentro, interno.lightened(0.2))
	var lucida := PackedVector2Array()
	for q in cima:
		lucida.append(cc + (q - cc) * 0.35 + Vector2(-1.2, -1.6))
	ci.draw_colored_polygon(lucida, Color(1, 1, 1, 0.2))
	smusso(ci, cima, interno, 1.2)
	# gomma tutto intorno, a metà altezza, e faccia che spara più spessa e chiara
	var gomma := PackedVector2Array()
	for q in giro:
		gomma.append(q + su(H * 0.25))
	tubo(ci, gomma, 4.5, H * 0.3, col)
	tubo(ci, PackedVector2Array([pts[0] + su(H * 0.25), pts[pts.size() - 1] + su(H * 0.25)]), 6.0, H * 0.32, col.lightened(0.3))
	# paletti cromati agli angoli
	for q in pts:
		cilindro(ci, q, 2.8, H, METALLO)
		disco(ci, q + su(H), 2.8, Color(0.92, 0.93, 0.97), 1.0)

static func forma_paletta(L: float, sp: float) -> PackedVector2Array:
	var punta := sp * 0.6
	return Geometry2D.convex_hull(PackedVector2Array([Vector2(0, -sp), Vector2(0, sp), Vector2(-sp * signf(L), 0),
		Vector2(L, -punta), Vector2(L, punta), Vector2(L + punta * signf(L), 0)]))

## Ombra della paletta (t = trasformazione della paletta, `rot` = la sua rotazione).
static func ombra_paletta(ci: CanvasItem, t: Transform2D, L: float, sp: float, rot: float, h := H_PALETTA) -> void:
	var f := forma_paletta(L, sp)
	for i in 3:
		var o := (OMBRA * h * (0.5 + 0.3 * i)).rotated(-rot)
		ci.draw_set_transform_matrix(t * Transform2D(0.0, o))
		ci.draw_colored_polygon(f, Color(0, 0, 0, 0.16))
	ci.draw_set_transform_matrix(t)

## Paletta (coordinate della paletta: perno in 0,0, punta verso +x o -x; `rot` = rotazione sullo schermo, serve per
## alzare la cima sempre verso l'alto dello schermo): fianco spesso, cima colorata con bordo di gomma bianco, perno.
static func paletta(ci: CanvasItem, L: float, sp: float, col: Color, p: bool, rot := 0.0, h := H_PALETTA) -> void:
	var forma := forma_paletta(L, sp)
	var giro := PackedVector2Array(forma)
	giro.append(forma[0])
	if p:
		ci.draw_colored_polygon(forma, col)
		ci.draw_polyline(giro, Color(1, 1, 1, 0.95), 2.2 if sp > 9.0 else 1.6, true)
		ci.draw_circle(Vector2.ZERO, sp * 0.4, Color(0.95, 0.95, 0.95))
		ci.draw_circle(Vector2.ZERO, sp * 0.18, Color(0.55, 0.56, 0.6))
		return
	var u := su(h).rotated(-rot)
	# fianchi: si estrude il contorno (più chiaro a sinistra, scuro a destra)
	var area := 0.0
	for i in forma.size():
		var a := forma[i]
		var b := forma[(i + 1) % forma.size()]
		area += a.x * b.y - b.x * a.y
	var verso := 1.0 if area > 0.0 else -1.0
	for i in forma.size():
		var a := forma[i]
		var b := forma[(i + 1) % forma.size()]
		var nrm := Vector2(b.y - a.y, a.x - b.x).normalized() * verso
		var nrm_schermo := nrm.rotated(rot)
		if nrm_schermo.y < -0.02:
			continue
		var k := _tinta(Color(0.95, 0.95, 0.93), _lum(nrm_schermo))
		ci.draw_polygon(PackedVector2Array([a, b, b + u, a + u]), PackedColorArray([k.darkened(0.25), k.darkened(0.25), k, k]))
	var cima := PackedVector2Array()
	for v in forma:
		cima.append(v + u)
	var giro_c := PackedVector2Array(cima)
	giro_c.append(cima[0])
	ci.draw_colored_polygon(cima, Color(0.96, 0.96, 0.94))
	var dentro := PackedVector2Array()
	for v in forma:
		dentro.append(v * 0.78 + Vector2(L * 0.1, 0) + u)
	ci.draw_colored_polygon(dentro, col)
	var lucida := PackedVector2Array()
	for v in forma:
		lucida.append(Vector2(v.x * 0.7 + L * 0.12, v.y * 0.3 - sp * 0.22) + u)
	ci.draw_colored_polygon(lucida, Color(1, 1, 1, 0.3))
	ci.draw_polyline(giro_c, Color(0.35, 0.35, 0.38), 0.8, true)
	ci.draw_circle(u, sp * 0.42, Color(0.75, 0.76, 0.8))
	ci.draw_circle(u + Vector2(-0.4, -0.5), sp * 0.3, Color(0.95, 0.95, 1.0))
	ci.draw_circle(u, sp * 0.14, Color(0.4, 0.41, 0.45))

## Kickback: piastra del pistone (bassa) con il bordo cromato.
static func kickback(ci: CanvasItem, c: Vector2, dim: Vector2, col: Color, p: bool, alto := H_KICKBACK) -> void:
	var r := Rect2(c - dim * 0.5, dim)
	if p:
		ci.draw_rect(r, Color(col, 0.75))
		ci.draw_rect(r, col.lightened(0.4), false, 1.2)
		return
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cima := prisma(ci, pts, alto, col, METALLO)
	smusso(ci, cima, col, 1.2)
