## Regole di base dei tavoli nuovi del Pinball Editor 2D (versione 0.1, prima dei mattoncini): partita, 3 palline,
## punti per ogni pezzo colpito, bonus, salva-pallina, pallina extra, tilt (tutto da RegoleBase).
## I lock (prigioni) rilasciano le palline quando sono pieni: multiball semplice.
extends RegoleBase

const PUNTI := {"bumper": 100, "fionda": 10, "bersaglio": 500, "bersaglio_mobile": 500, "spinner": 20, "sensore": 50,
	"buca": 1000, "rampa": 2000, "kickback": 200, "portale": 500, "prigione": 1500, "cancello": 10, "captive": 1500}
const PUNTI_FILA := 5000                # tutti i bersagli abbattibili di un gruppo giù

## v0.10: MISSIONI A MATTONCINI scritte nel file del tavolo (desc["missioni"]), fatte avanzare da Mattoncini.
var missioni: Mattoncini
var colpiti := {}                     # v0.11: pezzi colpiti in questa pallina (per le luci «pezzo già colpito»)

func collega(t_: TavoloFisico) -> void:
	super(t_)
	missioni = Mattoncini.new(tavolo.d, self)
	segreti = Segreti.new(tavolo.d)

## v0.23: obiettivi segreti (desc["segreti"]), in parallelo alle missioni; una volta per partita.
var segreti: Segreti

func _segreto(tipo: String, id: String, pos: Vector2) -> void:
	if segreti == null:
		return
	for s in segreti.evento(tipo, id, t):
		aggiungi_punti(int(s.get("punti", 50000)) * punti_x)
		messaggio.emit(Testi.t("SEGRETO SCOPERTO!"), str(s.get("nome", "")).to_upper(), 3.0)
		effetto.emit("segreto", pos)

func _azzera_partita() -> void:
	if missioni:
		missioni.nuova_partita()
	if segreti:
		segreti.azzera_partita()

func _inizio_pallina() -> void:
	colpiti = {}
	_prepara_corsie()
	if missioni:
		missioni.inizio_pallina(t)
	if segreti:
		segreti.azzera_pallina()

func _process(_delta: float) -> void:
	if missioni and stato == GIOCO:
		missioni.tick(t)
		# v0.12: le palette scelgono la missione (se pronta) e spostano le corsie accese (cambio corsia)
		for verso in [-1, 1]:
			if Input.is_action_just_pressed("paletta_sx" if verso < 0 else "paletta_dx") and not tavolo.tilt:
				palette_premuta(verso)

## Paletta premuta (−1 sinistra, +1 destra): anche dai test.
func palette_premuta(verso: int) -> void:
	if missioni:
		missioni.cambia_scelta(verso)
	for g in corsie:
		var acc: Array = corsie[g]
		if acc.size() > 1:
			if verso < 0:
				acc.push_back(acc.pop_front())
			else:
				acc.push_front(acc.pop_back())

# ---------------------------------------------------------------- CAMBIO CORSIA (v0.12)
## desc["cambio_corsie"] = [{"gruppo", "premio": {...}}]: i sensori del gruppo (da sinistra a destra) si accendono
## quando la pallina ci passa; le palette spostano le luci accese; tutte accese = premio, poi si spengono.
var corsie := {}                       # gruppo -> Array[bool] (da sinistra a destra)
var _ordine_corsie := {}               # gruppo -> Array[id sensore]

func _prepara_corsie() -> void:
	corsie = {}
	_ordine_corsie = {}
	for cc in tavolo.d.get("cambio_corsie", []):
		var g := str(cc.get("gruppo", ""))
		var ids: Array = tavolo.d.get("sensori", []).filter(func(s): return str(s.get("gruppo", "")) == g)
		ids.sort_custom(func(a, b): return Vector2(a["pos"]).x < Vector2(b["pos"]).x)
		if ids.size() >= 2:
			_ordine_corsie[g] = ids.map(func(s): return str(s["id"]))
			var acc: Array = []
			acc.resize(ids.size())
			acc.fill(false)
			corsie[g] = acc

func corsia_accesa(id: String) -> bool:
	for g in _ordine_corsie:
		var k: int = _ordine_corsie[g].find(id)
		if k >= 0:
			return bool(corsie[g][k])
	return false

func _corsia(id: String, pos: Vector2) -> void:
	for g in _ordine_corsie:
		var k: int = _ordine_corsie[g].find(id)
		if k < 0:
			continue
		var acc: Array = corsie[g]
		acc[k] = true
		if not acc.has(false):
			acc.fill(false)
			for cc in tavolo.d.get("cambio_corsie", []):
				if str(cc.get("gruppo", "")) == g:
					var pr: Dictionary = cc.get("premio", {})
					aggiungi_punti(int(pr.get("punti", 25000)) * punti_x)
					if int(pr.get("bonus_x", 0)) > 0:
						moltiplicatore += int(pr["bonus_x"])
					messaggio.emit(Testi.t("CORSIE COMPLETE"), "+%s%s" % [formatta(int(pr.get("punti", 25000)) * punti_x), ("  bonus ×%d" % moltiplicatore) if int(pr.get("bonus_x", 0)) > 0 else ""], 2.0)
			effetto.emit("corsie_complete", pos)
			if missioni:
				missioni.evento("corsie", g, pos, t)

func _evento_tavolo(tipo: String, id: String, pos: Vector2) -> void:
	aggiungi_punti(int(PUNTI.get(tipo, 0)) * punti_x)
	conta(tipo)
	colpiti[id] = true
	if tipo == "sensore":
		_corsia(id, pos)
	if missioni:
		missioni.evento(tipo, id, pos, t)
	_segreto(tipo, id, pos)
	if tipo == "bersaglio" and tavolo.has_method("rialza"):
		# v0.7: FILA di bersagli abbattibili tutta giù = premio, poi dopo 1 s si rialza (regola minima, poi i mattoncini)
		var gruppo := ""
		for b in tavolo.d["bersagli"]:
			if b["id"] == id:
				gruppo = str(b.get("gruppo", ""))
		if gruppo == "":
			return
		var tutti := true
		var quanti := 0
		for b in tavolo.d["bersagli"]:
			if str(b.get("gruppo", "")) == gruppo and bool(b.get("abbattibile", false)):
				quanti += 1
				tutti = tutti and bool(tavolo.bersagli_giu.get(b["id"], false))
		if tutti and quanti > 0:
			aggiungi_punti(PUNTI_FILA * punti_x)
			conta("fila")
			if missioni:
				missioni.evento("fila", gruppo, pos, t)
			await get_tree().create_timer(1.0).timeout
			tavolo.rialza(gruppo)

func _voci_bonus() -> Array:
	var v := []
	for k in ["bumper", "bersaglio", "rampa"]:
		if contatori.has(k):
			v.append([k.to_upper(), int(contatori[k]) * 100])
	return v

func riga_missioni() -> String:
	return missioni.riga() if missioni else ""

func obiettivo() -> String:
	return missioni.obiettivo(t) if missioni and stato == GIOCO else ""

## v0.11: luci del piano che seguono la loro regola (RegiaDati.MODI_LUCE: guida al tiro, missione, barra, multiball…).
func stato_luci() -> Dictionary:
	var l := {}
	for info in tavolo.d.get("inserti", []):
		if info is Dictionary and str(info.get("luce_modo", "")) != "":
			l[info["id"]] = RegiaDati.stato_luce(info, self)
	return l
