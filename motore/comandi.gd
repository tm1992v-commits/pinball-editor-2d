## Comandi (autoload "Comandi"): mappatura configurabile di tastiera, gamepad ed encoder USB (che di solito
## simulano una tastiera o un joystick HID: nessun accesso root richiesto). Le scelte si salvano in user://comandi.cfg.
extends Node

const FILE := "user://comandi.cfg"

## Azioni del gioco con nome leggibile e tasti predefiniti.
const AZIONI := {
	"paletta_sx": {"nome": "Paletta sinistra", "tasti": [KEY_Z, KEY_LEFT, KEY_SHIFT], "joy": [JOY_BUTTON_LEFT_SHOULDER, 0]},
	"paletta_dx": {"nome": "Paletta destra", "tasti": [KEY_M, KEY_RIGHT, KEY_SHIFT], "joy": [JOY_BUTTON_RIGHT_SHOULDER, 1]},
	"lancio": {"nome": "Lancio pallina", "tasti": [KEY_SPACE, KEY_DOWN], "joy": [2]},
	"start": {"nome": "Start", "tasti": [KEY_ENTER, KEY_KP_ENTER, KEY_1], "joy": [JOY_BUTTON_START, 3]},
	"spinta": {"nome": "Nudge (frontale)", "tasti": [KEY_B, KEY_UP], "joy": [7]},
	"spinta_sx": {"nome": "Nudge sinistro", "tasti": [KEY_C], "joy": [11]},
	"spinta_dx": {"nome": "Nudge destro", "tasti": [KEY_N], "joy": [12]},
	"pausa": {"nome": "Menu / pausa", "tasti": [KEY_ESCAPE, KEY_P], "joy": [JOY_BUTTON_BACK]},
}

func _ready() -> void:
	carica()

func _evento_tasto(k: int, posizione := KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.location = posizione
	return e

func _evento_joy(b: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = -1
	return e

func predefiniti() -> void:
	for azione in AZIONI:
		if InputMap.has_action(azione):
			InputMap.erase_action(azione)
		InputMap.add_action(azione, 0.2)
		for k in AZIONI[azione]["tasti"]:
			var loc := KEY_LOCATION_UNSPECIFIED
			if k == KEY_SHIFT:
				loc = KEY_LOCATION_LEFT if azione == "paletta_sx" else KEY_LOCATION_RIGHT
			InputMap.action_add_event(azione, _evento_tasto(k, loc))
		for b in AZIONI[azione]["joy"]:
			InputMap.action_add_event(azione, _evento_joy(b))

func carica() -> void:
	predefiniti()
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	for azione in AZIONI:
		var lista = cfg.get_value("comandi", azione, null)
		if lista is Array and not lista.is_empty():
			InputMap.action_erase_events(azione)
			for ev in lista:
				if ev is InputEvent:
					InputMap.action_add_event(azione, ev)

func salva() -> void:
	var cfg := ConfigFile.new()
	for azione in AZIONI:
		cfg.set_value("comandi", azione, InputMap.action_get_events(azione))
	cfg.save(FILE)

## Sostituisce i comandi di un'azione con l'evento appena premuto (schermata di configurazione).
func assegna(azione: String, ev: InputEvent) -> void:
	var nuovo: InputEvent
	if ev is InputEventKey:
		nuovo = _evento_tasto(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode, ev.location)
	elif ev is InputEventJoypadButton:
		nuovo = _evento_joy(ev.button_index)
	else:
		return
	InputMap.action_erase_events(azione)
	InputMap.action_add_event(azione, nuovo)
	salva()

func ripristina() -> void:
	predefiniti()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))

func descrivi(azione: String) -> String:
	var parti := PackedStringArray()
	for ev in InputMap.action_get_events(azione):
		if ev is InputEventKey:
			var nome := OS.get_keycode_string(ev.physical_keycode)
			if ev.location == KEY_LOCATION_LEFT:
				nome += " sx"
			elif ev.location == KEY_LOCATION_RIGHT:
				nome += " dx"
			parti.append(nome)
		elif ev is InputEventJoypadButton:
			parti.append("Pulsante %d" % ev.button_index)
	return ", ".join(parti)

func premuto(azione: String) -> bool:
	return Input.is_action_pressed(azione)
