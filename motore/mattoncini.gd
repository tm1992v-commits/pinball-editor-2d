## niente linguaggio di regole libero»). Interprete SENZA fisica: riceve gli eventi del tavolo (colpi, rampe, buche…)
## e il tempo, e fa avanzare le missioni scritte come DATI nel file del tavolo (desc["missioni"]).
##
## Una MISSIONE = nome + FASI in fila + PREMIO finale (+ cosa succede all'inizio, tempo massimo, sblocco).
## Una FASE = QUANDO (tipo di evento, pezzo o gruppo) + COME si conta (modo) + quante volte + tempo + premio della fase.
##   modi: "conta"     = N eventi che corrispondono;
##         "tutti"     = ogni pezzo indicato (ids, o tutti quelli del gruppo/tipo) almeno una volta;
##         "sequenza"  = i pezzi in "ids" nell'ordine giusto (sbagliare l'ordine fa ripartire);
##         "combo"     = N eventi di fila, ognuno entro "finestra" secondi dal precedente;
##         "hurry_up"  = un evento solo; il premio parte da premio.punti e CALA ogni secondo ("cala") finché lo prendi.
##         "stato"     = (v0.18.3) TIENI VIVO: il primo colpo accende, poi un colpo almeno ogni "finestra" secondi per
##                       "durata" secondi; se passa troppo tempo si spegne e si ricomincia.
## (v0.18.3) ENERGIA della missione: m["energia"] = {"luci", "cala" (s per luce), "ricarica" (QUANDO)}: le luci calano,
## il tiro di ricarica ne riaccende una; a zero la missione è fallita.
## Il motore e l'editor non cambiano per una regola nuova: si aggiunge un modo, un'azione o un premio qui (registro).
class_name Mattoncini
extends RefCounted

## Callback verso le regole della partita (RegoleBase): punti, messaggi, effetti, premi.
var regole: Node
var missioni: Array = []
var avvio: Dictionary = {"tipo": "subito"}      # come parte la missione: subito, oppure con un tiro {"tipo", "id"}

# stato della partita
var completate := {}           # id missione -> volte completata
var corrente := -1             # indice della missione in corso (-1 = nessuna)
var fase := 0
var conta := 0
var visti := {}                # modo "tutti": pezzi già colpiti
var passo_seq := 0             # modo "sequenza"
var ultimo_t := -99.0          # modo "combo"
var inizio_fase := 0.0
var inizio_missione := 0.0
var pronta := -1               # missione pronta a partire (avvio con un tiro)
var pausa_fino := 0.0
var hurry_valore := 0.0
var stato_da := -1.0           # v0.18.3 modo "stato": quando si è acceso (-1 = spento)
var energia := 0.0             # v0.18.3 energia della missione in corso (luci accese)
var energia_t := 0.0
# v0.13 MODALITÀ con priorità: una missione con "priorita" > 0 parte da sola appena è sbloccata, anche se un'altra
# missione è in corso: quella viene messa IN PAUSA e riprende da dove era quando la modalità finisce.
var sospese: Array = []        # stati delle missioni interrotte (la più recente in fondo)
var normali_fatte := 0         # missioni normali completate in tutto (anche ripetute), per sbloccare le modalità
var base_modalita := {}        # id modalità -> normali_fatte quando è finita l'ultima volta
# v0.14 COLLEZIONE (catture) e ZONE (viaggi): desc["collezione"] = {"nome", "oggetti": [{id, nome, rarita 1-3, punti}]},
# desc["zone"] = [{"nome"}, …]. Premi "cattura" e "zona_avanti"; sblocco "collezione" (quanti oggetti presi);
# missione "zone" = in quali zone si gioca (indici; vuoto = tutte).
var presi := {}                # id oggetto -> quante volte catturato
var zona := 0

const EVENTI := ["bumper", "bersaglio", "fila", "corsie", "lama", "rampa", "rampa_entrata", "spinner", "sensore", "buca", "fionda",
	"elastico", "kickback", "cancello", "portale", "prigione", "captive", "bersaglio_mobile", "passaggio_entrata", "qualsiasi"]
const MODI := ["conta", "tutti", "sequenza", "combo", "hurry_up", "stato"]

func _init(desc: Dictionary, r: Node) -> void:
	regole = r
	missioni = desc.get("missioni", []) if desc.get("missioni") is Array else []
	if desc.get("missioni_avvio") is Dictionary:
		avvio = desc["missioni_avvio"]
	_desc = desc

var _desc: Dictionary

func attive() -> Array:
	return missioni.filter(func(m): return m is Dictionary and bool(m.get("attiva", true)))

# ---------------------------------------------------------------- partita e palline
func nuova_partita() -> void:
	completate = {}
	corrente = -1
	pronta = -1
	sospese = []
	normali_fatte = 0
	base_modalita = {}
	presi = {}
	zona = 0

func inizio_pallina(t: float) -> void:
	# una missione interrotta dalla pallina persa riparte da capo quando torna il suo turno
	corrente = -1
	pronta = -1
	sospese = []
	pausa_fino = t + 1.5

## Da chiamare a ogni fotogramma con il tempo della partita: tempo scaduto, hurry-up, avvio della prossima.
func tick(t: float) -> void:
	_controlla_modalita(t)
	if corrente >= 0:
		var m: Dictionary = missioni[corrente]
		var f: Dictionary = _fase(m)
		if float(m.get("tempo", 0.0)) > 0.0 and t - inizio_missione > float(m["tempo"]):
			_fallita(t, "tempo scaduto")
			return
		if float(f.get("entro", 0.0)) > 0.0 and t - inizio_fase > float(f["entro"]):
			_fallita(t, "tempo della fase scaduto")
			return
		if str(f.get("modo", "conta")) == "hurry_up":
			var pr: Dictionary = f.get("premio", {})
			hurry_valore = maxf(float(pr.get("minimo", 0.0)), float(pr.get("punti", 0)) - float(f.get("cala", 1000.0)) * (t - inizio_fase))
		if str(f.get("modo", "conta")) == "stato" and stato_da >= 0.0:
			if t - ultimo_t > float(f.get("finestra", 4.0)):
				stato_da = -1.0
				conta = 0
				regole.messaggio.emit(Testi.t("SPENTO!"), Testi.t("ricomincia"), 1.5)
			else:
				conta = int(t - stato_da)
				if t - stato_da >= float(f.get("durata", 15.0)):
					_fase_fatta(t, Vector2.ZERO)
					return
		var en = m.get("energia")
		if en is Dictionary and corrente >= 0:
			if t - energia_t >= maxf(0.5, float(en.get("cala", 4.0))):
				energia -= 1.0
				energia_t = t
				if energia <= 0.0:
					_fallita(t, "energia finita")
					return
		return
	if t < pausa_fino or pronta >= 0:
		return
	var i := prossima()
	if i < 0:
		return
	if str(avvio.get("tipo", "subito")) == "subito":
		_avvia(i, t)
	else:
		pronta = i
		regole.messaggio.emit(Testi.t("MISSIONE PRONTA"), "%s: %s" % [nome_di(missioni[i]), _testo_avvio()], 2.5)

static func priorita(m) -> int:
	return int(m.get("priorita", 0)) if m is Dictionary else 0

## Una modalità sbloccata parte subito se la sua priorità supera quella di ciò che è in corso (che va in pausa).
func _controlla_modalita(t: float) -> void:
	if t < pausa_fino:
		return
	var p_ora := priorita(missioni[corrente]) if corrente >= 0 else 0
	for i in missioni.size():
		var m = missioni[i]
		if priorita(m) <= p_ora or not m is Dictionary or not bool(m.get("attiva", true)) or (m.get("fasi", []) as Array).is_empty():
			continue
		var sb: Dictionary = m.get("sblocco", {}) if m.get("sblocco") is Dictionary else {}
		var mid := str(m.get("id", i))
		if str(sb.get("dopo", "")) != "" and not completate.has(str(sb["dopo"])):
			continue
		var serve := maxi(1, int(sb.get("completate", 0))) if str(sb.get("dopo", "")) == "" else 0
		if normali_fatte - int(base_modalita.get(mid, 0)) < serve:
			continue
		if completate.has(mid) and not bool(m.get("ripeti", true)):
			continue
		if not _zona_e_collezione_ok(m):
			continue
		if str(sb.get("dopo", "")) != "" and base_modalita.has(mid):
			continue                    # sbloccata da una missione: una volta sola
		if corrente >= 0:
			sospese.append({"i": corrente, "fase": fase, "conta": conta, "visti": visti.duplicate(), "passo": passo_seq,
				"dt_m": t - inizio_missione, "dt_f": t - inizio_fase, "hurry": hurry_valore, "energia": energia})
			regole.messaggio.emit(Testi.t("IN PAUSA"), str(missioni[corrente].get("nome", "")).to_upper(), 1.5)
		pronta = -1
		base_modalita[mid] = normali_fatte
		_avvia(i, t)
		regole.effetto.emit("modalita_inizio", Vector2.ZERO)
		return

## Finita una missione: se ce n'era una in pausa, riprende da dove era (il tempo della pausa non conta).
func _riprendi(t: float) -> void:
	if sospese.is_empty():
		return
	var st: Dictionary = sospese.pop_back()
	corrente = int(st["i"])
	fase = int(st["fase"])
	conta = int(st["conta"])
	visti = st["visti"]
	passo_seq = int(st["passo"])
	hurry_valore = float(st["hurry"])
	energia = float(st.get("energia", energia))
	energia_t = t
	stato_da = -1.0
	inizio_missione = t - float(st["dt_m"])
	inizio_fase = t - float(st["dt_f"])
	regole.messaggio.emit(Testi.t("RIPRENDE") + ": " + nome_di(missioni[corrente]).to_upper(), testo_fase(), 2.0)

## v0.12: missioni che si possono proporre adesso (non completate prima; poi le ripetibili).
func proponibili() -> Array:
	var out: Array = []
	var i0 := prossima()
	if i0 < 0:
		return out
	for i in missioni.size():
		if _giocabile(i) and not completate.has(str(missioni[i].get("id", i))):
			out.append(i)
	if out.is_empty():
		for i in missioni.size():
			if _giocabile(i) and bool(missioni[i].get("ripeti", true)):
				out.append(i)
	return out

## SCELTA DELLA MISSIONE con le palette (avvio con un tiro + "scelta"): passa alla missione dopo o prima.
func cambia_scelta(verso: int) -> void:
	if pronta < 0 or not bool(avvio.get("scelta", false)):
		return
	var l := proponibili()
	if l.size() < 2:
		return
	var k := l.find(pronta)
	pronta = l[(k + verso + l.size()) % l.size()]
	regole.messaggio.emit(Testi.t("SCEGLI") + ": " + nome_di(missioni[pronta]).to_upper(), descrivi_fase((missioni[pronta].get("fasi", [{}]) as Array)[0]), 1.5)
	regole.effetto.emit("missione_scelta", Vector2.ZERO)

func _giocabile(i: int) -> bool:
	var m = missioni[i]
	if not m is Dictionary or not bool(m.get("attiva", true)) or (m.get("fasi", []) as Array).is_empty() or priorita(m) > 0:
		return false
	var sb: Dictionary = m.get("sblocco", {}) if m.get("sblocco") is Dictionary else {}
	if str(sb.get("dopo", "")) != "" and not completate.has(str(sb["dopo"])):
		return false
	return completate.size() >= int(sb.get("completate", 0)) and _zona_e_collezione_ok(m)

## v0.14: la missione si gioca solo nelle sue zone e dopo aver catturato abbastanza oggetti.
func _zona_e_collezione_ok(m: Dictionary) -> bool:
	var zz: Array = m.get("zone", [])
	if not zz.is_empty() and not zz.map(func(x): return int(x)).has(zona):
		return false
	var sb: Dictionary = m.get("sblocco", {}) if m.get("sblocco") is Dictionary else {}
	return presi.size() >= int(sb.get("collezione", 0))

## Indice della prossima missione giocabile (in ordine; le completate si ripetono solo se "ripeti").
func prossima() -> int:
	var fatte_tot := 0
	for k in completate:
		fatte_tot += 1
	var candidate: Array = []
	for i in missioni.size():
		var m = missioni[i]
		if not m is Dictionary or not bool(m.get("attiva", true)) or (m.get("fasi", []) as Array).is_empty() or priorita(m) > 0:
			continue
		var sb: Dictionary = m.get("sblocco", {}) if m.get("sblocco") is Dictionary else {}
		if str(sb.get("dopo", "")) != "" and not completate.has(str(sb["dopo"])):
			continue
		if fatte_tot < int(sb.get("completate", 0)) or not _zona_e_collezione_ok(m):
			continue
		candidate.append(i)
	for i in candidate:
		if not completate.has(str(missioni[i].get("id", i))):
			return i
	for i in candidate:
		if bool(missioni[i].get("ripeti", true)):
			return i
	return -1

# ---------------------------------------------------------------- eventi
func evento(tipo: String, id: String, pos: Vector2, t: float) -> void:
	if corrente < 0:
		if pronta >= 0 and _corrisponde(avvio, tipo, id):
			var i := pronta
			pronta = -1
			_avvia(i, t)
		return
	var m: Dictionary = missioni[corrente]
	var f: Dictionary = _fase(m)
	var q: Dictionary = f.get("quando", {})
	var modo := str(f.get("modo", "conta"))
	# v0.18.3: ricarica dell'energia
	var en = m.get("energia")
	if en is Dictionary and en.get("ricarica") is Dictionary and _corrisponde(en["ricarica"], tipo, id):
		var mx := float(maxi(1, int(en.get("luci", 6))))
		if energia < mx:
			energia = minf(mx, energia + 1.0)
			energia_t = t
			regole.effetto.emit("energia", pos)
	match modo:
		"stato":
			if not _corrisponde(q, tipo, id):
				return
			if stato_da < 0.0 or t - ultimo_t > float(f.get("finestra", 4.0)):
				stato_da = t
				regole.messaggio.emit(Testi.t("TIENI!"), Testi.t("per %d s") % int(f.get("durata", 15.0)), 1.5)
			ultimo_t = t
			regole.effetto.emit("missione_passo", pos)
		"sequenza":
			var ids: Array = f.get("ids", [])
			if ids.is_empty() or not _corrisponde({"tipo": q.get("tipo", "qualsiasi")}, tipo, id):
				return
			if id == str(ids[passo_seq]):
				passo_seq += 1
				conta = passo_seq
				if passo_seq >= ids.size():
					_fase_fatta(t, pos)
				else:
					regole.effetto.emit("missione_passo", pos)
			elif id in ids.map(func(x): return str(x)):
				passo_seq = 1 if id == str(ids[0]) else 0
				conta = passo_seq
		"tutti":
			if not _corrisponde(q, tipo, id):
				return
			var serve := _pezzi_da_colpire(f)
			if not serve.is_empty() and not id in serve:
				return
			visti[id] = true
			conta = visti.size()
			regole.effetto.emit("missione_passo", pos)
			if conta >= maxi(1, serve.size() if not serve.is_empty() else int(f.get("volte", 1))):
				_fase_fatta(t, pos)
		"combo":
			if not _corrisponde(q, tipo, id):
				return
			conta = conta + 1 if t - ultimo_t <= float(f.get("finestra", 3.0)) else 1
			ultimo_t = t
			if conta >= int(f.get("volte", 2)):
				_fase_fatta(t, pos)
			elif conta > 1:
				regole.messaggio.emit(Testi.t("COMBO ×%d") % conta, "", 1.0)
		"hurry_up":
			if _corrisponde(q, tipo, id):
				conta = 1
				_fase_fatta(t, pos)
		_:
			if not _corrisponde(q, tipo, id):
				return
			conta += 1
			regole.effetto.emit("missione_passo", pos)
			if conta >= int(f.get("volte", 1)):
				_fase_fatta(t, pos)

## L'evento corrisponde al QUANDO? tipo ("qualsiasi" = ogni colpo), id facoltativo, gruppo facoltativo.
func _corrisponde(q: Dictionary, tipo: String, id: String) -> bool:
	var qt := str(q.get("tipo", "qualsiasi"))
	if qt != "qualsiasi" and qt != tipo:
		return false
	if qt == "qualsiasi" and tipo in ["lancio", "porta", "deviatore", "ricaduta", "rampa_fallita", "portale_uscita", "passaggio_uscita"]:
		return false
	if str(q.get("id", "")) != "" and str(q["id"]) != id:
		return false
	if str(q.get("gruppo", "")) != "" and _gruppo_di(tipo, id) != str(q["gruppo"]) and not (tipo == "fila" and id == str(q["gruppo"])):
		return false
	return true

func _gruppo_di(tipo: String, id: String) -> String:
	var lista: String = {"bersaglio": "bersagli", "bumper": "bumper", "spinner": "spinner", "sensore": "sensori", "buca": "buche",
		"elastico": "elastici", "rampa": "rampe", "rampa_entrata": "rampe"}.get(tipo, "")
	for e in _desc.get(lista, []):
		if e is Dictionary and str(e.get("id", "")) == id:
			return str(e.get("gruppo", ""))
	return ""

## Modo "tutti": quali pezzi servono (ids scritti, oppure tutti quelli del gruppo o del tipo).
func _pezzi_da_colpire(f: Dictionary) -> Array:
	var ids: Array = f.get("ids", [])
	if not ids.is_empty():
		return ids.map(func(x): return str(x))
	var q: Dictionary = f.get("quando", {})
	var lista: String = {"bersaglio": "bersagli", "bumper": "bumper", "spinner": "spinner", "sensore": "sensori", "buca": "buche",
		"elastico": "elastici", "rampa": "rampe"}.get(str(q.get("tipo", "")), "")
	var out: Array = []
	for e in _desc.get(lista, []):
		if e is Dictionary and e.has("id") and not e.has("da_nastro") and (str(q.get("gruppo", "")) == "" or str(e.get("gruppo", "")) == str(q["gruppo"])):
			out.append(str(e["id"]))
	return out

# ---------------------------------------------------------------- avanzamento
func _fase(m: Dictionary) -> Dictionary:
	var fasi: Array = m.get("fasi", [])
	return fasi[clampi(fase, 0, fasi.size() - 1)] if not fasi.is_empty() else {}

func _avvia(i: int, t: float) -> void:
	corrente = i
	fase = 0
	inizio_missione = t
	var m: Dictionary = missioni[i]
	if m.get("energia") is Dictionary:
		energia = float(maxi(1, int(m["energia"].get("luci", 6))))
		energia_t = t
	var ini: Dictionary = m.get("inizio", {}) if m.get("inizio") is Dictionary else {}
	_esegui(ini, t, Vector2.ZERO)
	_inizia_fase(t)
	regole.messaggio.emit(nome_di(m).to_upper(), testo_fase(), 3.0)
	regole.effetto.emit("missione_inizio", Vector2.ZERO)

func _inizia_fase(t: float) -> void:
	conta = 0
	visti = {}
	passo_seq = 0
	ultimo_t = -99.0
	stato_da = -1.0
	inizio_fase = t
	var f := _fase(missioni[corrente])
	if str(f.get("modo", "")) == "hurry_up":
		hurry_valore = float(f.get("premio", {}).get("punti", 0))
	var fai = f.get("fai", {})
	if fai is Dictionary:
		_esegui(fai, t, Vector2.ZERO)

func _fase_fatta(t: float, pos: Vector2) -> void:
	var m: Dictionary = missioni[corrente]
	var f := _fase(m)
	var pr: Dictionary = f.get("premio", {}) if f.get("premio") is Dictionary else {}
	if str(f.get("modo", "")) == "hurry_up":
		pr = pr.duplicate()
		pr["punti"] = int(hurry_valore)
	_premia(pr, pos, "")
	fase += 1
	if fase >= (m.get("fasi", []) as Array).size():
		var mid := str(m.get("id", corrente))
		completate[mid] = int(completate.get(mid, 0)) + 1
		if priorita(m) == 0:
			normali_fatte += 1
		else:
			base_modalita[mid] = normali_fatte
		corrente = -1
		pausa_fino = t + 2.5
		_premia(m.get("premio", {}) if m.get("premio") is Dictionary else {}, pos, nome_di(m).to_upper() + " " + Testi.t("COMPLETATA"))
		regole.effetto.emit("missione_completa", pos)
		_riprendi(t)
	else:
		_inizia_fase(t)
		regole.messaggio.emit(Testi.t("FASE %d") % (fase + 1), testo_fase(), 2.0)
		regole.effetto.emit("missione_passo", pos)

func _fallita(t: float, perche: String) -> void:
	var m: Dictionary = missioni[corrente]
	corrente = -1
	pausa_fino = t + 3.0
	if priorita(m) > 0:
		base_modalita[str(m.get("id", ""))] = normali_fatte
	regole.messaggio.emit(nome_di(m).to_upper() + " " + Testi.t("FALLITA"), Testi.t(perche), 2.5)
	regole.effetto.emit("missione_fallita", Vector2.ZERO)
	_riprendi(t)

## PREMI (registro): punti, pallina extra, bonus ×, salva-pallina, multiball, punti doppi per N secondi, rialza un gruppo.
func _premia(pr: Dictionary, pos: Vector2, titolo: String) -> void:
	var testo: Array = []
	if int(pr.get("punti", 0)) > 0:
		regole.aggiungi_punti(int(pr["punti"]) * regole.punti_x)
		testo.append("+" + RegoleBase.formatta(int(pr["punti"]) * regole.punti_x))
	if int(pr.get("bonus_x", 0)) > 0:
		regole.moltiplicatore += int(pr["bonus_x"])
		testo.append("bonus ×%d" % regole.moltiplicatore)
	if titolo != "" and not testo.is_empty():
		regole.messaggio.emit(titolo, "  ".join(testo), 3.0)
	elif titolo != "":
		regole.messaggio.emit(titolo, "", 3.0)
	_esegui(pr, regole.t, pos)
	if bool(pr.get("pallina_extra", false)):
		regole.premia_extra(pos, titolo.to_lower())
	if bool(pr.get("cattura", false)):
		cattura(pos)
	if bool(pr.get("zona_avanti", false)):
		cambia_zona(zona + 1)

## CATTURA: un oggetto della collezione a caso, i rari escono meno (comune 6, raro 3, leggendario 1); prima quelli
## non ancora presi. Collezione completa = gran premio.
## v0.17.2 EVOLUZIONI: un oggetto con "evolve_in" (id di un altro oggetto) e "evolve_dopo" (N) dopo N catture si
## EVOLVE: l'oggetto di arrivo si ottiene così e solo così (non esce mai a caso). Per completare la collezione bisogna
## far evolvere.
func cattura(pos: Vector2) -> void:
	var col: Dictionary = _desc.get("collezione", {}) if _desc.get("collezione") is Dictionary else {}
	var ogg: Array = col.get("oggetti", [])
	if ogg.is_empty():
		return
	var solo_evo := {}
	for o in ogg:
		if str(o.get("evolve_in", "")) != "":
			solo_evo[str(o["evolve_in"])] = true
	var catturabili: Array = ogg.filter(func(o): return not solo_evo.has(str(o.get("id", ""))))
	if catturabili.is_empty():
		catturabili = ogg
	var liberi: Array = catturabili.filter(func(o): return not presi.has(str(o.get("id", ""))))
	var tra: Array = liberi if not liberi.is_empty() else catturabili
	var pesi := {1: 6.0, 2: 3.0, 3: 1.0}
	var tot := 0.0
	for o in tra:
		tot += float(pesi.get(int(o.get("rarita", 1)), 6.0))
	var x := randf() * tot
	var scelto: Dictionary = tra[0]
	for o in tra:
		x -= float(pesi.get(int(o.get("rarita", 1)), 6.0))
		if x <= 0.0:
			scelto = o
			break
	var oid := str(scelto.get("id", ""))
	presi[oid] = int(presi.get(oid, 0)) + 1
	regole.aggiungi_punti(int(scelto.get("punti", 10000)) * regole.punti_x)
	var rar: String = [Testi.t("comune"), Testi.t("raro"), Testi.t("leggendario")][clampi(int(scelto.get("rarita", 1)) - 1, 0, 2)]
	regole.messaggio.emit(Testi.t("CATTURATO") + ": " + str(scelto.get("nome", oid)).to_upper(), "%s · %d/%d" % [rar, presi.size(), ogg.size()], 2.5)
	regole.effetto.emit("cattura", pos)
	var nuovo := int(presi[oid]) == 1
	# evoluzione
	var dest := str(scelto.get("evolve_in", ""))
	if dest != "" and not presi.has(dest) and int(presi[oid]) >= maxi(1, int(scelto.get("evolve_dopo", 3))):
		for o in ogg:
			if str(o.get("id", "")) == dest:
				presi[dest] = 1
				nuovo = true
				regole.aggiungi_punti(int(o.get("punti", 10000)) * 2 * regole.punti_x)
				regole.messaggio.emit(Testi.t("EVOLUZIONE!"), "%s → %s · %d/%d" % [str(scelto.get("nome", oid)).to_upper(), str(o.get("nome", dest)).to_upper(), presi.size(), ogg.size()], 3.0)
				regole.effetto.emit("evoluzione", pos)
				break
	if presi.size() == ogg.size() and nuovo:
		regole.aggiungi_punti(int(col.get("premio_completa", 1000000)) * regole.punti_x)
		regole.messaggio.emit(Testi.t("COLLEZIONE COMPLETA!"), "+" + RegoleBase.formatta(int(col.get("premio_completa", 1000000)) * regole.punti_x), 3.0)
		regole.effetto.emit("collezione_completa", pos)

## VIAGGIO: si passa a un'altra zona (dopo l'ultima si ricomincia dalla prima).
func cambia_zona(n: int) -> void:
	var zz: Array = _desc.get("zone", []) if _desc.get("zone") is Array else []
	if zz.is_empty():
		return
	zona = posmod(n, zz.size())
	regole.messaggio.emit(Testi.t("ZONA") + ": " + nome_zona().to_upper(), "", 2.5)
	regole.effetto.emit("zona", Vector2.ZERO)
	pronta = -1                    # le missioni della zona nuova

func nome_zona() -> String:
	var zz: Array = _desc.get("zone", []) if _desc.get("zone") is Array else []
	if zz.is_empty():
		return ""
	var z = zz[clampi(zona, 0, zz.size() - 1)]
	return str(z.get("nome_en" if Testi.lingua == "en" and str(z.get("nome_en", "")) != "" else "nome", "")) if z is Dictionary else str(z)

## AZIONI (registro), usate sia all'inizio («inizio», «fai») sia nei premi.
func _esegui(a: Dictionary, t: float, _pos: Vector2) -> void:
	if float(a.get("salva_pallina", 0.0)) > 0.0:
		regole.salva_fino = maxf(regole.salva_fino, t + float(a["salva_pallina"]))
		regole.effetto.emit("salva_pallina", Vector2.ZERO)
	if int(a.get("multiball", 0)) > 0 and regole.tavolo != null:
		regole.avvia_multiball(int(a["multiball"]))
	if int(a.get("punti_x", 0)) > 1:
		regole.punti_x = int(a["punti_x"])
	if str(a.get("rialza", "")) != "" and regole.tavolo != null and regole.tavolo.has_method("rialza"):
		regole.tavolo.rialza(str(a["rialza"]))
	# v0.15: porte e deviatori sul piano comandati dalle missioni
	if regole.tavolo != null:
		if str(a.get("apri_porta", "")) != "" and regole.tavolo.porte_aperte.has(str(a["apri_porta"])):
			regole.tavolo.apri_porta(str(a["apri_porta"]), true)
		if str(a.get("chiudi_porta", "")) != "" and regole.tavolo.porte_aperte.has(str(a["chiudi_porta"])):
			regole.tavolo.apri_porta(str(a["chiudi_porta"]), false)
		if str(a.get("lama", "")) != "" and regole.tavolo.has_method("muovi_lama"):
			regole.tavolo.muovi_lama(str(a["lama"]), str(a.get("lama_verso", "alterna")))
	# v0.17: spettacolo di luce del tavolo
	if str(a.get("spettacolo", "")) != "":
		regole.effetto.emit("spettacolo:" + str(a["spettacolo"]), Vector2.ZERO)
	if str(a.get("messaggio", "")) != "":
		regole.messaggio.emit(str(a["messaggio"]), "", 2.0)

# ---------------------------------------------------------------- per le luci (v0.11)
## La missione chiede ADESSO questo pezzo? (guida al tiro: la luce vicina lampeggia)
func chiede_pezzo(id: String) -> bool:
	if id == "":
		return false
	if corrente < 0:
		return pronta >= 0 and str(avvio.get("id", "")) == id
	var f := _fase(missioni[corrente])
	var q: Dictionary = f.get("quando", {})
	match str(f.get("modo", "conta")):
		"sequenza":
			var ids: Array = f.get("ids", [])
			return passo_seq < ids.size() and str(ids[passo_seq]) == id
		"tutti":
			var serve := _pezzi_da_colpire(f)
			return id in serve and not visti.has(id)
	if str(q.get("id", "")) != "":
		return str(q["id"]) == id
	var tipo := str(q.get("tipo", "qualsiasi"))
	if tipo == "fila":
		return _gruppo_di("bersaglio", id) != "" and (str(q.get("gruppo", "")) == "" or _gruppo_di("bersaglio", id) == str(q["gruppo"]))
	if tipo == "qualsiasi":
		return true
	var lista: String = {"bersaglio": "bersagli", "bumper": "bumper", "spinner": "spinner", "sensore": "sensori", "buca": "buche",
		"elastico": "elastici", "rampa": "rampe", "rampa_entrata": "rampe", "kickback": "kickback", "cancello": "cancelli"}.get(tipo, "")
	for e in _desc.get(lista, []):
		if e is Dictionary and str(e.get("id", "")) == id:
			return str(q.get("gruppo", "")) == "" or str(e.get("gruppo", "")) == str(q["gruppo"])
	return false

## Avanzamento della missione in corso, da 0 a 1 (fasi già fatte + parte della fase attuale).
func frazione() -> float:
	if corrente < 0:
		return 0.0
	var m: Dictionary = missioni[corrente]
	var n := maxi(1, (m.get("fasi", []) as Array).size())
	var f := _fase(m)
	var tot := float(maxi(1, int(f.get("volte", 1))))
	match str(f.get("modo", "conta")):
		"sequenza":
			tot = float(maxi(1, (f.get("ids", []) as Array).size()))
		"tutti":
			var serve := _pezzi_da_colpire(f)
			tot = float(maxi(1, serve.size() if not serve.is_empty() else int(f.get("volte", 1))))
		"hurry_up":
			tot = 1.0
		"stato":
			tot = maxf(1.0, float(f.get("durata", 15.0)))
	return (float(fase) + clampf(float(conta) / tot, 0.0, 1.0)) / float(n)

# ---------------------------------------------------------------- testi per il tabellone
func testo_fase() -> String:
	if corrente < 0:
		return ""
	var f := _fase(missioni[corrente])
	var s := str(f.get("testo_en" if Testi.lingua == "en" else "testo", ""))
	return s if s != "" else descrivi_fase(f)

## Nome della missione nella lingua del tavolo (nome_en se c'è).
static func nome_di(m) -> String:
	if not m is Dictionary:
		return ""
	if Testi.lingua == "en" and str(m.get("nome_en", "")) != "":
		return str(m["nome_en"])
	return str(m.get("nome", Testi.t("MISSIONE")))

func riga() -> String:
	if corrente >= 0:
		var m: Dictionary = missioni[corrente]
		var f := _fase(m)
		var n_fasi := (m.get("fasi", []) as Array).size()
		var tot := int(f.get("volte", 1))
		match str(f.get("modo", "conta")):
			"sequenza":
				tot = (f.get("ids", []) as Array).size()
			"tutti":
				var serve := _pezzi_da_colpire(f)
				tot = serve.size() if not serve.is_empty() else tot
			"hurry_up":
				return "%s  HURRY-UP %s" % [nome_di(m).to_upper(), RegoleBase.formatta(int(hurry_valore))]
			"stato":
				tot = int(f.get("durata", 15.0))
		var en_t := ("  ⚡%d/%d" % [int(energia), int(m["energia"].get("luci", 6))]) if m.get("energia") is Dictionary else ""
		return "%s%s  %d/%d%s%s" % [nome_di(m).to_upper(), ("  %s %d/%d" % [Testi.t("fase"), fase + 1, n_fasi]) if n_fasi > 1 else "", conta, tot, " s" if str(f.get("modo", "")) == "stato" else "", en_t]
	if pronta >= 0:
		return "%s: %s" % [Testi.t("PRONTA"), nome_di(missioni[pronta]).to_upper()]
	var zt := (nome_zona().to_upper() + "   ") if nome_zona() != "" else ""
	return zt + ("%s: %d/%d" % [Testi.t("MISSIONI"), completate.size(), attive().size()] if not attive().is_empty() else "")

func obiettivo(t: float) -> String:
	if corrente >= 0:
		var m: Dictionary = missioni[corrente]
		var s := testo_fase()
		var resto := -1.0
		if float(m.get("tempo", 0.0)) > 0.0:
			resto = float(m["tempo"]) - (t - inizio_missione)
		var f := _fase(m)
		if float(f.get("entro", 0.0)) > 0.0:
			var rf := float(f["entro"]) - (t - inizio_fase)
			resto = rf if resto < 0.0 else minf(resto, rf)
		return s + ("  ·  %d s" % ceili(maxf(resto, 0.0)) if resto >= 0.0 else "")
	if pronta >= 0:
		return _testo_avvio() + Testi.t(" per iniziare")
	return ""

func _testo_avvio() -> String:
	return Testi.t("tira in ") + (str(avvio.get("id", "")) if str(avvio.get("id", "")) != "" else Testi.t(NOMI_EVENTI.get(str(avvio.get("tipo", "")), str(avvio.get("tipo", "")))))

const NOMI_EVENTI := {"bumper": "un bumper", "bersaglio": "un bersaglio", "fila": "una fila di bersagli tutta giù",
	"corsie": "tutte le corsie accese (cambio corsia)", "lama": "un deviatore sul piano",
	"rampa": "una rampa (fino in fondo)", "rampa_entrata": "l'imbocco di una rampa", "spinner": "lo spinner",
	"sensore": "una corsia (sensore)", "buca": "una buca", "fionda": "una fionda", "elastico": "un paletto di gomma",
	"kickback": "il kickback", "cancello": "un cancelletto", "portale": "un portale", "prigione": "il lock",
	"captive": "la captive ball", "bersaglio_mobile": "il bersaglio mobile", "passaggio_entrata": "un passaggio",
	"qualsiasi": "qualsiasi pezzo"}

## Testo automatico di una fase (se non ne è stato scritto uno).
static func descrivi_fase(f: Dictionary) -> String:
	var q: Dictionary = f.get("quando", {})
	var cosa: String = str(q.get("id", "")) if str(q.get("id", "")) != "" else ((Testi.t("gruppo ") + str(q["gruppo"])) if str(q.get("gruppo", "")) != "" else Testi.t(NOMI_EVENTI.get(str(q.get("tipo", "qualsiasi")), str(q.get("tipo", "")))))
	match str(f.get("modo", "conta")):
		"tutti":
			return Testi.t("colpisci tutti: ") + cosa
		"sequenza":
			return Testi.t("in ordine: ") + " → ".join((f.get("ids", []) as Array).map(func(x): return str(x)))
		"combo":
			return Testi.t("combo ×%d su %s (entro %.0f s l'uno dall'altro)") % [int(f.get("volte", 2)), cosa, float(f.get("finestra", 3.0))]
		"hurry_up":
			return Testi.t("HURRY-UP: presto, ") + cosa
		"stato":
			return Testi.t("tieni vivo %s per %d s (un colpo ogni %d s)") % [cosa, int(f.get("durata", 15.0)), int(f.get("finestra", 4.0))]
	var n := int(f.get("volte", 1))
	return (Testi.t("colpisci %s") % cosa) if n <= 1 else ("%s ×%d" % [cosa, n])
