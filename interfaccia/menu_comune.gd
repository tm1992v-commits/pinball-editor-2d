## Cambiano solo colori, font, visuali e testi: ogni tavolo ha la sua sottoclasse MenuGioco che riempie i «ganci» (_gancio).
##
## Sempre visibili in alto a destra: pulsante TELECAMERA (scelta rapida delle visuali, senza entrare nel menu) e
## pulsante ☰ (apre / chiude il menu e mette in pausa).
## Menu in UNA schermata, a gruppi: RIPRENDI · NUOVA PARTITA / VISUALE / AUDIO / PARTITA E GRAFICA /
## REGOLE · MISSIONI · CREDITI (+ voci del singolo tavolo). Le pagine di testo hanno AVANTI / INDIETRO.
## Si usa col dito (pulsanti veri di Godot) e coi pulsanti del cabinato: paletta sinistra / freccia su = voce prima,
## paletta destra / freccia giù = voce dopo, LANCIO / START / Invio = conferma, MENU / Esc = indietro.
## Le scelte si salvano subito (Parametri.imposta).
class_name MenuComune
extends CanvasLayer

signal visuale_cambiata(id)

# ---- aspetto (la sottoclasse lo cambia in _configura)
var titolo := "MENU"
var col_a := Color(0.12, 0.6, 0.92)          # colore principale (bordi, sezioni)
var col_b := Color(0.86, 0.0, 0.1)           # colore secondario (pulsanti alternati, titolo)
var col_testo := Color(0.92, 0.94, 1.0)
var col_fondo := Color(0.02, 0.03, 0.06, 0.9)
var col_pannello := Color(0.05, 0.06, 0.1, 0.97)
var font: Font
var font_titolo: Font
var chiave_fps := ["sistema", "mostra_fps"]  # dove il tavolo salva «Mostra FPS»

var aperto := false                          # menu (o una sua pagina) aperto
var rapido_aperto := false                   # scelta rapida della visuale aperta
var pagina := ""
var pubblicita                               # Pubblicita (solo nell'APK con pubblicità)

var _strato: Control                         # tutto il menu
var _rapido: Control                         # tendina della telecamera
var _icone: Control
var _icona_menu: Button
var _icona_camera: Button
var _navigabili: Array = []                  # pulsanti nell'ordine dei pulsanti fisici
var _sel := 0
var _obbligatoria := false                   # pagina da cui si esce solo scegliendo (consenso, premio)
var _pausa_prima := false
var _pausa_rapido := false
var _pagina_testo_args: Array = []

const ALTEZZA_PULSANTE := 56.0
const LARGHEZZA := 680.0

# ================================================================ ganci (la sottoclasse li riempie)
func _configura() -> void: pass
## [[id, "Nome"], ...] visuali che il tavolo supporta davvero
func _visuali() -> Array: return []
func _visuale_attuale(): return null
func _imposta_visuale(_id) -> void: pass
## Interruttori della visuale: [["Nome", sezione, chiave, predefinito], ...]
func _opzioni_visuale() -> Array: return []
## Canali audio regolabili (nomi in Parametri [audio])
func _canali_audio() -> Array: return ["Musica", "Effetti"]
## Righe in più nella sezione PARTITA E GRAFICA: ogni riga è un Control già pronto (_scelta, _riga…) o un Array di Control
func _righe_partita() -> Array: return []
func _nuova_partita() -> void: pass
## Interruttori della grafica messi accanto a «Mostra FPS» (es. segnaposto): Array di Control
func _interruttori_grafica() -> Array: return []
func _riprendi() -> void: chiudi()
func _testo_regole() -> String: return ""
func _testo_missioni() -> String: return ""
func _pagine_crediti() -> Array: return []
## Voci in più in fondo al menu: [["NOME", callable], ...]
func _voci_extra() -> Array: return []
func _nota_comandi() -> String: return ""
## Angolo in alto a sinistra dei due pulsanti rotondi (telecamera, poi ☰), in coordinate del canvas.
func _posizione_icone(schermo: Vector2) -> Vector2: return Vector2(schermo.x - 120, 8)
## Mette / toglie la pausa del gioco.
func _pausa(p: bool) -> void: get_tree().paused = p
func _in_pausa() -> bool: return get_tree().paused
## Usato dai tavoli che devono catturare un tasto (Configura pulsanti): true = evento usato.
func _cattura_input(_e: InputEvent) -> bool: return false
## Suono della scelta (facoltativo)
func _suono_scelta() -> void: pass

# ================================================================ avvio
func prepara_menu() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configura()
	if font == null:
		font = ThemeDB.fallback_font
	if font_titolo == null:
		font_titolo = font
	_icone = Control.new()
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icone)
	_icona_camera = _icona("camera", func(): apri_visuali_rapide() if not rapido_aperto else chiudi_visuali_rapide())
	_icona_menu = _icona("menu", func():
		if rapido_aperto:
			chiudi_visuali_rapide()
		if aperto:
			if not _obbligatoria:
				_indietro_o_chiudi(true)
		else:
			apri())
	_icone.add_child(_icona_camera)
	_icone.add_child(_icona_menu)
	get_viewport().size_changed.connect(_disponi_icone)
	_disponi_icone()

func _disponi_icone() -> void:
	var s := get_viewport().get_visible_rect().size
	var p := _posizione_icone(s)
	_icona_camera.position = p
	_icona_menu.position = p + Vector2(60, 0)
	if aperto and pagina != "":
		_ricostruisci()

func _icona(tipo: String, azione: Callable) -> Button:
	var b := Button.new()
	b.size = Vector2(52, 52)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Menu" if tipo == "menu" else "Visuale"
	b.pressed.connect(func():
		_suono_scelta()
		azione.call())
	b.draw.connect(func():
		b.draw_circle(Vector2(26, 26), 24, Color(0, 0, 0, 0.6))
		b.draw_arc(Vector2(26, 26), 24, 0, TAU, 32, col_a, 3.0, true)
		if tipo == "menu":
			for i in 3:
				b.draw_line(Vector2(15, 17 + i * 9), Vector2(37, 17 + i * 9), Color.WHITE, 3.5, true)
		else:
			b.draw_rect(Rect2(12, 18, 20, 16), Color.WHITE)
			b.draw_colored_polygon(PackedVector2Array([Vector2(32, 22), Vector2(41, 17), Vector2(41, 35), Vector2(32, 30)]), Color.WHITE))
	return b

## Rettangoli dei pulsanti rotondi (per chi deve sapere che un tocco era lì, es. i comandi touch).
func rettangoli_icone() -> Array:
	return [_icona_camera.get_global_rect().grow(8), _icona_menu.get_global_rect().grow(8)]

## Il tocco in questo punto è dell'interfaccia (pulsanti rotondi, tendina o menu aperto)?
func tocco_interfaccia(pos: Vector2) -> bool:
	if aperto or rapido_aperto:
		return true
	for r in rettangoli_icone():
		if r.has_point(pos):
			return true
	return false

# ================================================================ scelta rapida della visuale
func apri_visuali_rapide() -> void:
	if aperto or _visuali().is_empty():
		return
	rapido_aperto = true
	_pausa_rapido = _in_pausa()
	_pausa(true)
	_costruisci_rapido()

func chiudi_visuali_rapide() -> void:
	if not rapido_aperto:
		return
	rapido_aperto = false
	if _rapido:
		_rapido.queue_free()
		_rapido = null
	_navigabili = []
	_pausa(_pausa_rapido)

func _costruisci_rapido() -> void:
	if _rapido:
		_rapido.queue_free()
	_navigabili = []
	_rapido = PanelContainer.new()
	_rapido.add_theme_stylebox_override("panel", _stile_pannello())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_rapido.add_child(v)
	v.add_child(_sezione("VISUALE"))
	var attuale = _visuale_attuale()
	var i := 0
	for vis in _visuali():
		var id = vis[0]
		var b := _pulsante(str(vis[1]), col_a if i % 2 == 0 else col_b, func():
			_imposta_visuale(id)
			visuale_cambiata.emit(id)
			chiudi_visuali_rapide(), id == attuale)
		b.custom_minimum_size = Vector2(250, 52)
		v.add_child(b)
		if id == attuale:
			_sel = i
		i += 1
	add_child(_rapido)
	move_child(_icone, get_child_count() - 1)
	_rapido.reset_size()
	var s := get_viewport().get_visible_rect().size
	var p := _posizione_icone(s)
	_rapido.position = Vector2(clampf(p.x + 112 - _rapido.size.x, 8, s.x - _rapido.size.x - 8), p.y + 60)
	_evidenzia()

## Visuale successiva (tasto V, o chi non usa la tendina).
func visuale_successiva() -> void:
	var lista := _visuali()
	if lista.is_empty():
		return
	var idx := 0
	for i in lista.size():
		if lista[i][0] == _visuale_attuale():
			idx = i
	var id = lista[(idx + 1) % lista.size()][0]
	_imposta_visuale(id)
	visuale_cambiata.emit(id)

# ================================================================ apertura e chiusura
func apri(p := "principale") -> void:
	if rapido_aperto:
		chiudi_visuali_rapide()
	if not aperto:
		_pausa_prima = _in_pausa()
		_pausa(true)
	aperto = true
	pagina = p
	_sel = 0
	_obbligatoria = false
	_ricostruisci()

func chiudi() -> void:
	aperto = false
	pagina = ""
	_obbligatoria = false
	if _strato:
		_strato.queue_free()
		_strato = null
	_navigabili = []
	_pausa(false)

func _indietro_o_chiudi(chiudi_tutto := false) -> void:
	if _obbligatoria:
		return
	if pagina == "principale" or chiudi_tutto:
		_riprendi()
	else:
		apri("principale")

func _ricostruisci() -> void:
	match pagina:
		"principale": _costruisci_principale()
		"regole": pagina_testo("REGOLE", _testo_regole(), [])
		"missioni": pagina_testo("MISSIONI", _testo_missioni(), [])
		_:
			if pagina.begins_with("crediti_"):
				var n := int(pagina.substr(8))
				var pagine := _pagine_crediti()
				var voci: Array = []
				if n < pagine.size():
					voci.append(["AVANTI ▶", func(): _vai("crediti_%d" % (n + 1))])
				if n > 1:
					voci.append(["◀ PRIMA", func(): _vai("crediti_%d" % (n - 1))])
				pagina_testo("CREDITI  %d/%d" % [n, pagine.size()], str(pagine[n - 1]) if n <= pagine.size() else "", voci, false, 15)
			elif not _pagina_testo_args.is_empty():
				callv("_pagina_testo_interna", _pagina_testo_args)

func _vai(p: String) -> void:
	pagina = p
	_sel = 0
	_ricostruisci()

# ================================================================ pagina principale
func _costruisci_principale() -> void:
	var col := _nuovo_strato(false)
	col.add_child(_titolo(titolo))
	col.add_child(_riga([_pulsante("RIPRENDI", col_a, func(): _riprendi()), _pulsante("NUOVA PARTITA", col_b, func():
		chiudi()
		_nuova_partita())]))
	if not _visuali().is_empty():
		col.add_child(_sezione("VISUALE"))
		var nomi: Array = []
		var ids: Array = []
		for v in _visuali():
			ids.append(v[0])
			nomi.append(v[1])
		col.add_child(_scelta(nomi, ids, _visuale_attuale(), func(id):
			_imposta_visuale(id)
			visuale_cambiata.emit(id)))
		var opz := _opzioni_visuale()
		var i := 0
		while i < opz.size():
			var gruppo: Array = []
			for o in opz.slice(i, i + 2):
				if o.size() >= 5 and o[4] is Callable:
					gruppo.append(_pulsante(o[0], col_a, o[4]))          # voce che apre una pagina
				else:
					gruppo.append(_interruttore(o[0], o[1], o[2], o[3]))
			col.add_child(_riga(gruppo))
			i += 2
	col.add_child(_sezione("AUDIO"))
	var canali := _canali_audio()
	var j := 0
	while j < canali.size():
		var gruppo: Array = []
		for c in canali.slice(j, j + 2):
			gruppo.append(_volume(c))
		col.add_child(_riga(gruppo))
		j += 2
	col.add_child(_sezione("PARTITA E GRAFICA  (la qualità vale dal prossimo avvio)"))
	for r in _righe_partita():
		col.add_child(_riga(r) if r is Array else r)
	col.add_child(_scelta(["Grafica bassa", "Media", "Alta"], ["bassa", "media", "alta"], Parametri.qualita(), func(v):
		Parametri.imposta("grafica", "qualita", v)))
	var ultime: Array = _interruttori_grafica() + [_interruttore("Mostra FPS", chiave_fps[0], chiave_fps[1], false)]
	if pubblicita:
		ultime.append(_pulsante("Pubblicità personal.: " + ("SÌ" if bool(Parametri.valore("pubblicita", "consenso", false)) else "NO"), col_a, func():
			pubblicita.cambia_consenso(not bool(Parametri.valore("pubblicita", "consenso", false)))
			_ricostruisci(), bool(Parametri.valore("pubblicita", "consenso", false))))
	var u := 0
	while u < ultime.size():
		col.add_child(_riga(ultime.slice(u, u + 2)))
		u += 2
	col.add_child(_sezione("INFORMAZIONI"))
	col.add_child(_riga([_pulsante("REGOLE", col_a, func(): _vai("regole")), _pulsante("MISSIONI", col_b, func(): _vai("missioni")),
		_pulsante("CREDITI", col_a, func(): _vai("crediti_1"))]))
	var extra := _voci_extra()
	if not extra.is_empty():
		var bottoni: Array = []
		var k := 0
		for e in extra:
			bottoni.append(_pulsante(e[0], col_b if k % 2 == 0 else col_a, e[1]))
			k += 1
		var passo := 3 if bottoni.size() == 3 else 2
		var i := 0
		while i < bottoni.size():
			col.add_child(_riga(bottoni.slice(i, i + passo)))
			i += passo
	var nota_t := _nota_comandi()
	if nota_t != "":
		var nota := _testo(nota_t, 16, Color(col_testo, 0.8))
		nota.autowrap_mode = TextServer.AUTOWRAP_WORD
		nota.custom_minimum_size = Vector2(LARGHEZZA - 40, 0)
		col.add_child(nota)
	_finisci_strato()

# ================================================================ pagine di testo
## Pagina con titolo, testo (scorre solo se è molto lungo) e pulsanti. Sempre con INDIETRO, tranne le pagine
## obbligatorie (consenso alla pubblicità, video con premio) dove si deve scegliere una voce.
func pagina_testo(t: String, testo: String, voci: Array, obbligatoria := false, corpo := 18, in_basso := false) -> void:
	_pagina_testo_args = [t, testo, voci, obbligatoria, corpo, in_basso]
	_pagina_testo_interna(t, testo, voci, obbligatoria, corpo, in_basso)

## Apre il menu direttamente su una pagina di testo (es. proposta del video con premio).
func apri_pagina(nome: String, t: String, testo: String, voci: Array, obbligatoria := false, corpo := 18, in_basso := false) -> void:
	if rapido_aperto:
		chiudi_visuali_rapide()
	if not aperto:
		_pausa_prima = _in_pausa()
		_pausa(true)
	aperto = true
	pagina = nome
	_sel = 0
	pagina_testo(t, testo, voci, obbligatoria, corpo, in_basso)

func _pagina_testo_interna(t: String, testo: String, voci: Array, obbligatoria: bool, corpo: int, in_basso: bool) -> void:
	_obbligatoria = obbligatoria
	var col := _nuovo_strato(in_basso)
	col.add_child(_titolo(t))
	if testo != "":
		var l := _testo(testo, corpo, col_testo)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(LARGHEZZA - 40, 0)
		var s := get_viewport().get_visible_rect().size
		var scorri := ScrollContainer.new()
		scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scorri.custom_minimum_size = Vector2(LARGHEZZA - 30, minf(s.y * 0.62, 760.0))
		scorri.add_child(l)
		col.add_child(scorri)
		# testo corto: niente spazio vuoto
		l.reset_size()
		var h := l.get_combined_minimum_size().y
		if h > 0.0:
			scorri.custom_minimum_size.y = minf(scorri.custom_minimum_size.y, h + 8.0)
	var bottoni: Array = []
	var k := 0
	for v in voci:
		bottoni.append(_pulsante(v[0], col_a if k % 2 == 0 else col_b, v[1]))
		k += 1
	if not obbligatoria:
		bottoni.append(_pulsante("INDIETRO", col_b if k % 2 == 0 else col_a, func(): _indietro_o_chiudi()))
	# al massimo 3 per riga
	var i := 0
	while i < bottoni.size():
		col.add_child(_riga(bottoni.slice(i, i + 3)))
		i += 3
	_finisci_strato()

## Primo avvio dell'APK con pubblicità: scelta del consenso (GDPR). Si cambia poi dal menu.
func chiedi_consenso(scelta: Callable) -> void:
	apri_pagina("consenso", "PUBBLICITÀ", ("Il gioco è gratuito grazie alla pubblicità%s: una pubblicità a fine partita, mai durante il gioco.\n\n" % ((" di " + str(Parametri.valore("pubblicita", "fornitore", ""))) if str(Parametri.valore("pubblicita", "fornitore", "")) != "" else "")) \
		+ "Vuoi pubblicità personalizzate in base ai tuoi interessi? Se scegli NO vedrai pubblicità generiche.\n" \
		+ "Puoi cambiare idea quando vuoi dal menu (☰).", [
			["SÌ, PERSONALIZZATE", func():
				chiudi()
				scelta.call(true)],
			["NO, GENERICHE", func():
				chiudi()
				scelta.call(false)]], true, 22)

## Persa l'ultima pallina (APK con pubblicità, una volta per partita): video con premio = UNA PALLINA in più
## (non una «vita» né una partita nuova). guarda / rifiuta li chiama il tavolo.
func proponi_premio(guarda: Callable, rifiuta: Callable) -> void:
	apri_pagina("premio", "UN'ALTRA PALLINA?", "Guarda un breve video fino alla fine e ricevi UNA PALLINA in più: la partita continua con il punteggio che hai.\nUna volta per partita.", [
		["GUARDA IL VIDEO", func():
			chiudi()
			guarda.call()],
		["NO, GRAZIE", func():
			chiudi()
			rifiuta.call()]], true, 22)

# ================================================================ costruzione
func _nuovo_strato(in_basso: bool) -> VBoxContainer:
	if _strato:
		_strato.queue_free()
	_navigabili = []
	var s := get_viewport().get_visible_rect().size
	_strato = Control.new()
	_strato.size = s
	_strato.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_strato)
	if not in_basso:
		var fondo := ColorRect.new()
		fondo.color = col_fondo
		fondo.size = s
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_strato.add_child(fondo)
	else:
		_strato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pannello := PanelContainer.new()
	pannello.name = "Pannello"
	pannello.add_theme_stylebox_override("panel", _stile_pannello())
	pannello.set_meta("in_basso", in_basso)
	_strato.add_child(pannello)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(LARGHEZZA - 30, 0)
	col.add_theme_constant_override("separation", 8)
	pannello.add_child(col)
	return col

func _finisci_strato() -> void:
	move_child(_icone, get_child_count() - 1)
	var pannello: PanelContainer = _strato.get_node("Pannello")
	pannello.reset_size()
	var s := get_viewport().get_visible_rect().size
	var h := pannello.get_combined_minimum_size().y
	var cima := _posizione_icone(s).y + 64.0
	var x := (s.x - LARGHEZZA) * 0.5
	if pannello.get_meta("in_basso"):
		pannello.position = Vector2(x, maxf(s.y - h - 16.0, cima))
	elif h > s.y - cima - 10.0:
		# schermo basso (orizzontale): si scorre, il pannello resta sotto i pulsanti rotondi
		var col := pannello.get_child(0)
		pannello.remove_child(col)
		var scorri := ScrollContainer.new()
		scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scorri.custom_minimum_size = Vector2(LARGHEZZA - 20, s.y - cima - 30.0)
		scorri.add_child(col)
		pannello.add_child(scorri)
		pannello.position = Vector2(x, cima)
	else:
		pannello.position = Vector2(x, cima + maxf((s.y - cima - h) * 0.3, 0.0))
	_sel = clampi(_sel, 0, maxi(_navigabili.size() - 1, 0))
	_evidenzia()

func _stile_pannello() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col_pannello
	sb.border_color = col_a
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(14)
	return sb

func _titolo(t: String) -> Label:
	var l := _testo(t, 38, col_b, font_titolo)
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(LARGHEZZA - 40, 0)
	return l

func _testo(t: String, corpo: int, colore: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f if f else font)
	l.add_theme_font_size_override("font_size", corpo)
	l.add_theme_color_override("font_color", colore)
	return l

func _sezione(t: String) -> Label:
	var l := _testo(t, 19, col_a)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l

func _stile(colore: Color, pieno: bool, fuoco := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = colore if pieno else Color(0.08, 0.1, 0.14)
	sb.border_color = Color.WHITE if fuoco else colore
	sb.set_border_width_all(5 if fuoco else 3)
	sb.set_corner_radius_all(14)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	return sb

func _pulsante(t: String, colore: Color, azione: Callable, pieno := true) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, ALTEZZA_PULSANTE)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _stile(colore, pieno))
	b.set_meta("colore", colore)
	b.set_meta("pieno", pieno)
	b.pressed.connect(func():
		_sel = maxi(_navigabili.find(b), 0)
		_suono_scelta()
		azione.call())
	_navigabili.append(b)
	return b

## Riga di controlli larghi uguali.
func _riga(controlli: Array) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	for c in controlli:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(c)
	return r

## Scelta tra più valori: il valore attuale è il pulsante pieno.
func _scelta(nomi: Array, valori: Array, attuale, azione: Callable) -> HBoxContainer:
	var controlli: Array = []
	for i in nomi.size():
		var v = valori[i]
		controlli.append(_pulsante(nomi[i], col_a if i % 2 == 0 else col_b, func():
			azione.call(v)
			_ricostruisci(), v == attuale))
	return _riga(controlli)

## Interruttore SÌ/NO salvato in Parametri: pieno = acceso.
func _interruttore(nome: String, sezione: String, chiave: String, predefinito := true) -> Button:
	var acceso := bool(Parametri.valore(sezione, chiave, predefinito))
	return _pulsante(nome + (": SÌ" if acceso else ": NO"), col_a, func():
		Parametri.imposta(sezione, chiave, not acceso)
		_ricostruisci(), acceso)

## Volume a passi del 10%: [−] MUSICA 80% [+] (funziona col dito e coi pulsanti fisici).
func _volume(canale: String) -> HBoxContainer:
	return _regolatore(canale.to_upper(), "audio", canale, 0.8, 0.0, 1.0, 0.1)

## Valore a passi: [−] NOME 80% [+]. dopo(valore) viene chiamato a ogni cambio (es. applicare subito le luci).
func _regolatore(nome: String, sezione: String, chiave: String, predefinito: float, minimo: float, massimo: float,
		passo: float, dopo := Callable()) -> HBoxContainer:
	var v := float(Parametri.valore(sezione, chiave, predefinito))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	var cambia := func(d: float):
		var n := snappedf(clampf(v + d, minimo, massimo), passo)
		Parametri.imposta(sezione, chiave, n)
		if dopo.is_valid():
			dopo.call(n)
		_ricostruisci()
	var meno := _pulsante("−", col_b, func(): cambia.call(-passo))
	meno.custom_minimum_size.x = 56
	var l := _testo("%s %d%%" % [nome, int(round(v * 100))], 18, col_testo)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	var piu := _pulsante("+", col_a, func(): cambia.call(passo))
	piu.custom_minimum_size.x = 56
	r.add_child(meno)
	r.add_child(l)
	r.add_child(piu)
	return r

## Pagine dei crediti del motore, uguali in tutti i flipper: licenza MIT di Godot (obbligatoria) e componenti.
static func crediti_godot() -> Array:
	var paragrafi := PackedStringArray()
	for par in Engine.get_license_text().strip_edges().split("\n\n"):
		paragrafi.append(par.replace("\n", " "))
	var nomi := PackedStringArray()
	for c in Engine.get_copyright_info():
		if str(c["name"]) != "Godot Engine":
			nomi.append(str(c["name"]))
	return ["Realizzato con Godot Engine (godotengine.org), licenza MIT:\n\n" + "\n\n".join(paragrafi),
		"Portions of this software are copyright © The FreeType Project (www.freetype.org). All rights reserved.\n\n" \
		+ "Il motore Godot contiene anche questi componenti open source, con le loro licenze permissive: " + ", ".join(nomi) + "."]

# ================================================================ pulsanti fisici
func _evidenzia() -> void:
	for i in _navigabili.size():
		var b: Button = _navigabili[i]
		if not is_instance_valid(b):
			continue
		var st := _stile(b.get_meta("colore"), b.get_meta("pieno"), i == _sel)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)

func _input(e: InputEvent) -> void:
	if not (aperto or rapido_aperto):
		return
	if _cattura_input(e):
		get_viewport().set_input_as_handled()
		return
	if not (e is InputEventKey or e is InputEventJoypadButton or e is InputEventAction):
		return
	if not e.is_pressed() or e.is_echo():
		# anche il rilascio non deve arrivare al tavolo (palette)
		if e.is_action("paletta_sx") or e.is_action("paletta_dx") or e.is_action("lancio"):
			get_viewport().set_input_as_handled()
		return
	var su: bool = e.is_action_pressed("paletta_sx") or (e is InputEventKey and (e.keycode == KEY_UP or e.keycode == KEY_LEFT))
	var giu: bool = e.is_action_pressed("paletta_dx") or (e is InputEventKey and (e.keycode == KEY_DOWN or e.keycode == KEY_RIGHT))
	var ok: bool = e.is_action_pressed("lancio") or e.is_action_pressed("start") or (e is InputEventKey and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_SPACE))
	var via: bool = e.is_action_pressed("pausa") or (e is InputEventKey and e.keycode == KEY_ESCAPE)
	if su or giu:
		if not _navigabili.is_empty():
			_sel = (_sel + (-1 if su else 1) + _navigabili.size()) % _navigabili.size()
			_evidenzia()
	elif ok:
		if _sel < _navigabili.size() and is_instance_valid(_navigabili[_sel]):
			(_navigabili[_sel] as Button).pressed.emit()
	elif via:
		if rapido_aperto:
			chiudi_visuali_rapide()
		else:
			_indietro_o_chiudi()
	elif e is InputEventKey and e.keycode == KEY_V and rapido_aperto:
		chiudi_visuali_rapide()
	else:
		return
	get_viewport().set_input_as_handled()

# ================================================================ prove automatiche
## Per i test: tutti i pulsanti visibili adesso, con il testo.
func pulsanti_visibili() -> Array:
	var r: Array = []
	for b in _navigabili:
		if is_instance_valid(b):
			r.append(b)
	return r

func premi(testo: String) -> bool:
	for b in pulsanti_visibili():
		if (b as Button).text.begins_with(testo):
			(b as Button).pressed.emit()
			return true
	return false

## Altezza del pannello attuale (per controllare che stia nello schermo senza scorrere).
func pannello_rect() -> Rect2:
	if _strato and _strato.has_node("Pannello"):
		var p: Control = _strato.get_node("Pannello")
		return Rect2(p.position, p.get_combined_minimum_size().max(p.size))
	if _rapido:
		return Rect2(_rapido.position, _rapido.size)
	return Rect2()
