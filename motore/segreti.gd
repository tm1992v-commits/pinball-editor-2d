## non sono scritti sul tabellone, si scoprono giocando; ognuno vale UNA volta per partita. Sono DATI nel tavolo
## (desc["segreti"]) e girano in parallelo alle missioni, senza disturbarle. Tipi:
##   "raffica" = N colpi (quando: tipo e/o id) entro T secondi        (es. 6 bumper in 2 secondi)
##   "di_fila" = i pezzi "ids" uno dopo l'altro, senza altri pezzi dell'elenco in mezzo (es. rampa, buca, rampa)
##   "entro"   = il pezzo "poi" entro T secondi dal pezzo "primo"        (es. rampa entro 5 s dal kickback)
##   "tutti"   = tutti i pezzi "ids" nella stessa pallina              (es. le due corsie esterne)
## Premio: "punti". Il messaggio è «SEGRETO SCOPERTO!» + il nome.
class_name Segreti
extends RefCounted

const TIPI := {"raffica": "colpi veloci (N colpi in T secondi)", "di_fila": "pezzi di fila (nell'ordine)",
	"entro": "un pezzo subito dopo un altro (entro T secondi)", "tutti": "tutti i pezzi nella stessa pallina"}

var elenco: Array = []
var scoperti := {}
var _tempi := {}          # id segreto -> [tempi dei colpi]   (raffica)
var _passo := {}          # id segreto -> indice nella fila   (di_fila)
var _primo_t := {}        # id segreto -> tempo del "primo"   (entro)
var _visti := {}          # id segreto -> {id pezzo: true}    (tutti)

func _init(desc: Dictionary) -> void:
	elenco = (desc.get("segreti", []) as Array).filter(func(s): return s is Dictionary and s.has("id")) if desc.get("segreti") is Array else []

func azzera_partita() -> void:
	scoperti = {}
	azzera_pallina()

func azzera_pallina() -> void:
	_tempi = {}
	_passo = {}
	_primo_t = {}
	_visti = {}

## Un colpo del tavolo. Ritorna i segreti scoperti adesso (di solito nessuno).
func evento(tipo: String, id: String, t: float) -> Array:
	var nuovi: Array = []
	for s in elenco:
		var k := str(s["id"])
		if scoperti.has(k):
			continue
		if _controlla(s, k, tipo, id, t):
			scoperti[k] = true
			nuovi.append(s)
	return nuovi

static func _vale(q, tipo: String, id: String) -> bool:
	if not q is Dictionary:
		return false
	if str(q.get("id", "")) != "":
		return str(q["id"]) == id
	return str(q.get("tipo", "")) in ["", "qualsiasi", tipo]

func _controlla(s: Dictionary, k: String, tipo: String, id: String, t: float) -> bool:
	match str(s.get("tipo", "raffica")):
		"raffica":
			if not _vale(s.get("quando", {}), tipo, id):
				return false
			var l: Array = _tempi.get(k, [])
			l.append(t)
			var finestra := float(s.get("secondi", 2.0))
			while not l.is_empty() and t - float(l[0]) > finestra:
				l.pop_front()
			_tempi[k] = l
			return l.size() >= maxi(1, int(s.get("volte", 6)))
		"di_fila":
			var ids: Array = s.get("ids", [])
			if ids.is_empty() or not id in ids:
				return false
			var p := int(_passo.get(k, 0))
			if str(ids[p]) == id:
				p += 1
			else:
				p = 1 if str(ids[0]) == id else 0
			_passo[k] = p
			if p >= ids.size():
				_passo[k] = 0
				return true
			return false
		"entro":
			if id == str(s.get("primo", "")):
				_primo_t[k] = t
				return false
			return id == str(s.get("poi", "")) and t - float(_primo_t.get(k, -999.0)) <= float(s.get("secondi", 5.0))
		"tutti":
			var ids2: Array = s.get("ids", [])
			if ids2.is_empty() or not id in ids2:
				return false
			var v: Dictionary = _visti.get(k, {})
			v[id] = true
			_visti[k] = v
			return v.size() >= ids2.size()
	return false

## Descrizione in parole semplici (editor e menu del gioco).
static func testo(s: Dictionary) -> String:
	match str(s.get("tipo", "raffica")):
		"raffica":
			var q: Dictionary = s.get("quando", {})
			var cosa := str(q.get("id", "")) if str(q.get("id", "")) != "" else str(q.get("tipo", "qualsiasi pezzo"))
			return "%d colpi su %s in %s secondi" % [int(s.get("volte", 6)), cosa, str(s.get("secondi", 2.0))]
		"di_fila":
			return "di fila: " + " → ".join(s.get("ids", []))
		"entro":
			return "%s entro %s s da %s" % [str(s.get("poi", "?")), str(s.get("secondi", 5.0)), str(s.get("primo", "?"))]
		"tutti":
			return "tutti nella stessa pallina: " + ", ".join(s.get("ids", []))
	return ""
