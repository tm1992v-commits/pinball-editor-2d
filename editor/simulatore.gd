## SIMULATORE DI REGOLE (Pinball Editor 2D v0.16, PROGETTO §D.8): prova le missioni senza giocare. Si «premono»
## i pezzi con un clic (come se la pallina li colpisse) e si vedono punti, missioni, messaggi del tabellone e luci.
## Usa le regole VERE del gioco (regole_tavolo + Mattoncini) su un tavolo tenuto in un mondo a parte (SubViewport),
## senza pallina: il tempo scorre davvero e si può anche far avanzare di colpo.
class_name SimulatoreRegole
extends Node

signal cambiato

var regole: RegoleBase
var tavolo: TavoloFisico
var messaggi: Array = []          # ultimi messaggi del tabellone
var _mondo: SubViewport

const TIPI := {"bumper": "bumper", "bersagli": "bersaglio", "rampe": "rampa", "buche": "buca", "spinner": "spinner",
	"sensori": "sensore", "elastici": "elastico", "cancelli": "cancello", "kickback": "kickback", "lame": "lama", "fionde": "fionda", "captive": "captive"}

func avvia(desc: Dictionary) -> String:
	ferma()
	if str(desc.get("regole", FileTavolo.REGOLE_BASE)) != FileTavolo.REGOLE_BASE:
		return "Questo tavolo usa le regole già scritte di Space: il simulatore vale per i tavoli nuovi."
	_mondo = SubViewport.new()
	_mondo.own_world_3d = true
	_mondo.world_2d = World2D.new()
	_mondo.size = Vector2i(8, 8)
	_mondo.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_mondo)
	tavolo = TavoloFisico.new(desc.duplicate(true))
	_mondo.add_child(tavolo)
	regole = load(FileTavolo.REGOLE_BASE).new()
	regole.salva_record = false
	_mondo.add_child(regole)
	regole.collega(tavolo)
	regole.messaggio.connect(func(a, b, _d):
		messaggi.append(a + ("  ·  " + b if b != "" else ""))
		if messaggi.size() > 8:
			messaggi.pop_front()
		cambiato.emit())
	regole.punteggio_cambiato.connect(func(_p): cambiato.emit())
	regole.stato = RegoleBase.GIOCO
	regole.pallina = 1
	regole.t = 0.0
	regole._azzera_partita()
	regole._inizio_pallina()
	regole.t = 2.0                    # come in gioco dopo il lancio: la prima missione parte subito
	regole.missioni.tick(regole.t)
	messaggi = ["Simulatore pronto: premi i pezzi qui sotto."]
	cambiato.emit()
	return "Simulatore: partita nuova"

func ferma() -> void:
	if _mondo != null:
		_mondo.queue_free()
	_mondo = null
	regole = null
	tavolo = null

func attivo() -> bool:
	return regole != null

## La pallina «colpisce» un pezzo (tipo dell'elenco del tavolo, id del pezzo).
func premi(lista: String, id: String) -> void:
	if not attivo():
		return
	var tipo: String = TIPI.get(lista, lista)
	regole.t += 0.3
	if tipo == "bersaglio" and tavolo.bersagli_giu.has(id):
		var info: Dictionary = {}
		for b in tavolo.d.get("bersagli", []):
			if b["id"] == id:
				info = b
		if bool(info.get("abbattibile", false)):
			if tavolo.bersagli_giu[id]:
				return                       # già giù: non si colpisce
			tavolo.bersagli_giu[id] = true
	if tipo == "lama":
		tavolo.muovi_lama(id, "alterna")
	regole._evento_tavolo(tipo, id, _pos(lista, id))
	regole.missioni.tick(regole.t)
	cambiato.emit()

func tempo(s: float) -> void:
	if not attivo():
		return
	var fine := regole.t + s
	while regole.t < fine:
		regole.t = minf(fine, regole.t + 0.5)
		regole.missioni.tick(regole.t)
	cambiato.emit()

func paletta(verso: int) -> void:
	if attivo():
		regole.palette_premuta(verso)
		cambiato.emit()

func _pos(lista: String, id: String) -> Vector2:
	for e in tavolo.d.get(lista, []):
		if e is Dictionary and str(e.get("id", "")) == id:
			return ProgettoEditor.centro(lista, e)
	return Vector2.ZERO

## Testo dello stato: punti, missione, obiettivo, luci accese.
func stato() -> Dictionary:
	if not attivo():
		return {}
	var luci: Array = []
	var sl := regole.stato_luci()
	for k in sl:
		luci.append("%s %s" % ["●" if sl[k] == 1 else ("◐" if sl[k] == 2 else "○"), k])
	return {"punti": regole.punti, "riga": regole.riga_missioni(), "obiettivo": regole.obiettivo(), "tempo": regole.t,
		"bonus": regole.moltiplicatore, "luci": luci, "messaggi": messaggi.duplicate()}
