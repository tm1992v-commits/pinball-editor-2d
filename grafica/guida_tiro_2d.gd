## Sul tavolo si illumina SOLO il punto da colpire adesso, nel colore della missione: alone che respira, anello netto e
## 2 onde che si allargano come un faro; più forte per 3 secondi quando cambia l'obiettivo. Niente frecce né scritte.
## Il tavolo dice cosa illuminare con `guida(regole)` nel suo file delle luci: [lista di id, colore].
class_name GuidaTiro2D
extends Node2D

const MAX_PUNTI := 8
const RAGGIO_ANELLO := 16.0         # mm
const ONDA_DA := 14.0
const ONDA_A := 50.0

var regole: RegoleBase
var cfg: Script
var t := 0.0
var _intro := 0.0
var _chiave := ""
var _posti := {}                    # id -> posizione mm
var _attivi: Array = []             # posizioni
var _colore := Color.WHITE
var _t_lista := 0.0
var _alone: Texture2D
var _anello: Texture2D

func prepara(v: Vista2D, script_luci: Script) -> void:
	regole = v.regole
	cfg = script_luci
	var d: Dictionary = v.desc
	for k in ["inserti", "bersagli", "buche", "spinner", "bumper"]:
		for e in d.get(k, []):
			_posti[e["id"]] = Vector2(e["pos"])
	for e in d.get("bersagli_mobili", []):
		_posti[e["id"]] = (Vector2(e["da"]) + Vector2(e["a"])) * 0.5
	for e in d.get("captive", []):
		_posti[e["id"]] = Vector2(e["bersaglio"])
	_alone = v.tex_alone()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.68, Color(1, 1, 1, 0))
	g.add_point(0.80, Color(1, 1, 1, 1))
	g.add_point(0.90, Color(1, 1, 1, 0.5))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = g
	_anello = tex
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add

## Punti illuminati adesso (per i test): lista di id.
func attivi() -> Array:
	if not cfg.has_method("guida"):
		return []
	var out := []
	for id in cfg.guida(regole)[0]:
		if _posti.has(id):
			out.append(id)
	return out

func _process(delta: float) -> void:
	t += delta
	_intro = maxf(0.0, _intro - delta)
	_t_lista -= delta
	if _t_lista <= 0.0:
		_t_lista = 1.0 / 15.0
		var g: Array = cfg.guida(regole) if cfg.has_method("guida") else [[], Color.WHITE]
		_colore = g[1]
		_attivi.clear()
		for id in g[0]:
			if _posti.has(id) and _attivi.size() < MAX_PUNTI:
				_attivi.append(_posti[id])
		var chiave := "%s|%s" % [str(g[0]), _colore.to_html()]
		if chiave != _chiave:
			if not (g[0] as Array).is_empty():
				_intro = 3.0
			_chiave = chiave
	if not _attivi.is_empty() or get_meta("pieno", false):
		set_meta("pieno", not _attivi.is_empty())
		queue_redraw()

func _draw() -> void:
	var forza := (0.6 + 0.4 * (0.5 + 0.5 * sin(t * 5.0)) + 0.4 * clampf(_intro / 3.0, 0.0, 1.0)) * 0.8
	var col := _colore
	var respiro := 1.0 + 0.12 * sin(t * 5.0)
	for p in _attivi:
		_quad(_alone, p, 92.0, Color(col, 0.75 * forza))
		_quad(_alone, p, 36.0, Color(col.lightened(0.6), forza))
		_quad(_anello, p, RAGGIO_ANELLO * 2.4 * respiro, Color(col.lightened(0.4), 0.9 * forza))
		for k in 2:
			var f := fmod(t * 0.9 + k * 0.5, 1.0)
			_quad(_anello, p, (ONDA_DA + f * (ONDA_A - ONDA_DA)) * 2.4, Color(col, (1.0 - f) * 0.8))

func _quad(tex: Texture2D, centro: Vector2, lato: float, col: Color) -> void:
	draw_texture_rect(tex, Rect2(centro - Vector2(lato, lato) * 0.5, Vector2(lato, lato)), false, col)
