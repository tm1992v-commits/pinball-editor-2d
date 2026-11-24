## Vista del tavolo nel Pinball Editor 2D (v0.1, 23/11/2026): il tavolo dall'alto in millimetri veri.
## Mouse: clic = seleziona · trascina = sposta (anche i quadratini dei punti) · rotella = zoom · tasto destro o centrale
## trascinato = scorre · doppio clic su un muro selezionato = aggiunge un punto · clic destro su un quadratino = toglie
## il punto. Con un pezzo scelto nella libreria, il clic sul tavolo lo aggiunge (i muri: un clic per punto, Invio o
## doppio clic per finire, Esc per annullare).
## Il disegno qui è SOLO per costruire (lo strumento): il gioco usa la sua grafica, prerenderizzata col BAKE.
class_name VistaTavolo
extends Control

signal pezzo_cliccato(id: String)       # v0.21: ogni clic su un pezzo (anche già scelto): simulatore
signal selezione_cambiata(id: String)
signal posizione_mouse(mm: Vector2)
signal messaggio(testo: String)
signal punto_scelto(indice: int)
## tracciatore (v0.9.5): clic = punto di partenza, trascina = direzione e forza, rilascia = tiro
signal traccia_richiesta(da: Vector2, vel: Vector2)
var _traccia_da := Vector2(-1, -1)
## righello (v0.16): ultima misura fatta (da, a), resta sul tavolo finché non se ne fa un'altra o si cambia strumento
var righello_da := Vector2(-1, -1)
var righello_a := Vector2(-1, -1)
const TRACCIA_K := 6.0
var mostra_collisioni := false        # v0.19: guide delle collisioni (solo nell'editor, mai nel gioco)
const C_COLL := Color(0.2, 1.0, 0.95, 0.9)              # mm/s di forza per ogni mm trascinato

const PRIORITA := ["palette", "captive", "bumper", "bersagli", "spinner", "cancelli", "buche", "elastici", "kickback", "sensori", "campi",
	"inserti", "fionde", "lame", "porte", "muri", "rampe", "nastri", "piani", "decorazioni"]
const C_SFONDO := Color(0.09, 0.09, 0.11)
const C_SEL := Color(1.0, 0.9, 0.2)

var progetto: ProgettoEditor
var scala := 0.7                       # pixel per mm
var origine := Vector2(40, 20)         # pixel dove sta lo 0,0 del tavolo
var griglia := true
var passo_griglia := 5.0               # mm (aggancio)
var aggancio := true
var mostra_problemi := true
var selezionato := ""                  # pezzo principale scelto (quello del pannello)
var selezionati: Array = []            # tutti i pezzi scelti (Maiusc+clic, rettangolo)
var _rett_da := Vector2(-1, -1)        # selezione a rettangolo (mm), -1 = nessuna
var _centri0 := {}                     # id -> centro all'inizio del trascinamento di gruppo
var da_inserire := ""                  # tipo di pezzo scelto nella libreria ("" = selezione)
var problemi: Array = []
var evidenziato := Vector2(-1, -1)     # problema scelto nell'elenco
var _muro_nuovo := PackedVector2Array()
var _muro_nuovo_curvi: Array = []
var punto := -1                        # punto di controllo scelto (muri): per Curvo / Fionda nel pannello
var _trascina := ""                    # "pezzo" | "punto" | "vista"
var _punto_trascinato := -1
var _ultimo_mm := Vector2.ZERO
var _inizio_trascina := Vector2.ZERO
var _mosso := false
var _font: Font

var _barra_disegno: PanelContainer
var _testo_disegno: Label

func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	_font = get_theme_default_font()
	resized.connect(adatta)
	# per terminare»): pulsanti grandi Fine / Annulla e cosa fare
	_barra_disegno = PanelContainer.new()
	_barra_disegno.position = Vector2(12, 12)
	_barra_disegno.visible = false
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(0.1, 0.1, 0.14, 0.92)
	stile.border_color = Color(1, 0.9, 0.2)
	stile.set_border_width_all(2)
	stile.set_corner_radius_all(6)
	stile.set_content_margin_all(8)
	_barra_disegno.add_theme_stylebox_override("panel", stile)
	var col := VBoxContainer.new()
	_barra_disegno.add_child(col)
	_testo_disegno = Label.new()
	col.add_child(_testo_disegno)
	var riga := HBoxContainer.new()
	col.add_child(riga)
	var fine := Button.new()
	fine.text = "  ✔  FINE  "
	fine.add_theme_font_size_override("font_size", 18)
	fine.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	fine.focus_mode = Control.FOCUS_NONE
	fine.tooltip_text = "Finisce il disegno (anche: clic destro, Invio, doppio clic)"
	fine.pressed.connect(finisci_muro)
	riga.add_child(fine)
	var no := Button.new()
	no.text = "  ✖  Annulla  "
	no.add_theme_font_size_override("font_size", 18)
	no.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	no.focus_mode = Control.FOCUS_NONE
	no.tooltip_text = "Butta via il disegno in corso (Esc)"
	no.pressed.connect(func(): annulla_disegno(); messaggio.emit("Disegno annullato"))
	riga.add_child(no)
	var togli := Button.new()
	togli.text = "  ↶ Togli l'ultimo punto  "
	togli.focus_mode = Control.FOCUS_NONE
	togli.pressed.connect(func():
		if not _muro_nuovo.is_empty():
			_muro_nuovo.remove_at(_muro_nuovo.size() - 1)
			_muro_nuovo_curvi.pop_back()
			_aggiorna_barra()
			queue_redraw())
	riga.add_child(togli)
	add_child(_barra_disegno)

## Sta disegnando un muro, una rampa o un nastro?
func disegno_in_corso() -> bool:
	return not _muro_nuovo.is_empty()

## Chiude il disegno in corso (se ha almeno 2 punti lo crea, altrimenti lo butta): prima di GIOCA, Salva, ecc.
func chiudi_disegno() -> void:
	if _muro_nuovo.size() >= 2:
		finisci_muro()
	else:
		annulla_disegno()

func annulla_disegno() -> void:
	_muro_nuovo.clear()
	_muro_nuovo_curvi.clear()
	_aggiorna_barra()
	queue_redraw()

func _aggiorna_barra() -> void:
	_barra_disegno.visible = not _muro_nuovo.is_empty()
	var cosa: String = {"muri": "MURO", "rampe": "RAMPA", "nastri": "NASTRO", "piani": "PIANO RIALZATO"}.get(da_inserire, "FORMA")
	if da_inserire == "rampe":
		_testo_disegno.text = "Stai disegnando: RAMPA · %d punti  (clic = punto; la rampa è sempre morbida)" % _muro_nuovo.size()
	else:
		_testo_disegno.text = "Stai disegnando: %s · %d punti  (clic = punto ad angolo, Maiusc+clic = punto CURVO)" % [cosa, _muro_nuovo.size()]

## Punto del tavolo (mm) al centro della vista: dove nascono gli elementi nuovi.
func centro_vista() -> Vector2:
	return ((size * 0.5 - origine) / maxf(scala, 0.001)).snapped(Vector2(5, 5))

func adatta() -> void:
	if progetto == null or progetto.desc.is_empty():
		return
	var dim: Vector2 = progetto.desc.get("dimensioni", Vector2(635, 1240))
	var tutto := dim + Vector2(0, 70)          # sotto il tavolo: scarico e grembiuli
	if anteprima_tel > 0.0:
		# v0.25: con l'anteprima telefono si inquadra tutto lo schermo del telefono (con il tabellone)
		var rt := _rett_telefono()
		scala = minf((size.x - 30.0) / rt.size.x, (size.y - 40.0) / rt.size.y)
		origine = size * 0.5 - rt.get_center() * scala + Vector2(0, 8)
		queue_redraw()
		return
	scala = minf((size.x - 30.0) / tutto.x, (size.y - 20.0) / tutto.y)
	origine = (size - tutto * scala) * 0.5
	queue_redraw()

func mm(px: Vector2) -> Vector2:
	return (px - origine) / scala

func px(m: Vector2) -> Vector2:
	return origine + m * scala

func centra_su(m: Vector2) -> void:
	origine = size * 0.5 - m * scala
	queue_redraw()

# ================================================================ disegno
## v0.25 ANTEPRIMA TELEFONO: riquadro dello schermo del telefono (20:9 = 720×1600, 16:9 = 720×1280) con il tabellone,
## calcolato come la telecamera del gioco (Vista2D): fuori dal riquadro si scurisce. 0 = spenta.
var anteprima_tel := 0.0

## Lo schermo del telefono in mm del tavolo (come la telecamera del gioco).
func _rett_telefono() -> Rect2:
	var dim: Vector2 = progetto.desc["dimensioni"]
	var hud := Hud.altezza_di(progetto.desc)
	var sp := Vista2D.sporge_di(progetto.desc)
	var M := Vista2D.MARGINE
	var z := minf(720.0 / (dim.x + 2.0 * M), (anteprima_tel - hud) / (dim.y + sp + 2.0 * M))
	var c := Vector2(dim.x * 0.5, (dim.y - sp) * 0.5 - hud * 0.5 / z)
	var mezzo := Vector2(720.0, anteprima_tel) / z * 0.5
	return Rect2(c - mezzo, mezzo * 2.0)

func _disegna_telefono() -> void:
	if anteprima_tel <= 0.0 or progetto.desc.is_empty():
		return
	var hud := Hud.altezza_di(progetto.desc)
	var rm := _rett_telefono()
	var z := 720.0 / rm.size.x
	var r := Rect2(px(rm.position), rm.size * scala)
	var buio := Color(0, 0, 0, 0.55)
	var tutto := get_rect().size
	draw_rect(Rect2(0, 0, tutto.x, r.position.y), buio)
	draw_rect(Rect2(0, r.end.y, tutto.x, tutto.y - r.end.y), buio)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), buio)
	draw_rect(Rect2(r.end.x, r.position.y, tutto.x - r.end.x, r.size.y), buio)
	var banda := Rect2(r.position, Vector2(r.size.x, hud / z * scala))
	draw_rect(banda, Color(0.05, 0.05, 0.08, 0.85))
	draw_string(_font, banda.get_center() + Vector2(-60, 5), "TABELLONE (punti)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.85, 1.0))
	draw_rect(r.grow(6.0), Color(0.85, 0.85, 0.9), false, 6.0)
	draw_string(_font, r.position + Vector2(4, -10), "📱 telefono %s" % ("20:9" if anteprima_tel > 1500.0 else "16:9"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.9))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_SFONDO)
	if progetto == null or progetto.desc.is_empty():
		draw_string(_font, Vector2(30, 60), "Nessun tavolo aperto: premi NUOVO o APRI", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.8))
		return
	var d := _desc_visibile()
	var dim: Vector2 = d.get("dimensioni", Vector2(635, 1240))
	var col: Dictionary = d.get("colori", {}) if d.get("colori", {}) is Dictionary else {}
	var piano: Color = col.get("piano", Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(px(Vector2.ZERO), dim * scala), piano.lightened(0.05))
	var base := Transform2D(0.0, Vector2(scala, scala), 0.0, origine)
	# v0.6: fondo dipinto e immagini sul piano (sotto tutti i pezzi)
	if PittorePezzi.fondo(self, d, base):
		draw_set_transform_matrix(Transform2D.IDENTITY)
	for de in d.get("decorazioni", []):
		if not bool(de.get("sopra", false)):
			_disegna_decorazione(de, d, base)
	PittorePezzi.ambiente_sul_piano(self, d, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if griglia:
		_disegna_griglia(dim)
	for p in d.get("passaggi", []):
		_linea_tratteggiata(p.get("percorso", PackedVector2Array()), Color(0.7, 0.4, 1.0, 0.6), 2.0)
	for c in d.get("campi", []):
		var cpos: Vector2 = c["pos"]
		draw_arc(px(cpos), float(c["raggio"]) * scala, 0, TAU, 40, Color(0.75, 0.4, 1.0, 0.7), 1.5)
		draw_circle(px(cpos), 5.0 * scala, Color(0.75, 0.4, 1.0))
	# luci del piano: la forma vera (v0.8), mezze accese per vederne il colore
	for i in d.get("inserti", []):
		draw_set_transform_matrix(base)
		PittorePezzi.luce(self, i, d, 0.7)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for s in d.get("sensori", []):
		_rettangolo(s["pos"], s["dim"], 0.0, Color(0.4, 1.0, 0.5), false)
	for k in d.get("kickback", []):
		PittorePezzi.disegna(self, "kickback", k, d, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for nn in d.get("nastri", []):
		if CurveEditor.nastro_alto(nn):
			continue                    # i nastri sollevati si disegnano dopo i pezzi del piano (sono sopra)
		CurveEditor.disegna_nastro(self, nn, px, scala)
	for r in d.get("rampe", []):
		_disegna_rampa(r)
	for m in d.get("muri", []):
		if not m.has("da_nastro") and not m.has("da_piano"):
			_disegna_muro(m, d, base)
	# v0.9: piani rialzati (sopra i pezzi del tavolo, sotto i pezzi che stanno sul piano)
	for pr in d.get("piani", []):
		PittorePezzi.disegna(self, "piani", pr, d, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for po in d.get("porte", []):
		_polilinea(po["punti"], Color(0.95, 0.45, 0.45), 4.0)
	# v0.15: deviatori sul piano: posizione di partenza piena, l'altra tratteggiata, arco del movimento
	for la in d.get("lame", []):
		var pp: Vector2 = la["perno"]
		var lun := float(la.get("lunghezza", 55.0))
		var in_b := str(la.get("posizione", "a")) == "b"
		var pa := pp + Vector2(lun, 0).rotated(float(la.get("angolo_a", 0.0)))
		var pb := pp + Vector2(lun, 0).rotated(float(la.get("angolo_b", 0.0)))
		_linea_tratteggiata(PackedVector2Array([pp, pb if not in_b else pa]), Color(0.8, 0.85, 0.95, 0.6), 2.0)
		draw_line(px(pp), px(pa if not in_b else pb), Color(0.85, 0.87, 0.95), maxf(2.0, 4.0 * scala))
		draw_circle(px(pp), maxf(3.0, 4.5 * scala), Color(0.95, 0.75, 0.3))
		if scala > 0.5:
			draw_string(_font, px(pp) + Vector2(-8, -10), "A" if not in_b else "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	# v0.17.2: pallina prigioniera (il canale è un muro generato, disegnato con i muri): pallina e bersaglio in fondo
	for cb in d.get("captive", []):
		if not cb.has("bersaglio"):
			continue
		var bz: Vector2 = cb["bersaglio"]
		var dz: Vector2 = (bz - Vector2(cb["casa"])).normalized()
		draw_line(px(bz - dz.orthogonal() * 13.0), px(bz + dz.orthogonal() * 13.0), Color(1.0, 0.85, 0.3), maxf(2.0, 5.0 * scala))
		draw_circle(px(Vector2(cb["casa"])), 13.5 * scala, Color(0.78, 0.8, 0.85))
		draw_circle(px(Vector2(cb["casa"]) + Vector2(-4, -4)), 4.0 * scala, Color(1, 1, 1, 0.8))
	# pezzi col disegno del gioco (PittorePezzi: piatto o effetto 3D, colore proprio o del tavolo)
	for chiave in ["buche", "fionde", "bumper", "elastici", "bersagli", "spinner", "cancelli", "palette"]:
		for e in d.get(chiave, []):
			PittorePezzi.disegna(self, chiave, e, d, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# cancelletti: freccia del verso in cui passa la pallina (solo nell'editor)
	for cg in d.get("cancelli", []):
		var dirc := Vector2(0, -1).rotated(float(cg.get("angolo", 0.0)))
		var pc: Vector2 = cg["pos"]
		draw_line(px(pc + dirc * 6.0), px(pc + dirc * 26.0), Color(0.5, 1.0, 0.6), 2.0)
		var pu := px(pc + dirc * 30.0)
		var lat := dirc.orthogonal() * 6.0 * scala
		draw_colored_polygon(PackedVector2Array([pu, pu - dirc * 9.0 * scala + lat, pu - dirc * 9.0 * scala - lat]), Color(0.5, 1.0, 0.6))
	for nn in d.get("nastri", []):
		if not CurveEditor.nastro_alto(nn):
			continue
		CurveEditor.disegna_nastro(self, nn, px, scala)
		# v0.5: il nastro sollevato si vede più in alto (vista 3D): qui la sua «pianta» sul piano, dove stanno i punti
		if not PittorePezzi.piatto(nn, d):
			var eb := CurveEditor.espandi_nastro(nn)
			var bb := CurveEditor.bordi_nastro(eb[0], eb[1])
			_linea_tratteggiata(bb[0], Color(1, 1, 1, 0.35), 1.0)
			_linea_tratteggiata(bb[1], Color(1, 1, 1, 0.35), 1.0)
	for de in d.get("decorazioni", []):
		if bool(de.get("sopra", false)):
			_disegna_decorazione(de, d, base)
	_disegna_lancio(d)
	_disegna_collisioni(d)
	_disegna_selezione()
	if not _muro_nuovo.is_empty():
		_disegna_anteprima()
	_disegna_traccia()
	_disegna_righello()
	if mostra_problemi:
		_disegna_problemi()
	_disegna_telefono()

## v0.19 (elementi da immagine): forma VERA di collisione dei pezzi, in azzurro. Sempre per i pezzi con l'immagine
## «al posto del disegno» (lì l'immagine non dice dove sbatte la pallina); per tutti con «Collisioni» acceso.
func _disegna_collisioni(d: Dictionary) -> void:
	var w := maxf(1.0, 1.5 * scala)
	for chiave in ["bumper", "elastici", "buche"]:
		for e in d.get(chiave, []):
			if not mostra_collisioni and not PittorePezzi.sostituisce(e):
				continue
			var c: Vector2 = e["pos"]
			var r := float(e.get("raggio", 10.0))
			var ry := float(e.get("raggio_y", r)) if chiave == "bumper" else r
			var rot := float(e.get("angolo_coll", 0.0)) if chiave == "bumper" else 0.0
			var pts := PackedVector2Array()
			for i in 41:
				var a := TAU * i / 40.0
				pts.append(px(c + Vector2(cos(a) * r, sin(a) * ry).rotated(rot)))
			draw_polyline(pts, C_COLL, w)
	for chiave in ["bersagli", "kickback"]:
		for e in d.get(chiave, []):
			if not mostra_collisioni and not PittorePezzi.sostituisce(e):
				continue
			var h: Vector2 = Vector2(e.get("dim", Vector2(24, 8))) * 0.5
			var ang := float(e.get("angolo", 0.0))
			var c2: Vector2 = e["pos"]
			var q := PackedVector2Array()
			for v in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y)]:
				q.append(px(c2 + v.rotated(ang)))
			draw_polyline(q, C_COLL, w)
	for e in d.get("muri", []):
		if not (mostra_collisioni or PittorePezzi.sostituisce(e)) or e.has("da_nastro") or e.has("da_piano"):
			continue
		var pm: Array = Array(e.get("punti", []))
		if bool(e.get("chiuso", false)) and pm.size() > 2:
			pm.append(pm[0])
		_polilinea(pm, C_COLL, w)
	for f in d.get("fionde", []):
		if not (mostra_collisioni or PittorePezzi.sostituisce(f)):
			continue
		var pf: Array = Array(f["punti"])
		pf.append(pf[0])
		_polilinea(pf, C_COLL, w)

func _disegna_righello() -> void:
	if da_inserire != "righello" or righello_da.x < 0.0:
		return
	var a := px(righello_da)
	var b := px(righello_a)
	var col := Color(1.0, 0.85, 0.2)
	draw_line(a, b, Color(0, 0, 0, 0.6), 4.0)
	draw_line(a, b, col, 2.0)
	var lun := righello_da.distance_to(righello_a)
	if lun > 1.0:
		var dir := (righello_a - righello_da) / lun
		var nrm := dir.orthogonal()
		var k := 10.0
		while k < lun:
			var q := righello_da + dir * k
			var lung_t := 6.0 if int(k) % 50 == 0 else 3.0
			draw_line(px(q - nrm * lung_t), px(q + nrm * lung_t), col, 1.0)
			k += 10.0
	for q in [a, b]:
		draw_circle(q, 4.0, col)
	draw_string(_font, b + Vector2(10, -8), "%.0f mm · %.0f°" % [lun, rad_to_deg((righello_a - righello_da).angle())], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

## Velocità del tiro dal trascinamento: verso = dove trascini, forza = lunghezza × 6 (100-3200 mm/s);
## un clic senza trascinare = dritto in alto a 1500 mm/s.
static func vel_traccia(da: Vector2, a: Vector2) -> Vector2:
	var d := a - da
	if d.length() < 5.0:
		return Vector2(0, -1500)
	return d.normalized() * clampf(d.length() * TRACCIA_K, 100.0, 3200.0)

static func colore_velocita(v: float) -> Color:
	return Color.from_hsv(lerpf(0.62, 0.0, clampf(v / 2600.0, 0.0, 1.0)), 0.85, 1.0)

## Freccia del tiro mentre trascini e percorsi dell'ultimo tiro (colore = velocità: blu lento → rosso veloce;
## tratteggio = sopra una rampa; pallini bianchi = colpi, con il nome; croce = dove è finita).
func _disegna_traccia() -> void:
	if _trascina == "traccia":
		var v := vel_traccia(_traccia_da, _ultimo_mm)
		var a := px(_traccia_da)
		var b := a + v.normalized() * maxf(30.0, v.length() / TRACCIA_K * scala)
		draw_circle(a, 13.5 * scala, Color(0.9, 0.9, 0.95, 0.8))
		draw_line(a, b, colore_velocita(v.length()), 3.0)
		var lat := v.normalized().orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([b + v.normalized() * 10.0, b + lat, b - lat]), colore_velocita(v.length()))
		draw_string(_font, b + Vector2(10, -6), "%.0f mm/s" % v.length(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var tr: Dictionary = progetto.ultima_traccia if progetto else {}
	if tr.is_empty() or not bool(tr.get("ok", false)) or da_inserire != "traccia":
		return
	# v0.16: mappa di calore (quadretti di 20 mm: più passaggi = più caldo)
	if tr.has("calore"):
		var cal: Dictionary = tr["calore"]
		var mx := 1.0
		for k in cal:
			mx = maxf(mx, float(cal[k]))
		var lato := float(tr.get("cella", 20.0))
		for k in cal:
			var xy: PackedStringArray = str(k).split(",")
			var f := sqrt(float(cal[k]) / mx)
			var col := Color.from_hsv(lerpf(0.62, 0.0, f), 0.9, 1.0, 0.25 + 0.5 * f)
			draw_rect(Rect2(px(Vector2(float(xy[0]), float(xy[1])) * lato), Vector2(lato, lato) * scala), col)
		return
	if not tr.has("ventaglio"):
		draw_circle(px(tr["da"]), 13.5 * scala, Color(0.9, 0.9, 0.95, 0.5))
	for t in tr.get("tiri", []):
		var pts: Array = t.get("punti", [])
		for i in range(1, pts.size()):
			var p0: Array = pts[i - 1]
			var p1: Array = pts[i]
			var alta := float(p1[3]) > 1.0
			if alta and i % 3 == 0:
				continue
			draw_line(px(Vector2(p0[0], p0[1])), px(Vector2(p1[0], p1[1])), colore_velocita(float(p1[2])), 2.5 if not alta else 4.0)
		for e in t.get("eventi", []):
			var q := px(Vector2(e[3], e[4]))
			draw_circle(q, 5.0, Color.WHITE)
			if scala > 0.5:
				draw_string(_font, q + Vector2(7, 4), str(e[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.85))
		if not pts.is_empty():
			var f := px(Vector2(pts[-1][0], pts[-1][1]))
			var col_f := Color(1, 0.3, 0.3) if str(t["fine"]) in ["ferma", "fuori"] else Color(1, 1, 1)
			draw_line(f + Vector2(-6, -6), f + Vector2(6, 6), col_f, 2.5)
			draw_line(f + Vector2(-6, 6), f + Vector2(6, -6), col_f, 2.5)

## Linea che si sta disegnando, GIÀ con le curve (24/11: prima era sempre dritta e Maiusc+clic sembrava non fare
## niente): punto curvo = cerchio, punto ad angolo = quadratino; il punto sotto il mouse è curvo se si tiene Maiusc.
func _disegna_anteprima() -> void:
	var ctrl := _muro_nuovo.duplicate()
	var curvi: Array = _muro_nuovo_curvi.duplicate()
	ctrl.append(_ultimo_mm)
	curvi.append(Input.is_key_pressed(KEY_SHIFT))
	var linea := PackedVector2Array()
	if da_inserire == "rampe":
		# la rampa è sempre morbida (il motore la leviga): si mostra come sarà
		var grezzi: Array = []
		for q in ctrl:
			grezzi.append(Vector3(q.x, q.y, 0.0))
		for q in Binario.levigato(grezzi):
			linea.append(Vector2(q.x, q.y))
	else:
		var m := {"controllo": ctrl, "curvi": curvi, "chiuso": da_inserire == "piani" and ctrl.size() >= 3}
		CurveEditor.rigenera(m)
		linea = m["punti"]
	_polilinea(linea, C_SEL, 3.0)
	for i in _muro_nuovo.size():
		var q := px(_muro_nuovo[i])
		if da_inserire != "rampe" and i < _muro_nuovo_curvi.size() and bool(_muro_nuovo_curvi[i]):
			draw_arc(q, 6.0, 0, TAU, 16, C_SEL, 2.5)
		else:
			draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), C_SEL)

## Immagine sul piano; senza immagine, un riquadro tratteggiato con la scritta (si sceglie l'immagine a destra).
func _disegna_decorazione(de: Dictionary, d: Dictionary, base: Transform2D) -> void:
	if not PittorePezzi.decorazione(self, de, d, base):
		var dimd: Vector2 = de.get("dim", Vector2(100, 100))
		draw_set_transform_matrix(base * Transform2D(float(de.get("angolo", 0.0)), de["pos"]))
		draw_rect(Rect2(-dimd * 0.5, dimd), Color(0.6, 0.9, 0.6, 0.12))
		draw_rect(Rect2(-dimd * 0.5, dimd), Color(0.6, 0.9, 0.6, 0.8), false, 1.0 / scala)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_string(_font, px(de["pos"]) + Vector2(-40, 4), "scegli l'immagine", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.95, 0.7))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _disegna_griglia(dim: Vector2) -> void:
	var passo := 10.0 if scala > 1.2 else 50.0
	var c := Color(1, 1, 1, 0.05)
	var x := 0.0
	while x <= dim.x:
		draw_line(px(Vector2(x, 0)), px(Vector2(x, dim.y)), Color(1, 1, 1, 0.1) if fmod(x, 100.0) < 0.1 else c)
		x += passo
	var y := 0.0
	while y <= dim.y:
		draw_line(px(Vector2(0, y)), px(Vector2(dim.x, y)), Color(1, 1, 1, 0.1) if fmod(y, 100.0) < 0.1 else c)
		y += passo

func _disegna_muro(m: Dictionary, d: Dictionary, base: Transform2D) -> void:
	PittorePezzi.disegna(self, "muri", m, d, base)
	PittorePezzi.gomme_tratti(self, m, PittorePezzi.piatto(m, d))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if bool(m.get("senso_unico", false)):
		_linea_tratteggiata(m["punti"], Color(0.5, 1.0, 1.0), 2.0)

func _disegna_rampa(r: Dictionary) -> void:
	if r.has("da_nastro"):
		return                      # nastro sollevato: già disegnato come nastro (con ombra e fianchi)
	if r["punti"].size() < 2:
		return
	# v0.19: rampa da immagine: si vede l'immagine; sopra resta solo la linea del percorso (guida dell'editor)
	if PittorePezzi.ha_immagine(r):
		var base := Transform2D(0.0, Vector2(scala, scala), 0.0, origine)
		PittorePezzi.disegna_immagine(self, r, progetto.desc, PittorePezzi.ancora("rampe", r, progetto.desc), base)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if PittorePezzi.sostituisce(r):
			_linea_tratteggiata(_linea_rampa(r), Color(0.2, 1.0, 0.95, 0.9), 2.0)
			var mz := float(r.get("larghezza", 38.0)) * 0.5
			for lato in [1.0, -1.0]:
				var bordo: Array = []
				var lr := _linea_rampa(r)
				for i in lr.size():
					var dd: Vector2 = (lr[mini(i + 1, lr.size() - 1)] - lr[maxi(i - 1, 0)]).normalized()
					bordo.append(lr[i] + dd.orthogonal() * mz * lato)
				_polilinea(bordo, Color(0.2, 1.0, 0.95, 0.5), 1.0)
			return
	# 24/11: la stessa linea morbida del gioco (prima qui era a spigoli), col colore e l'imbocco della rampa
	var linea := _linea_rampa(r)
	var pts := PackedVector2Array()
	for q in linea:
		pts.append(px(q))
	var col: Color = PittorePezzi.colore("rampe", r, progetto.desc)
	draw_polyline(pts, Color(col, 0.25), maxf(3.0, 34.0 * scala))
	if r.has("invito") and pts.size() > 1:
		var d0 := (pts[1] - pts[0]).normalized()
		var n0 := Vector2(-d0.y, d0.x) * float(r["invito"]) * scala
		draw_line(pts[0] + n0, pts[0] + n0 * 0.76 + d0 * 30.0 * scala, Color(col, 0.8), 2.0)
		draw_line(pts[0] - n0, pts[0] - n0 * 0.76 + d0 * 30.0 * scala, Color(col, 0.8), 2.0)
	draw_polyline(pts, col, 2.0)
	if bool(r.get("frecce", false)):
		var acc := 0.0
		for i in range(1, linea.size()):
			acc += linea[i].distance_to(linea[i - 1])
			if acc >= 60.0:
				acc = 0.0
				var dz := (pts[i] - pts[i - 1]).normalized()
				var lat := Vector2(-dz.y, dz.x) * 6.0 * scala
				draw_colored_polygon(PackedVector2Array([pts[i] + dz * 7.0 * scala, pts[i] - dz * 4.0 * scala + lat, pts[i] - dz * 4.0 * scala - lat]), Color(1, 1, 1, 0.8))
	var fine: Vector2 = pts[pts.size() - 1]
	draw_circle(fine, 4.0, col)
	if scala > 0.5:
		draw_string(_font, pts[0] + Vector2(6, -6), str(r.get("nome", r["id"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col.lightened(0.3))

## Linea della rampa come la fa il motore (morbida, Binario.levigato).
func _linea_rampa(r: Dictionary) -> PackedVector2Array:
	var grezzi: Array = []
	for q in r["punti"]:
		grezzi.append(Vector3(q.x, q.y, q.z))
	var out := PackedVector2Array()
	for q in Binario.levigato(grezzi):
		out.append(Vector2(q.x, q.y))
	return out

func _disegna_lancio(d: Dictionary) -> void:
	var l: Dictionary = d.get("lancio", {})
	if l.has("pos"):
		var lp: Vector2 = l["pos"]
		draw_circle(px(lp), 13.5 * scala, Color(0.75, 0.75, 0.8))
		if scala > 0.5:
			draw_string(_font, px(lp) + Vector2(-20, 30), "lancio", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.75))

## v0.7: maniglie dell'IMMAGINE del pezzo scelto: rombo azzurro al centro (sposta), quadratino nell'angolo (grandezza,
## proporzioni mantenute). Non per la paletta (l'immagine gira con lei) né per le immagini sul piano (si spostano intere).
func _maniglie_immagine() -> Array:
	if selezionato == "" or selezionati.size() > 1:
		return []
	var t := progetto.trova(selezionato)
	if t.is_empty() or t[0] in ["palette", "decorazioni"] or not t[0] in PittorePezzi.TIPI:
		return []
	var e: Dictionary = progetto.desc[t[0]][t[1]]
	if not PittorePezzi.ha_immagine(e):
		return []
	var im: Dictionary = e["immagine"]
	var c: Vector2 = PittorePezzi.ancora(t[0], e, progetto.desc) + Vector2(im.get("pos", Vector2.ZERO))
	var mezza: Vector2 = Vector2(im.get("dim", Vector2(40, 40))) * 0.5
	return [c, c + mezza.rotated(float(im.get("rot", 0.0))), e, PittorePezzi.ancora(t[0], e, progetto.desc)]

## v0.9: maniglie della BUCA scelta: freccia verde = direzione d'uscita (trascinala), mirino viola = dove riappare la
## pallina quando la buca «la manda in un altro punto» (anche su un piano rialzato).
func _maniglie_buca() -> Dictionary:
	if selezionato == "" or selezionati.size() > 1:
		return {}
	var t := progetto.trova(selezionato)
	if t.is_empty() or t[0] != "buche":
		return {}
	var e: Dictionary = progetto.desc["buche"][t[1]]
	var out := {"e": e, "freccia": Vector2(e["pos"]) + Vector2(e.get("uscita_dir", Vector2(0, 1))).normalized() * (float(e.get("raggio", 14.0)) + 26.0)}
	if str(e.get("tipo", "")) == "passaggio" and e.get("uscita") is Vector2:
		out["uscita"] = e["uscita"]
	return out

func _maniglia_in(m: Vector2) -> String:
	var mb := _maniglie_buca()
	if mb.has("uscita") and px(m).distance_to(px(mb["uscita"])) < 10.0:
		return "uscita"
	if mb.has("freccia") and px(m).distance_to(px(mb["freccia"])) < 9.0:
		return "freccia"
	var mi := _maniglie_immagine()
	if mi.is_empty():
		return ""
	if px(m).distance_to(px(mi[1])) < 9.0:
		return "angolo"
	if px(m).distance_to(px(mi[0])) < 9.0:
		return "centro"
	return ""

func _disegna_selezione() -> void:
	var mb := _maniglie_buca()
	if not mb.is_empty():
		var cb := px(mb["e"]["pos"])
		var fr := px(mb["freccia"])
		draw_line(cb, fr, Color(0.5, 1.0, 0.6), 2.0)
		var dirf := (fr - cb).normalized()
		draw_colored_polygon(PackedVector2Array([fr + dirf * 9.0, fr + dirf.orthogonal() * 6.0, fr - dirf.orthogonal() * 6.0]), Color(0.5, 1.0, 0.6))
		if mb.has("uscita"):
			var u := px(mb["uscita"])
			_linea_tratteggiata(PackedVector2Array([mb["e"]["pos"], mb["uscita"]]), Color(0.8, 0.5, 1.0, 0.8), 1.5)
			draw_arc(u, 9.0, 0, TAU, 20, Color(0.8, 0.5, 1.0), 2.0)
			draw_line(u - Vector2(12, 0), u + Vector2(12, 0), Color(0.8, 0.5, 1.0), 1.5)
			draw_line(u - Vector2(0, 12), u + Vector2(0, 12), Color(0.8, 0.5, 1.0), 1.5)
	var mi := _maniglie_immagine()
	if not mi.is_empty():
		var c0 := px(mi[0])
		draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, -7), c0 + Vector2(7, 0), c0 + Vector2(0, 7), c0 + Vector2(-7, 0)]), Color(0.3, 0.85, 1.0))
		draw_rect(Rect2(px(mi[1]) - Vector2(5, 5), Vector2(10, 10)), Color(0.3, 0.85, 1.0))
		draw_line(c0, px(mi[1]), Color(0.3, 0.85, 1.0, 0.5), 1.0)
	if _rett_da.x >= 0.0:
		var r := Rect2(px(_rett_da), px(_ultimo_mm) - px(_rett_da)).abs()
		draw_rect(r, Color(1, 0.9, 0.2, 0.12))
		draw_rect(r, C_SEL, false, 1.5)
	if selezionati.size() > 1:
		for sid in selezionati:
			var ts := progetto.trova(str(sid))
			if ts.is_empty():
				continue
			var es: Dictionary = progetto.desc[ts[0]][ts[1]]
			var cs := ProgettoEditor.centro(ts[0], es)
			draw_arc(px(cs), maxf(12.0, _raggio_presa(ts[0], es) * scala + 6.0), 0, TAU, 32, C_SEL, 2.0)
			var pts_s := ProgettoEditor.punti_2d(ts[0], es)
			if not pts_s.is_empty():
				_polilinea(pts_s, C_SEL, 2.0)
		return
	if selezionato == "":
		return
	var t := progetto.trova(selezionato)
	if t.is_empty():
		return
	var e: Dictionary = progetto.desc[t[0]][t[1]]
	var pts := ProgettoEditor.punti_2d(t[0], e)
	if not pts.is_empty():
		if t[0] == "nastri":
			var en2 := CurveEditor.espandi_nastro(e)
			_polilinea(en2[0], C_SEL, 2.0)
		else:
			_polilinea(e["punti"] if t[0] in ["muri", "piani"] else (_linea_rampa(e) if t[0] == "rampe" else pts), C_SEL, 2.0)
		var curvi: Array = e.get("curvi", [])
		for i in pts.size():
			var col_p := Color.WHITE if (i == _punto_trascinato or i == punto) else C_SEL
			if i < curvi.size() and bool(curvi[i]):
				draw_arc(px(pts[i]), 6.0, 0, TAU, 16, col_p, 2.0)
			else:
				draw_rect(Rect2(px(pts[i]) - Vector2(5, 5), Vector2(10, 10)), col_p, false, 2.0)
			if i == punto:
				draw_arc(px(pts[i]), 11.0, 0, TAU, 20, Color.WHITE, 1.5)
			if t[0] == "nastri":
				draw_string(_font, px(pts[i]) + Vector2(8, -8), "%.0f mm%s" % [float(e["larghezze"][i]), (" · h %.0f" % float(e["altezze"][i])) if float(e["altezze"][i]) > 0.5 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.88, 1.0))
			if t[0] == "rampe":
				var zq: float = e["punti"][i].z
				draw_string(_font, px(pts[i]) + Vector2(8, -8), "%.0f mm" % zq, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.88, 1.0))
	else:
		var c := ProgettoEditor.centro(t[0], e)
		draw_arc(px(c), maxf(12.0, _raggio_presa(t[0], e) * scala + 6.0), 0, TAU, 32, C_SEL, 2.0)

func _disegna_problemi() -> void:
	for p in problemi:
		var pos: Vector2 = p["pos"]
		if pos.x < -900.0:
			continue                    # problema senza posto sul tavolo (es. una missione)
		var c := Color(1.0, 0.2, 0.2) if p["livello"] == "errore" else Color(1.0, 0.55, 0.1)
		if p.has("a"):
			draw_line(px(p["a"]), px(p["b"]), c, 3.0)
		draw_arc(px(pos), 9.0, 0, TAU, 20, c, 2.5)
		if pos.distance_to(evidenziato) < 0.5:
			draw_arc(px(pos), 18.0, 0, TAU, 24, Color.WHITE, 2.0)

func _polilinea(punti, c: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for q in punti:
		pts.append(px(Vector2(q.x, q.y)))
	if pts.size() >= 2:
		draw_polyline(pts, c, w)

func _linea_tratteggiata(punti, c: Color, w: float) -> void:
	for i in range(punti.size() - 1):
		if i % 2 == 0:
			draw_line(px(punti[i]), px(punti[i + 1]), c, w)

func _rettangolo(pos: Vector2, dim: Vector2, ang: float, c: Color, pieno: bool) -> void:
	var h := dim * 0.5
	var pts := PackedVector2Array()
	for v in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		pts.append(px(pos + v.rotated(ang)))
	if pieno:
		draw_colored_polygon(pts, Color(c, 0.85))
	pts.append(pts[0])
	draw_polyline(pts, c, 2.0)

# ================================================================ ricerca col mouse
func _raggio_presa(chiave: String, e: Dictionary) -> float:
	if e.has("raggio"):
		return float(e["raggio"])
	if e.has("dim"):
		var dd: Vector2 = e["dim"]
		return maxf(dd.x, dd.y) * 0.5
	if e.has("larghezza"):
		return float(e["larghezza"]) * 0.5
	if chiave == "palette":
		return 14.0
	if chiave == "lame":
		return 18.0
	return 10.0

## v0.9.4: il tavolo SENZA i pezzi dei livelli nascosti (copia leggera: le liste filtrate, i pezzi sono gli stessi).
func _desc_visibile() -> Dictionary:
	var d := progetto.desc
	var ev = d.get("editor_livelli", {})
	var nascosti := {}
	if ev is Dictionary:
		for n in ev:
			if progetto.livello_nascosto(int(n)):
				nascosti[int(n)] = true
	if nascosti.is_empty():
		return d
	var out := d.duplicate(false)
	for k in d:
		if d[k] is Array and k in ProgettoEditor.LISTE:
			out[k] = d[k].filter(func(e): return not (e is Dictionary and nascosti.has(ProgettoEditor.livello_di(k, e))))
	return out

## Pezzo che non si può scegliere: bloccato da solo o nel suo livello (nascosto o col lucchetto).
func _non_sceglibile(k: String, e) -> bool:
	return not e is Dictionary or not e.has("id") or e.has("da_nastro") or e.has("da_captive") or bool(e.get("bloccato", false)) \
		or progetto.livello_bloccato(ProgettoEditor.livello_di(k, e))

## v0.21: immagine e collisione sono un pezzo solo? (pezzo nato da un'immagine, o immagine «al posto del disegno»)
func unito(id: String) -> bool:
	var t := progetto.trova(id)
	if t.is_empty() or t[0] == "palette":
		return false
	var e: Dictionary = progetto.desc[t[0]][t[1]]
	return PittorePezzi.ha_immagine(e) and (e.has("da_immagine") or str(e["immagine"].get("modo", "")) == "sostituisce")

## v0.21: pezzo con immagine sotto il punto: basta cliccare DENTRO l'immagine (non solo sulla collisione).
func _pezzo_immagine_in(m: Vector2) -> String:
	for k in PRIORITA:
		var lista = progetto.desc.get(k, [])
		if not lista is Array or k == "palette":
			continue
		for i in range(lista.size() - 1, -1, -1):
			var e = lista[i]
			if _non_sceglibile(k, e) or not PittorePezzi.ha_immagine(e):
				continue
			var im: Dictionary = e["immagine"]
			var c: Vector2 = PittorePezzi.ancora(k, e, progetto.desc) + Vector2(im.get("pos", Vector2.ZERO))
			var loc: Vector2 = (m - c).rotated(-float(im.get("rot", 0.0)))
			var mz: Vector2 = Vector2(im.get("dim", Vector2(40, 40))) * 0.5
			if absf(loc.x) <= mz.x and absf(loc.y) <= mz.y:
				return e["id"]
	return ""

## Id del pezzo sotto il punto (mm), "" se nessuno.
func pezzo_in(m: Vector2) -> String:
	var di := _pezzo_in_forme(m)
	return di if di != "" else _pezzo_immagine_in(m)

func _pezzo_in_forme(m: Vector2) -> String:
	var tolleranza := 7.0 / scala
	for k in PRIORITA:
		var lista = progetto.desc.get(k, [])
		if not lista is Array:
			continue
		for i in range(lista.size() - 1, -1, -1):
			var e = lista[i]
			if _non_sceglibile(k, e):
				continue
			if k == "nastri":
				var en := CurveEditor.espandi_nastro(e)
				var cn: PackedVector2Array = en[0]
				for j in range(cn.size() - 1):
					if Geometry2D.get_closest_point_to_segment(m, cn[j], cn[j + 1]).distance_to(m) < float(en[1][j]) * 0.5 + tolleranza:
						return e["id"]
				continue
			if k == "palette":
				var perno: Vector2 = e["perno"]
				var verso := float(e.get("verso", 1.0))
				var ang: Vector2 = progetto.desc.get("paletta_angoli", Vector2(0.5, -0.5))
				var fine: Vector2 = perno + Vector2(verso, 0).rotated(ang.x if verso > 0 else -ang.x) * float(e["lunghezza"])
				if Geometry2D.get_closest_point_to_segment(m, perno, fine).distance_to(m) < 8.0 + tolleranza:
					return e["id"]
				continue
			var pts := ProgettoEditor.punti_2d(k, e)
			if not pts.is_empty():
				if k in ["fionde", "piani"] and Geometry2D.is_point_in_polygon(m, pts if k == "fionde" else PackedVector2Array(e.get("punti", pts))):
					return e["id"]
				for j in range(pts.size() - 1):
					if Geometry2D.get_closest_point_to_segment(m, pts[j], pts[j + 1]).distance_to(m) < tolleranza + 3.0:
						return e["id"]
				continue
			var c := ProgettoEditor.centro(k, e)
			if c.distance_to(m) < _raggio_presa(k, e) + tolleranza:
				return e["id"]
	return ""

func _punto_in(m: Vector2) -> int:
	if selezionato == "":
		return -1
	var t := progetto.trova(selezionato)
	if t.is_empty():
		return -1
	var pts := ProgettoEditor.punti_2d(t[0], progetto.desc[t[0]][t[1]])
	for i in pts.size():
		if pts[i].distance_to(m) < 8.0 / scala:
			return i
	return -1

func _aggancia(m: Vector2) -> Vector2:
	if aggancio and passo_griglia > 0.0:
		return (m / passo_griglia).round() * passo_griglia
	return m

## Aggiunge o toglie un pezzo dalla scelta (Maiusc+clic).
func alterna(id: String) -> void:
	if id == "":
		return
	if id in selezionati:
		selezionati.erase(id)
	else:
		selezionati.append(id)
	selezionato = selezionati[-1] if not selezionati.is_empty() else ""
	punto = -1
	selezione_cambiata.emit(selezionato)
	queue_redraw()

func scegli_tutti(ids: Array) -> void:
	selezionati = ids.duplicate()
	selezionato = selezionati[-1] if not selezionati.is_empty() else ""
	punto = -1
	selezione_cambiata.emit(selezionato)
	queue_redraw()

func seleziona(id: String) -> void:
	selezionati = [id] if id != "" else []
	if id != selezionato:
		selezionato = id
		punto = -1
		_punto_trascinato = -1
		selezione_cambiata.emit(id)
	queue_redraw()

# ================================================================ mouse e tastiera
func _gui_input(ev: InputEvent) -> void:
	if progetto == null or progetto.desc.is_empty():
		return
	if ev is InputEventKey and ev.pressed and disegno_in_corso():
		if ev.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			finisci_muro()
			accept_event()
			return
		if ev.keycode == KEY_ESCAPE:
			annulla_disegno()
			messaggio.emit("Disegno annullato")
			accept_event()
			return
	if ev is InputEventKey and ev.keycode == KEY_SHIFT and disegno_in_corso():
		queue_redraw()                  # l'anteprima mostra subito il punto curvo
	if ev is InputEventMouseMotion:
		var m := mm(ev.position)
		posizione_mouse.emit(m)
		if _trascina == "vista":
			origine += ev.relative
			queue_redraw()
		elif _trascina == "gruppo":
			if not _mosso:
				progetto.inizia_trascinamento()
				_mosso = true
			var dd := _aggancia(m - _inizio_trascina)
			for gid in _centri0:
				var tg := progetto.trova(str(gid))
				if not tg.is_empty():
					var eg: Dictionary = progetto.desc[tg[0]][tg[1]]
					ProgettoEditor.trasla(tg[0], eg, Vector2(_centri0[gid]) + dd - ProgettoEditor.centro(tg[0], eg))
					if tg[0] == "muri":
						CurveEditor.rigenera(eg)
			if _mosso:
				CurveEditor.genera_nastri(progetto.desc)
			queue_redraw()
		elif _trascina == "righello":
			righello_a = _aggancia(m)
			queue_redraw()
		elif _trascina in ["rettangolo", "traccia"]:
			_ultimo_mm = m
			queue_redraw()
		elif _trascina == "pezzo":
			var t := progetto.trova(selezionato)
			if not t.is_empty():
				if not _mosso:
					progetto.inizia_trascinamento()
					_mosso = true
				var e: Dictionary = progetto.desc[t[0]][t[1]]
				var nuovo_centro := _aggancia(m - _inizio_trascina)
				ProgettoEditor.trasla(t[0], e, nuovo_centro - ProgettoEditor.centro(t[0], e))
				if t[0] == "muri":
					CurveEditor.rigenera(e)
				elif t[0] == "nastri":
					CurveEditor.genera_nastri(progetto.desc)
				queue_redraw()
		elif _trascina in ["img_freccia", "img_uscita"]:
			var mb2 := _maniglie_buca()
			if not mb2.is_empty():
				if not _mosso:
					progetto.inizia_trascinamento()
					_mosso = true
				var eb: Dictionary = mb2["e"]
				if _trascina == "img_freccia":
					var dv := m - Vector2(eb["pos"])
					if dv.length() > 3.0:
						eb["uscita_dir"] = dv.normalized().snapped(Vector2(0.01, 0.01))
				else:
					eb["uscita"] = _aggancia(m)
				queue_redraw()
		elif _trascina.begins_with("img_"):
			var mi := _maniglie_immagine()
			if not mi.is_empty():
				if not _mosso:
					progetto.inizia_trascinamento()
					_mosso = true
				var im: Dictionary = mi[2]["immagine"]
				if _trascina == "img_tutto":
					var tt := progetto.trova(selezionato)
					var dimt: Vector2 = im.get("dim", Vector2(40, 40))
					var vt: Vector2 = (m - Vector2(mi[0])).rotated(-float(im.get("rot", 0.0)))
					var ft := clampf(maxf(absf(vt.x) * 2.0, 6.0) / maxf(dimt.x, 0.1), 0.8, 1.25)
					if absf(ft - 1.0) > 0.002:
						ProgettoEditor._scala_pezzo(tt[0], mi[2], ft, ProgettoEditor.centro(tt[0], mi[2]))
						if tt[0] == "muri":
							CurveEditor.rigenera(mi[2])
				elif _trascina == "img_centro":
					im["pos"] = (_aggancia(m) - Vector2(mi[3])).snapped(Vector2(0.5, 0.5))
				else:
					var dim0: Vector2 = im.get("dim", Vector2(40, 40))
					var verso: Vector2 = (m - Vector2(mi[0])).rotated(-float(im.get("rot", 0.0)))
					# l'angolo segue il mouse in orizzontale; l'altezza segue (proporzioni mantenute)
					var f := maxf(absf(verso.x) * 2.0, 4.0) / maxf(dim0.x, 0.1)
					im["dim"] = (dim0 * f).snapped(Vector2(0.5, 0.5))
				queue_redraw()
		elif _trascina == "punto":
			var t2 := progetto.trova(selezionato)
			if not t2.is_empty():
				if not _mosso:
					progetto.inizia_trascinamento()
					_mosso = true
				ProgettoEditor.imposta_punto(t2[0], progetto.desc[t2[0]][t2[1]], _punto_trascinato, _aggancia(m))
				if t2[0] == "muri":
					CurveEditor.rigenera(progetto.desc[t2[0]][t2[1]])
				elif t2[0] == "nastri":
					CurveEditor.genera_nastri(progetto.desc)
				queue_redraw()
		_ultimo_mm = _aggancia(m)
		if not _muro_nuovo.is_empty():
			queue_redraw()
	elif ev is InputEventMouseButton:
		var m2 := mm(ev.position)
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if ev.pressed:
				var k := 1.15 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				scala = clampf(scala * k, 0.2, 8.0)
				origine = ev.position - m2 * scala
				queue_redraw()
			return
		if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed and disegno_in_corso():
			finisci_muro()
			return
		if ev.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				var ip := _punto_in(m2)
				if ip >= 0:
					var r := progetto.esegui({"comando": "togli_punto", "id": selezionato, "indice": ip})
					messaggio.emit(r["messaggio"])
					return
			_trascina = "vista" if ev.pressed else ""
			return
		if ev.button_index != MOUSE_BUTTON_LEFT:
			return
		grab_focus()
		if ev.pressed:
			if da_inserire == "righello":
				righello_da = _aggancia(m2)
				righello_a = righello_da
				_trascina = "righello"
				return
			if da_inserire == "traccia":
				_traccia_da = m2
				_ultimo_mm = m2
				_trascina = "traccia"
				return
			if da_inserire != "":
				_inserisci(_aggancia(m2), ev.double_click, ev.shift_pressed)
				return
			if ev.double_click and selezionato != "":
				var t3 := progetto.trova(selezionato)
				if not t3.is_empty() and t3[0] in ["muri", "porte", "rampe"]:
					var pts := ProgettoEditor.punti_2d(t3[0], progetto.desc[t3[0]][t3[1]])
					var migliore := 0
					var dist := INF
					for j in range(pts.size() - 1):
						var dd := Geometry2D.get_closest_point_to_segment(m2, pts[j], pts[j + 1]).distance_to(m2)
						if dd < dist:
							dist = dd
							migliore = j
					if dist < 12.0 / scala:
						var r2 := progetto.esegui({"comando": "aggiungi_punto", "id": selezionato, "dopo": migliore, "pos": _aggancia(m2)})
						messaggio.emit(r2["messaggio"])
						return
			var man := _maniglia_in(m2)
			if man != "" and not ev.shift_pressed:
				# v0.21: pezzo NATO da un'immagine (o con l'immagine «al posto del disegno»): immagine e collisione
				# sono una cosa sola. Il rombo sposta tutto, il quadratino ingrandisce tutto. Alt = solo l'immagine.
				if unito(selezionato) and not ev.alt_pressed:
					if man == "centro":
						var tu := progetto.trova(selezionato)
						_inizio_trascina = m2 - ProgettoEditor.centro(tu[0], progetto.desc[tu[0]][tu[1]])
						_trascina = "pezzo"
						_mosso = false
						return
					if man == "angolo":
						_trascina = "img_tutto"
						_mosso = false
						return
				_trascina = "img_" + man
				_mosso = false
				return
			var ip2 := _punto_in(m2) if selezionati.size() <= 1 else -1
			if ip2 >= 0 and not ev.shift_pressed:
				punto = ip2
				punto_scelto.emit(ip2)
				_punto_trascinato = ip2
				_trascina = "punto"
				_mosso = false
				return
			var id := pezzo_in(m2)
			if id != "":
				pezzo_cliccato.emit(id)
			if ev.shift_pressed:
				alterna(id)
				return
			# v0.16: un pezzo di un gruppo con nome sceglie tutto il gruppo (Alt+clic = solo quel pezzo)
			var gn := progetto.gruppo_di(id) if id != "" and not ev.alt_pressed else ""
			if gn != "" and not (id in selezionati and selezionati.size() > 1):
				scegli_tutti(progetto.gruppi_editor()[gn])
				messaggio.emit("Gruppo «%s» (Alt+clic per un pezzo solo)" % gn)
			if id != "" and id in selezionati and selezionati.size() > 1:
				_centri0.clear()
				for gid in selezionati:
					var tg2 := progetto.trova(str(gid))
					if not tg2.is_empty():
						_centri0[gid] = ProgettoEditor.centro(tg2[0], progetto.desc[tg2[0]][tg2[1]])
				_inizio_trascina = m2
				_trascina = "gruppo"
				_mosso = false
				return
			seleziona(id)
			if id == "":
				_rett_da = m2
				_ultimo_mm = m2
				_trascina = "rettangolo"
				return
			if id != "":
				var t4 := progetto.trova(id)
				_inizio_trascina = m2 - ProgettoEditor.centro(t4[0], progetto.desc[t4[0]][t4[1]])
				_trascina = "pezzo"
				_mosso = false
		else:
			if _trascina == "righello":
				_trascina = ""
				messaggio.emit("Righello: %.0f mm (orizzontale %.0f, verticale %.0f), angolo %.0f°" % [righello_da.distance_to(righello_a), absf(righello_a.x - righello_da.x), absf(righello_a.y - righello_da.y), rad_to_deg((righello_a - righello_da).angle())])
				return
			if _trascina == "traccia":
				_trascina = ""
				traccia_richiesta.emit(_traccia_da, vel_traccia(_traccia_da, m2))
				queue_redraw()
				return
			if _trascina == "rettangolo":
				var r := Rect2(_rett_da, m2 - _rett_da).abs()
				_rett_da = Vector2(-1, -1)
				_trascina = ""
				if r.size.length() > 4.0:
					var dentro: Array = []
					for k in PRIORITA:
						for e in progetto.desc.get(k, []):
							if not _non_sceglibile(k, e) and r.has_point(ProgettoEditor.centro(k, e)):
								dentro.append(e["id"])
					scegli_tutti(dentro)
					messaggio.emit("%d pezzi scelti" % dentro.size())
				queue_redraw()
				return
			if _trascina == "gruppo" and _mosso:
				progetto.fine_trascinamento()
				messaggio.emit("%d pezzi spostati" % _centri0.size())
			if _trascina.begins_with("img_") and _mosso:
				progetto.fine_trascinamento()
				messaggio.emit({"img_tutto": "Elemento ridimensionato (immagine e collisione insieme)", "img_centro": "Solo l'immagine spostata", "img_angolo": "Immagine ridimensionata", "img_freccia": "Direzione d'uscita cambiata", "img_uscita": "Punto d'uscita spostato"}.get(_trascina, "Fatto"))
				selezione_cambiata.emit(selezionato)
			if _trascina in ["pezzo", "punto"] and _mosso:
				progetto.fine_trascinamento()
				messaggio.emit("Spostato")
				selezione_cambiata.emit(selezionato)       # il pannello mostra la posizione nuova
			_trascina = ""
			_punto_trascinato = -1
			queue_redraw()

func _inserisci(m: Vector2, doppio: bool, maiusc := false) -> void:
	if da_inserire.begins_with("preset:"):
		var r0 := progetto.esegui({"comando": "aggiungi", "tipo": "muri", "preset": da_inserire.trim_prefix("preset:"), "pos": m})
		messaggio.emit(r0["messaggio"])
		if r0.get("ok", false):
			seleziona(r0["id"])
		return
	if da_inserire.begins_with("composto:"):
		var rc := progetto.esegui({"comando": "aggiungi_composto", "nome": da_inserire.trim_prefix("composto:"), "pos": m})
		messaggio.emit(rc["messaggio"])
		return
	if da_inserire in ["muri", "rampe", "nastri", "piani"]:
		if doppio:
			finisci_muro()
			return
		_muro_nuovo.append(m)
		_muro_nuovo_curvi.append(maiusc)
		_aggiorna_barra()
		if da_inserire == "nastri":
			messaggio.emit("Nastro: punto %d (il primo è l'ingresso). Clic = punto ad angolo, Maiusc+clic = CURVO. Invio o doppio clic per finire." % _muro_nuovo.size())
		elif da_inserire == "piani":
			messaggio.emit("Piano rialzato: punto %d. DOPPIO CLIC SUBITO = forma pronta; oppure clic per i punti della forma (Maiusc+clic = curvo) e Invio." % _muro_nuovo.size())
		elif da_inserire == "rampe":
			messaggio.emit("Rampa: punto %d. Il primo è l'IMBOCCO (a terra). Clic per i punti del percorso; Invio o doppio clic per finire, Esc per annullare." % _muro_nuovo.size())
		else:
			messaggio.emit("Muro: punto %d%s. Clic = punto ad angolo, Maiusc+clic = punto CURVO. Invio o doppio clic per finire, Esc per annullare." % [_muro_nuovo.size(), " (curvo)" if maiusc else ""])
		queue_redraw()
		return
	var r := progetto.esegui({"comando": "aggiungi", "tipo": da_inserire, "pos": m})
	messaggio.emit(r["messaggio"])
	if r.get("ok", false):
		seleziona(r["id"])

func finisci_muro() -> void:
	if da_inserire == "piani" and _muro_nuovo.size() in [1, 2]:
		# piano rialzato con un doppio clic: forma pronta (rettangolo con gli angoli curvi) intorno al punto
		var rp := progetto.esegui({"comando": "aggiungi", "tipo": "piani", "pos": _muro_nuovo[0]})
		messaggio.emit(rp["messaggio"] + " (forma pronta: trascina i quadratini per cambiarla)")
		if rp.get("ok", false):
			seleziona(rp["id"])
	elif _muro_nuovo.size() >= 2:
		var r := progetto.esegui({"comando": "aggiungi", "tipo": da_inserire, "punti": Array(_muro_nuovo), "curvi": _muro_nuovo_curvi.duplicate()})
		messaggio.emit(r["messaggio"])
		if r.get("ok", false):
			seleziona(r["id"])
	else:
		messaggio.emit("Servono almeno 2 punti")
	_muro_nuovo.clear()
	_muro_nuovo_curvi.clear()
	_aggiorna_barra()
	queue_redraw()

func annulla_inserimento() -> void:
	_muro_nuovo.clear()
	_muro_nuovo_curvi.clear()
	if _barra_disegno:
		_aggiorna_barra()
	da_inserire = ""
	queue_redraw()
