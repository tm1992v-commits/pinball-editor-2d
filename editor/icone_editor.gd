## Icone e anteprime del Pinball Editor 2D (v0.2, 24/11/2026): disegnate dal codice SOLO per l'interfaccia
## dell'editor (strumento, non grafica di gioco). BottoneIcona = pulsante con il disegno del pezzo e il nome sotto.
## AnteprimaTavolo = un tavolo in piccolo (forme e tavoli pronti nella finestra «Nuovo»).
class_name IconeEditor

## Disegna il simbolo di uno strumento o pezzo dentro il rettangolo r.
static func disegna(ci: CanvasItem, tipo: String, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var m := minf(r.size.x, r.size.y) * 0.5
	match tipo:
		"seleziona":
			var p := PackedVector2Array([c + Vector2(-m * 0.45, -m * 0.75), c + Vector2(-m * 0.45, m * 0.55), c + Vector2(-m * 0.12, m * 0.25),
				c + Vector2(m * 0.12, m * 0.8), c + Vector2(m * 0.32, m * 0.7), c + Vector2(m * 0.08, m * 0.15), c + Vector2(m * 0.5, m * 0.12)])
			ci.draw_colored_polygon(p, Color(0.95, 0.95, 0.98))
			p.append(p[0])
			ci.draw_polyline(p, Color(0.2, 0.2, 0.25), 1.5)
		"righello":
			var rr := Rect2(c + Vector2(-m * 0.8, -m * 0.22), Vector2(m * 1.6, m * 0.44))
			ci.draw_rect(rr, col.darkened(0.2))
			for k in 9:
				var x := rr.position.x + rr.size.x * (k + 0.5) / 9.0
				ci.draw_line(Vector2(x, rr.position.y), Vector2(x, rr.position.y + (rr.size.y * 0.55 if k % 2 == 0 else rr.size.y * 0.3)), Color(0.15, 0.12, 0.05), 1.2)
		"lame":
			ci.draw_line(c + Vector2(-m * 0.5, m * 0.4), c + Vector2(m * 0.45, -m * 0.5), Color(0.85, 0.87, 0.95), 4.0)
			ci.draw_line(c + Vector2(-m * 0.5, m * 0.4), c + Vector2(m * 0.6, m * 0.25), Color(0.85, 0.87, 0.95, 0.35), 2.0)
			ci.draw_circle(c + Vector2(-m * 0.5, m * 0.4), m * 0.16, Color(0.95, 0.75, 0.3))
		"captive":
			ci.draw_line(c + Vector2(-m * 0.38, m * 0.8), c + Vector2(-m * 0.38, -m * 0.75), Color(0.8, 0.82, 0.88), 2.0)
			ci.draw_line(c + Vector2(m * 0.38, m * 0.8), c + Vector2(m * 0.38, -m * 0.75), Color(0.8, 0.82, 0.88), 2.0)
			ci.draw_line(c + Vector2(-m * 0.3, -m * 0.65), c + Vector2(m * 0.3, -m * 0.65), Color(1.0, 0.85, 0.3), 3.0)
			ci.draw_circle(c + Vector2(0, m * 0.45), m * 0.3, Color(0.8, 0.82, 0.88))
			ci.draw_circle(c + Vector2(-m * 0.1, m * 0.35), m * 0.09, Color(1, 1, 1))
		"porte":
			ci.draw_rect(Rect2(c + Vector2(-m * 0.7, -m * 0.12), Vector2(m * 1.4, m * 0.24)), Color(0.85, 0.15, 0.15))
			ci.draw_circle(c + Vector2(-m * 0.7, 0), m * 0.12, Color(0.8, 0.8, 0.85))
			ci.draw_circle(c + Vector2(m * 0.7, 0), m * 0.12, Color(0.8, 0.8, 0.85))
		"traccia":
			var cu := PackedVector2Array()
			for k in 13:
				var tt := float(k) / 12.0
				cu.append(c + Vector2(lerpf(-m * 0.7, m * 0.6, tt), m * 0.6 - sin(tt * PI) * m * 1.1 + tt * m * 0.1))
			for k in range(0, 12, 2):
				ci.draw_line(cu[k], cu[k + 1], Color.from_hsv(lerpf(0.62, 0.0, k / 12.0), 0.85, 1.0), 2.5)
			ci.draw_circle(cu[0], m * 0.16, Color(0.9, 0.9, 0.95))
			ci.draw_circle(cu[12], m * 0.08, col)
		"bumper":
			ci.draw_circle(c + Vector2(2, 3), m * 0.75, Color(0, 0, 0, 0.35))
			ci.draw_circle(c, m * 0.75, col.darkened(0.35))
			ci.draw_circle(c - Vector2(0, m * 0.08), m * 0.55, col)
			ci.draw_circle(c - Vector2(m * 0.15, m * 0.25), m * 0.18, Color(1, 1, 1, 0.6))
		"bersagli":
			var rr := Rect2(c - Vector2(m * 0.55, m * 0.22), Vector2(m * 1.1, m * 0.44))
			ci.draw_rect(Rect2(rr.position + Vector2(2, 3), rr.size), Color(0, 0, 0, 0.35))
			ci.draw_rect(rr, col.darkened(0.25))
			ci.draw_rect(Rect2(rr.position, Vector2(rr.size.x, rr.size.y * 0.45)), col.lightened(0.25))
		"fionde", "preset:fionda":
			var tri := PackedVector2Array([c + Vector2(-m * 0.35, -m * 0.75), c + Vector2(-m * 0.45, m * 0.4), c + Vector2(m * 0.5, m * 0.75)])
			ci.draw_colored_polygon(tri, col.darkened(0.3))
			ci.draw_line(tri[0], tri[2], Color(1, 1, 1), 3.0)
			ci.draw_line(tri[0], tri[2], col.lightened(0.3), 1.5)
		"preset:gomma":
			var anello := PackedVector2Array()
			for k in 25:
				var a := TAU * k / 24.0
				anello.append(c + Vector2(cos(a) * m * 0.7, sin(a) * m * 0.35))
			ci.draw_polyline(anello, Color(0.1, 0.1, 0.1), 5.0)
			ci.draw_polyline(anello, col, 2.5)
			ci.draw_circle(c + Vector2(-m * 0.5, 0), m * 0.1, Color(0.75, 0.75, 0.8))
			ci.draw_circle(c + Vector2(m * 0.5, 0), m * 0.1, Color(0.75, 0.75, 0.8))
		"preset:isola":
			var blob := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				blob.append(c + Vector2(cos(a) * m * 0.45, sin(a) * m * 0.7))
			ci.draw_colored_polygon(blob, Color(col, 0.35))
			blob.append(blob[0])
			ci.draw_polyline(blob, col, 2.0)
		"nastri":
			var cn := PackedVector2Array()
			for k in 13:
				var a := PI * 0.95 + PI * 0.75 * k / 12.0
				cn.append(c + Vector2(cos(a) * m * 0.62, sin(a) * m * 0.62 + m * 0.3))
			ci.draw_polyline(cn, Color(0.85, 0.87, 0.92), m * 0.62)
			ci.draw_polyline(cn, col.darkened(0.3), m * 0.42)
			ci.draw_polyline(cn, col, m * 0.18)
		"rampe":
			var curva := PackedVector2Array()
			for k in 13:
				var a := PI * 0.9 + PI * 0.8 * k / 12.0
				curva.append(c + Vector2(cos(a) * m * 0.7, sin(a) * m * 0.7 + m * 0.35))
			ci.draw_polyline(curva, Color(col, 0.45), m * 0.45)
			ci.draw_polyline(curva, col.lightened(0.3), 1.5)
		"composto:abbattibili_3", "composto:abbattibili_5":
			var na := 3 if tipo.ends_with("3") else 5
			var passo := m * 1.6 / na
			for i in na:
				var x := c.x - m * 0.8 + passo * (i + 0.5)
				ci.draw_rect(Rect2(Vector2(x - passo * 0.4, c.y - m * 0.15), Vector2(passo * 0.8, m * 0.3)), col)
				ci.draw_rect(Rect2(Vector2(x - passo * 0.4, c.y + m * 0.15), Vector2(passo * 0.8, m * 0.1)), col.darkened(0.5))
				ci.draw_circle(Vector2(x, c.y + m * 0.55), passo * 0.2, Color(1, 0.85, 0.4))
		"composto:bumper_3":
			for q in [Vector2(-0.45, -0.3), Vector2(0.45, -0.3), Vector2(0, 0.45)]:
				ci.draw_circle(c + q * m, m * 0.3, col)
				ci.draw_circle(c + q * m, m * 0.15, Color(1, 1, 1, 0.8))
		"composto:bersagli_buca":
			ci.draw_circle(c + Vector2(0, m * 0.35), m * 0.22, Color(0.1, 0.1, 0.12))
			ci.draw_arc(c + Vector2(0, m * 0.35), m * 0.24, 0, TAU, 16, Color(0.7, 0.7, 0.75), 1.5)
			for a in [-0.6, 0.0, 0.6]:
				var q := c + Vector2(0, m * 0.35) + Vector2(0, -m * 0.75).rotated(a)
				ci.draw_rect(Rect2(q - Vector2(m * 0.18, m * 0.07), Vector2(m * 0.36, m * 0.14)), col)
		"composto:spinner_corsia":
			for dx in [-0.45, 0.45]:
				ci.draw_line(c + Vector2(dx * m, -m * 0.7), c + Vector2(dx * m, m * 0.7), Color(0.8, 0.82, 0.88), 2.0)
			ci.draw_rect(Rect2(c - Vector2(m * 0.35, m * 0.08), Vector2(m * 0.7, m * 0.16)), col)
		"composto:corsia", "composto:corsie_3":
			var nn := 1 if tipo == "composto:corsia" else 3
			var lg := m * 1.4 / nn
			for g in nn + 1:
				var x := c.x - m * 0.7 + lg * g
				ci.draw_line(Vector2(x, c.y - m * 0.6), Vector2(x, c.y + m * 0.4), Color(0.8, 0.82, 0.88), 2.0)
			for k in nn:
				var cx := c.x - m * 0.7 + lg * (k + 0.5)
				ci.draw_line(Vector2(cx - lg * 0.3, c.y), Vector2(cx + lg * 0.3, c.y), Color(0.4, 1.0, 0.5), 2.0)
				ci.draw_circle(Vector2(cx, c.y + m * 0.6), m * 0.1, Color(1.0, 0.85, 0.4))
		"palette":
			var a := c + Vector2(-m * 0.6, -m * 0.2)
			var b := c + Vector2(m * 0.65, m * 0.35)
			ci.draw_line(a + Vector2(2, 3), b + Vector2(2, 3), Color(0, 0, 0, 0.35), m * 0.32)
			ci.draw_line(a, b, Color(0.95, 0.95, 0.92), m * 0.32)
			ci.draw_circle(a, m * 0.2, Color(0.95, 0.95, 0.92))
			ci.draw_circle(a, m * 0.08, Color(0.5, 0.5, 0.55))
		"spinner":
			ci.draw_line(c - Vector2(m * 0.7, 0), c + Vector2(m * 0.7, 0), Color(0.7, 0.7, 0.75), 2.0)
			ci.draw_rect(Rect2(c - Vector2(m * 0.5, m * 0.25), Vector2(m, m * 0.5)), col)
			ci.draw_line(c - Vector2(m * 0.5, 0), c + Vector2(m * 0.5, 0), col.darkened(0.4), 2.0)
		"sensori":
			ci.draw_line(c + Vector2(-m * 0.5, -m * 0.7), c + Vector2(-m * 0.5, m * 0.7), Color(0.75, 0.75, 0.8), 2.0)
			ci.draw_line(c + Vector2(m * 0.5, -m * 0.7), c + Vector2(m * 0.5, m * 0.7), Color(0.75, 0.75, 0.8), 2.0)
			ci.draw_rect(Rect2(c - Vector2(m * 0.35, m * 0.1), Vector2(m * 0.7, m * 0.2)), col)
			ci.draw_line(c + Vector2(0, -m * 0.55), c + Vector2(0, -m * 0.2), col, 2.0)
		"elastici":
			ci.draw_circle(c, m * 0.32, Color(0.15, 0.15, 0.15))
			ci.draw_circle(c, m * 0.2, col)
		"buche":
			ci.draw_circle(c, m * 0.6, Color(0.55, 0.55, 0.62))
			ci.draw_circle(c, m * 0.45, Color(0.02, 0.02, 0.03))
		"kickback":
			ci.draw_line(c + Vector2(0, m * 0.7), c + Vector2(0, -m * 0.5), col, 3.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -m * 0.8), c + Vector2(-m * 0.3, -m * 0.35), c + Vector2(m * 0.3, -m * 0.35)]), col)
		"campi":
			for k in 3:
				ci.draw_arc(c, m * (0.25 + 0.22 * k), 0, TAU, 24, Color(col, 1.0 - 0.25 * k), 1.5)
			ci.draw_circle(c, m * 0.12, col)
		"inserti":
			ci.draw_circle(c, m * 0.6, Color(col, 0.25))
			ci.draw_circle(c, m * 0.4, col)
			ci.draw_circle(c - Vector2(m * 0.12, m * 0.12), m * 0.12, Color(1, 1, 1, 0.7))
		"muri":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-m * 0.7, m * 0.6), c + Vector2(-m * 0.2, -m * 0.4), c + Vector2(m * 0.7, -m * 0.6)]), col, 3.0)
			for q in [c + Vector2(-m * 0.7, m * 0.6), c + Vector2(-m * 0.2, -m * 0.4), c + Vector2(m * 0.7, -m * 0.6)]:
				ci.draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.9, 0.2))
		"piani":
			var rr := Rect2(c - Vector2(m * 0.75, m * 0.55), Vector2(m * 1.5, m * 0.8))
			ci.draw_rect(Rect2(rr.position + Vector2(0, rr.size.y), Vector2(rr.size.x, m * 0.3)), col.darkened(0.5))
			ci.draw_rect(rr, col)
			ci.draw_rect(rr, Color(0.3, 0.9, 1.0), false, 1.5)
			ci.draw_circle(rr.get_center() + Vector2(-m * 0.25, 0), m * 0.15, Color(0.95, 0.95, 1.0))
			ci.draw_circle(rr.get_center() + Vector2(m * 0.25, 0), m * 0.15, Color(0.95, 0.95, 1.0))
		"cancelli":
			ci.draw_line(c + Vector2(-m * 0.7, m * 0.1), c + Vector2(m * 0.7, m * 0.1), Color(0.85, 0.86, 0.9), 2.0)
			ci.draw_rect(Rect2(c + Vector2(-m * 0.6, m * 0.1), Vector2(m * 1.2, m * 0.35)), col)
			ci.draw_line(c + Vector2(0, -m * 0.2), c + Vector2(0, -m * 0.8), Color(0.5, 1.0, 0.6), 2.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -m * 0.95), c + Vector2(-m * 0.2, -m * 0.6), c + Vector2(m * 0.2, -m * 0.6)]), Color(0.5, 1.0, 0.6))
		"decorazioni":
			var cornice := Rect2(c - Vector2(m * 0.75, m * 0.6), Vector2(m * 1.5, m * 1.2))
			ci.draw_rect(cornice, Color(0.2, 0.35, 0.6))
			ci.draw_colored_polygon(PackedVector2Array([cornice.position + Vector2(0, cornice.size.y), cornice.position + Vector2(cornice.size.x * 0.4, cornice.size.y * 0.35),
				cornice.position + Vector2(cornice.size.x * 0.65, cornice.size.y * 0.7), cornice.position + Vector2(cornice.size.x * 0.8, cornice.size.y * 0.5), cornice.end]), col.darkened(0.2))
			ci.draw_circle(cornice.position + Vector2(cornice.size.x * 0.75, cornice.size.y * 0.25), m * 0.13, Color(1, 0.9, 0.4))
			ci.draw_rect(cornice, Color(0.95, 0.95, 1.0), false, 1.5)
		_:
			ci.draw_circle(c, m * 0.5, col)

## Disegna un tavolo in piccolo: sponda, muri, palette, fionde, bumper, bersagli.
static func anteprima(ci: CanvasItem, d: Dictionary, r: Rect2, sfondo := true) -> void:
	if d.is_empty():
		return
	var dim: Vector2 = d.get("dimensioni", Vector2(635, 1240)) + Vector2(0, 60)
	var k := minf(r.size.x / dim.x, r.size.y / dim.y)
	var o := r.position + (r.size - dim * k) * 0.5
	var px := func(p) -> Vector2: return o + Vector2(p.x, p.y) * k
	if sfondo:
		ci.draw_rect(Rect2(o, Vector2(dim.x, dim.y - 60) * k), Color(0.14, 0.15, 0.19))
	for m in d.get("muri", []):
		var pts := PackedVector2Array()
		for q in m["punti"]:
			pts.append(px.call(q))
		ci.draw_polyline(pts, Color(0.8, 0.6, 0.4) if m.get("id", "") == "sponda" else Color(0.75, 0.78, 0.85), 1.5 if m.get("id", "") == "sponda" else 1.0)
	for f in d.get("fionde", []):
		var fp := PackedVector2Array()
		for q in f["punti"]:
			fp.append(px.call(q))
		ci.draw_colored_polygon(fp, Color(1.0, 0.6, 0.8, 0.8))
	for b in d.get("bumper", []):
		ci.draw_circle(px.call(b["pos"]), maxf(1.5, float(b["raggio"]) * k), Color(1.0, 0.45, 0.35))
	for t in d.get("bersagli", []):
		ci.draw_circle(px.call(t["pos"]), maxf(1.0, 6.0 * k), Color(1.0, 0.85, 0.3))
	for s in d.get("spinner", []):
		ci.draw_circle(px.call(s["pos"]), maxf(1.0, 8.0 * k), Color(0.6, 0.9, 1.0))
	for c in d.get("campi", []):
		ci.draw_arc(px.call(c["pos"]), float(c["raggio"]) * k, 0, TAU, 16, Color(0.75, 0.4, 1.0), 1.0)
	for ra in d.get("rampe", []):
		var rp := PackedVector2Array()
		for q in ra["punti"]:
			rp.append(px.call(q))
		ci.draw_polyline(rp, Color(0.5, 0.7, 1.0, 0.8), maxf(1.0, 20.0 * k))
	var ang: Vector2 = d.get("paletta_angoli", Vector2(0.5, -0.5))
	for pa in d.get("palette", []):
		var verso := float(pa.get("verso", 1.0))
		var fine: Vector2 = Vector2(pa["perno"]) + Vector2(verso, 0).rotated(ang.x if verso > 0 else -ang.x) * float(pa["lunghezza"])
		ci.draw_line(px.call(pa["perno"]), px.call(fine), Color(0.97, 0.96, 0.94), maxf(1.5, 8.0 * k))


## Pulsante con icona disegnata e nome sotto.
class BottoneIcona extends Button:
	var tipo := ""
	var nome := ""
	var colore := Color.WHITE

	func _init(t: String, n: String, c: Color) -> void:
		tipo = t
		nome = n
		colore = c
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(88, 74)
		tooltip_text = n

	func _draw() -> void:
		var r := Rect2(Vector2(0, 4), Vector2(size.x, size.y - 26))
		IconeEditor.disegna(self, tipo, r, colore)
		var f := get_theme_default_font()
		var fs := 12
		var w := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - minf(w, size.x - 4)) * 0.5, size.y - 8), nome, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, fs,
			Color(1, 1, 1) if button_pressed else Color(0.8, 0.8, 0.85))


## Riquadro che mostra un tavolo in piccolo, cliccabile.
class AnteprimaTavolo extends Button:
	var desc: Dictionary = {}
	var titolo := ""

	func _init(d: Dictionary, t: String, dim := Vector2(110, 190)) -> void:
		desc = d
		titolo = t
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = dim

	func _draw() -> void:
		IconeEditor.anteprima(self, desc, Rect2(Vector2(6, 6), size - Vector2(12, 30)))
		var f := get_theme_default_font()
		var w := f.get_string_size(titolo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(f, Vector2((size.x - minf(w, size.x - 4)) * 0.5, size.y - 8), titolo, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, 13,
			Color(1, 0.9, 0.4) if button_pressed else Color(0.85, 0.85, 0.9))
