## GUIDA INTEGRATA (Pinball Editor 2D v0.18.2, Fase 10): il manuale (MANUALE_EDITOR.md, accanto al progetto) dentro
## l'editor, in una finestra con l'indice dei capitoli e la ricerca. Il manuale resta UNO solo: quello che Claude
## aggiorna a ogni versione; qui si legge e basta.
class_name GuidaEditor
extends Window

var _indice: ItemList
var _testo: RichTextLabel
var _cerca: LineEdit
var _capitoli: Array = []          # [titolo, testo]

static func percorso_manuale() -> String:
	# v0.26: il manuale del repository (docs/MANUALE.md) se c'è, altrimenti quello accanto al progetto
	var nel_progetto := ProjectSettings.globalize_path("res://docs/MANUALE.md")
	if FileAccess.file_exists(nel_progetto):
		return nel_progetto
	return ProjectSettings.globalize_path("res://").path_join("..").path_join("MANUALE_EDITOR.md").simplify_path()

## Capitoli del manuale: [titolo, testo] (il primo è l'introduzione).
static func capitoli(testo_md: String) -> Array:
	var out: Array = [["Introduzione", ""]]
	for riga in testo_md.split("\n"):
		if riga.begins_with("## "):
			out.append([riga.substr(3).strip_edges(), ""])
		else:
			out[out.size() - 1][1] += riga + "\n"
	return out.filter(func(c): return str(c[1]).strip_edges() != "" or c[0] != "Introduzione")

## Markdown semplice → BBCode (grassetto, corsivo, codice, titoletti, elenchi).
static func bbcode(md: String) -> String:
	var t := md.replace("[", "[lb]")
	var re := RegEx.new()
	re.compile("\\*\\*(.+?)\\*\\*")
	t = re.sub(t, "[b]$1[/b]", true)
	re.compile("(?<![\\*\\w])\\*(?!\\s)(.+?)\\*(?!\\*)")
	t = re.sub(t, "[i]$1[/i]", true)
	re.compile("`([^`]+)`")
	t = re.sub(t, "[code]$1[/code]", true)
	var righe := PackedStringArray()
	for r in t.split("\n"):
		if r.begins_with("### "):
			r = "[font_size=17][b]" + r.substr(4) + "[/b][/font_size]"
		elif r.begins_with("- "):
			r = "  • " + r.substr(2)
		elif r.begins_with("|---"):
			continue
		righe.append(r)
	return "\n".join(righe)

func _init() -> void:
	title = "❓ Guida del Pinball Editor 2D"
	size = Vector2i(980, 720)
	wrap_controls = true
	close_requested.connect(hide)
	var fondo := PanelContainer.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var col := VBoxContainer.new()
	fondo.add_child(col)
	_cerca = LineEdit.new()
	_cerca.placeholder_text = "Cerca nella guida (es. rampa, missione, licenze)…"
	_cerca.text_changed.connect(_filtra)
	col.add_child(_cerca)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(split)
	_indice = ItemList.new()
	_indice.custom_minimum_size = Vector2(280, 0)
	_indice.item_selected.connect(_mostra)
	split.add_child(_indice)
	_testo = RichTextLabel.new()
	_testo.bbcode_enabled = true
	_testo.selection_enabled = true
	_testo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_testo)
	var f := percorso_manuale()
	var md := FileAccess.get_file_as_string(f) if FileAccess.file_exists(f) else "Manuale non trovato: " + f
	_capitoli = capitoli(md)
	_filtra("")

func _filtra(q: String) -> void:
	_indice.clear()
	for i in _capitoli.size():
		if q.strip_edges() == "" or str(_capitoli[i][0]).to_lower().contains(q.to_lower()) or str(_capitoli[i][1]).to_lower().contains(q.to_lower()):
			var k := _indice.add_item(str(_capitoli[i][0]))
			_indice.set_item_metadata(k, i)
	if _indice.item_count > 0:
		_indice.select(0)
		_mostra(0)
	else:
		_testo.text = "Niente trovato per «%s»." % q

func _mostra(k: int) -> void:
	var i: int = _indice.get_item_metadata(k)
	_testo.text = "[font_size=20][b]%s[/b][/font_size]\n\n%s" % [str(_capitoli[i][0]).replace("[", "[lb]"), bbcode(str(_capitoli[i][1]))]
	_testo.scroll_to_line(0)

## Apre la guida sul primo capitolo che parla di `argomento` ("" = indice).
func apri(argomento := "") -> void:
	_cerca.text = argomento
	_filtra(argomento)
	popup_centered()
