## Parametri centralizzati (autoload "Parametri").
## Legge res://config/gioco.cfg, poi le scelte dell'utente in user://impostazioni.cfg (che hanno la precedenza).
extends Node

signal cambiati()

const FILE_BASE := "res://config/gioco.cfg"
const FILE_UTENTE := "user://impostazioni.cfg"

var _base := ConfigFile.new()
var _utente := ConfigFile.new()

## Argomenti da riga di comando (dopo "--"): --bench, --prova=SECONDI, --debug, --finestra, --qualita=bassa ...
var argomenti := {}

func _ready() -> void:
	_base.load(FILE_BASE)
	_utente.load(FILE_UTENTE)
	var lista := Array(OS.get_cmdline_user_args())
	# sul telefono (sviluppo, APK di prova): argomenti scritti in user://argomenti.txt, uno per riga
	if OS.is_debug_build() and FileAccess.file_exists("user://argomenti.txt"):
		lista.append_array(FileAccess.get_file_as_string("user://argomenti.txt").split("\n", false))
	for a: String in lista:
		if a.begins_with("--"):
			var parti := a.substr(2).split("=", true, 1)
			argomenti[parti[0]] = parti[1] if parti.size() > 1 else "1"
	if argomenti.has("qualita"):
		_utente.set_value("grafica", "qualita", argomenti["qualita"])

func valore(sezione: String, chiave: String, predefinito = null):
	if _utente.has_section_key(sezione, chiave):
		return _utente.get_value(sezione, chiave)
	return _base.get_value(sezione, chiave, predefinito)

## Il valore esiste (nel file base o nelle scelte dell'utente)?
func ha(sezione: String, chiave: String) -> bool:
	return _utente.has_section_key(sezione, chiave) or _base.has_section_key(sezione, chiave)

func f(chiave: String, predefinito := 0.0) -> float:
	return float(valore("fisica", chiave, predefinito))

func imposta(sezione: String, chiave: String, v) -> void:
	_utente.set_value(sezione, chiave, v)
	_utente.save(FILE_UTENTE)
	cambiati.emit()

func qualita() -> String:
	return str(valore("grafica", "qualita", "bassa"))

## Strumenti di debug: mai nella modalità commerciale normale.
func debug_attivo() -> bool:
	return argomenti.has("debug") or bool(valore("sistema", "strumenti_debug", false))

## Diagnosi (sviluppo): --senza=regia,hud,audio,scala,accelerometro,vista spegne quelle parti, per trovare un problema.
func senza(parte: String) -> bool:
	return parte in arg("senza").split(",")

func arg(nome: String) -> String:
	return str(argomenti.get(nome, ""))
