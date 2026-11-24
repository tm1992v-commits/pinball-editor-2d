## SCHEMA DELLE DIPENDENZE delle missioni (Pinball Editor 2D v0.18.3, brief §6): una casella per missione, in colonne
## (prima quelle che partono da sole, poi quelle che aspettano una missione), frecce «si sblocca dopo». Le modalità
## sono dorate, le missioni spente grigie, quelle in un cerchio impossibile rosse. Solo disegno dell'interfaccia.
class_name SchemaMissioni
extends Control

var lista: Array = []
var _caselle := {}            # id -> Rect2
const L := 190.0
const H := 54.0
const SPAZIO_X := 70.0
const SPAZIO_Y := 18.0

func imposta(missioni: Array) -> void:
	lista = missioni
	_caselle.clear()
	var col := ModelliMissioni.colonne(lista)
	var cerchio := {}
	for g in ModelliMissioni.cicli(lista):
		for x in g:
			cerchio[x] = true
	var alt := 0.0
	for c in col.size():
		for r in col[c].size():
			_caselle[col[c][r]] = Rect2(Vector2(16 + c * (L + SPAZIO_X), 16 + r * (H + SPAZIO_Y)), Vector2(L, H))
			alt = maxf(alt, 16 + (r + 1) * (H + SPAZIO_Y))
	set_meta("cerchio", cerchio)
	custom_minimum_size = Vector2(32 + col.size() * (L + SPAZIO_X), alt + 16)
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var cerchio: Dictionary = get_meta("cerchio", {})
	for m in lista:
		var id := str(m.get("id", ""))
		var sb: Dictionary = m.get("sblocco", {}) if m.get("sblocco") is Dictionary else {}
		var d := str(sb.get("dopo", ""))
		if d != "" and _caselle.has(d) and _caselle.has(id):
			var a: Rect2 = _caselle[d]
			var b: Rect2 = _caselle[id]
			var p0 := a.position + Vector2(a.size.x, a.size.y * 0.5)
			var p1 := b.position + Vector2(0, b.size.y * 0.5)
			if p1.x <= p0.x:
				p0 = a.position + Vector2(a.size.x * 0.5, a.size.y)
				p1 = b.position + Vector2(b.size.x * 0.5, 0)
			var colf := Color(1, 0.35, 0.3) if cerchio.has(id) else Color(0.7, 0.8, 1.0)
			draw_line(p0, p1, colf, 2.0, true)
			var dir := (p1 - p0).normalized()
			draw_colored_polygon(PackedVector2Array([p1, p1 - dir * 10 + dir.orthogonal() * 5, p1 - dir * 10 - dir.orthogonal() * 5]), colf)
	for m in lista:
		var id := str(m.get("id", ""))
		if not _caselle.has(id):
			continue
		var r: Rect2 = _caselle[id]
		var fondo := Color(0.18, 0.2, 0.28)
		if int(m.get("priorita", 0)) > 0:
			fondo = Color(0.42, 0.33, 0.1)
		if not bool(m.get("attiva", true)):
			fondo = Color(0.22, 0.22, 0.22)
		if cerchio.has(id):
			fondo = Color(0.45, 0.12, 0.12)
		draw_rect(r, fondo)
		draw_rect(r, Color(1, 1, 1, 0.35), false, 1.5)
		draw_string(font, r.position + Vector2(8, 20), str(m.get("nome", id)), HORIZONTAL_ALIGNMENT_LEFT, L - 16, 14, Color.WHITE)
		var sb: Dictionary = m.get("sblocco", {}) if m.get("sblocco") is Dictionary else {}
		var sotto := ""
		if int(m.get("priorita", 0)) > 0:
			sotto = "MODALITÀ · dopo %d missioni" % maxi(1, int(sb.get("completate", 0)))
		elif int(sb.get("completate", 0)) > 0:
			sotto = "dopo %d missioni" % int(sb["completate"])
		elif str(sb.get("dopo", "")) == "":
			sotto = "parte da sola"
		else:
			sotto = "dopo «%s»" % ModelliMissioni._nome_id(lista, str(sb["dopo"]))
		if not bool(m.get("attiva", true)):
			sotto = "SPENTA"
		if cerchio.has(id):
			sotto = "IN CERCHIO: non parte mai"
		draw_string(font, r.position + Vector2(8, 42), sotto, HORIZONTAL_ALIGNMENT_LEFT, L - 16, 11, Color(1, 1, 1, 0.7))

## Finestra con lo schema (scorrevole).
static func finestra(missioni: Array) -> Window:
	var w := Window.new()
	w.title = "Schema delle missioni: chi sblocca chi"
	w.size = Vector2i(900, 560)
	w.close_requested.connect(w.queue_free)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.add_child(sc)
	var s := SchemaMissioni.new()
	sc.add_child(s)
	s.imposta(missioni)
	return w
