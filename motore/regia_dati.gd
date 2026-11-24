## REGIA A DATI di luci e suoni (Pinball Editor 2D v0.11, 24/11/2026, Fase 6). Tutto scritto nel file del tavolo:
##  - ogni LUCE del piano (inserti) ha "luce_modo" (cosa segue), "luce_rif" (quale missione o pezzo), "luce_parte" /
##    "luce_su" (per le barre di avanzamento);
##  - desc["suoni"]       = {evento: nome del suono del catalogo, "" = nessun suono}
##  - desc["luci_eventi"] = {evento: {"effetto": onda|flash|spazzata|strobo|girandola|nessuno, "colore": nome}}
## Suoni: SOLO quelli del nostro catalogo (generati dal codice o file con licenza già verificata): niente suoni di
class_name RegiaDati

const SUONI := {"": "nessun suono", "bumper": "colpo di bumper", "fionda": "fionda", "bersaglio": "bersaglio",
	"lancio": "lancio", "lock": "aggancio", "passaggio": "passaggio", "spinner": "ticchettio", "rampa": "rampa (salita)",
	"rampa_fine": "rampa (arrivo)", "combo": "combo", "skill": "colpo speciale", "jackpot_spazio": "jackpot",
	"multiball_spazio": "multiball", "missione_inizio": "inizio missione", "missione_completa": "missione completata",
	"missione_fallita": "missione fallita", "pallina_extra": "pallina extra", "avviso": "avviso",
	"corsia_spazio": "corsia", "portale": "portale", "pozzo": "vortice", "magnete": "magnete"}

const EVENTI := {
	"bumper": ["Bumper colpito", "bumper"], "fionda": ["Fionda", "fionda"], "bersaglio": ["Bersaglio", "bersaglio"], "captive": ["Pallina prigioniera (bersaglio in fondo)", "bersaglio"],
	"elastico": ["Paletto di gomma", ""], "spinner": ["Spinner", "spinner"], "rampa_entrata": ["Imbocco della rampa", "rampa"],
	"rampa": ["Rampa completata", "rampa_fine"], "sensore": ["Corsia (sensore)", ""], "buca": ["Buca", ""],
	"kickback": ["Kickback", "lancio"], "cancello": ["Cancelletto", ""], "lancio": ["Lancio", "lancio"],
	"missione_inizio": ["Missione: inizio", "missione_inizio"], "missione_passo": ["Missione: un passo avanti", ""],
	"missione_completa": ["Missione completata", "missione_completa"], "missione_fallita": ["Missione fallita", "missione_fallita"],
	"multiball": ["Multiball", "multiball_spazio"], "pallina_extra": ["Pallina extra", "pallina_extra"],
	"salva_pallina": ["Salva-pallina", "pallina_extra"], "tilt": ["Tilt", "avviso"],
	"missione_scelta": ["Missione: scelta con le palette", "corsia_spazio"], "cattura": ["Cattura (collezione)", "jackpot_spazio"], "evoluzione": ["Evoluzione (collezione)", "multiball_spazio"], "energia": ["Energia ricaricata", "pallina_extra"],
	"collezione_completa": ["Collezione completa", "multiball_spazio"], "zona": ["Cambio di zona (viaggio)", "portale"], "corsie_complete": ["Cambio corsia: tutte accese", "combo"]}

const EFFETTI := {"": "come prima", "nessuno": "nessuno", "onda": "onda che si allarga", "flash": "lampo",
	"spazzata": "spazzata su tutto il tavolo", "strobo": "lampeggio veloce", "girandola": "girandola"}

const COLORI := {"caldo": Color(1.0, 0.85, 0.6), "freddo": Color(0.55, 0.8, 1.0), "rosso": Color(1.0, 0.2, 0.15),
	"verde": Color(0.35, 1.0, 0.45), "viola": Color(0.75, 0.4, 1.0), "oro": Color(1.0, 0.78, 0.2), "bianco": Color(1, 1, 1)}

## Cosa segue una luce del piano. 0 spenta, 1 accesa, 2 lampeggia.
const MODI_LUCE := {"": "solo effetti (nessuna regola)", "accesa": "sempre accesa", "lampeggia": "lampeggia sempre",
	"tiro": "GUIDA AL TIRO: lampeggia se la missione chiede questo pezzo", "missione_in_corso": "missione in corso",
	"missione_fatta": "missione completata", "progresso": "barra: accesa quando la missione arriva a questa parte",
	"missione_pronta": "missione pronta (lampeggia)", "colpito": "pezzo già colpito in questa pallina",
	"giu": "bersaglio abbattuto", "corsia": "corsia accesa (cambio corsia con le palette)",
	"preso": "oggetto della collezione già catturato", "zona": "accesa nella zona numero… (viaggi)", "multiball": "durante il multiball", "salva": "salva-pallina attivo",
	"extra": "pallina extra da giocare", "energia": "energia: accesa se restano almeno N luci (N = «parte»)"}

## Specifica dell'effetto di luce scelta dal tavolo (null = usa quella di base).
## v0.17: l'effetto può essere anche «spettacolo:NOME» (uno spettacolo di luce del tavolo, vedi sotto).
static func effetto_luce(desc: Dictionary, evento: String):
	var le = desc.get("luci_eventi", {})
	if not le is Dictionary or not le.has(evento):
		return null
	var e: Dictionary = le[evento]
	var eff := str(e.get("effetto", ""))
	if eff.begins_with("spettacolo:"):
		return spettacolo(desc, eff.substr(11))
	if eff == "nessuno":
		return []
	var col: Color = COLORI.get(str(e.get("colore", "caldo")), COLORI["caldo"])
	var durate := {"onda": 0.45, "flash": 0.35, "spazzata": 0.9, "strobo": 0.8, "girandola": 1.2}
	if not durate.has(eff):
		return null
	var sp := spec(eff, col, float(durate[eff]), "su")
	if eff == "spazzata":
		sp["grande"] = true
	return [sp]

## Un effetto pronto per la regia (tipo, colore, durata in secondi; verso «su»/«giu» per la spazzata).
static func spec(effetto: String, col: Color, dur: float, verso := "su") -> Dictionary:
	match effetto:
		"onda":
			return {"tipo": "onda", "col": col, "dur": dur, "vel": 420.0, "larg": 30.0, "max": 160.0}
		"onda_grande":
			return {"tipo": "onda", "col": col, "dur": dur, "vel": 900.0, "larg": 70.0}
		"flash":
			return {"tipo": "flash", "col": col, "dur": dur}
		"spazzata":
			return {"tipo": "spazzata", "verso": 1.0 if verso == "giu" else -1.0, "col": col, "dur": dur}
		"strobo":
			return {"tipo": "strobo", "col": col, "dur": dur, "freq": 8.0}
		"lampeggio":
			return {"tipo": "lampeggio", "col": col, "dur": dur, "freq": 2.5}
		"girandola":
			return {"tipo": "girandola", "col": col, "dur": dur, "giri": maxf(1.0, dur * 1.6)}
	return {}

# ================================================================ SPETTACOLI DI LUCE (v0.17, Fase 6)
## Uno spettacolo = una TRACCIA di passi a tempo: [{"dopo": s, "effetto", "colore", "dur": s, "verso"?, "grande"?}].
## Si scrivono in desc["spettacoli"] = {nome: {"passi": [...]}} e si usano: per un evento («spettacolo:NOME»), come
## azione di una missione («spettacolo») e nell'attesa in sala (desc["attesa"]).
## «grande» = abbassa per un attimo le altre luci, così lo spettacolo si legge bene.
const EFFETTI_PASSO := {"onda": "onda dal centro", "onda_grande": "onda su tutto il tavolo", "flash": "lampo",
	"spazzata": "spazzata", "strobo": "lampeggio veloce", "lampeggio": "lampeggio lento", "girandola": "girandola"}

## Spettacoli pronti (fatti da noi): si copiano nel tavolo e poi si cambiano.
const SPETTACOLI_PRONTI := {
	"Arcobaleno": [{"dopo": 0.0, "effetto": "spazzata", "colore": "rosso", "dur": 0.8, "verso": "su"},
		{"dopo": 0.3, "effetto": "spazzata", "colore": "oro", "dur": 0.8, "verso": "su"},
		{"dopo": 0.6, "effetto": "spazzata", "colore": "verde", "dur": 0.8, "verso": "su"},
		{"dopo": 0.9, "effetto": "spazzata", "colore": "freddo", "dur": 0.8, "verso": "su"},
		{"dopo": 1.2, "effetto": "spazzata", "colore": "viola", "dur": 0.8, "verso": "su"}],
	"Festa": [{"dopo": 0.0, "effetto": "flash", "colore": "bianco", "dur": 0.3, "grande": true},
		{"dopo": 0.2, "effetto": "girandola", "colore": "oro", "dur": 1.4},
		{"dopo": 0.9, "effetto": "strobo", "colore": "viola", "dur": 0.8},
		{"dopo": 1.6, "effetto": "onda_grande", "colore": "oro", "dur": 0.9}],
	"Allarme": [{"dopo": 0.0, "effetto": "lampeggio", "colore": "rosso", "dur": 1.6, "grande": true},
		{"dopo": 0.4, "effetto": "spazzata", "colore": "rosso", "dur": 0.7, "verso": "giu"},
		{"dopo": 1.1, "effetto": "spazzata", "colore": "rosso", "dur": 0.7, "verso": "su"}],
	"Respiro": [{"dopo": 0.0, "effetto": "onda_grande", "colore": "freddo", "dur": 1.8},
		{"dopo": 1.6, "effetto": "onda_grande", "colore": "caldo", "dur": 1.8}],
}

## Durata di uno spettacolo (fine dell'ultimo passo), in secondi.
static func durata_spettacolo(passi: Array) -> float:
	var d := 0.0
	for p in passi:
		d = maxf(d, float(p.get("dopo", 0.0)) + float(p.get("dur", 0.5)))
	return d

## Passi di uno spettacolo del tavolo (o di uno pronto, se il tavolo non ne ha uno con quel nome).
static func passi_spettacolo(desc: Dictionary, nome: String) -> Array:
	var sp = desc.get("spettacoli", {})
	if sp is Dictionary and sp.has(nome) and sp[nome] is Dictionary:
		return sp[nome].get("passi", [])
	return SPETTACOLI_PRONTI.get(nome, [])

## Effetti pronti per la regia di uno spettacolo ([] se non esiste).
static func spettacolo(desc: Dictionary, nome: String) -> Array:
	var out: Array = []
	for p in passi_spettacolo(desc, nome):
		var col: Color = COLORI.get(str(p.get("colore", "caldo")), COLORI["caldo"])
		var e := spec(str(p.get("effetto", "onda")), col, clampf(float(p.get("dur", 0.6)), 0.05, 10.0), str(p.get("verso", "su")))
		if e.is_empty():
			continue
		e["dopo"] = clampf(float(p.get("dopo", 0.0)), 0.0, 30.0)
		if bool(p.get("grande", false)):
			e["grande"] = true
		out.append(e)
	return out

## Attesa in sala (fuori partita): {"spettacolo": nome ("" = quello di base), "pausa": s tra una ripetizione e
## l'altra, "scritta": testo che si alterna a «premi START» sul tabellone}.
static func attesa(desc: Dictionary) -> Dictionary:
	var a = desc.get("attesa", {})
	return a if a is Dictionary else {}

## Suono scelto dal tavolo per un evento: null = quello di base; "" = nessun suono.
static func suono(desc: Dictionary, evento: String):
	var s = desc.get("suoni", {})
	if s is Dictionary and s.has(evento):
		return str(s[evento])
	return null

## Stato di una luce del piano secondo la sua regola (r = regole della partita con le missioni).
static func stato_luce(info: Dictionary, r) -> int:
	var modo := str(info.get("luce_modo", ""))
	var rif := str(info.get("luce_rif", ""))
	var m: Mattoncini = r.get("missioni")
	match modo:
		"accesa":
			return 1
		"lampeggia":
			return 2
		"multiball":
			return 1 if r.multiball else 0
		"salva":
			return 2 if r.salva_attivo() else 0
		"extra":
			return 1 if r.extra_palline > 0 else 0
		"giu":
			return 1 if r.tavolo != null and bool(r.tavolo.bersagli_giu.get(rif, false)) else 0
		"corsia":
			return 1 if r.has_method("corsia_accesa") and r.corsia_accesa(rif) else 0
		"colpito":
			var c = r.get("colpiti")
			return 1 if c is Dictionary and c.has(rif) else 0
	if m == null:
		return 0
	match modo:
		"tiro":
			return 2 if m.chiede_pezzo(rif) else 0
		"missione_in_corso":
			return 2 if m.corrente >= 0 and (rif == "" or str(m.missioni[m.corrente].get("id", "")) == rif) else 0
		"missione_fatta":
			return 1 if m.completate.has(rif) else 0
		"missione_pronta":
			return 2 if m.pronta >= 0 else 0
		"preso":
			return 1 if m.presi.has(rif) else 0
		"zona":
			return 1 if m.zona == int(info.get("luce_parte", 1)) - 1 else 0
		"energia":
			return 1 if m.corrente >= 0 and m.missioni[m.corrente].get("energia") is Dictionary and m.energia >= float(info.get("luce_parte", 1)) else 0
		"progresso":
			var f := m.frazione()
			var k := float(info.get("luce_parte", 1))
			var n := maxf(1.0, float(info.get("luce_su", 3)))
			return 1 if m.corrente >= 0 and f >= k / n - 0.001 else 0
	return 0
