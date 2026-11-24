## Controlli automatici della geometria (Pinball Editor 2D v0.1, 23/11/2026).
## VARCHI: regola dei flipper (REGOLE_FLIPPER.md §4.10, corridoi di tiro): con la pallina da 27 mm, uno spazio tra due
## pezzi va tenuto o sotto i 20 mm (la pallina non ci entra) o sopra i 36 mm (ci passa bene). Tra 20 e 36 mm la pallina
## può incastrarsi: il controllo lo SEGNALA, poi va giudicato (direzione della pallina, prove di gioco).
## INCASTRI: li trova la caccia agli incastri del motore (tools/caccia_incastri), lanciata dall'editor.
class_name ControlliEditor

const VARCO_MIN := 20.0
const VARCO_MAX := 36.0

## Problemi: [{tipo, livello ("errore" | "potenziale" | "avviso"), pos, testo, pezzi}]
static func varchi(desc: Dictionary) -> Array:
	var segmenti: Array = []     # [a, b, id]
	var cerchi: Array = []       # [centro, raggio, id]
	# v0.17: pezzi su livelli diversi (tavolo e piano rialzato) non si toccano: niente confronto tra loro
	var liv := {}
	for k in ["muri", "fionde", "porte", "bumper", "elastici"]:
		for e in desc.get(k, []):
			if e is Dictionary:
				liv[str(e.get("id", ""))] = int(e.get("livello", 0))
	for m in desc.get("muri", []):
		var pm: Array = Array(m["punti"])
		if m.get("pieno", false) and pm.size() > 2:
			pm.append(pm[0])
		_aggiungi_linea(segmenti, pm, str(m.get("id", "")))
	# v0.17.1: pareti delle rampe SOLIDE dove sono basse (come le fa il motore): la pallina ci sbatte, quindi contano
	for r in desc.get("rampe", []):
		if not r is Dictionary or not bool(r.get("solida", desc.get("rampe_solide", true))):
			continue
		var pr: Array = r.get("punti", [])
		var lv := int(r.get("livello", 0))
		var q0 := float(desc.get("livelli", {}).get(lv, {}).get("altezza", 0.0)) if lv > 0 else 0.0
		var mezze: Array = r.get("mezze", [])
		var lati := {1.0: [], -1.0: []}
		for i in pr.size():
			var pi := Vector2(pr[i].x, pr[i].y)
			var h := float(pr[i].z) - q0
			if h >= 32.0 or h < -1.0:
				if lati[1.0].size() >= 2:
					for l in [1.0, -1.0]:
						_aggiungi_linea(segmenti, lati[l], str(r["id"]))
				lati = {1.0: [], -1.0: []}
				continue
			var a := Vector2(pr[maxi(i - 1, 0)].x, pr[maxi(i - 1, 0)].y)
			var b := Vector2(pr[mini(i + 1, pr.size() - 1)].x, pr[mini(i + 1, pr.size() - 1)].y)
			var n := (b - a).normalized().orthogonal()
			var mezza := 19.0
			if i == 0 and absf(h) < 1.0:
				mezza = float(r.get("invito", 25.0))     # imbocco svasato come nel motore
			if mezze.size() == pr.size():
				mezza = float(mezze[i][1])
			elif float(r.get("larghezza", 0.0)) > 0.0:
				mezza = float(r["larghezza"]) * 0.5
			for l in [1.0, -1.0]:
				lati[l].append(pi + n * mezza * l)
		if lati[1.0].size() >= 2:
			for l in [1.0, -1.0]:
				_aggiungi_linea(segmenti, lati[l], str(r["id"]))
		liv[str(r["id"])] = lv
	for f in desc.get("fionde", []):
		var p: Array = f["punti"].duplicate()
		p.append(p[0])
		_aggiungi_linea(segmenti, p, str(f["id"]))
	for po in desc.get("porte", []):
		_aggiungi_linea(segmenti, po["punti"], str(po["id"]))
	for b in desc.get("bumper", []):
		cerchi.append([b["pos"], float(b["raggio"]), str(b["id"])])
	for e in desc.get("elastici", []):
		cerchi.append([e["pos"], float(e["raggio"]), str(e["id"])])
	var trovati := {}
	var out: Array = []
	# segmento contro segmento (pezzi diversi)
	for i in segmenti.size():
		var s1: Array = segmenti[i]
		for j in range(i + 1, segmenti.size()):
			var s2: Array = segmenti[j]
			if s1[2] == s2[2] or liv.get(s1[2], 0) != liv.get(s2[2], 0):
				continue
			var cp := Geometry2D.get_closest_points_between_segments(s1[0], s1[1], s2[0], s2[1])
			_valuta(out, trovati, cp[0], cp[1], cp[0].distance_to(cp[1]), s1[2], s2[2])
	# cerchio contro segmento e contro cerchio
	for c in cerchi:
		for s in segmenti:
			if liv.get(c[2], 0) != liv.get(s[2], 0):
				continue
			var q := Geometry2D.get_closest_point_to_segment(c[0], s[0], s[1])
			var dir: Vector2 = (q - c[0]).normalized()
			_valuta(out, trovati, c[0] + dir * c[1], q, c[0].distance_to(q) - c[1], c[2], s[2])
		for c2 in cerchi:
			if c2[2] <= c[2] or liv.get(c[2], 0) != liv.get(c2[2], 0):
				continue
			var dir2: Vector2 = (c2[0] - c[0]).normalized()
			_valuta(out, trovati, c[0] + dir2 * c[1], c2[0] - dir2 * c2[1], c[0].distance_to(c2[0]) - c[1] - c2[1], c[2], c2[2])
	return out

static func _aggiungi_linea(segmenti: Array, pts, id: String) -> void:
	for k in range(pts.size() - 1):
		var a := Vector2(pts[k].x, pts[k].y)
		var b := Vector2(pts[k + 1].x, pts[k + 1].y)
		if a.distance_to(b) > 0.5:
			segmenti.append([a, b, id])

static func _valuta(out: Array, trovati: Dictionary, a: Vector2, b: Vector2, d: float, id1: String, id2: String) -> void:
	if d < VARCO_MIN or d > VARCO_MAX:
		return
	var centro := (a + b) * 0.5
	# un solo avviso per coppia di pezzi e per zona di 25 mm; v0.17.2: con una rampa di mezzo (pareti lunghe e
	# parallele alle guide) uno solo per coppia, con lo spazio più stretto
	var coppia := "%s|%s" % [id1 if id1 < id2 else id2, id2 if id1 < id2 else id1]
	var chiave := "%s|%s" % [coppia, str((centro / 25.0).floor())]
	if (id1.contains("@rampa") or id2.contains("@rampa") or id1.contains("rampa") or id2.contains("rampa")) and trovati.has(coppia):
		var vecchio: Dictionary = trovati[coppia]
		if d < float(vecchio["d"]):
			vecchio.merge({"d": d, "pos": centro, "a": a, "b": b, "testo": "Spazio di %.0f mm tra «%s» e «%s»: la pallina (27 mm) può incastrarsi. Meglio sotto 20 o sopra 36 mm." % [d, id1, id2]}, true)
		return
	if trovati.has(chiave):
		return
	trovati[chiave] = true
	var voce := {"tipo": "varco", "livello": "potenziale", "pos": centro, "a": a, "b": b, "pezzi": [id1, id2], "d": d,
		"testo": "Spazio di %.0f mm tra «%s» e «%s»: la pallina (27 mm) può incastrarsi. Meglio sotto 20 o sopra 36 mm." % [d, id1, id2]}
	trovati[coppia] = voce
	out.append(voce)

# ================================================================ SUPERFICI PIATTE IN ALTO (v0.17.2)
## Lezione dei tavoli di prova (24/11): una superficie dritta e ORIZZONTALE rivolta verso l'alto del tavolo (fila di
## bersagli dritta, cancelletto dritto, lato alto piatto di un piano staccato) può tenere la pallina in equilibrio:
## la gravità del tavolo inclinato tira solo verso il basso (+y) e niente la fa scivolare di lato. Basta inclinarla
## di qualche grado. Avviso arancio (va giudicato: se la pallina lì non arriva mai, non è un problema).
const PIATTO_MIN := 30.0          # mm: più corta della pallina larga non la regge
const PIATTO_ANGOLO := 0.06       # rad (≈3,5°)

static func piatti(desc: Dictionary) -> Array:
	var out: Array = []
	# file di bersagli dritti affiancati (anche uno solo, se largo)
	var dritti: Array = []
	for b in desc.get("bersagli", []):
		if not b is Dictionary or not b.has("pos"):
			continue
		var a := wrapf(float(b.get("angolo", 0.0)), -PI * 0.5, PI * 0.5)
		if absf(a) < PIATTO_ANGOLO:
			var dim: Vector2 = Vector2(b.get("dim", Vector2(24, 8)))
			dritti.append([Vector2(b["pos"]), dim.x, str(b["id"]), int(b.get("livello", 0))])
	dritti.sort_custom(func(x, y): return x[0].x < y[0].x)
	var usati := {}
	for i in dritti.size():
		if usati.has(i):
			continue
		var fila: Array = [dritti[i]]
		usati[i] = true
		var fine: float = dritti[i][0].x + dritti[i][1] * 0.5
		for j in range(i + 1, dritti.size()):
			if usati.has(j) or absf(dritti[j][0].y - dritti[i][0].y) > 3.0 or dritti[j][3] != dritti[i][3]:
				continue
			if dritti[j][0].x - dritti[j][1] * 0.5 - fine < 10.0:
				fila.append(dritti[j])
				usati[j] = true
				fine = dritti[j][0].x + dritti[j][1] * 0.5
		var inizio: float = fila[0][0].x - fila[0][1] * 0.5
		if fine - inizio >= PIATTO_MIN:
			var c := Vector2((inizio + fine) * 0.5, fila[0][0].y)
			out.append(_piatto(c, fine - inizio, fila.map(func(x): return x[2])))
	for g in desc.get("cancelli", []):
		if g is Dictionary and g.has("pos") and float(g.get("larghezza", 40.0)) >= PIATTO_MIN \
				and absf(wrapf(float(g.get("angolo", 0.0)), -PI * 0.5, PI * 0.5)) < PIATTO_ANGOLO:
			out.append(_piatto(Vector2(g["pos"]), float(g.get("larghezza", 40.0)), [str(g["id"])]))
	# lato alto dei piani staccati (fianco pieno: la pallina del tavolo ci arriva sopra)
	for m in desc.get("muri", []):
		if not m is Dictionary or not m.get("pieno", false):
			continue
		var pts: PackedVector2Array = m["punti"]
		var cen := Vector2.ZERO
		for q in pts:
			cen += q
		cen /= maxf(1.0, float(pts.size()))
		# tratti consecutivi quasi orizzontali sul lato alto, sommati
		var tratto := 0.0
		var da := Vector2.ZERO
		for k in pts.size():
			var a := pts[k]
			var b := pts[(k + 1) % pts.size()]
			var dd := b - a
			var orizz := dd.length() > 0.5 and absf(dd.y) / dd.length() < sin(PIATTO_ANGOLO) and (a + b).y * 0.5 < cen.y
			if orizz:
				if tratto == 0.0:
					da = a
				tratto += dd.length()
			if (not orizz or k == pts.size() - 1) and tratto > 0.0:
				if tratto >= PIATTO_MIN:
					out.append(_piatto((da + (b if orizz else a)) * 0.5, tratto, [str(m.get("da_piano", m.get("id", "")))]))
				tratto = 0.0
	return out

static func _piatto(c: Vector2, largo: float, pezzi: Array) -> Dictionary:
	return {"tipo": "piatto", "livello": "potenziale", "pos": c, "a": c - Vector2(largo * 0.5, 0), "b": c + Vector2(largo * 0.5, 0),
		"pezzi": pezzi, "testo": "Superficie piatta in alto lunga %.0f mm (%s): la pallina può restare in equilibrio sopra. Inclinala di qualche grado (es. 5-10°)." % [largo, ", ".join(pezzi.slice(0, 3))]}

# ================================================================ INCROCI DELLE RAMPE (v0.17.2, Fase 7)
## Due rampe che si incrociano (viste dall'alto) devono avere almeno LIBERO mm di differenza d'altezza nel punto
## d'incrocio: la pallina (27 mm) che corre su quella sotto non deve toccare il fondo di quella sopra. Lo stesso per una
## rampa che passa sopra un piano rialzato (che non sia il piano dove comincia o finisce): sotto la quota del piano la
## rampa lo attraversa (errore), poco sopra la pallina del piano la tocca. Rampe collegate (una continua l'altra) no.
const LIBERO := 32.0

static func _campioni_rampa(r: Dictionary) -> Array:
	var out: Array = []          # [Vector2, altezza]
	var pr: Array = r.get("punti", [])
	for i in range(pr.size() - 1):
		var a: Vector3 = pr[i]
		var b: Vector3 = pr[i + 1]
		var n := maxi(1, int(Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) / 8.0))
		for k in n:
			var t := float(k) / float(n)
			var q := a.lerp(b, t)
			out.append([Vector2(q.x, q.y), q.z])
	if not pr.is_empty():
		out.append([Vector2(pr[pr.size() - 1].x, pr[pr.size() - 1].y), float(pr[pr.size() - 1].z)])
	return out

static func incroci(desc: Dictionary) -> Array:
	var out: Array = []
	var rampe: Array = desc.get("rampe", []).filter(func(r): return r is Dictionary and r.get("punti", []).size() >= 2)
	var camp: Array = rampe.map(func(r): return _campioni_rampa(r))
	var visti := {}
	for i in rampe.size():
		for j in range(i + 1, rampe.size()):
			var ri: Dictionary = rampe[i]
			var rj: Dictionary = rampe[j]
			# collegate: una finisce dove comincia l'altra (o prosegue_in)
			var ci: Array = camp[i]
			var cj: Array = camp[j]
			var estremi := [ci[0][0], ci[ci.size() - 1][0], cj[0][0], cj[cj.size() - 1][0]]
			for a in range(ci.size() - 1):
				for b in range(cj.size() - 1):
					var x = Geometry2D.segment_intersects_segment(ci[a][0], ci[a + 1][0], cj[b][0], cj[b + 1][0])
					if x == null:
						continue
					var vicino_estremo := false
					for e in estremi:
						if (x as Vector2).distance_to(e) < 30.0:
							vicino_estremo = true
					if vicino_estremo:
						continue
					var hi := lerpf(ci[a][1], ci[a + 1][1], (x as Vector2).distance_to(ci[a][0]) / maxf(0.01, ci[a][0].distance_to(ci[a + 1][0])))
					var hj := lerpf(cj[b][1], cj[b + 1][1], (x as Vector2).distance_to(cj[b][0]) / maxf(0.01, cj[b][0].distance_to(cj[b + 1][0])))
					var chiave := "%s|%s" % [ri["id"], rj["id"]]
					if absf(hi - hj) < LIBERO and not visti.has(chiave):
						visti[chiave] = true
						out.append({"tipo": "incrocio", "livello": "potenziale", "pos": x, "pezzi": [str(ri["id"]), str(rj["id"])],
							"testo": "«%s» e «%s» si incrociano a %.0f e %.0f mm d'altezza: servono almeno %.0f mm di differenza (nel gioco la pallina di quella sotto si vedrebbe passare attraverso quella sopra). Alza una delle due nel punto d'incrocio." % [_nome(ri), _nome(rj), minf(hi, hj), maxf(hi, hj), LIBERO]})
	# rampe sopra i piani rialzati
	var livelli = desc.get("livelli", {})
	if livelli is Dictionary:
		for i in rampe.size():
			var r: Dictionary = rampe[i]
			for n in livelli:
				var lv = livelli[n]
				if not lv is Dictionary or not lv.has("zona") or int(r.get("livello", 0)) == int(n) or int(r.get("livello_fine", 0)) == int(n):
					continue
				var zona := PackedVector2Array(lv["zona"])
				var q := float(lv.get("altezza", 40.0))
				for c in camp[i]:
					if Geometry2D.is_point_in_polygon(c[0], zona) and c[1] - q < LIBERO:
						out.append({"tipo": "incrocio", "livello": "errore", "pos": c[0], "pezzi": [str(r["id"]), str(lv.get("nome", "piano"))],
							"testo": ("«%s» passa DENTRO il piano «%s» (%.0f mm, il piano è a %.0f): alzala sopra %.0f mm." if c[1] < q else "«%s» passa troppo bassa sopra il piano «%s» (%.0f mm, il piano è a %.0f): la pallina del piano la tocca. Alzala sopra %.0f mm.") % [_nome(r), lv.get("nome", "piano"), c[1], q, q + LIBERO]})
						break
	return out

static func _nome(r: Dictionary) -> String:
	var n := str(r.get("nome", ""))
	return str(r["id"]) if n == "" or n == str(r["id"]) else "%s (%s)" % [n, r["id"]]

# ================================================================ MISURATORE DI PESO (v0.18.2, Fase 4)
## Stima della memoria grafica del tavolo nel gioco (STIMA, non misura): immagini tue (decomprimute: larghezza ×
## altezza × 4 byte), i 3 strati «cotti» all'avvio (2 px per mm) e le musiche (file nella cartella del tavolo).
## Soglie pensate per il Raspberry Pi 4 da 1 GB e i telefoni economici: fino a 150 MB bene, fino a 300 pesante.
const PESO_BENE := 150.0
const PESO_TROPPO := 300.0

static func _misura_png(b64: String) -> Vector2i:
	var raw := Marshalls.base64_to_raw(b64.substr(0, 64))
	if raw.size() < 24:
		return Vector2i.ZERO
	var w := (raw[16] << 24) | (raw[17] << 16) | (raw[18] << 8) | raw[19]
	var h := (raw[20] << 24) | (raw[21] << 16) | (raw[22] << 8) | raw[23]
	return Vector2i(w, h)

static func peso(desc: Dictionary, cartella := "") -> Dictionary:
	var mb := 1024.0 * 1024.0
	var imm := 0.0
	var grandi: Array = []
	var lib: Dictionary = desc.get("immagini", {}) if desc.get("immagini") is Dictionary else {}
	for n in lib:
		var m := _misura_png(str(lib[n]))
		imm += float(m.x * m.y * 4) / mb
		if maxi(m.x, m.y) > 2048:
			grandi.append("%s (%d × %d)" % [n, m.x, m.y])
	var dim: Vector2 = Vector2(desc.get("dimensioni", Vector2(635, 1240))) + Vector2(16, 16)
	var cotto := 3.0 * (dim.x * 2.0) * (dim.y * 2.0) * 4.0 / mb
	var mus := 0.0
	if cartella != "" and DirAccess.dir_exists_absolute(cartella.path_join("musica")):
		for f in DirAccess.get_files_at(cartella.path_join("musica")):
			var fa := FileAccess.open(cartella.path_join("musica").path_join(f), FileAccess.READ)
			if fa != null:
				mus += float(fa.get_length()) / mb
				fa.close()
	var tot := imm + cotto + mus
	return {"immagini": imm, "cotto": cotto, "musica": mus, "totale": tot, "grandi": grandi,
		"giudizio": "bene" if tot <= PESO_BENE else ("pesante" if tot <= PESO_TROPPO else "troppo")}

static func testo_peso(p: Dictionary) -> String:
	return "Peso stimato in memoria: %.0f MB (immagini tue %.0f, disegno del tavolo %.0f, musiche %.0f) → %s" % [p["totale"], p["immagini"], p["cotto"], p["musica"],
		{"bene": "va bene anche per Raspberry Pi e telefoni", "pesante": "PESANTE per il Raspberry Pi da 1 GB: riduci le immagini", "troppo": "TROPPO: togli o rimpicciolisci immagini"}[p["giudizio"]]]
