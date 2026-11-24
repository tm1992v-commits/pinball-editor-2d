## MODELLI DI MISSIONE pronti (Pinball Editor 2D v0.10, 24/11/2026). Ogni modello costruisce una missione a
## mattoncini con i pezzi che ci sono DAVVERO sul tavolo (se manca il pezzo giusto, il modello non si può usare e
## l'editor dice perché). Valori di punti e tempi = STIMA di partenza, da regolare provando.
class_name ModelliMissioni

const ELENCO := [
	["bumper", "Pioggia di colpi", "colpisci i bumper 25 volte"],
	["rampe", "Giro delle rampe", "fai 3 rampe fino in fondo"],
	["corsie", "Corsie accese", "passa nelle corsie (sensori) 6 volte"],
	["fila", "Abbatti la fila", "abbatti tutta una fila di bersagli 2 volte"],
	["tutti_bersagli", "Tiro a segno", "colpisci tutti i bersagli almeno una volta"],
	["spinner", "Elica", "fai girare lo spinner 30 volte"],
	["buca", "Caccia alla buca", "prendi la buca 2 volte"],
	["combo", "Combo", "3 tiri di fila entro 4 secondi l'uno dall'altro"],
	["a_tempo", "Corsa contro il tempo", "15 colpi in 30 secondi"],
	["hurry_up", "Hurry-up", "presto! il premio cala ogni secondo finché non prendi il tiro"],
	["jackpot", "Multiball jackpot", "multiball: 3 jackpot da prendere"],
	["wizard", "Modalità finale", "si sblocca dopo 6 missioni: multiball, punti doppi, gran premio"],
	["cattura", "Cattura", "colpisci 5 volte, poi la buca: catturi un oggetto della collezione"],
	["viaggio", "Viaggio", "2 rampe (o 2 buche): si passa alla zona successiva"],
	["tieni_vivo", "Tieni acceso", "tieni vivi i bumper per 15 secondi (un colpo almeno ogni 4 s)"],
	["energia", "Corsa all'energia", "fai 4 rampe prima che finisca l'energia (si ricarica con lo spinner o i bumper)"],
]

## Nomi in inglese (tabellone in inglese)
const NOMI_EN := {"bumper": "Bumper Storm", "rampe": "Ramp Tour", "corsie": "Lane Lights", "fila": "Drop the Bank",
	"tutti_bersagli": "Sharpshooter", "spinner": "Propeller", "buca": "Hole Hunt", "combo": "Combo", "a_tempo": "Beat the Clock",
	"hurry_up": "Hurry-Up", "jackpot": "Multiball Jackpot", "wizard": "Wizard Mode", "cattura": "Capture", "viaggio": "Journey", "tieni_vivo": "Keep It Lit", "energia": "Energy Run"}

static func _ha(desc: Dictionary, k: String, filtro := Callable()) -> Array:
	var out: Array = []
	for e in desc.get(k, []):
		if e is Dictionary and e.has("id") and not e.has("da_nastro") and (not filtro.is_valid() or filtro.call(e)):
			out.append(e)
	return out

## Le rampe vere: anche i NASTRI alzati (nel gioco sono rampe, id "<nastro>@rampa").
static func _rampe(desc: Dictionary) -> Array:
	return desc.get("rampe", []).filter(func(e): return e is Dictionary and e.has("id"))

static func _file(desc: Dictionary) -> Array:
	var g := {}
	for b in _ha(desc, "bersagli", func(e): return bool(e.get("abbattibile", false)) and str(e.get("gruppo", "")) != ""):
		g[str(b["gruppo"])] = true
	return g.keys()

## [{id, nome, testo, ok, perche}] per la finestra «Aggiungi da modello».
static func disponibili(desc: Dictionary) -> Array:
	var out: Array = []
	for v in ELENCO:
		var m := crea(v[0], desc)
		out.append({"id": v[0], "nome": v[1], "testo": v[2], "ok": not m.has("errore"), "perche": str(m.get("errore", ""))})
	return out

## La missione del modello (con "errore" se sul tavolo manca il pezzo che serve).
static func crea(modello: String, desc: Dictionary) -> Dictionary:
	var nome := modello
	for v in ELENCO:
		if v[0] == modello:
			nome = v[1]
	var m := {"nome": nome, "nome_en": NOMI_EN.get(modello, nome), "attiva": true, "ripeti": true, "modello": modello}
	var colpo := "bumper" if not _ha(desc, "bumper").is_empty() else ("bersaglio" if not _ha(desc, "bersagli").is_empty() else "qualsiasi")
	match modello:
		"bumper":
			if _ha(desc, "bumper").is_empty():
				return {"errore": "sul tavolo non ci sono bumper"}
			m["fasi"] = [{"quando": {"tipo": "bumper"}, "volte": 25, "testo": "colpisci i bumper"}]
			m["premio"] = {"punti": 50000}
		"rampe":
			if _rampe(desc).is_empty():
				return {"errore": "sul tavolo non ci sono rampe"}
			m["fasi"] = [{"quando": {"tipo": "rampa"}, "volte": 3, "testo": "fai le rampe fino in fondo"}]
			m["premio"] = {"punti": 100000}
		"corsie":
			if _ha(desc, "sensori").is_empty():
				return {"errore": "sul tavolo non ci sono corsie con sensore"}
			m["fasi"] = [{"quando": {"tipo": "sensore"}, "volte": 6, "testo": "passa nelle corsie"}]
			m["premio"] = {"punti": 40000}
		"fila":
			var f := _file(desc)
			if f.is_empty():
				return {"errore": "sul tavolo non c'è una fila di bersagli abbattibili"}
			m["fasi"] = [{"quando": {"tipo": "fila"}, "volte": 2, "testo": "abbatti tutta la fila"}]
			m["premio"] = {"punti": 75000, "bonus_x": 1}
		"tutti_bersagli":
			if _ha(desc, "bersagli").size() < 2:
				return {"errore": "servono almeno 2 bersagli"}
			m["fasi"] = [{"quando": {"tipo": "bersaglio"}, "modo": "tutti", "testo": "colpisci tutti i bersagli"}]
			m["premio"] = {"punti": 80000}
		"spinner":
			if _ha(desc, "spinner").is_empty():
				return {"errore": "sul tavolo non c'è uno spinner"}
			m["fasi"] = [{"quando": {"tipo": "spinner"}, "volte": 30, "testo": "fai girare lo spinner"}]
			m["premio"] = {"punti": 40000}
		"buca":
			if _ha(desc, "buche").is_empty():
				return {"errore": "sul tavolo non ci sono buche"}
			m["fasi"] = [{"quando": {"tipo": "buca"}, "volte": 2, "testo": "prendi la buca"}]
			m["premio"] = {"punti": 60000}
		"combo":
			var tipo := "rampa" if not _rampe(desc).is_empty() else ("sensore" if not _ha(desc, "sensori").is_empty() else colpo)
			m["fasi"] = [{"quando": {"tipo": tipo}, "modo": "combo", "volte": 3, "finestra": 4.0, "testo": "combo: 3 tiri di fila"}]
			m["premio"] = {"punti": 150000}
		"a_tempo":
			m["tempo"] = 30.0
			m["fasi"] = [{"quando": {"tipo": colpo}, "volte": 15, "testo": "presto: 15 colpi"}]
			m["premio"] = {"punti": 100000}
		"hurry_up":
			var tipo2 := "buca" if not _ha(desc, "buche").is_empty() else ("rampa" if not _rampe(desc).is_empty() else "")
			if tipo2 == "":
				return {"errore": "serve una buca o una rampa"}
			m["tempo"] = 30.0
			m["fasi"] = [{"quando": {"tipo": tipo2}, "modo": "hurry_up", "cala": 10000.0, "premio": {"punti": 500000, "minimo": 50000}}]
		"jackpot":
			var tipo3 := "rampa" if not _rampe(desc).is_empty() else ("buca" if not _ha(desc, "buche").is_empty() else colpo)
			m["inizio"] = {"multiball": 1, "salva_pallina": 15.0}
			m["fasi"] = []
			for i in 3:
				m["fasi"].append({"quando": {"tipo": tipo3}, "volte": 1, "testo": "JACKPOT %d/3" % (i + 1), "premio": {"punti": 250000 * (i + 1)}})
			m["premio"] = {"punti": 250000}
		"tieni_vivo":
			var tv := "bumper" if not _ha(desc, "bumper").is_empty() else ("spinner" if not _ha(desc, "spinner").is_empty() else "")
			if tv == "":
				return {"errore": "servono bumper o uno spinner"}
			m["fasi"] = [{"quando": {"tipo": tv}, "modo": "stato", "durata": 15.0, "finestra": 4.0, "testo": "tieni acceso!"}]
			m["premio"] = {"punti": 120000}
		"energia":
			var bersaglio := "rampa" if not _rampe(desc).is_empty() else ("buca" if not _ha(desc, "buche").is_empty() else "")
			if bersaglio == "":
				return {"errore": "serve una rampa o una buca"}
			var ric := "spinner" if not _ha(desc, "spinner").is_empty() else colpo
			m["energia"] = {"luci": 6, "cala": 5.0, "ricarica": {"tipo": ric}}
			m["fasi"] = [{"quando": {"tipo": bersaglio}, "volte": 4, "testo": "4 tiri prima che finisca l'energia"}]
			m["premio"] = {"punti": 200000}
		"wizard":
			m["sblocco"] = {"completate": 6}
			m["ripeti"] = true
			m["priorita"] = 1                 # v0.13: è una MODALITÀ: parte da sola e mette in pausa la missione in corso
			m["inizio"] = {"multiball": 2, "salva_pallina": 30.0, "punti_x": 2}
			m["tempo"] = 60.0
			m["fasi"] = [{"quando": {"tipo": "qualsiasi"}, "volte": 60, "testo": "MODALITÀ FINALE: colpisci tutto"}]
			m["premio"] = {"punti": 5000000, "pallina_extra": true}
		"cattura":
			if not desc.get("collezione") is Dictionary or (desc["collezione"].get("oggetti", []) as Array).is_empty():
				return {"errore": "prima crea la collezione (Collezione e zone)"}
			var tipo4 := "buca" if not _ha(desc, "buche").is_empty() else ("rampa" if not _rampe(desc).is_empty() else colpo)
			m["fasi"] = [{"quando": {"tipo": colpo}, "volte": 5, "testo": "apri la cattura"},
				{"quando": {"tipo": tipo4}, "volte": 1, "testo": "CATTURA!"}]
			m["premio"] = {"cattura": true}
		"viaggio":
			if not desc.get("zone") is Array or (desc["zone"] as Array).size() < 2:
				return {"errore": "prima crea almeno 2 zone (Collezione e zone)"}
			var tipo5 := "rampa" if not _rampe(desc).is_empty() else ("buca" if not _ha(desc, "buche").is_empty() else colpo)
			m["fasi"] = [{"quando": {"tipo": tipo5}, "volte": 2, "testo": "viaggia: 2 tiri"}]
			m["premio"] = {"punti": 50000, "zona_avanti": true}
		_:
			return {"errore": "modello sconosciuto: " + modello}
	return m

## Problemi delle missioni (per CONTROLLA): pezzo citato che non esiste più, gruppo vuoto, missione mai sbloccabile.
static func controlla(desc: Dictionary) -> Array:
	var out: Array = []
	var ids := {}
	for k in ["bumper", "bersagli", "rampe", "buche", "spinner", "sensori", "elastici", "kickback", "cancelli", "fionde", "muri"]:
		for e in desc.get(k, []):
			if e is Dictionary and e.has("id"):
				ids[str(e["id"])] = true
	var lista: Array = desc.get("missioni", []) if desc.get("missioni") is Array else []
	var mids := {}
	for m in lista:
		mids[str(m.get("id", ""))] = true
	for m in lista:
		if not m is Dictionary or not bool(m.get("attiva", true)):
			continue
		var nome := str(m.get("nome", m.get("id", "")))
		if (m.get("fasi", []) as Array).is_empty():
			out.append("Missione «%s»: non ha fasi, non parte mai." % nome)
		for f in m.get("fasi", []):
			var q: Dictionary = f.get("quando", {})
			if str(q.get("id", "")) != "" and not ids.has(str(q["id"])):
				out.append("Missione «%s»: il pezzo «%s» non esiste più." % [nome, q["id"]])
			for x in f.get("ids", []):
				if not ids.has(str(x)):
					out.append("Missione «%s»: il pezzo «%s» non esiste più." % [nome, x])
		var sb: Dictionary = m.get("sblocco", {}) if m.get("sblocco") is Dictionary else {}
		if str(sb.get("dopo", "")) != "" and not mids.has(str(sb["dopo"])):
			out.append("Missione «%s»: si sblocca dopo una missione che non c'è più." % nome)
		if int(sb.get("completate", 0)) > lista.size() - 1:
			out.append("Missione «%s»: chiede %d missioni completate ma ce ne sono solo %d: non si sblocca mai." % [nome, int(sb["completate"]), lista.size() - 1])
		# v0.18.3: dipende da una missione spenta
		var dopo := str(sb.get("dopo", ""))
		for m2 in lista:
			if m2 is Dictionary and str(m2.get("id", "")) == dopo and dopo != "" and not bool(m2.get("attiva", true)):
				out.append("Missione «%s»: si sblocca dopo «%s», che è spenta: non parte mai." % [nome, m2.get("nome", dopo)])
		# v0.18.3: energia senza un tiro di ricarica che esista sul tavolo
		var en = m.get("energia")
		if en is Dictionary and float(en.get("cala", 4.0)) * float(en.get("luci", 6)) < 10.0:
			out.append("Missione «%s»: l'energia dura meno di 10 s: quasi impossibile." % nome)
	# v0.18.3: CICLI IMPOSSIBILI (A dopo B, B dopo A…): nessuna missione del giro parte mai
	for g in cicli(lista):
		out.append("Missioni in cerchio: %s → di nuovo la prima. Ognuna aspetta l'altra: non parte nessuna." % " → ".join(g.map(func(x): return "«%s»" % _nome_id(lista, x))))
	return out

static func _nome_id(lista: Array, id: String) -> String:
	for m in lista:
		if m is Dictionary and str(m.get("id", "")) == id:
			return str(m.get("nome", id))
	return id

## Giri chiusi nelle dipendenze «si sblocca dopo» (ogni giro una volta, come elenco di id).
static func cicli(lista: Array) -> Array:
	var dopo := {}
	for m in lista:
		if m is Dictionary and m.get("sblocco") is Dictionary and str(m["sblocco"].get("dopo", "")) != "":
			dopo[str(m.get("id", ""))] = str(m["sblocco"]["dopo"])
	var out: Array = []
	var visti := {}
	for inizio in dopo:
		if visti.has(inizio):
			continue
		var strada: Array = []
		var x: String = inizio
		while dopo.has(x) and not strada.has(x) and not visti.has(x):
			strada.append(x)
			x = dopo[x]
		if strada.has(x):
			out.append(strada.slice(strada.find(x)))
		for y in strada:
			visti[y] = true
	return out

## Livelli dello schema: [[id, ...] per colonna]; colonna 0 = missioni che non aspettano un'altra missione.
static func colonne(lista: Array) -> Array:
	var dopo := {}
	for m in lista:
		if m is Dictionary and m.get("sblocco") is Dictionary and str(m["sblocco"].get("dopo", "")) != "":
			dopo[str(m.get("id", ""))] = str(m["sblocco"]["dopo"])
	var prof := {}
	for m in lista:
		if not m is Dictionary:
			continue
		var id := str(m.get("id", ""))
		var d := 0
		var x := id
		var giro := {}
		while dopo.has(x) and not giro.has(x):
			giro[x] = true
			x = dopo[x]
			d += 1
		prof[id] = d if not giro.has(x) else -1          # -1 = in un cerchio
	var out: Array = []
	for id in prof:
		var c: int = prof[id] if prof[id] >= 0 else 99
		while out.size() <= mini(c, 98) and c != 99:
			out.append([])
		if c == 99:
			continue
		out[c].append(id)
	var in_cerchio: Array = prof.keys().filter(func(k): return prof[k] < 0)
	if not in_cerchio.is_empty():
		out.append(in_cerchio)
	return out
