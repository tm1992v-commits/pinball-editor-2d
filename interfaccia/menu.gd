## Qui solo colori, visuali, voci proprie del tavolo e testi (regole, missioni, crediti).
## Voci conservate dal menu precedente: visuale (tavolo intero / ravvicinata), telecamera sul lancio, forza delle luci,
## musica, effetti, 3/5 palline, qualità grafica, segnaposto grafica, mostra FPS, pubblicità personalizzata.
class_name MenuGioco
extends MenuComune

var vista: Vista2D
var regole: RegoleBase

const VIOLA := Color(0.58, 0.32, 1.0)
const ORO := Color(1.0, 0.8, 0.28)

## v0.14 (Pinball Editor 2D): MENU PERSONALIZZATO dal tavolo (desc["menu"]): titolo, colori, testi di REGOLE,
## MISSIONI e CREDITI, pagine in più. Quello che non è scelto resta COME PRIMA (predefinito = menu di oggi).
var _m: Dictionary = {}

func prepara(v: Vista2D, r: RegoleBase) -> void:
	vista = v
	regole = r
	if v != null and v.desc.get("menu") is Dictionary:
		_m = v.desc["menu"]
	prepara_menu()

func _scelto(k: String) -> bool:
	return _m.has(k) and not (_m[k] is String and str(_m[k]) == "")

func _configura() -> void:
	titolo = "PINBALL"
	if vista != null and str(vista.desc.get("titolo", "")) != "":
		titolo = str(vista.desc["titolo"])     # v0.22: nei tavoli dell'editor il menu porta il nome del tavolo
	col_a = ORO
	col_b = VIOLA
	col_fondo = Color(0.03, 0.03, 0.09, 0.9)
	col_pannello = Color(0.05, 0.05, 0.13, 0.97)
	font_titolo = load("res://interfaccia/font/NotoSerifDisplay-Bold.ttf")
	font = load("res://interfaccia/font/NotoSansDisplay-Bold.ttf")
	# v0.21: font scelti nell'editor (vale anche per il tabellone)
	if vista != null:
		font_titolo = Hud.font_di(vista.desc, str(_m.get("font_titolo", "")), "serif")
		font = Hud.font_di(vista.desc, str(_m.get("font", "")), "sans")
	if _scelto("titolo"):
		titolo = str(_m["titolo"])
	for k in ["col_a", "col_b", "col_fondo", "col_pannello", "col_testo"]:
		if _m.get(k) is Color:
			set(k, _m[k])

func _posizione_icone(s: Vector2) -> Vector2:
	return Vector2(s.x - 120, 8)

func _visuali() -> Array:
	return [["fissa", "Tavolo intero"]]     # 2D: una sola visuale (decisione 3); il pulsante telecamera resta (menu comune)

func _visuale_attuale():
	return vista.visuale if vista else "fissa"

func _imposta_visuale(id) -> void:
	if vista:
		vista.imposta_visuale(id)
	Parametri.imposta("grafica", "visuale", id)

func _opzioni_visuale() -> Array:
	return []

func _righe_partita() -> Array:
	return [
		[_regolatore("LUCI", "grafica", "luci_intensita", 1.0, 0.3, 1.8, 0.1, func(n):
			if vista and vista.regia:
				vista.regia.intensita = n)],
		_scelta(["3 palline", "5 palline"], [3, 5], int(Parametri.valore("regole", "palline", 3)), func(v):
			Parametri.imposta("regole", "palline", v)),
	] + _righe_musica()

func _righe_musica() -> Array:
	var lista: Array = Audio.brani()
	if lista.size() < 2:
		return []
	var nomi: Array = ["Musica casuale"]
	var valori: Array = ["casuale"]
	for x in lista:
		nomi.append(str(x[1]))
		valori.append(str(x[0]))
	var attuale := str(Parametri.valore("musica", "scelta", "casuale"))
	var righe: Array = []
	for i in range(0, nomi.size(), 2):
		var controlli: Array = []
		for k in range(i, mini(i + 2, nomi.size())):
			var v: String = valori[k]
			controlli.append(_pulsante(nomi[k], col_a if k % 2 == 0 else col_b, func():
				Parametri.imposta("musica", "scelta", v)
				Audio.applica_scelta()
				_ricostruisci(), v == attuale))
		righe.append(controlli)
	return righe

func _interruttori_grafica() -> Array:
	return [_interruttore("Segnaposto grafica", "grafica", "segnaposto", true)]

func _nuova_partita() -> void:
	regole.nuova_partita()

func _nota_comandi() -> String:
	return "Tocca a sinistra / a destra per le palette. Pallina nella corsia: tieni premuto a destra e lascia per lanciare. Strisciata veloce = scossa."

func _testo_regole() -> String:
	if _scelto("regole"):
		return str(_m["regole"])
	var proprio := _testi_del_tavolo()
	if proprio.has("regole"):
		return str(proprio["regole"])
	return """LANCIO: tieni premuto a destra (o LANCIO) e lascia: più tieni, più forte.
PALETTE: tocca a sinistra e a destra (o i tasti delle palette). Strisciata veloce o colpo al telefono = scossa; troppe = TILT.
PUNTI: ogni pezzo colpito dà punti; le corsie e le file di bersagli accese danno premi.
MISSIONI: le scrive il tabellone in alto; completarle dà punti, bonus e palline extra.
SALVA-PALLINA: all'inizio di ogni pallina, per pochi secondi."""

func _testo_missioni() -> String:
	if _scelto("missioni"):
		return str(_m["missioni"])
	var proprio := _testi_del_tavolo()
	if proprio.has("missioni"):
		return str(proprio["missioni"])
	# v0.26: le missioni del tavolo (a mattoncini), con il loro nome
	var righe := PackedStringArray()
	if vista != null:
		for m in vista.desc.get("missioni", []):
			if m is Dictionary and bool(m.get("attiva", true)):
				righe.append("%s" % str(m.get("nome", "")).to_upper())
	return "\n".join(righe) if not righe.is_empty() else "Il tabellone in alto dice cosa colpire."

## v0.26: testi di menu propri di un tavolo scritto a mano (file tavoli/<nome>/testi_menu.gd con REGOLE e MISSIONI).
func _testi_del_tavolo() -> Dictionary:
	if vista == null:
		return {}
	var f := "res://tavoli/%s/testi_menu.gd" % str(vista.desc.get("nome", ""))
	if not ResourceLoader.exists(f):
		return {}
	var sc = load(f)
	var out := {"regole": sc.REGOLE, "missioni": sc.MISSIONI}
	if "CREDITI" in sc:
		out["crediti"] = sc.CREDITI
	return out

## Pagine in più scelte nell'editor: [titolo, testo] → un pulsante ciascuna sotto INFORMAZIONI.
func _voci_extra() -> Array:
	var out: Array = []
	# v0.23: CLASSIFICA dei 10 migliori (se il tavolo la usa)
	if regole != null and regole.classifica != null:
		out.append([Testi.t("CLASSIFICA"), func():
			pagina = "extra"
			_sel = 0
			pagina_testo(Testi.t("CLASSIFICA"), regole.classifica.testo(), [])])
	for pg in _m.get("pagine", []):
		if pg is Dictionary and str(pg.get("titolo", "")) != "":
			var tt := str(pg["titolo"]).to_upper()
			var tx := str(pg.get("testo", ""))
			out.append([tt, func():
				pagina = "extra"
				_sel = 0
				pagina_testo(tt, tx, [])])
	return out

func _pagine_crediti() -> Array:
	if _scelto("crediti"):
		return [str(_m["crediti"])] + _crediti_rilascio() + crediti_godot()
	var proprio := _testi_del_tavolo()
	if proprio.has("crediti"):
		return proprio["crediti"] + crediti_godot()
	var gi: Dictionary = vista.desc.get("gioco_info", {}) if vista != null and vista.desc.get("gioco_info") is Dictionary else {}
	var autore := str(gi.get("autore", ""))
	return ["%s%s\n\nRealizzato con Pinball Editor 2D.\nCreated by Carmelo Vadalà – Open Source Community Project.\n\nCaratteri: Noto Sans Display e Noto Serif Display (The Noto Project Authors) – SIL Open Font License 1.1." % [titolo, ("\nUn pinball di " + autore) if autore != "" else ""],
	"""SUONI – Freesound.org, licenza CC0 (pubblico dominio). Grazie agli autori!

schafferdavid – palette, bumper, fionde, lancio, bersagli
NeatoEnt – pallina nella buca"""] + _crediti_rilascio() + crediti_godot()

## v0.26: pinball RILASCIATO dall'editor (res://gioco/rilascio.json): licenze e indirizzo del codice sorgente.
func _crediti_rilascio() -> Array:
	if not FileAccess.file_exists("res://gioco/rilascio.json"):
		return []
	var r = JSON.parse_string(FileAccess.get_file_as_string("res://gioco/rilascio.json"))
	if not r is Dictionary:
		return []
	return ["""%s %s – di %s

Codice: GNU GPL v3 o successiva. Contenuti originali: CC BY-SA 4.0.
Puoi usarlo, modificarlo, ridistribuirlo e venderlo, anche modificato, alle stesse condizioni e citando gli autori.

CODICE SORGENTE:
%s

Created by Carmelo Vadalà (Pinball Editor 2D). L'autore dell'editor non approva né sponsorizza i singoli giochi.""" % [str(r.get("nome", "")), str(r.get("versione", "")), str(r.get("autore", "")), str(r.get("repository", ""))]]
