## FORMA DEL TAVOLO (Pinball Editor 2D v0.2, 24/11/2026): la sponda esterna, la corsia di lancio col canale curvo e la
## zona bassa collaudata (palette, fionde, grembiuli, corsie di ritorno, perno) generate da pochi numeri:
##   larghezza (560-720 mm), raggio dell'angolo sinistro, raggio dell'angolo destro (dove curva il canale di lancio).
## Altezza fissa 1240 mm in questa versione: alcune soglie del motore (corsia di lancio) sono pensate per quella.
## La zona bassa resta centrata nel campo; i grembiuli si allungano fino alle sponde, il blocco destro fino alla corsia.
class_name FormaTavolo

const ALTEZZA := 1240.0
const CORSIA := 45.0                 # larghezza della corsia di lancio (mm)
const SPESSORE_DX := 4.0             # la sponda destra sta a larghezza - 4
const CAMPO_SPACE := 586.0           # campo del tavolo d'origine (zona bassa disegnata per questo)
const USCITA := -0.785               # angolo del cancelletto all'uscita del canale

## Forme pronte: nome visibile, descrizione, numeri.
const FORME := {
	"classica": {"nome": "Classica", "testo": "angolo sinistro stretto, canale di lancio largo a destra", "larghezza": 635.0, "r_sx": 120.0, "r_dx": 230.0},
	"simmetrica": {"nome": "Simmetrica", "testo": "i due angoli in alto uguali", "larghezza": 635.0, "r_sx": 200.0, "r_dx": 200.0},
	"arco": {"nome": "Arco", "testo": "tutta la parte alta a mezzo cerchio", "larghezza": 635.0, "r_sx": 315.0, "r_dx": 315.0},
	"squadrata": {"nome": "Squadrata", "testo": "angoli piccoli, più spazio in alto", "larghezza": 635.0, "r_sx": 60.0, "r_dx": 160.0},
	"larga": {"nome": "Larga (widebody)", "testo": "tavolo largo 700 mm, angoli uguali", "larghezza": 700.0, "r_sx": 220.0, "r_dx": 220.0},
	"stretta": {"nome": "Stretta", "testo": "tavolo largo 580 mm, angoli uguali", "larghezza": 580.0, "r_sx": 180.0, "r_dx": 180.0},
}

## Muri e sensori della forma (si sostituiscono quando si cambia forma).
const ID_MURI := ["sponda", "corsia_lancio", "fondo_lancio", "grembiule_sx", "grembiule_dx", "guida_27", "guida_28",
	"guida_colonna", "riempimento_dx"]
const ID_SENSORI := ["corsia_27", "corsia_28"]

static func limita(f: Dictionary) -> Dictionary:
	var l := clampf(float(f.get("larghezza", 635.0)), 560.0, 720.0)
	var x_dx := l - SPESSORE_DX
	# il canale di lancio ha bisogno di un raggio minimo; i due angoli non devono sovrapporsi
	var r_dx := clampf(float(f.get("r_dx", 230.0)), 150.0, x_dx * 0.5)
	var r_sx := clampf(float(f.get("r_sx", 120.0)), 30.0, x_dx - r_dx)
	return {"larghezza": l, "r_sx": r_sx, "r_dx": r_dx}

static func _arco(c: Vector2, r: float, da: float, a: float, passi: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(passi + 1):
		var t := da + (a - da) * float(i) / float(passi)
		out.append(c + Vector2(cos(t), sin(t)) * r)
	return out

static func _sposta(pts, dx: float):
	var out = pts.duplicate()
	for i in out.size():
		out[i] = out[i] + Vector2(dx, 0)
	return out

## Restituisce le voci del tavolo da sostituire: dimensioni, campo, centro_x, lancio, cancello, palette, fionde,
## porte, muri della forma (lista), sensori della forma (lista). `s` = descrizione del tavolo d'origine (Space).
static func genera(forma: Dictionary, s: Dictionary) -> Dictionary:
	var f := limita(forma)
	var l: float = f["larghezza"]
	var x_dx := l - SPESSORE_DX
	var r_dx: float = f["r_dx"]
	var r_sx: float = f["r_sx"]
	var c_dx := Vector2(x_dx - r_dx, r_dx)
	var c_sx := Vector2(r_sx, r_sx)
	var campo := x_dx - CORSIA
	var dx := (campo - CAMPO_SPACE) * 0.5        # la zona bassa si sposta al centro del campo nuovo
	var d := {}
	d["dimensioni"] = Vector2(l, ALTEZZA)
	d["campo"] = campo
	d["centro_x"] = float(s["centro_x"]) + dx
	d["forma"] = f.duplicate()
	var muri: Array = []
	var sponda := PackedVector2Array([Vector2(0, ALTEZZA + 60), Vector2(0, r_sx)])
	sponda.append_array(_arco(c_sx, r_sx, PI, PI * 1.5, 12))
	sponda.append_array(_arco(c_dx, r_dx, PI * 1.5, TAU, 16))
	sponda.append(Vector2(x_dx, ALTEZZA + 60))
	muri.append({"id": "sponda", "punti": sponda, "tipo": "legno", "altezza": 55.0})
	var lancio := PackedVector2Array([Vector2(campo, ALTEZZA + 60), Vector2(campo, c_dx.y)])
	lancio.append_array(_arco(c_dx, r_dx - CORSIA, 0.0, USCITA, 10))
	muri.append({"id": "corsia_lancio", "punti": lancio, "tipo": "metallo", "altezza": 30.0})
	muri.append({"id": "fondo_lancio", "punti": PackedVector2Array([Vector2(campo, ALTEZZA - 25), Vector2(x_dx, ALTEZZA - 25)]), "tipo": "metallo", "altezza": 10.0})
	# muri della zona bassa d'origine, adattati
	var orig := {}
	for m in s["muri"]:
		orig[m["id"]] = m
	# grembiuli: stessa pendenza, allungati fino alla sponda sinistra e alla corsia di lancio
	var g_sx: PackedVector2Array = _sposta(orig["grembiule_sx"]["punti"], dx)
	g_sx[0] = _su_x(g_sx[1], g_sx[0], 0.0)
	muri.append({"id": "grembiule_sx", "punti": g_sx, "tipo": "metallo", "altezza": 20.0})
	var g_dx: PackedVector2Array = _sposta(orig["grembiule_dx"]["punti"], dx)
	g_dx[0] = _su_x(g_dx[1], g_dx[0], campo)
	muri.append({"id": "grembiule_dx", "punti": g_dx, "tipo": "metallo", "altezza": 20.0})
	for id in ["guida_27", "guida_28"]:
		muri.append({"id": id, "punti": _sposta(orig[id]["punti"], dx), "tipo": "metallo", "altezza": 25.0})
	var gc: PackedVector2Array = _sposta(orig["guida_colonna"]["punti"], dx)
	gc[0] = Vector2(campo, gc[0].y)
	muri.append({"id": "guida_colonna", "punti": gc, "tipo": "metallo", "altezza": 25.0})
	# blocco a destra della corsia di ritorno: il lato destro resta attaccato alla corsia di lancio (niente fessure)
	var rd: PackedVector2Array = _sposta(orig["riempimento_dx"]["punti"], dx)
	for i in rd.size():
		if rd[i].x > CAMPO_SPACE - 10.0 + dx:
			rd[i] = Vector2(campo - 5.0, rd[i].y)
			# il punto basso del blocco resta appoggiato al grembiule (sul tavolo stretto si aprirebbe una fessura)
			var y_g := _su_x(g_dx[1], g_dx[0], campo - 5.0).y
			if rd[i].y > 1000.0 and y_g - rd[i].y > 15.0:
				rd[i] = Vector2(rd[i].x, y_g - 8.0)
	muri.append({"id": "riempimento_dx", "punti": rd, "tipo": "metallo", "altezza": 15.0})
	d["muri"] = muri
	var sensori: Array = []
	for se in s["sensori"]:
		if se["id"] in ID_SENSORI:
			var c: Dictionary = se.duplicate(true)
			c["pos"] = Vector2(c["pos"]) + Vector2(dx, 0)
			sensori.append(c)
	d["sensori"] = sensori
	d["cancello"] = [_arco(c_dx, r_dx - CORSIA, USCITA, USCITA, 1)[0], _arco(c_dx, r_dx - 1.0, USCITA, USCITA, 1)[0]]
	d["lancio"] = {"pos": Vector2(x_dx - 22.5, ALTEZZA - 40.0), "corsia_x": campo,
		"canale": {"centro": c_dx, "r_dentro": r_dx - CORSIA, "r_fuori": r_dx, "angolo_uscita": USCITA}}
	var pal: Array = []
	for p in s["palette"]:
		var c2: Dictionary = p.duplicate(true)
		c2["perno"] = Vector2(c2["perno"]) + Vector2(dx, 0)
		pal.append(c2)
	d["palette"] = pal
	var fio: Array = []
	for fi in s["fionde"]:
		var c3: Dictionary = fi.duplicate(true)
		c3["punti"] = _sposta(c3["punti"], dx)
		fio.append(c3)
	d["fionde"] = fio
	var por: Array = []
	for po in s["porte"]:
		var c4: Dictionary = po.duplicate(true)
		c4["punti"] = _sposta(c4["punti"], dx)
		por.append(c4)
	d["porte"] = por
	return d

## Punto sulla retta per a e b alla x data.
static func _su_x(a: Vector2, b: Vector2, x: float) -> Vector2:
	if absf(b.x - a.x) < 0.001:
		return Vector2(x, b.y)
	var t := (x - a.x) / (b.x - a.x)
	return a + (b - a) * t

## v0.26: ZONA BASSA COLLAUDATA (palette, fionde, grembiuli, corsie di ritorno, perno, corsia di lancio) come DATI
## in un file proprio (tavoli/base/zona_bassa.tavolo): stessi numeri di prima, senza dipendere da un tavolo completo.
static var _zona: Dictionary = {}
static func zona_bassa() -> Dictionary:
	if _zona.is_empty():
		_zona = FileTavolo.leggi("res://tavoli/base/zona_bassa.tavolo")
	return _zona.duplicate(true)

## Applica una forma a un tavolo: sostituisce sponda, corsia, zona bassa; gli altri pezzi restano dove sono
## (centrati di nuovo se il tavolo cambia larghezza).
static func applica(desc: Dictionary, forma: Dictionary) -> void:
	var s: Dictionary = zona_bassa()
	var vecchio_centro := float(desc.get("campo", CAMPO_SPACE)) * 0.5
	var g := genera(forma, s)
	# gli altri pezzi si allargano o stringono in proporzione col campo (restano dentro e alla stessa distanza relativa)
	var k := float(g["campo"]) / maxf(1.0, float(desc.get("campo", CAMPO_SPACE)))
	var nuovo_centro := float(g["campo"]) * 0.5
	if absf(k - 1.0) > 0.001:
		for lista in ProgettoEditor.LISTE:
			if lista in ["palette", "fionde", "porte"]:
				continue
			for e in desc.get(lista, []):
				if e is Dictionary and not (lista == "muri" and e.get("id", "") in ID_MURI) and not (lista == "sensori" and e.get("id", "") in ID_SENSORI):
					_scala_x(lista, e, vecchio_centro, nuovo_centro, k)
	var altri_muri: Array = desc.get("muri", []).filter(func(m): return not m.get("id", "") in ID_MURI)
	var altri_sensori: Array = desc.get("sensori", []).filter(func(x): return not x.get("id", "") in ID_SENSORI)
	for voce in ["dimensioni", "campo", "centro_x", "cancello", "lancio", "palette", "fionde", "porte", "forma"]:
		desc[voce] = g[voce]
	desc["muri"] = g["muri"] + altri_muri
	desc["sensori"] = g["sensori"] + altri_sensori

## Sposta un pezzo in orizzontale: x nuova = centro nuovo + (x - centro vecchio) × k (la misura dei pezzi non cambia).
static func _scala_x(lista: String, e: Dictionary, c0: float, c1: float, k: float) -> void:
	var cp := SchedeEditor.campo_pos(lista)
	if cp != "" and e.has(cp):
		var p: Vector2 = e[cp]
		e[cp] = Vector2(c1 + (p.x - c0) * k, p.y)
	if e.has("molla_verso"):
		var mv: Vector2 = e["molla_verso"]
		e["molla_verso"] = Vector2(c1 + (mv.x - c0) * k, mv.y)
	for chiave in ["punti", "percorso", "controllo"]:
		if e.has(chiave):
			var pts = e[chiave]
			for i in pts.size():
				var q = pts[i]
				if q is Vector3:
					pts[i] = Vector3(c1 + (q.x - c0) * k, q.y, q.z)
				else:
					pts[i] = Vector2(c1 + (q.x - c0) * k, q.y)
			e[chiave] = pts
	if e.has("uscita") and e["uscita"] is Vector2:
		var u: Vector2 = e["uscita"]
		e["uscita"] = Vector2(c1 + (u.x - c0) * k, u.y)
