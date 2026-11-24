## Luci di base dei tavoli nuovi del Pinball Editor 2D (versione 0.1, prima della regia a dati): effetti semplici e
## colori neutri (bianco caldo e azzurro), da sostituire con la regia del tavolo nella fase «luci».
class_name LuciTavolo

const CALDO := Color(1.0, 0.85, 0.6)
const FREDDO := Color(0.55, 0.8, 1.0)
const CENTRO := Vector2(317, 620)

const EVENTI := {
	"bumper": [{"tipo": "onda", "col": CALDO, "dur": 0.35, "vel": 420.0, "larg": 28.0, "max": 120.0}],
	"fionda": [{"tipo": "onda", "col": FREDDO, "dur": 0.3, "vel": 380.0, "larg": 30.0, "max": 110.0}],
	"bersaglio": [{"tipo": "onda", "col": CALDO, "dur": 0.4, "vel": 350.0, "larg": 30.0, "max": 110.0}],
	"spinner": [{"tipo": "onda", "col": FREDDO, "dur": 0.3, "vel": 300.0, "larg": 24.0, "max": 80.0}],
	"rampa": [{"tipo": "onda", "col": FREDDO, "dur": 0.6, "vel": 450.0, "larg": 40.0, "max": 220.0}],
	"multiball": [{"tipo": "spazzata", "verso": -1.0, "col": CALDO, "dur": 0.8, "grande": true}],
	"salva_pallina": [{"tipo": "spazzata", "verso": -1.0, "col": FREDDO, "dur": 0.7}],
	"game_over": [{"tipo": "spazzata", "verso": 1.0, "col": Color(0.6, 0.6, 0.8), "dur": 1.5}],
	"tilt": [{"tipo": "strobo", "col": Color(1.0, 0.15, 0.1), "dur": 1.0, "freq": 6.0, "grande": true}],
	# v0.11: missioni
	"missione_inizio": [{"tipo": "girandola", "col": CALDO, "dur": 1.2, "giri": 2.0}],
	"missione_completa": [{"tipo": "spazzata", "verso": -1.0, "col": Color(1.0, 0.78, 0.2), "dur": 1.0, "grande": true}],
	"missione_fallita": [{"tipo": "spazzata", "verso": 1.0, "col": Color(1.0, 0.25, 0.2), "dur": 0.9}],
	"pallina_extra": [{"tipo": "strobo", "col": Color(0.35, 1.0, 0.45), "dur": 1.0, "freq": 5.0}],
}

const ATTESA := [
	{"tipo": "spazzata", "verso": -1.0, "col": CALDO, "dur": 1.6},
	{"tipo": "spazzata", "verso": 1.0, "col": FREDDO, "dur": 1.6},
]

static func atmosfera() -> Array:
	return []

static func colore_pezzo(_id: String) -> Color:
	return CALDO

static func colore_missione_attiva(_r) -> Color:
	return CALDO

static func guida(_r) -> Array:
	return [[], CALDO]

static func ambiente_tavolo(_r) -> float:
	return 1.0
