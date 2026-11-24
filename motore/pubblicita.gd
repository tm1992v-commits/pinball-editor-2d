## Pubblicità: in questa versione libera non c'è nessuna pubblicità né SDK di terzi (modulo vuoto, mai attivo).
## Chi vuole aggiungerla può farlo nel proprio gioco rispettando le licenze (vedi AI_INSTRUCTIONS.md).
class_name Pubblicita
extends Node

signal chiusa()
var attiva := false

static func disponibile() -> bool:
	return false

static func consenso_scelto():
	return null

func avvia(_consenso: bool) -> void:
	pass

func cambia_consenso(_si: bool) -> void:
	pass

func fine_partita() -> void:
	pass

func premio_pronto() -> bool:
	return false

func mostra_premio(fatto: Callable) -> void:
	fatto.call(false)
