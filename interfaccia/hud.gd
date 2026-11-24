## Tabellone semplice e neutro: punti, pallina, record, messaggi, missioni. (La grafica a tema arriva nella Fase 7.)
class_name Hud
extends CanvasLayer

var regole: RegoleBase
var _punti: Label
var _info: Label
var _titolo: Label
var _sotto: Label
var _missioni: Label
var _obiettivo: Label                 # cosa fare adesso (riga sotto le missioni)
var _msg_fino := 0.0
var _font_titolo: FontFile
var _font_testo: FontFile
var _fps: Label
var _t := 0.0
## v0.21: tabellone regolabile dall'editor (desc["tabellone"]["altezza"], px su 720 di larghezza) e sempre
## CENTRATO sopra il tavolo, anche in una finestra larga del PC. _barra = [nodo, posizione, è_della_barra_alta].
var _barra: Array = []
var _alto := 150.0
var _scritte_in_alto := true

## Altezza del tabellone scelta nel tavolo (px, schermo largo 720): 100 piccolo, 150 normale, 190 grande.
static func altezza_di(desc: Dictionary) -> float:
	var tb = desc.get("tabellone", {})
	return clampf(float(tb.get("altezza", 150.0)), 90.0, 220.0) if tb is Dictionary else 150.0

## v0.21: font del menu e del tabellone scelti nell'editor. Valore: "" = predefinito, "sans", "serif",
## oppure il nome di un font importato (desc["font_file"][nome] = file TTF/OTF in base64).
static func font_di(desc: Dictionary, valore: String, predefinito: String) -> Font:
	var v := valore if valore != "" else predefinito
	match v:
		"sans":
			return load("res://interfaccia/font/NotoSansDisplay-Bold.ttf")
		"serif":
			return load("res://interfaccia/font/NotoSerifDisplay-Bold.ttf")
	var lib = desc.get("font_file", {})
	if lib is Dictionary and lib.has(v):
		var f := FontFile.new()
		f.data = Marshalls.base64_to_raw(str(lib[v]))
		return f
	return font_di(desc, "", predefinito) if valore != "" else null

func prepara(r: RegoleBase) -> void:
	regole = r
	var dm = regole.tavolo.d.get("menu", {})
	if not dm is Dictionary:
		dm = {}
	_font_titolo = Hud.font_di(regole.tavolo.d, str(dm.get("font_titolo", "")), "serif")
	_font_testo = Hud.font_di(regole.tavolo.d, str(dm.get("font", "")), "sans")
	_alto = Hud.altezza_di(regole.tavolo.d)
	var cc: Dictionary = regole.tavolo.d.get("colori", {})
	var c1: Color = cc.get("primario", Color(0.86, 0.0, 0.1))
	var c2: Color = cc.get("secondario", Color(0.12, 0.6, 0.92))
	# tabellone sottile e trasparente: il tavolo resta a tutto schermo
	var fondo := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.78))
	gr.set_color(1, Color(0, 0, 0, 0.0))
	gt.gradient = gr
	fondo.texture = gt
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.position = Vector2(0, 0)
	fondo.size = Vector2(720, 150)
	var pannello := str(regole.tavolo.d.get("cartella_grafica", "res://grafica/")) + "pannello.png"
	var con_pannello := ResourceLoader.exists(pannello) and not Parametri.senza("grafica")
	if con_pannello:
		fondo.texture = load(pannello)
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE      # 1440x300 disegnato a 720x150
		fondo.size = Vector2(720, 150)
	add_child(fondo)
	if con_pannello:
		_punti = _label(Vector2(57, 19), Vector2(606, 46), 40, c2, _font_testo)
		_info = _label(Vector2(57, 62), Vector2(606, 21), 16, Color(0.92, 0.92, 0.95), _font_testo)
		_missioni = _label(Vector2(57, 82), Vector2(606, 20), 13, Color(0.8, 0.85, 0.95), _font_testo)
		_obiettivo = _label(Vector2(57, 101), Vector2(606, 22), 15, c2.lightened(0.25), _font_testo)
	else:
		_punti = _label(Vector2(0, 4), Vector2(720, 62), 54, c2, _font_testo)
		_info = _label(Vector2(0, 62), Vector2(720, 26), 20, Color(0.92, 0.92, 0.95), _font_testo)
		_missioni = _label(Vector2(0, 88), Vector2(720, 24), 16, Color(0.8, 0.85, 0.95), _font_testo)
		_obiettivo = _label(Vector2(0, 110), Vector2(720, 24), 17, c2.lightened(0.25), _font_testo)
	_titolo = _label(Vector2(0, 420), Vector2(720, 80), 56, c1, _font_titolo)
	_sotto = _label(Vector2(0, 500), Vector2(720, 44), 28, c2, _font_testo)
	for l in [_punti, _info, _missioni, _obiettivo]:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 6)
	_punti.add_theme_color_override("font_outline_color", c1.darkened(0.2))
	_punti.add_theme_constant_override("outline_size", 8)
	_punti.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_punti.add_theme_constant_override("shadow_offset_y", 3)
	for l in [_titolo, _sotto]:
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1))
		l.add_theme_constant_override("outline_size", 10)
	_sotto.add_theme_color_override("font_color", c1.lightened(0.3))
	_titolo.add_theme_color_override("font_shadow_color", c2)
	_titolo.add_theme_constant_override("shadow_offset_x", 3)
	_titolo.add_theme_constant_override("shadow_offset_y", 4)
	# il tabellone, al posto delle righe piccole, come le scritte di un flipper vero. «centro» = come prima.
	var tb = regole.tavolo.d.get("tabellone", {})
	_scritte_in_alto = not (tb is Dictionary and str(tb.get("scritte", "alto")) == "centro")
	if _scritte_in_alto:
		_titolo.position = Vector2(0, 60)
		_titolo.size = Vector2(720, 50)
		_sotto.position = Vector2(0, 106)
		_sotto.size = Vector2(720, 30)
		_sotto.add_theme_font_size_override("font_size", 22)
		for l in [_titolo, _sotto]:
			l.add_theme_constant_override("outline_size", 6)
		_titolo.add_theme_constant_override("shadow_offset_x", 2)
		_titolo.add_theme_constant_override("shadow_offset_y", 2)
	for n in [fondo, _punti, _info, _missioni, _obiettivo]:
		_barra.append([n, n.position, true])
	for n in [_titolo, _sotto]:
		_barra.append([n, n.position, _scritte_in_alto])
	get_viewport().size_changed.connect(_sistema)
	_sistema()
	_fps = _label(Vector2(8, 1240), Vector2(200, 30), 20, Color(0.6, 1.0, 0.6), _font_testo)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	regole.messaggio.connect(_messaggio)

## Tabellone centrato sullo schermo e grande quanto scelto nell'editor (la vista lascia lo stesso spazio libero).
func _sistema() -> void:
	var largo := get_viewport().get_visible_rect().size.x
	var k := _alto / 150.0
	for b in _barra:
		var n: Control = b[0]
		if b[2]:
			n.scale = Vector2(k, k)
			n.position = Vector2(b[1]) * k + Vector2((largo - 720.0 * k) * 0.5, 0)
		else:
			n.position = Vector2(b[1]) + Vector2((largo - 720.0) * 0.5, 0)

func _label(pos: Vector2, dim: Vector2, corpo: int, col: Color, font: Font = null) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.position = pos
	l.size = dim
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", corpo)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

## Il titolo si rimpicciolisce se è lungo, così non esce mai dallo schermo.
func _imposta_titolo(testo: String) -> void:
	_titolo.text = testo
	var corpo := 40 if _scritte_in_alto else 56
	var f: Font = _font_titolo
	while corpo > 26 and f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, corpo).x + 2 * 12 > 690:
		corpo -= 2
	_titolo.add_theme_font_size_override("font_size", corpo)

func _messaggio(titolo: String, sotto: String, durata: float) -> void:
	_imposta_titolo(titolo)
	_sotto.text = sotto
	_msg_fino = _t + durata

func _process(delta: float) -> void:
	_t += delta
	_fps.text = ("FPS %d" % Engine.get_frames_per_second()) if bool(Parametri.valore("sistema", "mostra_fps", false)) else ""
	_punti.text = RegoleBase.formatta(regole.punti)
	if regole.scrive_iniziali():
		# v0.23: iniziali per la classifica (la lettera scelta è tra parentesi)
		var lt := ""
		for i in 3:
			lt += ("[%s]" % regole.iniziali[i]) if i == regole.iniziali_pos else (" %s " % regole.iniziali[i])
		_imposta_titolo(Testi.t("CLASSIFICA!"))
		_sotto.text = lt
		_info.text = Testi.t("palette = lettera · START = conferma")
		_msg_fino = _t
	elif regole.stato == RegoleBase.ATTESA or regole.stato == RegoleBase.GAME_OVER:
		_info.text = Testi.t("RECORD  %s") % RegoleBase.formatta(regole.record)
		if _t > _msg_fino:
			if _titolo.text != regole.titolo:
				_imposta_titolo(regole.titolo)
			# v0.17: scritta dell'attesa in sala scelta nell'editor, alternata a «premi START»
			var scritta := str(RegiaDati.attesa(regole.tavolo.d).get("scritta", "")) if regole.tavolo != null else ""
			if scritta != "" and fmod(_t, 7.0) >= 3.5:
				_sotto.text = scritta
			else:
				_sotto.text = "premi START (Invio)" if fmod(_t, 1.2) < 0.8 else ""
	else:
		var info := Testi.t("PALLINA %d / %d      BONUS x%d") % [regole.pallina, regole.palline_max, regole.moltiplicatore]
		if regole.extra_palline > 0:
			info += "      EXTRA %d" % regole.extra_palline     # 20/11: palline extra da giocare (TIRA ANCORA)
		if _info.text != info:
			_info.text = info
		if _t > _msg_fino:
			_imposta_titolo("")
			_sotto.text = ""
	if regole.has_method("riga_missioni"):
		_missioni.text = regole.riga_missioni()
	elif "missioni_fatte" in regole:
		var r = regole
		var nomi: Array = r.MISSIONI_BREVI if "MISSIONI_BREVI" in r else r.MISSIONI
		var parti := PackedStringArray()
		for i in nomi.size():
			parti.append(("● " if r.missioni_fatte[i] else "○ ") + nomi[i])
		_missioni.text = "   ".join(parti)
	_obiettivo.text = regole.obiettivo() if regole.has_method("obiettivo") else ""
	if _scritte_in_alto:
		# mentre c'è una scritta grande, le righe piccole del tabellone lasciano il posto
		var scritta := _titolo.text != "" or _sotto.text != ""
		for l in [_info, _missioni, _obiettivo]:
			l.visible = not scritta
