## Forme a punti del Pinball Editor 2D (v0.3, 24/11/2026), come le «drag point» di VPX/VPE (studio STUDIO_VPX_VPE.md):
##   "curvi"[i]  = il punto è CURVO (la linea passa morbida, curva di Catmull-Rom) oppure AD ANGOLO;
##   "fionda"[i] = il TRATTO che parte da quel punto è una FIONDA (spinge la pallina, gomma che si muove);
## "chiuso" = la forma si chiude (isola, blocco, fionda, gomma intorno ai paletti) o resta aperta (guida, corsia).
## Da questi l'editor GENERA la linea per il motore ("punti") e i tratti-fionda ("fionde_tratti"): il motore non
## cambia per le curve.
class_name CurveEditor

const PASSO := 8.0          # mm tra due punti generati su un tratto curvo

## Prepara un muro vecchio (solo "punti") per l'editor: punti di controllo = punti, tutti ad angolo.
static func normalizza(m: Dictionary) -> void:
	if m.has("controllo"):
		return
	var pts: PackedVector2Array = PackedVector2Array(m.get("punti", PackedVector2Array()))
	var chiuso := pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.5
	if chiuso:
		pts.remove_at(pts.size() - 1)
	m["controllo"] = pts
	m["chiuso"] = chiuso
	m["curvi"] = _lista(pts.size(), false)
	m["fionda"] = _lista(pts.size(), false)

static func _lista(n: int, v: bool) -> Array:
	var out: Array = []
	out.resize(n)
	out.fill(v)
	return out

## Ricostruisce "punti" e "fionde_tratti" dai punti di controllo.
static func rigenera(m: Dictionary) -> void:
	if not m.has("controllo"):
		return
	var c: PackedVector2Array = m["controllo"]
	var n := c.size()
	var curvi: Array = m.get("curvi", [])
	var fio: Array = m.get("fionda", [])
	while curvi.size() < n:
		curvi.append(false)
	while fio.size() < n:
		fio.append(false)
	curvi.resize(n)
	fio.resize(n)
	m["curvi"] = curvi
	m["fionda"] = fio
	var chiuso: bool = bool(m.get("chiuso", false)) and n >= 3
	var out := PackedVector2Array()
	var tratti: Array = []
	var ultimo := n if chiuso else n - 1
	for i in ultimo:
		var j := (i + 1) % n
		var p1 := c[i]
		var p2 := c[j]
		if bool(fio[i]):
			tratti.append([p1, p2])
		out.append(p1)
		if not bool(curvi[i]) and not bool(curvi[j]):
			continue
		var i0 := i - 1 if bool(curvi[i]) else i
		if i0 < 0:
			i0 = n - 1 if chiuso else 0
		var i3 := j + 1 if bool(curvi[j]) else j
		if i3 >= n:
			i3 = i3 - n if chiuso else n - 1
		var p0 := c[i0]
		var p3 := c[i3]
		var passi := maxi(2, int(ceil(p1.distance_to(p2) / PASSO)))
		for k in range(1, passi):
			out.append(catmull(p0, p1, p2, p3, float(k) / float(passi)))
	if n > 0:
		out.append(c[0] if chiuso else c[n - 1])
	m["punti"] = out
	m["fionde_tratti"] = tratti

static func catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## Tutti i muri del tavolo: pronti per l'editor e linee aggiornate.
static func prepara_tavolo(desc: Dictionary) -> void:
	if not desc.has("nastri"):
		desc["nastri"] = []
	genera_nastri(desc)
	# tavoli avevano ereditato da Space «rampe sopraelevate» e la pallina le attraversava. Si può spegnere per rampa.
	if str(desc.get("regole", FileTavolo.REGOLE_BASE)) == FileTavolo.REGOLE_BASE:
		for r in desc.get("rampe", []):
			if r is Dictionary and not r.has("solida"):
				r["solida"] = true
	for m in desc.get("muri", []):
		if m is Dictionary and not m.has("da_nastro") and not m.has("da_piano") and not m.has("da_captive"):
			normalizza(m)
			rigenera(m)
	# v0.9: piani rialzati (livelli, bordi, pezzi sul piano, rampe e buche che salgono e scendono)
	PianiRialzati.genera(desc)
	# v0.17.2: pallina prigioniera (canale, fermo, bersaglio)
	PianiRialzati.genera_captive(desc)

## Forme pronte da disegnare con un clic (preset della libreria).
static func preset(nome: String, centro: Vector2) -> Dictionary:
	match nome:
		"fionda":
			# triangolo come la fionda di Space; il lato lungo (dal 3° punto al 1°) è il tratto-fionda di gomma
			return {"tipo": "gomma", "altezza": 25.0, "chiuso": true,
				"controllo": PackedVector2Array([centro + Vector2(-16, -78), centro + Vector2(-21, 23), centro + Vector2(36, 55)]),
				"curvi": [false, false, false], "fionda": [false, false, true]}
		"gomma":
			# anello di gomma ovale (8 punti curvi): si allunga trascinando i punti, per avvolgere 2 o 3 paletti
			var anello := PackedVector2Array()
			for k in 8:
				var a := TAU * k / 8.0
				anello.append(centro + Vector2(cos(a) * 34.0, sin(a) * 12.0))
			return {"tipo": "gomma", "altezza": 25.0, "chiuso": true, "controllo": anello,
				"curvi": _lista(8, true), "fionda": _lista(8, false)}
		"isola":
			# blocco chiuso con i bordi curvi
			return {"tipo": "metallo", "altezza": 35.0, "chiuso": true,
				"controllo": PackedVector2Array([centro + Vector2(0, -50), centro + Vector2(35, 0), centro + Vector2(0, 50), centro + Vector2(-35, 0)]),
				"curvi": [true, true, true, true], "fionda": [false, false, false, false]}
	return {}

# ================================================================ NASTRO (corsia o rampa a nastro, 24/11)
## Il NASTRO è una linea centrale a punti (curvi o ad angolo) e, per ogni punto, LARGHEZZA e ALTEZZA:
## larghezze diverse = imbocco largo che si stringe, uscita larga o stretta; altezza 0 = corsia a terra con due
## pareti vere ai lati; altezza > 0 in qualche punto = RAMPA (binario del motore) disegnata come nastro.
## L'editor ne ricava da solo i pezzi per il motore (muri "<id>@sx" e "<id>@dx", oppure la rampa "<id>@rampa"),
## segnati con "da_nastro": non si modificano a mano, si modifica il nastro.

## Linea centrale espansa: [centri, larghezze, altezze] (interpolate lungo i tratti).
static func espandi_nastro(n: Dictionary) -> Array:
	var c: PackedVector2Array = n["controllo"]
	var k := c.size()
	var curvi: Array = n.get("curvi", [])
	var larg: Array = n.get("larghezze", [])
	var alt: Array = n.get("altezze", [])
	for lista in [curvi, larg, alt]:
		while lista.size() < k:
			lista.append(false if lista == curvi else (46.0 if lista == larg else 0.0))
	var centri := PackedVector2Array()
	var ll := PackedFloat32Array()
	var aa := PackedFloat32Array()
	for i in range(k - 1):
		var j := i + 1
		var p1 := c[i]
		var p2 := c[j]
		var passi := 1
		var p0 := p1
		var p3 := p2
		if bool(curvi[i]) or bool(curvi[j]):
			p0 = c[maxi(i - 1, 0)] if bool(curvi[i]) else p1
			p3 = c[mini(j + 1, k - 1)] if bool(curvi[j]) else p2
			passi = maxi(2, int(ceil(p1.distance_to(p2) / PASSO)))
		else:
			passi = maxi(1, int(ceil(p1.distance_to(p2) / 25.0)))
		for s in passi:
			var t := float(s) / float(passi)
			centri.append(catmull(p0, p1, p2, p3, t) if passi > 1 and (bool(curvi[i]) or bool(curvi[j])) else p1.lerp(p2, t))
			ll.append(lerpf(float(larg[i]), float(larg[j]), t))
			aa.append(lerpf(float(alt[i]), float(alt[j]), t))
	if k > 0:
		centri.append(c[k - 1])
		ll.append(float(larg[k - 1]))
		aa.append(float(alt[k - 1]))
	return [centri, ll, aa]

## Bordi sinistro e destro (rispetto al verso del nastro).
static func bordi_nastro(centri: PackedVector2Array, larg: PackedFloat32Array) -> Array:
	var sx := PackedVector2Array()
	var dx := PackedVector2Array()
	for i in centri.size():
		var a := centri[maxi(i - 1, 0)]
		var b := centri[mini(i + 1, centri.size() - 1)]
		var tang := (b - a).normalized()
		var nrm := Vector2(tang.y, -tang.x)
		sx.append(centri[i] + nrm * larg[i] * 0.5)
		dx.append(centri[i] - nrm * larg[i] * 0.5)
	return [sx, dx]

static func nastro_alto(n: Dictionary) -> bool:
	for z in n.get("altezze", []):
		if float(z) > 0.5:
			return true
	return false

## Rifà i pezzi del motore di tutti i nastri del tavolo.
static func genera_nastri(desc: Dictionary) -> void:
	desc["muri"] = desc.get("muri", []).filter(func(m): return not m.has("da_nastro"))
	desc["rampe"] = desc.get("rampe", []).filter(func(r): return not r.has("da_nastro"))
	for n in desc.get("nastri", []):
		if not n is Dictionary or n.get("controllo", PackedVector2Array()).size() < 2:
			continue
		var e := espandi_nastro(n)
		var centri: PackedVector2Array = e[0]
		var larg: PackedFloat32Array = e[1]
		var alt: PackedFloat32Array = e[2]
		var alto := false
		for z in alt:
			if z > 0.5:
				alto = true
		if alto:
			# rampa: il motore segue la linea centrale con le altezze; dalla v0.17.1 anche la LARGHEZZA vale (pareti e bocca)
			var pr: Array = []
			for i in centri.size():
				pr.append(Vector3(centri[i].x, centri[i].y, alt[i]))
			pr[0] = Vector3(pr[0].x, pr[0].y, 0.0)
			# v0.17.1: larghezza vera per il motore (pareti dove il nastro è basso, bocca larga come l'ingresso)
			var tot := 0.0
			for i in range(1, centri.size()):
				tot += centri[i].distance_to(centri[i - 1])
			var mezze: Array = []
			var acc := 0.0
			for i in centri.size():
				if i > 0:
					acc += centri[i].distance_to(centri[i - 1])
				mezze.append([acc / maxf(tot, 0.001), maxf(float(larg[i]) * 0.5, 15.0)])
			desc["rampe"].append({"id": str(n["id"]) + "@rampa", "nome": str(n.get("nome", n["id"])), "punti": pr,
				"stile": str(n.get("stile", "")), "da_nastro": n["id"], "mezze": mezze, "solida": bool(n.get("solida", true))})
			var col: Dictionary = desc.get("colori", {})
			if col.has("rampe") and col["rampe"] is Dictionary:
				col["rampe"][str(n["id"]) + "@rampa"] = n.get("colore", Color(0.25, 0.55, 1.0))
		else:
			var b := bordi_nastro(centri, larg)
			for lato in [["sx", b[0], "pareti_sx"], ["dx", b[1], "pareti_dx"]]:
				if bool(n.get(lato[2], true)):
					desc["muri"].append({"id": "%s@%s" % [n["id"], lato[0]], "punti": lato[1], "tipo": str(n.get("materiale", "metallo")),
						"altezza": float(n.get("altezza_pareti", 25.0)), "da_nastro": n["id"]})

## Disegno del NASTRO (gioco e editor). Due aspetti:
##      stessa vista inclinata dei pezzi (PittorePezzi.K): il nastro sollevato si vede PIÙ IN ALTO di quanto è alto,
##      con lo SPESSORE del pavimento visibile, i SOSTEGNI cromati fino al piano e l'ombra morbida sul piano sotto.
##      Pavimento colorato intenso, più scuro vicino alle pareti (ombra negli angoli) e con la striscia lucida al
##      centro; PARETI ALTE di plastica trasparente (o metallo/gomma/legno) con il bordo lucido in cima.
##  "piatto": solo il colore pieno e le pareti come linee, senza ombre né fianchi.
## Unità: mm. `px` trasforma i mm in pixel (editor) o niente (gioco).
static func disegna_nastro(ci: CanvasItem, n: Dictionary, px: Callable, scala: float) -> void:
	var e := espandi_nastro(n)
	var centri: PackedVector2Array = e[0]
	var larg: PackedFloat32Array = e[1]
	var alt: PackedFloat32Array = e[2]
	if centri.size() < 2:
		return
	var b := bordi_nastro(centri, larg)
	var sx: PackedVector2Array = b[0]
	var dx: PackedVector2Array = b[1]
	var col: Color = n.get("colore", Color(0.1, 0.45, 1.0))
	var piatto := str(n.get("aspetto", "3d")) == "piatto"
	var h_par := float(n.get("altezza_pareti", 25.0))
	var nseg := centri.size() - 1
	var quad := func(a: Vector2, b2: Vector2, c: Vector2, d: Vector2, c1: Color, c2: Color) -> void:
		ci.draw_polygon(PackedVector2Array([px.call(a), px.call(b2), px.call(c), px.call(d)]), PackedColorArray([c1, c1, c2, c2]))
	if piatto:
		for i in nseg:
			quad.call(sx[i], sx[i + 1], dx[i + 1], dx[i], col, col)
		_frecce_nastro(ci, n, centri, larg, px, Vector2.ZERO, alt)
		for lato in [[sx, "pareti_sx"], [dx, "pareti_dx"]]:
			if bool(n.get(lato[1], true)):
				var lp := PackedVector2Array()
				for q in lato[0]:
					lp.append(px.call(q))
				ci.draw_polyline(lp, col.lightened(0.55), maxf(1.5, 2.0 * scala), true)
		return
	var K := PittorePezzi.K
	var u := func(i: int) -> Vector2: return Vector2(0.0, -alt[i] * K)
	var alto := false
	for z in alt:
		alto = alto or z > 2.0
	var spess := 4.0 if alto else 0.0          # spessore del pavimento sollevato (mm)
	# 1) ombra sul piano, sotto il nastro (morbida: tre passate)
	for k in 3:
		for i in nseg:
			var o0: Vector2 = PittorePezzi.OMBRA * (alt[i] * 0.55 + h_par * 0.35) * (0.6 + 0.3 * k)
			var o1: Vector2 = PittorePezzi.OMBRA * (alt[i + 1] * 0.55 + h_par * 0.35) * (0.6 + 0.3 * k)
			var om := Color(0, 0, 0, 0.13)
			quad.call(sx[i] + o0, sx[i + 1] + o1, dx[i + 1] + o1, dx[i] + o0, om, om)
	# 2) sostegni cromati dove il nastro è alto (dal piano al pavimento, ai due lati)
	if alto:
		var acc := 999.0
		for i in centri.size():
			if i > 0:
				acc += centri[i].distance_to(centri[i - 1])
			if alt[i] > 14.0 and acc > 90.0:
				acc = 0.0
				for q in [sx[i], dx[i]]:
					var piede: Vector2 = q
					var testa: Vector2 = q + u.call(i)
					ci.draw_line(px.call(piede + PittorePezzi.OMBRA * 2.0), px.call(testa + PittorePezzi.OMBRA * 2.0), Color(0, 0, 0, 0.3), maxf(1.0, 3.5 * scala), true)
					ci.draw_line(px.call(piede), px.call(testa), Color(0.5, 0.52, 0.56), maxf(1.0, 3.0 * scala), true)
					ci.draw_line(px.call(piede + Vector2(-0.7, 0)), px.call(testa + Vector2(-0.7, 0)), Color(1, 1, 1, 0.7), maxf(0.6, 1.0 * scala), true)
					ci.draw_circle(px.call(piede), maxf(1.0, 2.4 * scala), Color(0.35, 0.36, 0.4))
	# 3) spessore del pavimento (si vede sul lato verso chi guarda)
	if spess > 0.0:
		var sp := Vector2(0.0, spess * K * 1.6)
		for i in nseg:
			var fs := col.darkened(0.55)
			var fd := col.darkened(0.7)
			quad.call(sx[i] + u.call(i), sx[i + 1] + u.call(i + 1), sx[i + 1] + u.call(i + 1) + sp, sx[i] + u.call(i) + sp, fs, fd)
			quad.call(dx[i] + u.call(i), dx[i + 1] + u.call(i + 1), dx[i + 1] + u.call(i + 1) + sp, dx[i] + u.call(i) + sp, fs, fd)
	# 4) pavimento: cinque fasce in larghezza (scuro alle pareti, chiaro e lucido al centro), più chiaro in alto
	var fasce := [0.0, 0.14, 0.42, 0.58, 0.86, 1.0]
	var toni := [col.darkened(0.45), col, col.lightened(0.18), col.lightened(0.18), col.darkened(0.08), col.darkened(0.5)]
	for i in nseg:
		var luce0 := clampf(alt[i] / 220.0, 0.0, 0.2)
		var luce1 := clampf(alt[i + 1] / 220.0, 0.0, 0.2)
		for f in fasce.size() - 1:
			var a0: Vector2 = sx[i].lerp(dx[i], fasce[f]) + u.call(i)
			var a1: Vector2 = sx[i + 1].lerp(dx[i + 1], fasce[f]) + u.call(i + 1)
			var b0: Vector2 = sx[i].lerp(dx[i], fasce[f + 1]) + u.call(i)
			var b1: Vector2 = sx[i + 1].lerp(dx[i + 1], fasce[f + 1]) + u.call(i + 1)
			var ca: Color = toni[f]
			var cb: Color = toni[f + 1]
			ci.draw_polygon(PackedVector2Array([px.call(a0), px.call(a1), px.call(b1), px.call(b0)]),
				PackedColorArray([ca.lightened(luce0), ca.lightened(luce1), cb.lightened(luce1), cb.lightened(luce0)]))
		# riflesso lucido lungo il centro
		var r0: Vector2 = sx[i].lerp(dx[i], 0.36) + u.call(i)
		var r1: Vector2 = sx[i + 1].lerp(dx[i + 1], 0.36) + u.call(i + 1)
		var r2: Vector2 = sx[i + 1].lerp(dx[i + 1], 0.46) + u.call(i + 1)
		var r3: Vector2 = sx[i].lerp(dx[i], 0.46) + u.call(i)
		quad.call(r0, r1, r2, r3, Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.16))
	_frecce_nastro(ci, n, centri, larg, px, Vector2.ZERO, alt)
	# 5) pareti alte: faccia dalla base (pavimento) alla cima, poi bordo lucido in cima
	var mat := str(n.get("materiale", "metallo"))
	var hp := Vector2(0.0, -h_par * K)
	for lato in [[sx, "pareti_sx", 1.0], [dx, "pareti_dx", -1.0]]:
		if not bool(n.get(lato[1], true)):
			continue
		var bordo: PackedVector2Array = lato[0]
		var cima := PackedVector2Array()
		for i in bordo.size():
			cima.append(px.call(bordo[i] + u.call(i) + hp))
		for i in bordo.size() - 1:
			var tang := (bordo[i + 1] - bordo[i]).normalized()
			var fuori := Vector2(tang.y, -tang.x) * float(lato[2])
			var lum := clampf(0.5 + 0.5 * fuori.dot(PittorePezzi.LUCE.normalized()), 0.0, 1.0)
			var faccia: Color
			match mat:
				"gomma":
					faccia = Color(0.08, 0.08, 0.09).lerp(Color(0.3, 0.3, 0.32), lum)
				"legno":
					faccia = PittorePezzi.LEGNO.darkened(0.4).lerp(PittorePezzi.LEGNO.lightened(0.2), lum)
				_:
					# plastica trasparente colorata come il nastro (si vede il pavimento attraverso)
					faccia = Color(col.lightened(0.35).lerp(Color.WHITE, 0.2 * lum), 0.32 + 0.2 * lum)
			var a: Vector2 = bordo[i] + u.call(i)
			var b2: Vector2 = bordo[i + 1] + u.call(i + 1)
			ci.draw_polygon(PackedVector2Array([px.call(a), px.call(b2), px.call(b2 + hp), px.call(a + hp)]),
				PackedColorArray([faccia.darkened(0.2), faccia.darkened(0.2), faccia, faccia]))
		var base_l := PackedVector2Array()
		for i in bordo.size():
			base_l.append(px.call(bordo[i] + u.call(i)))
		ci.draw_polyline(base_l, Color(0, 0, 0, 0.35), maxf(1.0, 1.4 * scala), true)
		var bordo_col := {"gomma": Color(0.12, 0.12, 0.13), "legno": PittorePezzi.LEGNO.lightened(0.15)}.get(mat, col.lightened(0.15)) as Color
		ci.draw_polyline(cima, Color(0.05, 0.06, 0.1, 0.8), maxf(1.5, 3.6 * scala), true)
		ci.draw_polyline(cima, bordo_col, maxf(1.2, 2.6 * scala), true)
		var luce_l := PackedVector2Array()
		for q in cima:
			luce_l.append(q + Vector2(-0.4, -0.6) * scala)
		ci.draw_polyline(luce_l, Color(1, 1, 1, 0.75), maxf(0.6, 0.9 * scala), true)

## Frecce sul fondo del nastro (se richieste), alla quota del pavimento.
static func _frecce_nastro(ci: CanvasItem, n: Dictionary, centri: PackedVector2Array, larg: PackedFloat32Array, px: Callable, _o: Vector2, alt: PackedFloat32Array) -> void:
	if not bool(n.get("frecce", false)):
		return
	var piatto := str(n.get("aspetto", "3d")) == "piatto"
	var acc := 0.0
	for i in range(1, centri.size()):
		acc += centri[i].distance_to(centri[i - 1])
		if acc >= 70.0:
			acc = 0.0
			var su := Vector2.ZERO if piatto else Vector2(0.0, -alt[i] * PittorePezzi.K)
			var dirz := (centri[i] - centri[i - 1]).normalized()
			var lat := Vector2(-dirz.y, dirz.x) * larg[i] * 0.22
			var punta := centri[i] + dirz * larg[i] * 0.2 + su
			var c := centri[i] + su
			ci.draw_colored_polygon(PackedVector2Array([px.call(punta), px.call(c - dirz * larg[i] * 0.12 + lat), px.call(c - dirz * larg[i] * 0.12 - lat)]), Color(1, 1, 1, 0.85))
