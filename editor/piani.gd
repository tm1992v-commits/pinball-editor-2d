##  - desc["livelli"][n] = {altezza, zona, nome, bordo_aperto}  (n = livello del piano: 1, 2, …)
##  - il bordo del piano (muro di livello n tutto intorno) se il bordo è chiuso;
##  - i PEZZI messi dentro la forma vanno sul piano (livello n) da soli; spostati fuori tornano sul tavolo;
##  - una RAMPA che finisce dentro un piano porta la pallina sul piano; una che parte da un piano la fa scendere;
##  - una BUCA «che manda la pallina in un altro punto»: se il punto è su un piano la pallina sale, altrimenti scende.
## Tutto ciò che è generato ha il segno "da_piano" / "da_buca" / "livello_auto" e si rifà da capo ogni volta.
class_name PianiRialzati

## Pezzi che salgono sul piano se stanno dentro la sua forma.
const LIVELLABILI := ["bumper", "bersagli", "spinner", "elastici", "buche", "palette", "fionde", "sensori", "cancelli",
	"kickback", "campi", "inserti", "muri"]

static func genera(desc: Dictionary) -> void:
	# 1) via tutto ciò che era generato
	if desc.get("muri") is Array:
		desc["muri"] = desc["muri"].filter(func(m): return not (m is Dictionary and m.has("da_piano")))
	if desc.get("passaggi") is Array:
		desc["passaggi"] = desc["passaggi"].filter(func(p): return not (p is Dictionary and p.has("da_buca")))
	var livelli = desc.get("livelli", {})
	if livelli is Dictionary:
		for k in livelli.keys():
			if livelli[k] is Dictionary and livelli[k].has("da_piano"):
				livelli.erase(k)
	var piani: Array = desc.get("piani", []) if desc.get("piani") is Array else []
	var usati := {}
	if livelli is Dictionary:
		for k in livelli:
			usati[int(k)] = true
	# 2) un livello per ogni piano
	var zone: Array = []                         # [livello, zona, altezza]
	for p in piani:
		if not p is Dictionary or not p.has("controllo"):
			continue
		p["chiuso"] = true
		CurveEditor.normalizza(p)
		CurveEditor.rigenera(p)
		var n := int(p.get("livello", 0))
		if n <= 0 or usati.has(n):
			n = 1
			while usati.has(n):
				n += 1
			p["livello"] = n
		usati[n] = true
		var zona := PackedVector2Array(p["punti"])
		if zona.size() > 3 and zona[0].distance_to(zona[zona.size() - 1]) < 0.5:
			zona.remove_at(zona.size() - 1)
		if zona.size() < 3:
			continue
		if not desc.get("livelli") is Dictionary:
			desc["livelli"] = {}
		desc["livelli"][n] = {"altezza": float(p.get("altezza", 40.0)), "zona": zona, "nome": str(p.get("nome", "Piano")),
			"bordo_aperto": bool(p.get("bordo_aperto", false)), "da_piano": p["id"]}
		zone.append([n, zona, float(p.get("altezza", 40.0))])
		# il suo fianco è un blocco pieno: la pallina ci sbatte contro; sul piano si arriva solo con rampa, binario o
		if not bool(p.get("passa_sotto", false)):
			if not desc.get("muri") is Array:
				desc["muri"] = []
			desc["muri"].append({"id": "%s@fianco" % p["id"], "punti": PackedVector2Array(zona), "tipo": "metallo", "livello": 0,
				"pieno": true, "da_piano": p["id"]})
		# rampa»): il bordo si spezza dove ci sono i varchi, e da lì la pallina può scendere (o entrare nella rampa).
		var estremi := estremi_varchi(p)
		desc["livelli"][n]["varchi"] = estremi
		if not bool(p.get("bordo_aperto", false)):
			if not desc.get("muri") is Array:
				desc["muri"] = []
			var pezzi := bordo_spezzato(p)
			for q in pezzi.size():
				desc["muri"].append({"id": "%s@bordo%s" % [p["id"], "" if q == 0 else str(q + 1)], "punti": pezzi[q], "tipo": "metallo", "livello": n, "altezza": 16.0, "da_piano": p["id"]})
	# 3) i pezzi dentro un piano salgono sul piano (solo quelli messi a mano restano come sono)
	for k in LIVELLABILI:
		for e in desc.get(k, []):
			if not e is Dictionary or e.has("da_nastro") or e.has("da_piano") or str(e.get("id", "")) == "sponda":
				continue
			if e.has("livello") and not bool(e.get("livello_auto", false)):
				continue
			var n_in := livello_in(zone, ProgettoEditor.centro(k, e))
			if n_in > 0:
				e["livello"] = n_in
				e["livello_auto"] = true
			elif bool(e.get("livello_auto", false)):
				e.erase("livello")
				e.erase("livello_auto")
	# 4) rampe: che finiscono su un piano (salita) o partono da un piano (discesa)
	for r in desc.get("rampe", []):
		if not r is Dictionary or r.get("punti", []).size() < 2:
			continue
		var pts: Array = r["punti"]
		var primo: Vector3 = pts[0]
		var ultimo: Vector3 = pts[pts.size() - 1]
		var n_fine := livello_in(zone, Vector2(ultimo.x, ultimo.y))
		if n_fine > 0:
			pts[pts.size() - 1] = Vector3(ultimo.x, ultimo.y, _altezza(zone, n_fine))
			r["livello_fine"] = n_fine
			r["livello_fine_auto"] = true
		elif bool(r.get("livello_fine_auto", false)):
			r.erase("livello_fine")
			r.erase("livello_fine_auto")
			pts[pts.size() - 1] = Vector3(ultimo.x, ultimo.y, 0.0)
		var n_inizio := livello_in(zone, Vector2(primo.x, primo.y))
		if n_inizio > 0:
			pts[0] = Vector3(primo.x, primo.y, _altezza(zone, n_inizio))
			r["livello"] = n_inizio
			r["livello_auto"] = true
		elif bool(r.get("livello_auto", false)):
			r.erase("livello")
			r.erase("livello_auto")
			pts[0] = Vector3(primo.x, primo.y, 0.0)
		# i punti in mezzo mai sotto la linea tra inizio e fine (la rampa non «scende sotto» un piano)
		for i in range(1, pts.size() - 1):
			var t := float(i) / float(pts.size() - 1)
			var minimo := lerpf(float(pts[0].z), float(pts[pts.size() - 1].z), t)
			if float(pts[i].z) < minimo:
				pts[i] = Vector3(pts[i].x, pts[i].y, minimo)
		r["punti"] = pts
	# 5) buche che mandano la pallina in un altro punto (sopra un piano = sale, sul tavolo = scende)
	for b in desc.get("buche", []):
		if not b is Dictionary or str(b.get("tipo", "")) != "passaggio" or not b.get("uscita") is Vector2:
			continue
		if b.has("passaggio") and not str(b["passaggio"]).ends_with("@via"):
			continue                          # passaggio scritto a mano (tavoli pronti): non si tocca
		var uscita: Vector2 = b["uscita"]
		var pid := "%s@via" % b["id"]
		if not desc.get("passaggi") is Array:
			desc["passaggi"] = []
		desc["passaggi"].append({"id": pid, "percorso": PackedVector2Array([b["pos"], uscita]), "vel_interna": 900.0,
			"uscita": uscita, "uscita_dir": Vector2(b.get("uscita_dir", Vector2(0, -1))), "uscita_vel": float(b.get("uscita_vel", 300.0)),
			"variazione": 0.05, "uscita_livello": livello_in(zone, uscita), "da_buca": b["id"]})
		b["passaggio"] = pid
	collega_rampe(desc)

## RAMPE COLLEGATE (v0.9.2): una rampa che comincia dove ne finisce un'altra (entro 30 mm, e quella finisce in alto)
## ne è il proseguimento; se ne cominciano due, un DEVIATORE che alterna le strade; una rampa che finisce dentro una
## buca ci lascia la pallina. Tutto rifatto a ogni modifica (segni "*_auto" e "da_rampa").
static func collega_rampe(desc: Dictionary) -> void:
	if desc.get("deviatori") is Array:
		desc["deviatori"] = desc["deviatori"].filter(func(dv): return not (dv is Dictionary and dv.has("da_rampa")))
	var rampe: Array = desc.get("rampe", []) if desc.get("rampe") is Array else []
	for r in rampe:
		if r is Dictionary and bool(r.get("prosegue_auto", false)):
			r.erase("prosegue_in")
			r.erase("prosegue_auto")
		if r is Dictionary and bool(r.get("inizio_auto", false)):
			var pz: Array = r["punti"]
			pz[0] = Vector3(pz[0].x, pz[0].y, 0.0)
			r["punti"] = pz
			r.erase("inizio_auto")
			if not bool(r.get("livello_auto", false)):
				r.erase("livello")
		if r is Dictionary and bool(r.get("finisce_auto", false)):
			r.erase("finisce_in")
			r.erase("finisce_auto")
	for r in rampe:
		if not r is Dictionary or r.get("punti", []).size() < 2 or (r.has("prosegue_in") and not bool(r.get("prosegue_auto", false))):
			continue
		var fine: Vector3 = r["punti"][r["punti"].size() - 1]
		var dopo: Array = []
		if fine.z > 5.0:
			for s in rampe:
				if s is Dictionary and s != r and s.get("punti", []).size() >= 2:
					var inizio: Vector3 = s["punti"][0]
					if Vector2(inizio.x, inizio.y).distance_to(Vector2(fine.x, fine.y)) < 30.0:
						dopo.append(s)
		for s in dopo:
			var pts: Array = s["punti"]
			pts[0] = Vector3(pts[0].x, pts[0].y, fine.z)
			s["punti"] = pts
			s["livello"] = int(r.get("livello_fine", 0))
			s["inizio_auto"] = true
		if dopo.size() == 1:
			r["prosegue_in"] = dopo[0]["id"]
			r["prosegue_auto"] = true
		elif dopo.size() >= 2:
			if not desc.get("deviatori") is Array:
				desc["deviatori"] = []
			desc["deviatori"].append({"id": "%s@deviatore" % r["id"], "rampa": r["id"], "aperto_verso": dopo[0]["id"],
				"chiuso_verso": dopo[1]["id"], "aperto": false, "alterna": true, "da_rampa": r["id"]})
		else:
			for b in desc.get("buche", []):
				if b is Dictionary and Vector2(fine.x, fine.y).distance_to(b["pos"]) < float(b.get("raggio", 14.0)) + 6.0 and str(b.get("tipo", "")) in ["tiene", "prigione"]:
					r["finisce_in"] = b["id"]
					r["finisce_auto"] = true

## ---------------------------------------------------------------- v0.29: VARCHI NEL BORDO DEL PIANO
## p["varchi"] = [{"t": dove (0-1 lungo il giro del bordo, dal primo punto), "larghezza": mm}]. La posizione è una
## frazione del giro, così se cambi la forma del piano il varco resta più o meno nello stesso punto.

## Il giro chiuso del bordo (primo punto ripetuto in fondo).
static func giro(p: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array(p.get("punti", PackedVector2Array()))
	if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.5:
		pts.remove_at(pts.size() - 1)
	if pts.size() < 3:
		return PackedVector2Array()
	pts.append(pts[0])
	return pts

static func lunghezza(linea: PackedVector2Array) -> float:
	var l := 0.0
	for k in linea.size() - 1:
		l += linea[k].distance_to(linea[k + 1])
	return l

## Tratti tolti, in mm lungo il giro: [[s1, s2], …] (s2 può superare la lunghezza: il varco passa dal primo punto).
static func tagli(p: Dictionary) -> Array:
	var g := giro(p)
	var tot := lunghezza(g)
	var out: Array = []
	if tot <= 0.0:
		return out
	for v in p.get("varchi", []):
		if not v is Dictionary:
			continue
		var mezzo := minf(float(v.get("larghezza", 50.0)), tot * 0.9) * 0.5
		var s := fposmod(float(v.get("t", 0.0)), 1.0) * tot
		out.append([s - mezzo, s + mezzo])
	return out

## Punto a distanza s (mm) lungo il giro, che si ripete (s fuori da 0..tot gira intorno).
static func punto_giro(g: PackedVector2Array, s: float) -> Vector2:
	var tot := lunghezza(g)
	s = fposmod(s, maxf(tot, 0.001))
	return ProgettoEditor._punto_a(g, s)

## Estremi dei varchi [[a, b], …] (per la fisica: da lì la pallina può uscire dal piano).
static func estremi_varchi(p: Dictionary) -> Array:
	var g := giro(p)
	var out: Array = []
	for tg in tagli(p):
		out.append([punto_giro(g, tg[0]), punto_giro(g, tg[1])])
	return out

## Il bordo senza i varchi: uno o più pezzi di linea, ognuno in ordine lungo il giro (angoli compresi).
static func bordo_spezzato(p: Dictionary) -> Array:
	var g := giro(p)
	if g.size() < 2:
		return []
	var tg := tagli(p)
	if tg.is_empty():
		return [g]
	var tot := lunghezza(g)
	var cum: Array = [0.0]
	for k in g.size() - 1:
		cum.append(float(cum[k]) + g[k].distance_to(g[k + 1]))
	var tolti: Array = []
	for t in tg:
		tolti.append([float(t[0]), float(t[1])])
	tolti.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array = []
	for i in tolti.size():
		# dal fondo di un varco all'inizio del successivo (l'ultimo fa il giro e arriva al primo)
		var da: float = tolti[i][1]
		var a: float = tolti[(i + 1) % tolti.size()][0] + (tot if i == tolti.size() - 1 else 0.0)
		if a - da <= 1.0:
			continue
		var punti_s: Array = []
		for giri in [-tot, 0.0, tot, 2.0 * tot]:
			for k in g.size() - 1:
				var sk: float = float(cum[k]) + giri
				if sk > da + 0.01 and sk < a - 0.01:
					punti_s.append([sk, g[k]])
		punti_s.sort_custom(func(x, y): return x[0] < y[0])
		var linea := PackedVector2Array([punto_giro(g, da)])
		for q in punti_s:
			linea.append(q[1])
		linea.append(punto_giro(g, a))
		out.append(linea)
	return out

## v0.30: VARCHI PROPOSTI. Dove una rampa (o un nastro sollevato) che sale su questo piano o ne scende attraversa il
## bordo chiuso e lì non c'è ancora un varco: [{"pos", "t" (0-1 sul giro), "rampa": id}]. L'editor li propone, il
## progettista li conferma (e poi può spostarli o chiuderli).
static func varchi_proposti(desc: Dictionary, p: Dictionary) -> Array:
	var out: Array = []
	if bool(p.get("bordo_aperto", false)):
		return out
	var n := int(p.get("livello", 0))
	var g := giro(p)
	if n <= 0 or g.size() < 4:
		return out
	var tot := lunghezza(g)
	var gia := estremi_varchi(p)
	for r in desc.get("rampe", []):
		if not r is Dictionary or (int(r.get("livello", 0)) != n and int(r.get("livello_fine", 0)) != n):
			continue
		var linea: Array = Binario.levigato(r.get("punti", []).map(func(q): return Vector3(q.x, q.y, q.z)))
		for i in linea.size() - 1:
			var acc := 0.0
			for k in g.size() - 1:
				var x = Geometry2D.segment_intersects_segment(Vector2(linea[i].x, linea[i].y), Vector2(linea[i + 1].x, linea[i + 1].y), g[k], g[k + 1])
				if x != null:
					var coperto := false
					for v in gia:
						if Geometry2D.get_closest_point_to_segment(x, v[0], v[1]).distance_to(x) < 20.0:
							coperto = true
					for o in out:
						if Vector2(o["pos"]).distance_to(x) < 30.0:
							coperto = true
					if not coperto:
						out.append({"pos": x, "t": fposmod((acc + g[k].distance_to(x)) / maxf(tot, 0.001), 1.0), "rampa": str(r.get("da_nastro", r["id"]))})
				acc += g[k].distance_to(g[k + 1])
	return out

## Livello del piano che contiene il punto (0 = tavolo). Se i piani si sovrappongono vince l'ultimo.
static func livello_in(zone: Array, q: Vector2) -> int:
	var n := 0
	for z in zone:
		if Geometry2D.is_point_in_polygon(q, z[1]):
			n = int(z[0])
	return n

static func _altezza(zone: Array, n: int) -> float:
	for z in zone:
		if int(z[0]) == n:
			return float(z[2])
	return 0.0

## Forma pronta: rettangolo con gli angoli curvi intorno al punto (larghezza × altezza in mm).
static func forma_pronta(c: Vector2, dim := Vector2(200, 150)) -> Dictionary:
	# v0.17.2: lato alto a «tetto» (punta di 30 mm al centro): ora il piano è un blocco e su un lato alto piatto la
	# pallina del tavolo poteva restare in equilibrio (caccia agli incastri sul tavolo di prova, 24/11)
	var h := dim * 0.5
	return {"controllo": PackedVector2Array([c + Vector2(-h.x, -h.y + 8.0), c + Vector2(0, -h.y - 22.0), c + Vector2(h.x, -h.y + 8.0), c + Vector2(h.x, h.y), c + Vector2(-h.x, h.y)]),
		"curvi": [true, false, true, true, true]}

# ================================================================ PALLINA PRIGIONIERA (v0.17.2)
## Dalla posizione, dal verso e dalla lunghezza l'editor costruisce ciò che il motore conosce già (la «Bilancia» di
## non entra ma tocca la prigioniera che sporge), il fermo (che solo la prigioniera vede) e il bersaglio in fondo.
const R_PALLINA := 13.5

static func genera_captive(desc: Dictionary) -> void:
	if desc.get("muri") is Array:
		desc["muri"] = desc["muri"].filter(func(m): return not (m is Dictionary and m.has("da_captive")))
	for cb in desc.get("captive", []):
		if not cb is Dictionary or not cb.has("casa") or bool(cb.get("canale_proprio", false)):
			continue                      # (v0.22: tavolo importato: il canale è già nei suoi muri)
		var c: Vector2 = Vector2(cb["casa"])
		var a := float(cb.get("angolo", 0.0))
		var dir := Vector2(sin(a), -cos(a))          # angolo 0 = canale verso l'alto
		var n := dir.orthogonal()
		var corsa := clampf(float(cb.get("corsa", 90.0)), 40.0, 200.0)
		cb["corsa"] = corsa
		cb["fermo"] = [c - dir * R_PALLINA + n * 16.0, c - dir * R_PALLINA - n * 16.0]
		cb["bersaglio"] = c + dir * corsa
		var fondo := c + dir * (corsa + 15.0)
		var u := PackedVector2Array([c - dir * 6.0 + n * 12.0, c + dir * 4.0 + n * 15.5, fondo + n * 15.5,
			fondo - n * 15.5, c + dir * 4.0 - n * 15.5, c - dir * 6.0 - n * 12.0])
		if not desc.get("muri") is Array:
			desc["muri"] = []
		desc["muri"].append({"id": "%s@canale" % cb["id"], "punti": u, "tipo": "metallo", "altezza": 22.0, "da_captive": cb["id"]})
