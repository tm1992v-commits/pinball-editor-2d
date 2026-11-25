## intersection & multi-level system», analisi in STUDIO_INCROCI.md). Regola: L'AUTOMATICO PROPONE, IL PROGETTISTA DECIDE.
##
## Dati (tutti facoltativi: un tavolo senza questi campi si comporta esattamente come prima):
##  - su ogni rampa/nastro: "incroci_modo" = "" (nessuna regola) | "sopra" | "sotto" | "stesso"
##    e "incroci_margine" (mm sopra/sotto l'altro percorso, 32), "incroci_salita" (mm di salita/discesa, 120),
##    "incroci_piano" (mm di tratto in piano sull'incrocio, 40);
##  - desc["incroci"][chiave] = {"modo": "a_sopra"|"a_sotto"|"b_sopra"|"b_sotto"|"stesso", "quota": mm (facoltativa),
##    "bloccato": bool} = scelta del SINGOLO incrocio (personalizzato); vince sempre sulle regole delle rampe.
##    chiave = "<id A>|<id B>#<n>" con A < B in ordine alfabetico e n = numero dell'incrocio lungo A (0, 1, …).
##
## Le altezze disegnate non si toccano mai: il risultato va in r["punti_gioco"] (la stessa curva del gioco, punto per
## punto, con salite e discese aggiunte). Motore, disegno del gioco e CONTROLLA usano punti_gioco se c'è.
class_name Incroci

const LIBERO := 32.0          # come CONTROLLA e il motore (pallina 27 mm + fondo della rampa)
const SALITA := 120.0
const PIANO := 40.0
const VICINO_ESTREMO := 30.0  # incroci vicino alle punte di tutte e due = collegamenti, non incroci
const PENDENZA_MAX := 0.6     # oltre: avviso «salita troppo ripida»

## Percorsi su cui la pallina corre: rampe (anche binari a fili e nastri sollevati) e nastri piatti.
## [{"id" (quello che vede il progettista), "tipo", "pezzo" (dizionario con le regole), "rampa" (dizionario del motore o
##   null), "campioni": [[Vector2, z, s]], "fisso": true se non può cambiare altezza}]
static func percorsi(desc: Dictionary) -> Array:
	var out: Array = []
	var nastri := {}
	for n in desc.get("nastri", []):
		if n is Dictionary and n.has("id"):
			nastri[str(n["id"])] = n
	for r in desc.get("rampe", []):
		if not r is Dictionary or r.get("punti", []).size() < 2:
			continue
		var da_n := str(r.get("da_nastro", ""))
		var pezzo: Dictionary = nastri.get(da_n, r) if da_n != "" else r
		out.append({"id": da_n if da_n != "" else str(r["id"]), "tipo": "nastro" if da_n != "" else ("binario" if str(r.get("stile", "")) == "filo" else "rampa"),
			"pezzo": pezzo, "rampa": r, "campioni": _campioni(Binario.levigato(_v3(r["punti"]))), "fisso": da_n != ""})
	for n in desc.get("nastri", []):
		if not n is Dictionary or CurveEditor.nastro_alto(n) or n.get("controllo", PackedVector2Array()).size() < 2:
			continue
		var centri: PackedVector2Array = CurveEditor.espandi_nastro(n)[0]
		var dati: Array = []
		for q in centri:
			dati.append(Vector3(q.x, q.y, 0.0))
		out.append({"id": str(n["id"]), "tipo": "nastro", "pezzo": n, "rampa": null, "campioni": _campioni(dati), "fisso": true})
	return out

static func _v3(pts: Array) -> Array:
	return pts.map(func(q): return Vector3(q.x, q.y, q.z) if q is Vector3 else Vector3(q.x, q.y, 0.0))

static func _campioni(dati: Array) -> Array:
	var out: Array = []
	var s := 0.0
	for i in dati.size():
		var q: Vector3 = dati[i]
		if i > 0:
			s += Vector2(q.x, q.y).distance_to(Vector2(dati[i - 1].x, dati[i - 1].y))
		out.append([Vector2(q.x, q.y), q.z, s])
	return out

## Tutti gli incroci: [{"chiave", "a", "b" (indici in percorsi), "pos", "sa", "sb", "za", "zb"}]
static func trova(desc: Dictionary, perc: Array = []) -> Array:
	if perc.is_empty():
		perc = percorsi(desc)
	var out: Array = []
	for i in perc.size():
		for j in range(i + 1, perc.size()):
			var pi: Dictionary = perc[i]
			var pj: Dictionary = perc[j]
			if pi["id"] == pj["id"] or _collegati(pi, pj):
				continue
			# A = quello col nome che viene prima (chiave stabile)
			var a := i if str(pi["id"]) < str(pj["id"]) else j
			var b := j if a == i else i
			var ca: Array = perc[a]["campioni"]
			var cb: Array = perc[b]["campioni"]
			var trovati: Array = []
			for u in ca.size() - 1:
				for v in cb.size() - 1:
					var x = Geometry2D.segment_intersects_segment(ca[u][0], ca[u + 1][0], cb[v][0], cb[v + 1][0])
					if x == null:
						continue
					var xa := _in_segmento(ca, u, x)
					var xb := _in_segmento(cb, v, x)
					var gia := false
					for t in trovati:
						if Vector2(t["pos"]).distance_to(x) < 20.0:
							gia = true
					if gia or _vicino_alle_punte(ca, x) and _vicino_alle_punte(cb, x):
						continue
					var da: Vector2 = (Vector2(ca[u + 1][0]) - Vector2(ca[u][0])).normalized()
					var db: Vector2 = (Vector2(cb[v + 1][0]) - Vector2(cb[v][0])).normalized()
					trovati.append({"a": a, "b": b, "pos": x, "sa": xa[0], "za": xa[1], "sb": xb[0], "zb": xb[1], "seno": absf(da.cross(db))})
			trovati.sort_custom(func(p, q): return float(p["sa"]) < float(q["sa"]))
			for n in trovati.size():
				trovati[n]["chiave"] = "%s|%s#%d" % [perc[a]["id"], perc[b]["id"], n]
				out.append(trovati[n])
	return out

static func _in_segmento(c: Array, u: int, x: Vector2) -> Array:
	var l := Vector2(c[u][0]).distance_to(c[u + 1][0])
	var t := Vector2(c[u][0]).distance_to(x) / maxf(l, 0.0001)
	return [lerpf(float(c[u][2]), float(c[u + 1][2]), t), lerpf(float(c[u][1]), float(c[u + 1][1]), t)]

static func _vicino_alle_punte(c: Array, x: Vector2) -> bool:
	return Vector2(c[0][0]).distance_to(x) < VICINO_ESTREMO or Vector2(c[c.size() - 1][0]).distance_to(x) < VICINO_ESTREMO

static func _collegati(p: Dictionary, q: Dictionary) -> bool:
	var rp = p["rampa"]
	var rq = q["rampa"]
	if rp == null or rq == null:
		return false
	return str(rp.get("prosegue_in", "")) == str(rq["id"]) or str(rq.get("prosegue_in", "")) == str(rp["id"])

## Come si risolve un incrocio: {"modo": "a_sopra"|…|"stesso"|"" (nessuna regola), "da": "incrocio" | "regole" | "",
## "muove": indice del percorso che cambia altezza (-1 = nessuno), "su": true se sale, "conflitto": testo o "",
## "bloccato": bool}
static func risolvi(desc: Dictionary, perc: Array, inc: Dictionary) -> Dictionary:
	var scelte: Dictionary = desc.get("incroci", {}) if desc.get("incroci") is Dictionary else {}
	var sc: Dictionary = scelte.get(inc["chiave"], {}) if scelte.get(inc["chiave"]) is Dictionary else {}
	var out := {"modo": "", "da": "", "muove": -1, "su": true, "conflitto": "", "bloccato": bool(sc.get("bloccato", false))}
	var pa: Dictionary = perc[inc["a"]]
	var pb: Dictionary = perc[inc["b"]]
	if str(sc.get("modo", "")) != "":
		out["modo"] = str(sc["modo"])
		out["da"] = "incrocio"
	else:
		var ra := str(pa["pezzo"].get("incroci_modo", ""))
		var rb := str(pb["pezzo"].get("incroci_modo", ""))
		if ra == "" and rb == "":
			return out
		out["da"] = "regole"
		if ra == "stesso" or rb == "stesso":
			if (ra in ["sopra", "sotto"]) or (rb in ["sopra", "sotto"]):
				out["conflitto"] = "«%s» vuole incrociarsi alla stessa altezza, «%s» passare %s: decidi tu questo incrocio" % [pa["id"] if ra == "stesso" else pb["id"], pb["id"] if ra == "stesso" else pa["id"], ra if ra != "stesso" else rb]
				return out
			out["modo"] = "stesso"
		elif ra != "" and rb != "" and ra == rb:
			out["conflitto"] = "«%s» e «%s» vogliono passare tutte e due %s: decidi tu chi passa sopra" % [pa["id"], pb["id"], ra]
			return out
		elif ra != "":
			out["modo"] = "a_" + ra
		else:
			out["modo"] = "b_" + rb
	if out["modo"] in ["stesso", "unito"] or out["bloccato"]:
		if out["modo"] == "unito":
			out["devia"] = str(sc.get("devia", "alterna"))
			if perc[inc["a"]]["rampa"] == null or perc[inc["b"]]["rampa"] == null:
				out["conflitto"] = "un nastro piatto non può comunicare con una rampa: usa l'incrocio alla stessa altezza o un nastro sollevato"
			elif absf(float(inc["za"]) - float(inc["zb"])) > 8.0:
				out["conflitto"] = "per comunicare i due percorsi devono essere alla stessa altezza nell'incrocio (ora %.0f e %.0f mm): sistema le altezze" % [float(inc["za"]), float(inc["zb"])]
		return out
	var chi := str(out["modo"]).substr(0, 1)
	out["muove"] = int(inc["a"]) if chi == "a" else int(inc["b"])
	out["su"] = str(out["modo"]).ends_with("sopra")
	if bool(perc[out["muove"]]["fisso"]):
		var nome: String = perc[out["muove"]]["id"]
		out["conflitto"] = "«%s» è un nastro: per ora la sua altezza non cambia da sola. Fai muovere l'altro percorso o alza il nastro a mano." % nome
		out["muove"] = -1
	return out

## Calcola tutto: profili di gioco delle rampe, ordine di disegno, elenco degli incroci risolti (desc["_incroci"],
## solo per l'editor: non serve al gioco). Chiamata da CurveEditor.prepara_tavolo a ogni modifica.
static func applica(desc: Dictionary) -> void:
	for r in desc.get("rampe", []):
		if r is Dictionary:
			r.erase("punti_gioco")
	desc.erase("ordine_rampe")
	desc.erase("innesti")
	var perc := percorsi(desc)
	var incs := trova(desc, perc)
	var info: Array = []
	var spinte := {}          # indice percorso -> [[s, delta, margini…]]
	var sopra_di := {}        # id rampa -> [id rampe che deve coprire] (ordine di disegno)
	for inc in incs:
		var ris := risolvi(desc, perc, inc)
		var scelte: Dictionary = desc.get("incroci", {}) if desc.get("incroci") is Dictionary else {}
		var sc: Dictionary = scelte.get(inc["chiave"], {}) if scelte.get(inc["chiave"]) is Dictionary else {}
		var voce: Dictionary = inc.duplicate()
		voce.merge(ris)
		voce["id_a"] = perc[inc["a"]]["id"]
		voce["id_b"] = perc[inc["b"]]["id"]
		voce["rampa_a"] = str(perc[inc["a"]]["rampa"]["id"]) if perc[inc["a"]]["rampa"] != null else ""
		voce["rampa_b"] = str(perc[inc["b"]]["rampa"]["id"]) if perc[inc["b"]]["rampa"] != null else ""
		if int(ris["muove"]) >= 0 and ris["conflitto"] == "":
			var m: int = ris["muove"]
			var altro: int = int(inc["b"]) if m == int(inc["a"]) else int(inc["a"])
			var s_m := float(inc["sa"]) if m == int(inc["a"]) else float(inc["sb"])
			var z_m := float(inc["za"]) if m == int(inc["a"]) else float(inc["zb"])
			var z_o := float(inc["zb"]) if m == int(inc["a"]) else float(inc["za"])
			var pz: Dictionary = perc[m]["pezzo"]
			var margine := float(pz.get("incroci_margine", LIBERO))
			var obiettivo := z_o + margine if ris["su"] else z_o - margine
			if sc.has("quota"):
				obiettivo = float(sc["quota"])            # quota scelta a mano per questo incrocio
			var delta := obiettivo - z_m
			if ris["su"]:
				delta = maxf(delta, 0.0)
			else:
				delta = minf(delta, 0.0)
				if z_m + delta < 0.0:
					voce["conflitto"] = "«%s» non può passare sotto «%s»: servirebbe scendere a %.0f mm (sotto il piano). Alza l'altro percorso o fai passare sopra questo." % [perc[m]["id"], perc[altro]["id"], z_m + delta]
					delta = 0.0
			# il tratto in piano copre TUTTA la larghezza dell'altro percorso più la pallina (anche se si incrociano di
			# sbieco): prima copriva 40 mm e ai bordi di un nastro largo 46 la rampa restava bassa e solida (collaudo)
			var largo_altro := _larghezza(perc[altro])
			# + la chiusura inclinata che il motore mette in fondo alla parte solida della rampa (30 mm per lato)
			var piano_min := (largo_altro + 2.0 * 15.0 + 2.0 * 32.0) / maxf(float(inc.get("seno", 1.0)), 0.35)
			var piano := maxf(float(pz.get("incroci_piano", PIANO)), piano_min)
			if absf(delta) > 0.01:
				if not spinte.has(m):
					spinte[m] = []
				# si salva la QUOTA da raggiungere (non quanto alzare): sul tratto in piano la rampa sta proprio lì anche se
				# sotto stava salendo o scendendo (prima su una rampa in discesa il tratto piano tornava basso troppo presto)
				spinte[m].append([s_m, obiettivo + (1.0 if delta > 0.0 else -1.0), float(pz.get("incroci_salita", SALITA)), piano, delta > 0.0])
			voce["obiettivo"] = obiettivo
		if str(ris["modo"]) == "unito" and str(voce.get("conflitto", "")) == "" and not bool(ris["bloccato"]):
			if not desc.get("innesti") is Array:
				desc["innesti"] = []
			desc["innesti"].append({"id": inc["chiave"], "a": voce["rampa_a"], "sa": inc["sa"], "b": voce["rampa_b"], "sb": inc["sb"], "devia": ris.get("devia", "alterna")})
		info.append(voce)
	# profili di gioco
	for m in spinte:
		var r: Dictionary = perc[m]["rampa"]
		var dati: Array = Binario.levigato(_v3(r["punti"]))
		var camp := _campioni(dati)
		var tot := float(camp[camp.size() - 1][2])
		var nuovi: Array = []
		for i in camp.size():
			var s := float(camp[i][2])
			var zb := float(camp[i][1])
			var z := zb
			# le punte (imbocco e uscita) restano dove sono
			if i > 0 and i < camp.size() - 1:
				var z_su := zb
				var z_giu := zb
				for sp in spinte[m]:
					var w := _peso(absf(s - float(sp[0])), float(sp[3]) * 0.5, float(sp[2]))
					var verso := lerpf(zb, float(sp[1]), w)
					if bool(sp[4]):
						z_su = maxf(z_su, verso)
					else:
						z_giu = minf(z_giu, verso)
				z = z_su if z_su > zb else z_giu
			z = maxf(z, 0.0)
			nuovi.append(Vector3(camp[i][0].x, camp[i][0].y, z))
		r["punti_gioco"] = nuovi
		perc[m]["campioni"] = _campioni(nuovi)
		perc[m]["lunghezza"] = tot
	# quote finali nell'incrocio, controlli e ordine di disegno
	for voce in info:
		var za := _z_a(perc[voce["a"]]["campioni"], float(voce["sa"]))
		var zb := _z_a(perc[voce["b"]]["campioni"], float(voce["sb"]))
		voce["za_gioco"] = za
		voce["zb_gioco"] = zb
		var ra = perc[voce["a"]]["rampa"]
		var rb = perc[voce["b"]]["rampa"]
		# solo dove c'è una regola o una scelta (i tavoli vecchi si disegnano esattamente come prima)
		if ra != null and rb != null and absf(za - zb) > 1.0 and str(voce.get("modo", "")) != "":
			var su_id := str(ra["id"]) if za > zb else str(rb["id"])
			var giu_id := str(rb["id"]) if za > zb else str(ra["id"])
			if not sopra_di.has(su_id):
				sopra_di[su_id] = []
			sopra_di[su_id].append(giu_id)
	desc["_incroci"] = info
	if not sopra_di.is_empty():
		desc["ordine_rampe"] = _ordina(desc, sopra_di)

## Larghezza (mm) di un percorso: nastro = la sua larghezza, rampa/binario = 38 (come le pareti del motore).
static func _larghezza(pc: Dictionary) -> float:
	var pz: Dictionary = pc["pezzo"]
	if pz.get("larghezze") is Array and not (pz["larghezze"] as Array).is_empty():
		var mx := 0.0
		for l in pz["larghezze"]:
			mx = maxf(mx, float(l))
		return mx
	if float(pz.get("larghezza", 0.0)) > 0.0 and pc["tipo"] == "nastro":
		return float(pz["larghezza"])
	return 38.0

## Peso della salita: 1 sul tratto in piano (|d| <= mezzo_piano), poi scende morbido a 0 in «salita» mm.
static func _peso(d: float, mezzo_piano: float, salita: float) -> float:
	if d <= mezzo_piano:
		return 1.0
	var t := (d - mezzo_piano) / maxf(salita, 1.0)
	if t >= 1.0:
		return 0.0
	return 1.0 - t * t * (3.0 - 2.0 * t)

static func _z_a(camp: Array, s: float) -> float:
	for i in camp.size() - 1:
		if float(camp[i + 1][2]) >= s:
			var l := float(camp[i + 1][2]) - float(camp[i][2])
			return lerpf(float(camp[i][1]), float(camp[i + 1][1]), (s - float(camp[i][2])) / maxf(l, 0.0001))
	return float(camp[camp.size() - 1][1])

## Ordine di disegno delle rampe: quella che passa sopra si disegna dopo quella che sta sotto (sempre lo stesso
## risultato a parità di tavolo). Le altre restano nell'ordine di sempre.
static func _ordina(desc: Dictionary, sopra_di: Dictionary) -> Array:
	var ids: Array = desc.get("rampe", []).map(func(r): return str(r.get("id", "")))
	var fatto := {}
	var out: Array = []
	var visita := func(f: Callable, id: String, profondo: int) -> void:
		if fatto.has(id) or profondo > 50:
			return
		fatto[id] = true
		for sotto in sopra_di.get(id, []):
			f.call(f, str(sotto), profondo + 1)
		out.append(id)
	for id in ids:
		visita.call(visita, id, 0)
	return out

## Punti con cui il gioco percorre e disegna la rampa (con le salite e discese degli incroci, se ci sono).
static func punti_gioco(r: Dictionary) -> Array:
	return r["punti_gioco"] if r.get("punti_gioco") is Array and not (r["punti_gioco"] as Array).is_empty() else r.get("punti", [])

## Controlli per CONTROLLA: conflitti, differenze d'altezza insufficienti negli incroci risolti, salite troppo ripide.
## [{"tipo": "incrocio", "livello": "info"|"potenziale"|"errore", "pos", "pezzi", "testo", "chiave"}]
static func controlli(desc: Dictionary) -> Array:
	var out: Array = []
	for v in desc.get("_incroci", []):
		var pezzi := [str(v["id_a"]), str(v["id_b"])]
		if str(v.get("conflitto", "")) != "":
			out.append({"tipo": "incrocio", "livello": "errore", "pos": v["pos"], "pezzi": pezzi, "chiave": v["chiave"], "testo": "Incrocio non risolto: " + str(v["conflitto"]) + "."})
			continue
		if str(v.get("modo", "")) == "unito":
			out.append({"tipo": "incrocio", "livello": "info", "pos": v["pos"], "pezzi": pezzi, "chiave": v["chiave"], "testo": "«%s» e «%s» comunicano: la pallina può cambiare strada (deviatore: %s)." % [pezzi[0], pezzi[1], str(v.get("devia", "alterna"))]})
			continue
		if str(v.get("modo", "")) == "stesso":
			out.append({"tipo": "incrocio", "livello": "info", "pos": v["pos"], "pezzi": pezzi, "chiave": v["chiave"], "testo": "«%s» e «%s» si incrociano alla stessa altezza (ognuna resta sulla sua strada)." % pezzi})
			continue
		# differenze d'altezza insufficienti: le segnala già il controllo degli incroci di CONTROLLA (sulle quote del gioco)
	for pp in desc.get("piani", []):
		if pp is Dictionary:
			for pr in PianiRialzati.varchi_proposti(desc, pp):
				out.append({"tipo": "varco", "livello": "info", "pos": pr["pos"], "pezzi": [str(pp["id"]), str(pr["rampa"])], "chiave": "",
					"testo": "«%s» attraversa il bordo chiuso del piano «%s»: nel pannello del piano puoi aprire lì il varco (la pallina passa comunque, ma il bordo si vede chiuso)." % [str(pr["rampa"]), str(pp.get("nome", pp["id"]))]})
	for r in desc.get("rampe", []):
		if not r is Dictionary or not r.get("punti_gioco") is Array:
			continue
		var c := _campioni(r["punti_gioco"])
		for i in range(1, c.size()):
			var ds := float(c[i][2]) - float(c[i - 1][2])
			if ds > 0.5 and absf(float(c[i][1]) - float(c[i - 1][1])) / ds > PENDENZA_MAX:
				out.append({"tipo": "pendenza", "livello": "potenziale", "pos": c[i][0], "pezzi": [str(r.get("da_nastro", r["id"]))], "chiave": "",
					"testo": "«%s»: la salita o discesa per un incrocio è troppo ripida (più di %d%%): la pallina potrebbe non farcela. Allunga la salita (pannello della rampa) o sposta l'incrocio più lontano dalle punte." % [str(r.get("da_nastro", r["id"])), int(PENDENZA_MAX * 100.0)]})
				break
	return out
