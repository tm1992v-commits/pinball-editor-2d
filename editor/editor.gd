## PINBALL EDITOR 2D – finestra principale (v0.1, 23/11/2026).
## Barra in alto (Nuovo, Apri, Salva, Salva con nome, Annulla, Ripristina, SEMPLICE/PRO, GIOCA, CONTROLLA) · a sinistra
## la libreria dei pezzi · al centro il tavolo · a destra le proprietà del pezzo scelto · in basso problemi, pezzi e
## diario. Tutto passa dai comandi di ProgettoEditor (gli stessi che usa l'AI).
extends Control

const VERSIONE := "0.16"
const CARTELLA_PROGETTI := "res://../progetti"

var progetto := ProgettoEditor.new()
var vista: VistaTavolo
var _pannello: VBoxContainer
var _libreria: VBoxContainer
var _stato: Label
var _mouse: Label
var _problemi: ItemList
var _pezzi: ItemList
var _livelli: VBoxContainer
var _lista_missioni: VBoxContainer
var _lista_regia: VBoxContainer
var _scheda_sim: VBoxContainer
var _sim: SimulatoreRegole
var _sim_stato: RichTextLabel
var _missione_scelta := ""
var _menu_aperto := false
var _lic_aperto := false
var _cz_aperto := false
var _schede: TabContainer
var _diario: RichTextLabel
var _b_modalita: Button
var _b_annulla: Button
var _b_ripristina: Button
var _b_controlla: Button
var _dialogo: FileDialog
var _scopo_dialogo := ""
var pro := false
var _thread: Thread
var _ricostruisci_pannello := true
var _appunti: Array = []                # pezzi copiati (Ctrl+C): [lista, dizionario]

func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Pinball Editor 2D " + VERSIONE)
		var schermo := DisplayServer.screen_get_usable_rect()
		var dim := Vector2i(mini(1600, schermo.size.x - 40), mini(960, schermo.size.y - 60))
		DisplayServer.window_set_size(dim)
		DisplayServer.window_set_position(schermo.position + (schermo.size - dim) / 2)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_costruisci()
	progetto.cambiato.connect(_su_cambiato)
	DirAccess.make_dir_recursive_absolute(cartella_progetti())
	# all'avvio: l'ultimo progetto aperto, altrimenti un tavolo nuovo dal modello Base
	var ultimo := _ultimo_progetto()
	if ultimo != "" and progetto.apri(ultimo).get("ok", false):
		_avviso("Riaperto «%s»" % ultimo.get_file())
	else:
		progetto.esegui({"comando": "nuovo", "modello": "base", "nome": "Nuovo tavolo"})
		progetto.modificato = false
		_avviso("Tavolo nuovo dal modello Base (zona bassa già pronta). Scegli un pezzo a sinistra e clicca sul tavolo.")
	vista.adatta.call_deferred()
	_aggiorna_tutto()
	# per le prove e per l'AI: --apri=CARTELLA apre un progetto, --scegli=ID seleziona un pezzo,
	# --foto=FILE.png salva una schermata dell'editor e chiude
	if Parametri.arg("apri") != "":
		_su_apri_diretto(Parametri.arg("apri"))
	if Parametri.arg("mostra") == "nuovo":
		_nuovo.call_deferred()
	elif Parametri.arg("mostra") == "apri":
		_apri_elenco.call_deferred()
	elif Parametri.arg("mostra") == "salva":
		_salva_con_nome.call_deferred()
	if Parametri.arg("traccia") != "":
		# per le foto di controllo: --traccia=X,Y,VX,VY[,TIRI]
		var q := Parametri.arg("traccia").split(",")
		_scegli_pezzo("traccia", null)
		if q.size() >= 5:
			_traccia_opz["tiri"] = int(q[4])
		progetto.ultima_traccia = Tracciatore.esegui(progetto.desc, {"da": Vector2(float(q[0]), float(q[1])), "vel": Vector2(float(q[2]), float(q[3])), "tiri": int(_traccia_opz["tiri"]), "variazione": 3.0})
		_ricostruisci_pannello = true
		_aggiorna_pannello()
	if Parametri.arg("ventaglio") != "" or Parametri.arg("calore") != "":
		_scegli_pezzo("traccia", null)
		progetto.ultima_traccia = Tracciatore.esegui(progetto.desc, {"paletta": Parametri.arg("ventaglio"), "colpi": 6} if Parametri.arg("ventaglio") != "" else {"calore": float(Parametri.arg("calore"))})
		_ricostruisci_pannello = true
		_aggiorna_pannello()
	if Parametri.arg("simula") != "":
		# foto di controllo: --simula=lista:id,lista:id… (avvia il simulatore e preme quei pezzi)
		_sim.avvia(progetto.desc)
		for x in Parametri.arg("simula").split(","):
			var q := x.split(":")
			if q.size() == 2:
				_sim.premi(q[0], q[1])
	if Parametri.arg("pannello") == "menu":
		_apri_menu(true)
	elif Parametri.arg("pannello") == "rilascio":
		get_tree().create_timer(0.5).timeout.connect(_rilascio_guidato)   # foto di controllo del rilascio
	elif Parametri.arg("pannello") == "guidata":
		get_tree().create_timer(0.5).timeout.connect(_procedura_guidata)   # foto di controllo della procedura guidata
	if Parametri.arg("telefono") != "":
		vista.anteprima_tel = float(Parametri.arg("telefono"))
		vista.adatta.call_deferred()
	elif Parametri.arg("pannello") == "cz":
		_apri_cz()
	if Parametri.arg("missione") != "":
		_scegli_missione(Parametri.arg("missione"))
	if Parametri.arg("scheda") != "" and _schede.has_node(Parametri.arg("scheda")):
		_schede.current_tab = _schede.get_node(Parametri.arg("scheda")).get_index()
	if Parametri.arg("foto") != "":
		_foto.call_deferred(Parametri.arg("foto"))

func _su_apri_diretto(dir: String) -> void:
	var r := progetto.esegui({"comando": "apri", "cartella": dir})
	_avviso(r["messaggio"])
	vista.adatta.call_deferred()
	if Parametri.arg("scegli") != "":
		vista.seleziona(Parametri.arg("scegli"))
	if Parametri.argomenti.has("controlla"):
		_controlla.call_deferred()

func _foto(file: String) -> void:
	await get_tree().create_timer(1.5).timeout
	if Parametri.argomenti.has("controlla"):
		while _thread != null and _thread.is_alive():
			await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.5).timeout
	if Parametri.argomenti.has("pro"):
		_cambia_modalita()
		await get_tree().process_frame
	# --renderizza: prova del pulsante RENDERIZZA (tutto il tavolo) prima della foto
	if Parametri.argomenti.has("renderizza"):
		await _renderizza(false)
		await get_tree().create_timer(8.0).timeout
	# --zoom=K --centro=X,Y (mm): foto ravvicinata di una zona del tavolo
	if Parametri.arg("zoom") != "":
		vista.scala = float(Parametri.arg("zoom"))
		var cc := Parametri.arg("centro").split(",")
		vista.centra_su(Vector2(float(cc[0]), float(cc[1])) if cc.size() == 2 else Vector2(317, 620))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)
	print("FOTO_EDITOR ", file)
	get_tree().quit()

static func cartella_progetti() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../progetti").simplify_path()

# ================================================================ costruzione dell'interfaccia
func _costruisci() -> void:
	var sfondo := ColorRect.new()
	sfondo.color = Color(0.13, 0.13, 0.15)
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sfondo)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	# --- barra in alto
	var barra := HFlowContainer.new()      # v0.21: va a capo se lo schermo è stretto (prima tagliava i pulsanti a destra)
	col.add_child(barra)
	_bottone(barra, "Nuovo", _nuovo, "Nuovo tavolo dal modello Base (zona bassa pronta)")
	_bottone(barra, "Apri", _apri_elenco, "Apri un tavolo salvato")
	var imp := MenuButton.new()
	imp.text = "📥 Importa flipper"
	imp.tooltip_text = "Apre come tavolo nuovo un tuo flipper 2D già fatto (copia: l'originale non cambia)"
	var trovati := ProgettoEditor.flipper_trovati()
	for t in trovati:
		imp.get_popup().add_item(str(t["nome"]))
	imp.get_popup().add_item("Scegli il file del tavolo (layout_….gd)…")
	imp.get_popup().index_pressed.connect(func(i):
		if i < trovati.size():
			_importa_flipper(str(trovati[i]["file"]))
		else:
			_scegli_file("Scegli il file del tavolo (tavoli/NOME/layout_NOME.gd)", _importa_flipper, "*.gd ; Tavolo di un flipper"))
	barra.add_child(imp)
	_bottone(barra, "Salva", _salva, "Salva il progetto (Ctrl+S)")
	_bottone(barra, "Salva con nome", _salva_con_nome, "Salva il tavolo con un nome nuovo, nella cartella «progetti»")
	barra.add_child(VSeparator.new())
	_b_annulla = _bottone(barra, "↶ Annulla", func(): _comando({"comando": "annulla"}), "Annulla l'ultima modifica (Ctrl+Z)")
	_b_ripristina = _bottone(barra, "↷ Ripristina", func(): _comando({"comando": "ripristina"}), "Ripristina (Ctrl+Y)")
	barra.add_child(VSeparator.new())
	_b_modalita = _bottone(barra, "Modalità: SEMPLICE", _cambia_modalita, "SEMPLICE: poche proprietà. PRO: tutte.")
	var g := CheckButton.new()
	g.text = "Griglia e aggancio 5 mm"
	g.button_pressed = true
	g.toggled.connect(func(v): vista.griglia = v; vista.aggancio = v; vista.queue_redraw())
	barra.add_child(g)
	# v0.19: guide delle collisioni (solo editor)
	var gc := CheckButton.new()
	gc.text = "Collisioni"
	gc.tooltip_text = "Mostra in azzurro dove sbatte davvero la pallina (le immagini «al posto del disegno» le mostrano sempre)"
	gc.toggled.connect(func(v): vista.mostra_collisioni = v; vista.queue_redraw())
	barra.add_child(gc)
	var spazio := Control.new()
	spazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(spazio)
	var rend := MenuButton.new()
	rend.text = "🖼  RENDERIZZA"
	rend.tooltip_text = "Salva il disegno finito in immagini PNG (cartella «renderizzati» del progetto)"
	rend.get_popup().add_item("Tutto il tavolo e ogni pezzo", 0)
	rend.get_popup().add_item("Solo il pezzo scelto", 1)
	rend.get_popup().id_pressed.connect(func(i): _renderizza(i == 1))
	barra.add_child(rend)
	# v0.21: aspetto del gioco a portata di mano (prima stava solo in fondo alle proprietà del tavolo)
	var asp := Button.new()
	asp.text = "🎨 Aspetto"
	asp.tooltip_text = "Colori e font del menu, altezza del tabellone, pagine del menu"
	asp.pressed.connect(func(): vista.seleziona(""); _apri_menu(true))
	barra.add_child(asp)
	# v0.20: ESPORTA il gioco vero
	var esp := MenuButton.new()
	esp.text = "📦 ESPORTA"
	esp.tooltip_text = "Crea il gioco vero dal tavolo (nella cartella «esportati» del progetto)"
	for k in Esportazione.PIATTAFORME:
		esp.get_popup().add_item(("Gioco per " if k in ["linux", "windows", "pi"] else "") + str(Esportazione.PIATTAFORME[k]["nome"]))
	var chiavi_esp: Array = Esportazione.PIATTAFORME.keys()
	esp.get_popup().add_item("🎬 Video promozionale (30 secondi, senza audio)")
	esp.get_popup().add_item("🚀 RILASCIO UFFICIALE (gioco + sorgente pubblico)")
	esp.get_popup().add_item("⬇ Installa i modelli di esportazione (una volta sola)")
	esp.get_popup().index_pressed.connect(func(i):
		if i < chiavi_esp.size():
			_esporta(str(chiavi_esp[i]))
		elif i == chiavi_esp.size():
			_video_promo()
		elif i == chiavi_esp.size() + 1:
			_rilascio_guidato()
		else:
			_installa_modelli())
	barra.add_child(esp)
	var gioca := _bottone(barra, "▶  GIOCA", _gioca, "Prova il tavolo con il motore vero (non cambia il progetto)")
	gioca.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_b_controlla = _bottone(barra, "✔  CONTROLLA", _controlla, "Cerca varchi pericolosi e palline incastrate")
	# v0.25: «Sistema tu» (allarga da solo i varchi pericolosi) e anteprima telefono
	_bottone(barra, "🔧 Sistema tu", _sistema_tu, "Allarga da solo gli spazi pericolosi tra i pezzi (dove la pallina si incastra). Un solo «annulla».")
	var tel := MenuButton.new()
	tel.text = "📱 Telefono"
	tel.tooltip_text = "Mostra sul tavolo lo schermo del telefono e il tabellone, come nel gioco"
	tel.get_popup().add_item("Spenta", 0)
	tel.get_popup().add_item("Telefono di oggi (20:9, lungo)", 1)
	tel.get_popup().add_item("Telefono vecchio (16:9)", 2)
	tel.get_popup().id_pressed.connect(func(i):
		vista.anteprima_tel = [0.0, 1600.0, 1280.0][i]
		vista.adatta()
		vista.queue_redraw())
	barra.add_child(tel)
	_bottone(barra, "🪄 Primo flipper", _procedura_guidata, "Procedura guidata: un flipper giocabile in 5 passi")
	_b_controlla.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	# v0.18.2: guida integrata (il manuale dentro l'editor)
	_bottone(barra, "❓ Guida", func(): _apri_guida(""), "Il manuale dell'editor, con indice e ricerca (F1)")
	# --- centro
	var centro := HSplitContainer.new()
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(centro)
	var sx := ScrollContainer.new()
	sx.custom_minimum_size = Vector2(200, 0)
	centro.add_child(sx)
	_libreria = VBoxContainer.new()
	_libreria.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sx.add_child(_libreria)
	var mezzo := HSplitContainer.new()
	mezzo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_child(mezzo)
	var vcol := VSplitContainer.new()
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mezzo.add_child(vcol)
	vista = VistaTavolo.new()
	vista.progetto = progetto
	vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vista.custom_minimum_size = Vector2(400, 300)
	vista.selezione_cambiata.connect(func(_id): _missione_scelta = ""; _menu_aperto = false; _lic_aperto = false; _cz_aperto = false; _ricostruisci_pannello = true; _aggiorna_pannello())
	vista.pezzo_cliccato.connect(_premi_nel_simulatore)
	vista.punto_scelto.connect(func(_i): _ricostruisci_pannello = true; _aggiorna_pannello.call_deferred())
	vista.posizione_mouse.connect(func(m): _mouse.text = "mouse: %.0f × %.0f mm" % [m.x, m.y])
	vista.messaggio.connect(_avviso)
	vista.traccia_richiesta.connect(_su_traccia)
	vcol.add_child(vista)
	var schede := TabContainer.new()
	_schede = schede
	schede.tab_changed.connect(_su_scheda)
	schede.custom_minimum_size = Vector2(0, 150)
	vcol.add_child(schede)
	_problemi = ItemList.new()
	_problemi.name = "Problemi"
	_problemi.item_selected.connect(_su_problema)
	schede.add_child(_problemi)
	_pezzi = ItemList.new()
	_pezzi.name = "Pezzi"
	_pezzi.item_selected.connect(func(i): vista.seleziona(str(_pezzi.get_item_metadata(i))))
	_pezzi.item_activated.connect(func(i):
		var pid := str(_pezzi.get_item_metadata(i))
		if bool(progetto.pezzo(pid).get("bloccato", false)):
			_avviso(progetto.esegui({"comando": "gruppo", "ids": [pid], "azione": "blocca", "valore": false})["messaggio"]))
	schede.add_child(_pezzi)
	# v0.9.4: LIVELLI con nome (tavolo e piani rialzati): occhio = mostra/nascondi, lucchetto = blocca
	var sc_liv := ScrollContainer.new()
	sc_liv.name = "Livelli"
	schede.add_child(sc_liv)
	_livelli = VBoxContainer.new()
	_livelli.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_liv.add_child(_livelli)
	# v0.11: SUONI e LUCI degli eventi
	var sc_reg := ScrollContainer.new()
	sc_reg.name = "Suoni e luci"
	schede.add_child(sc_reg)
	_lista_regia = VBoxContainer.new()
	_lista_regia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_reg.add_child(_lista_regia)
	# v0.16: SIMULATORE DI REGOLE
	var sc_sim := ScrollContainer.new()
	sc_sim.name = "Simulatore"
	schede.add_child(sc_sim)
	_scheda_sim = VBoxContainer.new()
	_scheda_sim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_sim.add_child(_scheda_sim)
	_sim = SimulatoreRegole.new()
	add_child(_sim)
	_sim.cambiato.connect(_aggiorna_sim_stato)
	# v0.10: MISSIONI a mattoncini
	var sc_mis := ScrollContainer.new()
	sc_mis.name = "Missioni"
	schede.add_child(sc_mis)
	_lista_missioni = VBoxContainer.new()
	_lista_missioni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_mis.add_child(_lista_missioni)
	_diario = RichTextLabel.new()
	_diario.name = "Diario"
	_diario.scroll_following = true
	schede.add_child(_diario)
	var dx := ScrollContainer.new()
	dx.custom_minimum_size = Vector2(330, 0)
	dx.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED     # v0.21: testi a capo, niente righe tagliate
	mezzo.add_child(dx)
	_pannello = VBoxContainer.new()
	_pannello.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dx.add_child(_pannello)
	# --- barra di stato
	var basso := HBoxContainer.new()
	col.add_child(basso)
	_stato = Label.new()
	_stato.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stato.clip_text = true
	basso.add_child(_stato)
	_mouse = Label.new()
	basso.add_child(_mouse)
	# --- finestra per aprire/salvare
	_dialogo = FileDialog.new()
	_dialogo.access = FileDialog.ACCESS_FILESYSTEM
	_dialogo.use_native_dialog = false
	_dialogo.size = Vector2i(900, 600)
	_dialogo.dir_selected.connect(_su_cartella_scelta)
	_dialogo.file_selected.connect(func(f): _su_cartella_scelta(f.get_base_dir()))
	add_child(_dialogo)
	_costruisci_libreria()

func _bottone(dove: Control, testo: String, f: Callable, aiuto := "") -> Button:
	var b := Button.new()
	b.text = testo
	b.tooltip_text = aiuto
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	dove.add_child(b)
	return b

## In SEMPLICE i pezzi più tecnici (kickback, pozzo/magnete, paletto) sono nascosti; in PRO ci sono tutti.
const SOLO_PRO := ["kickback", "campi", "elastici"]
## Forme pronte da muro (stile VPX): si mettono con un clic e poi si modificano punto per punto.
const PRESET_LIBRERIA := {
	"preset:fionda": {"nome": "Fionda: triangolo di gomma con il lato che spinge (forma libera)", "breve": "Fionda", "colore": Color(1.0, 0.6, 0.8)},
	"preset:gomma": {"nome": "Gomma: anello di gomma curvo (intorno a paletti)", "breve": "Gomma", "colore": Color(0.95, 0.35, 0.3)},
	"preset:isola": {"nome": "Isola: blocco chiuso con i bordi curvi", "breve": "Isola", "colore": Color(0.8, 0.82, 0.88)},
	"composto:corsia": {"nome": "Corsia: due guide + sensore + luce, con un clic", "breve": "Corsia", "colore": Color(0.4, 1.0, 0.5)},
	"composto:corsie_3": {"nome": "3 corsie in alto: guide, sensori e luci, con un clic", "breve": "3 corsie", "colore": Color(0.4, 1.0, 0.5)},
	"composto:abbattibili_3": {"nome": "Fila di 3 bersagli abbattibili con le luci (tutti giù = premio, poi si rialzano)", "breve": "3 abbattibili", "colore": Color(1.0, 0.82, 0.15)},
	"composto:abbattibili_5": {"nome": "Fila di 5 bersagli abbattibili con le luci (tutti giù = premio, poi si rialzano)", "breve": "5 abbattibili", "colore": Color(1.0, 0.82, 0.15)},
	"composto:scoop": {"nome": "Scoop: buca con il bordo a ferro di cavallo (prende la pallina dall'apertura e la risputa fuori)", "breve": "Scoop", "colore": Color(0.6, 0.6, 0.7)},
	"composto:bumper_3": {"nome": "Triangolo di 3 bumper, già alla giusta distanza (v0.25)", "breve": "3 bumper", "colore": Color(1.0, 0.4, 0.35)},
	"composto:bersagli_buca": {"nome": "Buca con 3 bersagli ad arco dietro (v0.25)", "breve": "Buca+bers.", "colore": Color(1.0, 0.82, 0.15)},
	"composto:spinner_corsia": {"nome": "Spinner in una corsia con due guide (v0.25)", "breve": "Spinner+corsia", "colore": Color(0.5, 0.85, 1.0)},
}

func _costruisci_libreria() -> void:
	for c in _libreria.get_children():
		_libreria.remove_child(c)
		c.queue_free()
	var t1 := Label.new()
	t1.text = "STRUMENTI"
	_libreria.add_child(t1)
	var g1 := GridContainer.new()
	g1.columns = 2
	_libreria.add_child(g1)
	var sel := IconeEditor.BottoneIcona.new("seleziona", "Seleziona", Color.WHITE)
	sel.tooltip_text = "Seleziona e sposta i pezzi (Esc)"
	sel.button_pressed = vista.da_inserire == ""
	sel.pressed.connect(func(): _scegli_pezzo("", sel))
	g1.add_child(sel)
	# v0.9.5: TRACCIATORE delle traiettorie
	var trc := IconeEditor.BottoneIcona.new("traccia", "Traccia tiro", Color(1.0, 0.55, 0.2))
	trc.tooltip_text = "Clic dove parte la pallina, trascina per direzione e forza, rilascia: vedi dove va"
	trc.button_pressed = vista.da_inserire == "traccia"
	trc.pressed.connect(func(): _scegli_pezzo("traccia", trc))
	g1.add_child(trc)
	# v0.16: RIGHELLO
	var rig := IconeEditor.BottoneIcona.new("righello", "Righello", Color(1.0, 0.85, 0.2))
	rig.tooltip_text = "Misura: clic e trascina, vedi la distanza in mm e l'angolo"
	rig.button_pressed = vista.da_inserire == "righello"
	rig.pressed.connect(func(): _scegli_pezzo("righello", rig))
	g1.add_child(rig)
	var t2 := Label.new()
	t2.text = "PEZZI (scegli, poi clicca sul tavolo)"
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD
	t2.custom_minimum_size = Vector2(180, 0)
	_libreria.add_child(t2)
	# v0.19: ELEMENTO DA IMMAGINE (la tua immagine intatta + collisione invisibile) e I MIEI ELEMENTI
	var b_img := _bottone(_libreria, "🖼 Da immagine…", _elemento_da_immagine, "La tua immagine diventa un pezzo (bumper, bersaglio, forma…): l'immagine resta com'è, la collisione azzurra si regola")
	b_img.custom_minimum_size = Vector2(180, 34)
	var b_lib := _bottone(_libreria, "⭐ I miei elementi", _apri_libreria_elementi, "Elementi salvati: inseriscili in questo tavolo")
	b_lib.custom_minimum_size = Vector2(180, 30)
	var g2 := GridContainer.new()
	g2.columns = 2
	_libreria.add_child(g2)
	for k in SchedeEditor.ORDINE:
		if k in SOLO_PRO and not pro:
			continue
		if k == "fionde":
			k = "preset:fionda"       # la fionda si disegna come forma libera (muro con tratto-fionda)
		var s: Dictionary = SchedeEditor.scheda(k) if not k.begins_with("preset:") else PRESET_LIBRERIA[k]
		var b := IconeEditor.BottoneIcona.new(k, str(s.get("breve", s["nome"])), s.get("colore", Color.WHITE))
		b.tooltip_text = str(s["nome"])
		b.button_pressed = vista.da_inserire == k
		b.pressed.connect(func(): _scegli_pezzo(k, b))
		g2.add_child(b)
		if k == "sensori":
			for pk in ["composto:corsia", "composto:corsie_3"]:
				var pc: Dictionary = PRESET_LIBRERIA[pk]
				var bc := IconeEditor.BottoneIcona.new(pk, pc["breve"], pc["colore"])
				bc.tooltip_text = pc["nome"]
				bc.button_pressed = vista.da_inserire == pk
				bc.pressed.connect(func(): _scegli_pezzo(pk, bc))
				g2.add_child(bc)
		var gruppi_dopo := {"bumper": ["composto:bumper_3"], "buche": ["composto:bersagli_buca"], "spinner": ["composto:spinner_corsia"]}
		for pk2 in gruppi_dopo.get(k, []):
			var pg: Dictionary = PRESET_LIBRERIA[pk2]
			var bg := IconeEditor.BottoneIcona.new(pk2, pg["breve"], pg["colore"])
			bg.tooltip_text = pg["nome"]
			bg.button_pressed = vista.da_inserire == pk2
			var pk_c: String = pk2
			bg.pressed.connect(func(): _scegli_pezzo(pk_c, bg))
			g2.add_child(bg)
		if k == "buche":
			var psc: Dictionary = PRESET_LIBRERIA["composto:scoop"]
			var bsc := IconeEditor.BottoneIcona.new("composto:scoop", psc["breve"], psc["colore"])
			bsc.tooltip_text = psc["nome"]
			bsc.button_pressed = vista.da_inserire == "composto:scoop"
			bsc.pressed.connect(func(): _scegli_pezzo("composto:scoop", bsc))
			g2.add_child(bsc)
		if k == "bersagli":
			for pk in ["composto:abbattibili_3", "composto:abbattibili_5"]:
				var pa: Dictionary = PRESET_LIBRERIA[pk]
				var ba := IconeEditor.BottoneIcona.new(pk, pa["breve"], pa["colore"])
				ba.tooltip_text = pa["nome"]
				ba.button_pressed = vista.da_inserire == pk
				ba.pressed.connect(func(): _scegli_pezzo(pk, ba))
				g2.add_child(ba)
		if k == "muri":
			for pk in ["preset:gomma", "preset:isola"]:
				var ps: Dictionary = PRESET_LIBRERIA[pk]
				var bp := IconeEditor.BottoneIcona.new(pk, ps["breve"], ps["colore"])
				bp.tooltip_text = ps["nome"]
				bp.button_pressed = vista.da_inserire == pk
				bp.pressed.connect(func(): _scegli_pezzo(pk, bp))
				g2.add_child(bp)

func _bottoni_libreria() -> Array:
	var out: Array = []
	for g in _libreria.get_children():
		if g is GridContainer:
			out.append_array(g.get_children())
	return out

func _scegli_pezzo(k: String, b: Button) -> void:
	vista.chiudi_disegno()          # cambiando strumento il disegno in corso si chiude (non si perde)
	vista.annulla_inserimento()
	if b != null and not b.button_pressed and k != "":
		k = ""
	vista.da_inserire = k
	for c in _bottoni_libreria():
		c.button_pressed = (c.tipo == k) if k != "" else (c.tipo == "seleziona")
		c.queue_redraw()
	_ricostruisci_pannello = true
	_aggiorna_pannello()
	vista.queue_redraw()
	if k == "righello":
		_avviso("RIGHELLO: clic e trascina sul tavolo; la misura (mm e angolo) resta finché non ne fai un'altra. Si aggancia alla griglia se è accesa.")
	elif k == "traccia":
		_avviso("TRACCIA TIRO: clic dove parte la pallina, TRASCINA verso dove va (più lungo = più forte), rilascia. Opzioni a destra.")
	elif k == "":
		_avviso("SELEZIONA: clicca un pezzo per sceglierlo, trascinalo per spostarlo.")
	elif k == "muri":
		_avviso("Muro: clic = punto ad angolo, Maiusc+clic = punto CURVO. Per finire: pulsante ✔ FINE sul tavolo (o clic destro).")
	elif k == "nastri":
		_avviso("Nastro: clic sull'INGRESSO, poi i punti del percorso (Maiusc+clic = curvo); per finire: pulsante ✔ FINE sul tavolo (o clic destro). Larghezza e altezza le regoli dopo, anche punto per punto.")
	elif k == "rampe":
		_avviso("Rampa: clic sull'IMBOCCO (dove la pallina entra, a terra), poi i punti del percorso; per finire: pulsante ✔ FINE sul tavolo (o clic destro). L'altezza la sistemi dopo, punto per punto.")
	elif k.begins_with("composto:"):
		_avviso("Clicca dove vuoi «%s» (al centro)." % PRESET_LIBRERIA[k]["breve"])
	elif k.begins_with("preset:"):
		_avviso("Clicca sul tavolo dove vuoi la «%s». Poi trascina i punti per darle la forma che vuoi." % PRESET_LIBRERIA[k]["breve"])
	else:
		_avviso("Clicca sul tavolo dove vuoi il pezzo «%s». Esc per tornare a Seleziona." % SchedeEditor.scheda(k)["nome"])

# ================================================================ COLLEZIONE e ZONE (v0.14)
func _apri_cz() -> void:
	_cz_aperto = true
	_menu_aperto = false
	_missione_scelta = ""
	vista.seleziona("")
	_cz_aperto = true
	_ricostruisci_pannello = true
	_aggiorna_pannello()

func _cz(c: Dictionary, rifai := false) -> void:
	_avviso(progetto.esegui(c)["messaggio"])
	_aggiorna_missioni()
	if rifai:
		_ricostruisci_pannello = true
		_aggiorna_pannello.call_deferred()

func _pannello_cz() -> void:
	var col: Dictionary = progetto.desc.get("collezione", {}) if progetto.desc.get("collezione") is Dictionary else {}
	_titolo_pannello("COLLEZIONE (catture)")
	_etichetta("Il premio «cattura» di una missione dà un oggetto a caso: i rari escono meno.")
	_campo_testo("Nome della collezione", str(col.get("nome", "Collezione")), func(v): _cz({"comando": "collezione", "azione": "nome", "nome": v}))
	var ogg: Array = col.get("oggetti", [])
	for k in ogg.size():
		var kk := k
		var r := HBoxContainer.new()
		_pannello.add_child(r)
		var le := LineEdit.new()
		le.text = str(ogg[k].get("nome", ""))
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_submitted.connect(func(v): _cz({"comando": "collezione", "azione": "imposta", "indice": kk, "nome": v}))
		le.focus_exited.connect(func(): _cz({"comando": "collezione", "azione": "imposta", "indice": kk, "nome": le.text}))
		r.add_child(le)
		_bottone(r, "✖", func(): _cz({"comando": "collezione", "azione": "togli", "indice": kk}, true), "Togli")
		r = HBoxContainer.new()
		_pannello.add_child(r)
		var ob := OptionButton.new()
		for x in ["comune", "raro", "leggendario"]:
			ob.add_item(x)
		ob.selected = clampi(int(ogg[k].get("rarita", 1)) - 1, 0, 2)
		ob.item_selected.connect(func(i): _cz({"comando": "collezione", "azione": "imposta", "indice": kk, "rarita": i + 1}))
		r.add_child(ob)
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = 10000000
		sp.step = 1000
		sp.value = float(ogg[k].get("punti", 10000))
		sp.tooltip_text = "Punti della cattura"
		sp.value_changed.connect(func(v): _cz({"comando": "collezione", "azione": "imposta", "indice": kk, "punti": int(v)}))
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(sp)
		# v0.17.2: evoluzione
		r = HBoxContainer.new()
		_pannello.add_child(r)
		var le2 := Label.new()
		le2.text = "  si evolve in"
		r.add_child(le2)
		var ob_e := OptionButton.new()
		var ids: Array = [""]
		ob_e.add_item("(nessuno)")
		for o in ogg:
			if str(o.get("id", "")) != str(ogg[k].get("id", "")):
				ids.append(str(o["id"]))
				ob_e.add_item(str(o.get("nome", o["id"])))
		ob_e.selected = maxi(0, ids.find(str(ogg[k].get("evolve_in", ""))))
		ob_e.tooltip_text = "Dopo tante catture di questo oggetto si ottiene l'altro (che non esce mai a caso)"
		ob_e.item_selected.connect(func(i): _cz({"comando": "collezione", "azione": "imposta", "indice": kk, "evolve_in": ids[i]}, true))
		r.add_child(ob_e)
		if str(ogg[k].get("evolve_in", "")) != "":
			var ld := Label.new()
			ld.text = "dopo"
			r.add_child(ld)
			var sp_e := _numero(r, float(ogg[k].get("evolve_dopo", 3)), 1, 20, 1)
			sp_e.tooltip_text = "Catture necessarie"
			sp_e.value_changed.connect(func(v): _cz({"comando": "collezione", "azione": "imposta", "indice": kk, "evolve_dopo": int(v)}))
	_bottone(_pannello, "+ Aggiungi un oggetto", func(): _cz({"comando": "collezione", "azione": "aggiungi"}, true), "")
	_etichetta("Premio per la collezione completa (punti)")
	var spc := _numero(_pannello, float(col.get("premio_completa", 1000000)), 0, 100000000, 50000)
	spc.value_changed.connect(func(v): _cz({"comando": "collezione", "azione": "premio", "punti": int(v)}))
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("ZONE (viaggi)")
	_etichetta("Il premio «zona successiva» porta alla zona dopo; ogni missione può valere solo in certe zone.")
	var zz: Array = progetto.desc.get("zone", []) if progetto.desc.get("zone") is Array else []
	for k in zz.size():
		var kk := k
		var rz := HBoxContainer.new()
		_pannello.add_child(rz)
		var lz := Label.new()
		lz.text = "%d." % (k + 1)
		rz.add_child(lz)
		var lez := LineEdit.new()
		lez.text = str(zz[k].get("nome", ""))
		lez.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lez.text_submitted.connect(func(v): _cz({"comando": "zone", "azione": "imposta", "indice": kk, "nome": v}))
		lez.focus_exited.connect(func(): _cz({"comando": "zone", "azione": "imposta", "indice": kk, "nome": lez.text}))
		rz.add_child(lez)
		_bottone(rz, "✖", func(): _cz({"comando": "zone", "azione": "togli", "indice": kk}, true), "Togli")
	_bottone(_pannello, "+ Aggiungi una zona", func(): _cz({"comando": "zone", "azione": "aggiungi"}, true), "")
	_pannello.add_child(HSeparator.new())
	_bottone(_pannello, "Chiudi", func(): _cz_aperto = false; _ricostruisci_pannello = true; _aggiorna_pannello(), "")

# ================================================================ LICENZE (v0.17.2)
func _apri_licenze(si: bool) -> void:
	_lic_aperto = si
	_menu_aperto = false
	_missione_scelta = ""
	_ricostruisci_pannello = true
	_aggiorna_pannello()

func _pannello_licenze() -> void:
	_titolo_pannello("📜 LICENZE")
	_etichetta("Per ogni immagine, musica e font del tavolo: da dove viene, chi l'ha fatta, con che licenza. Per un RILASCIO libero servono licenze che permettono uso commerciale e modifiche (niente «NonCommercial», «NoDerivatives», proprietarie o sconosciute).")
	var k_f: Array = ProgettoEditor.FONTI.keys()
	var lista := progetto.asset_usati()
	if lista.is_empty():
		_etichetta("(il tavolo non usa immagini né musiche tue)")
	for a in lista:
		var fo := progetto.fonte_di(a["chiave"])
		_etichetta("%s %s  →  %s" % ["🖼" if a["tipo"] == "immagine" else "♪", a["nome"], ", ".join(a["dove"]) if not a["dove"].is_empty() else "—"])
		var ob := OptionButton.new()
		for i in k_f.size():
			ob.add_item(ProgettoEditor.FONTI[k_f[i]])
			if k_f[i] == str(fo["fonte"]):
				ob.select(i)
		var ch: String = a["chiave"]
		ob.item_selected.connect(func(i): _menu_cmd({"comando": "licenza", "chiave": ch, "fonte": k_f[i]}))
		_pannello.add_child(ob)
		var le := LineEdit.new()
		le.text = str(fo.get("nota", ""))
		le.placeholder_text = "nota (es. link della licenza, data)"
		le.text_submitted.connect(func(v): _menu_cmd({"comando": "licenza", "chiave": ch, "nota": v}))
		le.focus_exited.connect(func(): if le.text != str(progetto.fonte_di(ch).get("nota", "")): _menu_cmd({"comando": "licenza", "chiave": ch, "nota": le.text}))
		_pannello.add_child(le)
		# v0.26: dati completi per il rilascio libero (autore, URL, licenza, modifiche, limitazioni)
		var lic_k: Array = LicenzeProgetto.LICENZE.keys()
		var lic_att := str(fo.get("licenza", LicenzeProgetto.LICENZA_DA_FONTE.get(str(fo["fonte"]), "sconosciuta")))
		var obl := OptionButton.new()
		for j in lic_k.size():
			obl.add_item("%s – %s%s" % [lic_k[j], LicenzeProgetto.LICENZE[lic_k[j]]["nome"], "" if LicenzeProgetto.LICENZE[lic_k[j]]["libera"] else "  ✖ non per rilasci liberi"])
			if lic_k[j] == lic_att:
				obl.select(j)
		obl.item_selected.connect(func(j): _menu_cmd({"comando": "licenza", "chiave": ch, "licenza": lic_k[j]}, true))
		_pannello.add_child(obl)
		for campo in [["autore", "autore (chi l'ha fatta)"], ["url", "indirizzo della fonte (https://…)"], ["modifiche", "modifiche fatte (es. ritagliata)"], ["limitazioni", "limitazioni (se ce ne sono)"]]:
			var lc := LineEdit.new()
			lc.text = str(fo.get(campo[0], ""))
			lc.placeholder_text = campo[1]
			var cc: String = campo[0]
			lc.text_submitted.connect(func(v): _menu_cmd({"comando": "licenza", "chiave": ch, cc: v}))
			lc.focus_exited.connect(func(): if lc.text != str(progetto.fonte_di(ch).get(cc, "")): _menu_cmd({"comando": "licenza", "chiave": ch, cc: lc.text}))
			_pannello.add_child(lc)
	_pannello.add_child(HSeparator.new())
	_bottone(_pannello, "Scrivi il registro (" + ProgettoEditor.FILE_REGISTRO + ")", func(): _menu_cmd({"comando": "registro_licenze"}), "Lo scrive nella cartella del tavolo: va consegnato con il gioco")
	_bottone(_pannello, "Chiudi", func(): _apri_licenze(false), "Torna alle proprietà del tavolo")

# ================================================================ MENU DEL GIOCO (v0.14)
func _apri_menu(si: bool) -> void:
	_menu_aperto = si
	_missione_scelta = ""
	_ricostruisci_pannello = true
	_aggiorna_pannello()

func _menu_cmd(c: Dictionary, rifai := false) -> void:
	_avviso(progetto.esegui(c)["messaggio"])
	if rifai:
		_ricostruisci_pannello = true
		_aggiorna_pannello.call_deferred()

func _testo_lungo(titolo: String, v: String, f: Callable) -> void:
	_etichetta(titolo)
	var te := TextEdit.new()
	te.text = v
	te.custom_minimum_size = Vector2(260, 110)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.focus_exited.connect(func(): if te.text != v: f.call(te.text))
	_pannello.add_child(te)

func _pannello_menu() -> void:
	var m: Dictionary = progetto.desc.get("menu", {}) if progetto.desc.get("menu") is Dictionary else {}
	_titolo_pannello("🎨 MENU E TABELLONE DEL GIOCO")
	_etichetta("Vuoto = come il menu di oggi. Le voci del menu restano tutte. Le prove: GIOCA e premi ☰.")
	# v0.25: TEMI PRONTI (colori del tavolo e del menu, luce, font) con un clic
	_titolo_pannello("TEMI PRONTI (un clic)")
	var gt := GridContainer.new()
	gt.columns = 2
	_pannello.add_child(gt)
	for nome_t in ProgettoEditor.TEMI:
		var te: Dictionary = ProgettoEditor.TEMI[nome_t]
		var bt := Button.new()
		bt.text = str(te["nome"])
		bt.tooltip_text = str(te["testo"])
		bt.custom_minimum_size = Vector2(150, 34)
		var sbt := StyleBoxFlat.new()
		sbt.bg_color = te["piano"]
		sbt.border_color = te["primario"]
		sbt.set_border_width_all(5 if str(progetto.desc.get("tema", "")) == nome_t else 2)
		sbt.set_corner_radius_all(6)
		bt.add_theme_stylebox_override("normal", sbt)
		bt.add_theme_stylebox_override("hover", sbt)
		bt.add_theme_color_override("font_color", _colore_leggibile(te))
		var nt: String = nome_t
		bt.pressed.connect(func(): _menu_cmd({"comando": "tema", "nome": nt}, true))
		gt.add_child(bt)
	_pannello.add_child(HSeparator.new())
	# v0.21: tabellone (la scritta dei punti in alto) e font
	_titolo_pannello("TABELLONE (punti in alto)")
	var alto := Hud.altezza_di(progetto.desc)
	var ob_t := OptionButton.new()
	var misure := [[100.0, "Piccolo: più spazio al tavolo"], [150.0, "Normale"], [190.0, "Grande: punti più leggibili"]]
	for i in misure.size():
		ob_t.add_item(misure[i][1])
		if absf(alto - misure[i][0]) < 1.0:
			ob_t.select(i)
	ob_t.item_selected.connect(func(i): _menu_cmd({"comando": "tabellone", "altezza": misure[i][0]}, true))
	_pannello.add_child(ob_t)
	_etichetta("Il tavolo si adatta sempre SOTTO il tabellone: non viene mai coperto.")
	_etichetta("Scritte grandi (nome del tavolo, «premi START», missioni, segreti):")
	var ob_s := OptionButton.new()
	ob_s.add_item("Dentro il tabellone (non coprono il tavolo)")
	ob_s.add_item("In mezzo al tavolo, grandi (come prima)")
	var tb_d = progetto.desc.get("tabellone", {})
	ob_s.select(1 if tb_d is Dictionary and str(tb_d.get("scritte", "alto")) == "centro" else 0)
	ob_s.item_selected.connect(func(i): _menu_cmd({"comando": "tabellone", "scritte": "centro" if i == 1 else "alto"}, true))
	_pannello.add_child(ob_s)
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("FONT (menu e tabellone)")
	var nomi_font: Array = ProgettoEditor.FONT_PRONTI.keys()
	if progetto.desc.get("font_file") is Dictionary:
		nomi_font.append_array(progetto.desc["font_file"].keys())
	for voce in [["font", "Scritte (pulsanti, testi, punti)"], ["font_titolo", "Titoli (nome del gioco, messaggi grandi)"]]:
		_etichetta(voce[1])
		var obf := OptionButton.new()
		var campo_f: String = voce[0]
		for i in nomi_font.size():
			obf.add_item(str(ProgettoEditor.FONT_PRONTI.get(nomi_font[i], "Importato: " + str(nomi_font[i]))))
			if str(m.get(campo_f, "")) == str(nomi_font[i]):
				obf.select(i)
		obf.item_selected.connect(func(i): _menu_cmd({"comando": "imposta_menu", "campo": campo_f, "valore": nomi_font[i]}, true))
		_pannello.add_child(obf)
	_bottone(_pannello, "Importa un font (.ttf / .otf)…", func(): _scegli_file("Scegli un font", func(f): _avviso(progetto.esegui({"comando": "importa_font", "file": f})["messaggio"]), "*.ttf, *.otf ; Font"), "Il font entra nel tavolo e viene usato per le scritte. Serve la licenza commerciale.")
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("TITOLO DEL MENU")
	_campo_testo("Titolo in alto (vuoto = come prima)", str(m.get("titolo", "")), func(v): _menu_cmd({"comando": "imposta_menu", "campo": "titolo", "valore": v}))
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("COLORI DEL MENU")
	for voce in [["col_a", "Colore principale (bordi, sezioni)"], ["col_b", "Colore secondario (pulsanti, titolo)"], ["col_testo", "Testo"], ["col_fondo", "Fondo dietro il menu"], ["col_pannello", "Pannello"]]:
		_etichetta(voce[1])
		var rc := HBoxContainer.new()
		_pannello.add_child(rc)
		var cp := ColorPickerButton.new()
		cp.color = m.get(voce[0], Color(0.5, 0.5, 0.5)) if m.get(voce[0]) is Color else Color(0.5, 0.5, 0.5)
		cp.edit_alpha = voce[0] in ["col_fondo", "col_pannello"]
		cp.custom_minimum_size = Vector2(120, 28)
		var campo: String = voce[0]
		_al_chiudere(cp, func(c: Color): _menu_cmd({"comando": "imposta_menu", "campo": campo, "valore": c}, true))
		rc.add_child(cp)
		var et := Label.new()
		et.text = "scelto" if m.get(campo) is Color else "come prima"
		rc.add_child(et)
		if m.get(campo) is Color:
			_bottone(rc, "Come prima", func(): _menu_cmd({"comando": "imposta_menu", "campo": campo, "valore": ""}, true), "Torna al colore di oggi")
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("PAGINE")
	_testo_lungo("REGOLE (vuoto = testo di oggi)", str(m.get("regole", "")), func(v): _menu_cmd({"comando": "imposta_menu", "campo": "regole", "valore": v}))
	_testo_lungo("MISSIONI (vuoto = testo di oggi)", str(m.get("missioni", "")), func(v): _menu_cmd({"comando": "imposta_menu", "campo": "missioni", "valore": v}))
	_bottone(_pannello, "Scrivi la pagina MISSIONI dalle missioni del tavolo", func(): _menu_cmd({"comando": "imposta_menu", "campo": "missioni", "valore": progetto.testo_missioni_menu()}, true), "L'elenco delle tue missioni con cosa chiedono")
	_testo_lungo("CREDITI (vuoto = testo di oggi; i crediti del motore Godot restano)", str(m.get("crediti", "")), func(v): _menu_cmd({"comando": "imposta_menu", "campo": "crediti", "valore": v}))
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("PAGINE IN PIÙ")
	var pagine: Array = m.get("pagine", [])
	for k in pagine.size():
		var kk := k
		_campo_testo("Pagina %d: titolo del pulsante" % (k + 1), str(pagine[k].get("titolo", "")), func(v): _menu_cmd({"comando": "pagina_menu", "azione": "imposta", "indice": kk, "titolo": v}))
		_testo_lungo("Pagina %d: testo" % (k + 1), str(pagine[k].get("testo", "")), func(v): _menu_cmd({"comando": "pagina_menu", "azione": "imposta", "indice": kk, "testo": v}))
		_bottone(_pannello, "Togli la pagina %d" % (k + 1), func(): _menu_cmd({"comando": "pagina_menu", "azione": "togli", "indice": kk}, true), "")
	_bottone(_pannello, "+ Aggiungi una pagina (es. «Come si gioca», «Storia»)", func(): _menu_cmd({"comando": "pagina_menu", "azione": "aggiungi", "titolo": "Storia", "testo": ""}, true), "Un pulsante in più nel menu, sotto INFORMAZIONI")
	_pannello.add_child(HSeparator.new())
	_bottone(_pannello, "Chiudi", func(): _apri_menu(false), "Torna alle proprietà del tavolo")

# ================================================================ REGIA: luci che seguono il gioco e suoni (v0.11)
func _sezione_luce(id: String, e: Dictionary) -> void:
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("COSA FA LA LUCE IN GIOCO")
	var modo := str(e.get("luce_modo", ""))
	var ob := OptionButton.new()
	var chiavi: Array = RegiaDati.MODI_LUCE.keys()
	for i in chiavi.size():
		ob.add_item(RegiaDati.MODI_LUCE[chiavi[i]])
		if chiavi[i] == modo:
			ob.select(i)
	ob.item_selected.connect(func(i): _imposta("luce_modo", chiavi[i], true))
	_pannello.add_child(ob)
	var voci: Array = []
	var valori: Array = []
	match modo:
		"tiro", "colpito":
			for v in progetto.elenco():
				if not v["tipo"] in ["inserti", "muri", "decorazioni", "piani", "nastri", "palette"]:
					voci.append(v["id"])
					valori.append(v["id"])
		"giu":
			for b in progetto.desc.get("bersagli", []):
				voci.append(str(b["id"]))
				valori.append(str(b["id"]))
		"missione_in_corso", "missione_fatta":
			if modo == "missione_in_corso":
				voci.append("(una qualsiasi)")
				valori.append("")
			for m in progetto.desc.get("missioni", []):
				voci.append(str(m.get("nome", m["id"])))
				valori.append(str(m["id"]))
	if not valori.is_empty():
		_etichetta({"tiro": "Pezzo che la luce indica", "colpito": "Pezzo", "giu": "Bersaglio", "missione_in_corso": "Missione", "missione_fatta": "Missione"}[modo])
		var ob2 := OptionButton.new()
		for i in voci.size():
			ob2.add_item(str(voci[i]))
			if str(valori[i]) == str(e.get("luce_rif", "")):
				ob2.select(i)
		if str(e.get("luce_rif", "")) == "" and modo != "missione_in_corso" and not valori.is_empty():
			_imposta.call_deferred("luce_rif", valori[0])
		ob2.item_selected.connect(func(i): _imposta("luce_rif", valori[i]))
		_pannello.add_child(ob2)
	if modo == "energia":
		_etichetta("Accesa se restano almeno… luci di energia")
		var se := _numero(_pannello, float(e.get("luce_parte", 1)), 1, 20, 1)
		se.value_changed.connect(func(v): _imposta("luce_parte", int(v)))
	if modo == "progresso":
		_etichetta("Questa luce è la numero… (della barra)")
		var s1 := _numero(_pannello, float(e.get("luce_parte", 1)), 1, 20, 1)
		s1.value_changed.connect(func(v): _imposta("luce_parte", int(v)))
		_etichetta("…su quante luci in tutto")
		var s2 := _numero(_pannello, float(e.get("luce_su", 3)), 1, 20, 1)
		s2.value_changed.connect(func(v): _imposta("luce_su", int(v)))
	if modo in ["tiro", "missione_in_corso", "missione_fatta", "progresso", "missione_pronta"] and progetto.desc.get("missioni", []).is_empty():
		_etichetta("(servono delle missioni: scheda Missioni)")

func _su_scheda(_i: int) -> void:
	if _schede.get_current_tab_control() != null and _schede.get_current_tab_control().name == "Suoni e luci":
		_aggiorna_regia()
	if _schede.get_current_tab_control() != null and _schede.get_current_tab_control().name == "Simulatore":
		_costruisci_sim()

# ================================================================ SIMULATORE DI REGOLE (v0.16)
func _costruisci_sim() -> void:
	for c in _scheda_sim.get_children():
		c.queue_free()
	_box_aiuto(_scheda_sim, "A COSA SERVE: provare punti e missioni SENZA giocare", [
		"1. Premi «▶ Nuova partita» (riparte da zero con le missioni di adesso).",
		"2. Clicca un pezzo SUL TAVOLO (o il suo pulsante qui sotto) = la pallina lo colpisce una volta.",
		"3. Guarda il riquadro: punti, missione in corso, cosa chiede adesso, messaggi del tabellone e luci accese.",
		"4. Missioni a tempo: «+5 secondi» fa passare il tempo. Le palette servono se le missioni si scelgono con le palette.",
		"Esempio: missione «colpisci 3 volte bumper1» → clicca 3 volte «bumper1» e vedi la missione completata."])
	var su := HBoxContainer.new()
	_scheda_sim.add_child(su)
	_bottone(su, "▶ Nuova partita", func(): _avviso(_sim.avvia(progetto.desc)); _costruisci_sim.call_deferred(), "Riparte con le regole e le missioni di adesso")
	_bottone(su, "+5 secondi", func(): _sim.tempo(5.0), "Fa passare il tempo (missioni a tempo, hurry-up)")
	_bottone(su, "◀ Paletta", func(): _sim.paletta(-1), "Paletta sinistra (scelta della missione, cambio corsia)")
	_bottone(su, "Paletta ▶", func(): _sim.paletta(1), "Paletta destra")
	var spieg := Label.new()
	spieg.text = "  Clicca un pezzo qui sotto = la pallina lo colpisce."
	su.add_child(spieg)
	_sim_stato = RichTextLabel.new()

	_sim_stato.fit_content = true
	_sim_stato.custom_minimum_size = Vector2(0, 60)
	_scheda_sim.add_child(_sim_stato)
	if not _sim.attivo():
		_sim_stato.text = "Premi «Nuova partita» per cominciare."
		return
	for lista in SimulatoreRegole.TIPI:
		var pezzi: Array = progetto.desc.get(lista, []).filter(func(e): return e is Dictionary and e.has("id"))
		if pezzi.is_empty():
			continue
		var riga := HFlowContainer.new()
		_scheda_sim.add_child(riga)
		var et := Label.new()
		et.text = SchedeEditor.scheda(lista).get("breve", lista) + ":"
		riga.add_child(et)
		for e in pezzi:
			var pid := str(e["id"])
			var li: String = lista
			_bottone(riga, pid, func(): _sim.premi(li, pid), "La pallina colpisce «%s»" % pid)
	_aggiorna_sim_stato()

## v0.21: con la scheda Simulatore aperta e la partita avviata, cliccare un pezzo SUL TAVOLO = la pallina lo colpisce.
func _premi_nel_simulatore(id: String) -> void:
	if id == "" or _sim == null or not _sim.attivo() or _schede.get_current_tab_control() == null or _schede.get_current_tab_control().name != "Simulatore":
		return
	var t := progetto.trova(id)
	if not t.is_empty() and SimulatoreRegole.TIPI.has(t[0]):
		_sim.premi(t[0], id)
		_avviso("Simulatore: la pallina colpisce «%s»" % id)

func _aggiorna_sim_stato() -> void:
	if _sim_stato == null or not is_instance_valid(_sim_stato) or not _sim.attivo():
		return
	var st := _sim.stato()
	_sim_stato.text = "[b]%s punti[/b]  ·  bonus ×%d  ·  %.0f s\n%s  ·  %s\nTabellone: %s\nLuci: %s" % [RegoleBase.formatta(int(st["punti"])), int(st["bonus"]), float(st["tempo"]),
		st["riga"], st["obiettivo"], "  |  ".join(st["messaggi"].slice(maxi(0, st["messaggi"].size() - 3))), "  ".join(st["luci"]) if not st["luci"].is_empty() else "(nessuna luce con una regola)"]
	_sim_stato.bbcode_enabled = true

func _prova_suono(nome: String) -> void:
	if nome != "":
		Audio.suona(nome)

func _aggiorna_regia() -> void:
	if _lista_regia == null:
		return
	for c in _lista_regia.get_children():
		c.queue_free()
	if progetto.desc.is_empty():
		return
	var titolo := Label.new()
	titolo.text = "Per ogni evento: il SUONO e l'EFFETTO DI LUCE (solo suoni del nostro catalogo)."
	_lista_regia.add_child(titolo)
	var suoni: Dictionary = progetto.desc.get("suoni", {}) if progetto.desc.get("suoni") is Dictionary else {}
	var luci: Dictionary = progetto.desc.get("luci_eventi", {}) if progetto.desc.get("luci_eventi") is Dictionary else {}
	var k_s: Array = RegiaDati.SUONI.keys()
	var k_e: Array = RegiaDati.EFFETTI.keys()
	var n_e: Array = k_e.map(func(k): return "luce: " + RegiaDati.EFFETTI[k])
	for nome_sp in _nomi_spettacoli():
		k_e.append("spettacolo:" + nome_sp)
		n_e.append("spettacolo: " + nome_sp)
	var k_c: Array = RegiaDati.COLORI.keys()
	_sezione_spettacoli()
	var t_ev := Label.new()
	t_ev.text = "\nEVENTI"
	_lista_regia.add_child(t_ev)
	for ev in RegiaDati.EVENTI:
		var riga := HBoxContainer.new()
		_lista_regia.add_child(riga)
		var et := Label.new()
		et.text = RegiaDati.EVENTI[ev][0]
		et.custom_minimum_size = Vector2(210, 0)
		riga.add_child(et)
		var ob_s := OptionButton.new()
		var attuale: String = str(suoni.get(ev, RegiaDati.EVENTI[ev][1]))
		for i in k_s.size():
			ob_s.add_item(RegiaDati.SUONI[k_s[i]])
			if k_s[i] == attuale:
				ob_s.select(i)
		var evento: String = ev
		ob_s.item_selected.connect(func(i): _avviso(progetto.esegui({"comando": "suono_evento", "evento": evento, "suono": k_s[i]})["messaggio"]); _prova_suono(k_s[i]))
		ob_s.tooltip_text = "Suono (si sente subito quando lo scegli)"
		riga.add_child(ob_s)
		var ob_e := OptionButton.new()
		var eff: Dictionary = luci.get(ev, {})
		for i in k_e.size():
			ob_e.add_item(n_e[i])
			if k_e[i] == str(eff.get("effetto", "")):
				ob_e.select(i)
		riga.add_child(ob_e)
		var ob_c := OptionButton.new()
		for i in k_c.size():
			ob_c.add_item(k_c[i])
			if k_c[i] == str(eff.get("colore", "caldo")):
				ob_c.select(i)
		ob_c.disabled = str(eff.get("effetto", "")) in ["", "nessuno"] or str(eff.get("effetto", "")).begins_with("spettacolo:")
		riga.add_child(ob_c)
		ob_e.item_selected.connect(func(i): _avviso(progetto.esegui({"comando": "luce_evento", "evento": evento, "effetto": k_e[i], "colore": k_c[ob_c.selected]})["messaggio"]))
		ob_c.item_selected.connect(func(i): _avviso(progetto.esegui({"comando": "luce_evento", "evento": evento, "effetto": k_e[ob_e.selected], "colore": k_c[i]})["messaggio"]))

# ================================================================ SPETTACOLI DI LUCE e ATTESA (v0.17)
## Nomi degli spettacoli usabili: quelli del tavolo, poi quelli pronti non ancora copiati.
func _nomi_spettacoli() -> Array:
	var out: Array = []
	var sp = progetto.desc.get("spettacoli", {})
	if sp is Dictionary:
		out.append_array(sp.keys())
	for k in RegiaDati.SPETTACOLI_PRONTI:
		if not k in out:
			out.append(k)
	return out

func _sp_cmd(c: Dictionary, rifai := false) -> void:
	_avviso(progetto.esegui(c)["messaggio"])
	if rifai:
		_aggiorna_regia.call_deferred()

func _sezione_spettacoli() -> void:
	var d: Dictionary = progetto.desc
	var sp: Dictionary = d.get("spettacoli", {}) if d.get("spettacoli") is Dictionary else {}
	# --- attesa in sala
	var ta := Label.new()
	ta.text = "ATTESA IN SALA (fuori partita, prima di START)"
	_lista_regia.add_child(ta)
	var att := RegiaDati.attesa(d)
	var ra := HBoxContainer.new()
	_lista_regia.add_child(ra)
	var la := Label.new()
	la.text = "Spettacolo:"
	ra.add_child(la)
	var ob_a := OptionButton.new()
	var nomi: Array = [""] + _nomi_spettacoli()
	for i in nomi.size():
		ob_a.add_item("luci di base" if nomi[i] == "" else str(nomi[i]))
		if str(nomi[i]) == str(att.get("spettacolo", "")):
			ob_a.select(i)
	ob_a.item_selected.connect(func(i): _sp_cmd({"comando": "attesa", "spettacolo": nomi[i]}))
	ra.add_child(ob_a)
	var lp := Label.new()
	lp.text = "  pausa (s):"
	ra.add_child(lp)
	var sp_p := _numero(ra, float(att.get("pausa", 1.0)), 0, 30, 0.1)
	sp_p.value_changed.connect(func(v): _sp_cmd({"comando": "attesa", "pausa": v}))
	var rs := HBoxContainer.new()
	_lista_regia.add_child(rs)
	var ls := Label.new()
	ls.text = "Scritta sul tabellone (si alterna a «premi START»):"
	rs.add_child(ls)
	var le := LineEdit.new()
	le.text = str(att.get("scritta", ""))
	le.placeholder_text = "es. «INSERT COIN» o il nome del tavolo"
	le.max_length = 40
	le.custom_minimum_size = Vector2(260, 0)
	le.text_submitted.connect(func(n): _sp_cmd({"comando": "attesa", "scritta": n}))
	le.focus_exited.connect(func(): if le.text != str(RegiaDati.attesa(progetto.desc).get("scritta", "")): _sp_cmd({"comando": "attesa", "scritta": le.text}))
	rs.add_child(le)
	# --- spettacoli
	var ts := Label.new()
	ts.text = "\nSPETTACOLI DI LUCE (sequenze di effetti a tempo: si usano per gli eventi, nelle missioni e nell'attesa)"
	_lista_regia.add_child(ts)
	var rn := HBoxContainer.new()
	_lista_regia.add_child(rn)
	_bottone(rn, "+ Nuovo spettacolo", func(): _sp_cmd({"comando": "spettacolo", "azione": "nuovo"}, true), "Uno spettacolo con un passo, da completare")
	var ob_p := OptionButton.new()
	for k in RegiaDati.SPETTACOLI_PRONTI:
		ob_p.add_item(k)
	rn.add_child(ob_p)
	_bottone(rn, "Copia il pronto", func(): _sp_cmd({"comando": "spettacolo", "azione": "pronto", "da": ob_p.get_item_text(ob_p.selected)}, true), "Copia nel tavolo uno spettacolo fatto da noi, da cambiare a piacere")
	var k_ef: Array = RegiaDati.EFFETTI_PASSO.keys()
	var k_co: Array = RegiaDati.COLORI.keys()
	for nome in sp:
		var passi: Array = sp[nome].get("passi", [])
		var rt := HBoxContainer.new()
		_lista_regia.add_child(rt)
		var le_n := LineEdit.new()
		le_n.text = str(nome)
		le_n.custom_minimum_size = Vector2(150, 0)
		var n0: String = nome
		le_n.text_submitted.connect(func(n): _sp_cmd({"comando": "spettacolo", "azione": "rinomina", "nome": n0, "nuovo_nome": n}, true))
		rt.add_child(le_n)
		var ld := Label.new()
		ld.text = "%d passi · %.1f s" % [passi.size(), RegiaDati.durata_spettacolo(passi)]
		rt.add_child(ld)
		_bottone(rt, "+ passo", func(): _sp_cmd({"comando": "spettacolo_passo", "nome": n0, "azione": "aggiungi"}, true), "Aggiunge un passo dopo la fine degli altri")
		_bottone(rt, "Togli", func(): _sp_cmd({"comando": "spettacolo", "azione": "togli", "nome": n0}, true), "Toglie lo spettacolo (gli eventi che lo usavano tornano come prima)")
		for i in passi.size():
			var p: Dictionary = passi[i]
			var rp := HBoxContainer.new()
			_lista_regia.add_child(rp)
			var li := Label.new()
			li.text = "    %d. dopo" % (i + 1)
			rp.add_child(li)
			var idx: int = i
			var s_d := _numero(rp, float(p.get("dopo", 0.0)), 0, 30, 0.05)
			s_d.tooltip_text = "Secondi dall'inizio dello spettacolo"
			s_d.value_changed.connect(func(v): _sp_cmd({"comando": "spettacolo_passo", "nome": n0, "azione": "imposta", "indice": idx, "dopo": v}))
			var ob_ef := OptionButton.new()
			for j in k_ef.size():
				ob_ef.add_item(RegiaDati.EFFETTI_PASSO[k_ef[j]])
				if k_ef[j] == str(p.get("effetto", "")):
					ob_ef.select(j)
			ob_ef.item_selected.connect(func(j): _sp_cmd({"comando": "spettacolo_passo", "nome": n0, "azione": "imposta", "indice": idx, "effetto": k_ef[j]}, true))
			rp.add_child(ob_ef)
			var ob_co := OptionButton.new()
			for j in k_co.size():
				ob_co.add_item(k_co[j])
				if k_co[j] == str(p.get("colore", "caldo")):
					ob_co.select(j)
			ob_co.item_selected.connect(func(j): _sp_cmd({"comando": "spettacolo_passo", "nome": n0, "azione": "imposta", "indice": idx, "colore": k_co[j]}))
			rp.add_child(ob_co)
			var lu := Label.new()
			lu.text = "dura"
			rp.add_child(lu)
			var s_u := _numero(rp, float(p.get("dur", 0.6)), 0.05, 10, 0.05)
			s_u.value_changed.connect(func(v): _sp_cmd({"comando": "spettacolo_passo", "nome": n0, "azione": "imposta", "indice": idx, "dur": v}))
			if str(p.get("effetto", "")) == "spazzata":
				var ob_v := OptionButton.new()
				ob_v.add_item("verso l'alto")
				ob_v.add_item("verso il basso")
				ob_v.select(1 if str(p.get("verso", "su")) == "giu" else 0)
				ob_v.item_selected.connect(func(j): _sp_cmd({"comando": "spettacolo_passo", "nome": n0, "azione": "imposta", "indice": idx, "verso": "giu" if j == 1 else "su"}))
				rp.add_child(ob_v)
			var cb := CheckBox.new()
			cb.text = "grande"
			cb.tooltip_text = "Abbassa per un attimo le altre luci (contrasto), come nei jackpot"
			cb.button_pressed = bool(p.get("grande", false))
			cb.toggled.connect(func(x): _sp_cmd({"comando": "spettacolo_passo", "nome": n0, "azione": "imposta", "indice": idx, "grande": x}))
			rp.add_child(cb)
			_bottone(rp, "✕", func(): _sp_cmd({"comando": "spettacolo_passo", "nome": n0, "azione": "togli", "indice": idx}, true), "Toglie questo passo")

# ================================================================ MISSIONI (v0.10)
const NOMI_MODI := {"conta": "conta N volte", "tutti": "tutti i pezzi almeno una volta", "sequenza": "in ordine (sequenza)",
	"combo": "combo: di fila, in fretta", "hurry_up": "hurry-up: premio che cala", "stato": "tieni vivo per N secondi"}
const LISTA_DEL_TIPO := {"bumper": "bumper", "bersaglio": "bersagli", "rampa": "rampe", "rampa_entrata": "rampe", "spinner": "spinner",
	"sensore": "sensori", "buca": "buche", "elastico": "elastici", "kickback": "kickback", "cancello": "cancelli", "prigione": "buche", "captive": "captive"}

func _aggiorna_missioni() -> void:
	if _lista_missioni == null:
		return
	for c in _lista_missioni.get_children():
		c.queue_free()
	if progetto.desc.is_empty():
		return
	_box_aiuto(_lista_missioni, "COME SI FA UNA MISSIONE (in 4 passi)", [
		"1. Qui sotto scegli un modello pronto (es. «Colpisci i bersagli») e premi «Aggiungi»: usa da solo i pezzi del tuo tavolo. Oppure «Tutte le pronte».",
		"2. Clicca il nome della missione nell'elenco: a destra vedi cosa chiede (es. «colpisci 3 volte bumper1»), il premio e il tempo. Puoi cambiarli lì.",
		"3. Qui sotto scegli COME partono: da sole una dopo l'altra, oppure con un tiro in una buca o in una rampa.",
		"4. Provala senza giocare nella scheda «Simulatore», oppure con ▶ GIOCA. Il tabellone in alto mostra la missione in corso."])
	if not progetto.missioni_valgono():
		var av := Label.new()
		av.text = "Questo tavolo usa le regole già scritte di Space: le missioni a mattoncini valgono per i tavoli nuovi."
		av.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
		_lista_missioni.add_child(av)
	var su := HBoxContainer.new()
	_lista_missioni.add_child(su)
	var ob := OptionButton.new()
	var disp := ModelliMissioni.disponibili(progetto.desc)
	for i in disp.size():
		ob.add_item(("%s – %s" % [disp[i]["nome"], disp[i]["testo"]]) if disp[i]["ok"] else ("%s (%s)" % [disp[i]["nome"], disp[i]["perche"]]))
		ob.set_item_disabled(i, not disp[i]["ok"])
		ob.set_item_metadata(i, disp[i]["id"])
	for i in disp.size():
		if disp[i]["ok"]:
			ob.select(i)
			break
	su.add_child(ob)
	_bottone(su, "Aggiungi", func(): _comando_missione({"comando": "missione_aggiungi", "modello": ob.get_item_metadata(ob.selected)}, true), "Aggiunge la missione del modello scelto, con i pezzi di questo tavolo")
	_bottone(su, "Tutte le pronte", func(): _comando_missione({"comando": "missioni_pacchetto"}), "Aggiunge tutti i modelli che il tavolo permette, più la modalità finale")
	_bottone(su, "Vuota", func(): _comando_missione({"comando": "missione_aggiungi"}, true), "Una missione da costruire a mattoncini")
	_bottone(su, "🗺 Schema", _apri_schema, "Chi sblocca chi: lo schema delle dipendenze delle missioni")
	var av_r := HBoxContainer.new()
	_lista_missioni.add_child(av_r)
	var la := Label.new()
	la.text = "Le missioni partono: "
	av_r.add_child(la)
	var ob_a := OptionButton.new()
	var scelte: Array = [{"tipo": "subito", "id": ""}]
	ob_a.add_item("da sole, una dopo l'altra")
	for k in ["buche", "rampe"]:
		for e in progetto.desc.get(k, []):
			if e is Dictionary and e.has("id") and not e.has("da_nastro"):
				scelte.append({"tipo": "buca" if k == "buche" else "rampa", "id": str(e["id"])})
				ob_a.add_item("con un tiro in «%s»" % e["id"])
	var att: Dictionary = progetto.desc.get("missioni_avvio", {"tipo": "subito"}) if progetto.desc.get("missioni_avvio") is Dictionary else {"tipo": "subito"}
	for i in scelte.size():
		if scelte[i]["tipo"] == str(att.get("tipo", "subito")) and scelte[i]["id"] == str(att.get("id", "")):
			ob_a.select(i)
	var cb_sc := CheckBox.new()
	cb_sc.text = "la scegli con le palette"
	cb_sc.tooltip_text = "Quando una missione è pronta, le palette cambiano la missione proposta; il tiro la fa partire"
	cb_sc.button_pressed = bool(att.get("scelta", false))
	cb_sc.disabled = str(att.get("tipo", "subito")) == "subito"
	ob_a.item_selected.connect(func(i): _comando_missione({"comando": "missioni_avvio", "tipo": scelte[i]["tipo"], "id": scelte[i]["id"], "scelta": cb_sc.button_pressed}))
	cb_sc.toggled.connect(func(v): _comando_missione({"comando": "missioni_avvio", "tipo": scelte[ob_a.selected]["tipo"], "id": scelte[ob_a.selected]["id"], "scelta": v}))
	av_r.add_child(ob_a)
	av_r.add_child(cb_sc)
	# v0.12: CAMBIO CORSIA (gruppi di sensori)
	var gruppi := {}
	for sen in progetto.desc.get("sensori", []):
		if str(sen.get("gruppo", "")) != "":
			gruppi[str(sen["gruppo"])] = int(gruppi.get(str(sen["gruppo"]), 0)) + 1
	var attivi := {}
	for cc in progetto.desc.get("cambio_corsie", []):
		attivi[str(cc.get("gruppo", ""))] = cc
	for g in gruppi:
		if gruppi[g] < 2:
			continue
		var rg := HBoxContainer.new()
		_lista_missioni.add_child(rg)
		var cbg := CheckBox.new()
		cbg.text = "Cambio corsia «%s» (%d corsie): le palette spostano le luci, tutte accese = premio di punti" % [g, gruppi[g]]
		cbg.button_pressed = attivi.has(g)
		var gg: String = g
		rg.add_child(cbg)
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = 5000000
		sp.step = 5000
		sp.value = float(attivi.get(g, {}).get("premio", {}).get("punti", 25000))
		rg.add_child(sp)
		cbg.toggled.connect(func(v): _comando_missione({"comando": "cambio_corsie", "gruppo": gg, "togli": not v, "punti": int(sp.value)}))
		sp.value_changed.connect(func(v): _premio_corsia(gg, int(v), cbg.button_pressed))
	# v0.14: COLLEZIONE e ZONE
	var rcz := HBoxContainer.new()
	_lista_missioni.add_child(rcz)
	var ncol: int = (progetto.desc.get("collezione", {}).get("oggetti", []) as Array).size() if progetto.desc.get("collezione") is Dictionary else 0
	var nzon: int = (progetto.desc.get("zone", []) as Array).size() if progetto.desc.get("zone") is Array else 0
	_bottone(rcz, "Collezione e zone… (%d oggetti, %d zone)" % [ncol, nzon], func(): _apri_cz(), "Oggetti da catturare (con rarità) e zone del viaggio, a destra")
	# v0.12: MUSICA del tavolo (le tue canzoni)
	var rm := HBoxContainer.new()
	_lista_missioni.add_child(rm)
	var lm := Label.new()
	lm.text = "Musica:"
	rm.add_child(lm)
	var mus: Dictionary = progetto.desc.get("musica", {}) if progetto.desc.get("musica") is Dictionary else {}
	for ruolo in ProgettoEditor.RUOLI_MUSICA:
		var rr: String = ruolo
		var nome_m := str(mus.get(ruolo, ""))
		_bottone(rm, "%s: %s" % [ProgettoEditor.RUOLI_MUSICA[ruolo], nome_m if nome_m != "" else "scegli…"], func(): _scegli_musica(rr, ""), "Scegli una tua canzone (ogg, mp3, wav): viene copiata nella cartella del tavolo")
		if nome_m != "":
			_bottone(rm, "✖", func(): _comando_missione({"comando": "musica", "ruolo": rr, "togli": true}), "Togli questa musica")
	var l: Array = progetto.desc.get("missioni", []) if progetto.desc.get("missioni") is Array else []
	for i in l.size():
		var m: Dictionary = l[i]
		var mid := str(m.get("id", ""))
		var riga := HBoxContainer.new()
		_lista_missioni.add_child(riga)
		var cb := CheckBox.new()
		cb.button_pressed = bool(m.get("attiva", true))
		cb.tooltip_text = "Attiva (togli la spunta per tenerla ma non giocarla)"
		cb.toggled.connect(func(v): _comando_missione({"comando": "missione_imposta", "id": mid, "campo": "attiva", "valore": v}))
		riga.add_child(cb)
		var et := Label.new()
		var fasi: Array = m.get("fasi", [])
		var descr := Mattoncini.descrivi_fase(fasi[0]) if not fasi.is_empty() else "nessuna fase"
		et.text = "%d. %s — %s%s%s" % [i + 1, m.get("nome", mid), descr, (" (+%d fasi)" % (fasi.size() - 1)) if fasi.size() > 1 else "", ("  ·  %d s" % int(m["tempo"])) if float(m.get("tempo", 0)) > 0 else ""]
		et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		et.clip_text = true
		if mid == _missione_scelta:
			et.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		riga.add_child(et)
		_bottone(riga, "Modifica", func(): _scegli_missione(mid), "I mattoncini della missione, a destra")
		_bottone(riga, "↑", func(): _comando_missione({"comando": "missione_sposta", "id": mid, "di": -1}), "Prima")
		_bottone(riga, "↓", func(): _comando_missione({"comando": "missione_sposta", "id": mid, "di": 1}), "Dopo")
		_bottone(riga, "✖", func(): _togli_missione(mid), "Togli la missione")
	_sezione_segreti()
	_sezione_classifica()

func _sezione_segreti() -> void:
	_lista_missioni.add_child(HSeparator.new())
	var t := Label.new()
	t.text = "🔒 SEGRETI – non si vedono sul tabellone: il giocatore li scopre giocando (valgono una volta per partita)"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	_lista_missioni.add_child(t)
	var su := HBoxContainer.new()
	_lista_missioni.add_child(su)
	var ob := OptionButton.new()
	var mods := progetto.modelli_segreti()
	for i in mods.size():
		ob.add_item(("%s – %s" % [mods[i]["nome"], mods[i]["testo"]]) if mods[i]["ok"] else ("%s (%s)" % [mods[i]["nome"], mods[i]["perche"]]))
		ob.set_item_disabled(i, not mods[i]["ok"])
	for i in mods.size():
		if mods[i]["ok"]:
			ob.select(i)
			break
	su.add_child(ob)
	_bottone(su, "Aggiungi segreto", func(): _comando_missione({"comando": "segreto_aggiungi", "modello": mods[ob.selected]["id"]}), "Aggiunge il segreto scelto, con i pezzi di questo tavolo")
	for sg in progetto.desc.get("segreti", []):
		if not sg is Dictionary:
			continue
		var sid := str(sg.get("id", ""))
		var riga := HBoxContainer.new()
		_lista_missioni.add_child(riga)
		var le := LineEdit.new()
		le.text = str(sg.get("nome", ""))
		le.custom_minimum_size = Vector2(170, 0)
		le.text_submitted.connect(func(v): _comando_missione({"comando": "segreto_imposta", "id": sid, "campo": "nome", "valore": v}))
		riga.add_child(le)
		var et := Label.new()
		et.text = Segreti.testo(sg)
		et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		et.clip_text = true
		riga.add_child(et)
		if str(sg.get("tipo", "")) == "raffica":
			var sv := _numero(riga, float(sg.get("volte", 6)), 2, 200, 1)
			sv.tooltip_text = "Quanti colpi"
			sv.value_changed.connect(func(v): _comando_missione({"comando": "segreto_imposta", "id": sid, "campo": "volte", "valore": int(v)}))
		if str(sg.get("tipo", "")) in ["raffica", "entro"]:
			var ss := _numero(riga, float(sg.get("secondi", 2.0)), 0.5, 30, 0.5)
			ss.tooltip_text = "Secondi"
			ss.value_changed.connect(func(v): _comando_missione({"comando": "segreto_imposta", "id": sid, "campo": "secondi", "valore": v}))
		var sp := _numero(riga, float(sg.get("punti", 50000)), 0, 10000000, 1000)
		sp.tooltip_text = "Punti del premio"
		sp.value_changed.connect(func(v): _comando_missione({"comando": "segreto_imposta", "id": sid, "campo": "punti", "valore": int(v)}))
		_bottone(riga, "✖", func(): _comando_missione({"comando": "segreto_togli", "id": sid}), "Togli il segreto")

func _sezione_classifica() -> void:
	_lista_missioni.add_child(HSeparator.new())
	var cb := CheckBox.new()
	cb.text = "🏆 Classifica dei 10 migliori: a fine partita il giocatore scrive le sue iniziali (palette = lettera, START = conferma). Nel menu c'è la pagina CLASSIFICA."
	cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cb.button_pressed = bool(progetto.desc.get("classifica", true))
	cb.toggled.connect(func(v): _comando_missione({"comando": "classifica", "attiva": v}))
	_lista_missioni.add_child(cb)

func _premio_corsia(g: String, punti: int, attivo: bool) -> void:
	if attivo:
		_comando_missione({"comando": "cambio_corsie", "gruppo": g, "punti": punti})

func _scegli_musica(ruolo: String, mid: String) -> void:
	_scegli_file("Scegli la canzone", func(f): _comando_missione({"comando": "musica", "ruolo": ruolo, "id": mid, "file": f}); _aggiorna_missioni(), "*.ogg, *.mp3, *.wav ; Musica")

func _togli_missione(mid: String) -> void:
	_comando_missione({"comando": "missione_togli", "id": mid})
	if _missione_scelta == mid:
		_scegli_missione("")

func _scegli_missione(mid: String) -> void:
	_cz_aperto = false
	_menu_aperto = false
	_missione_scelta = mid
	if mid != "":
		vista.seleziona("")
		_missione_scelta = mid
	_ricostruisci_pannello = true
	_aggiorna_pannello()
	_aggiorna_missioni()

func _comando_missione(c: Dictionary, scegli := false) -> void:
	var r := progetto.esegui(c)
	_avviso(r["messaggio"])
	if scegli and r.has("id"):
		_scegli_missione(r["id"])

## Un campo della missione scelta (es. "premio.punti", "fasi.0.volte"); `rifai` = ridisegna il pannello.
func _mi(campo: String, valore, rifai := false) -> void:
	_avviso(progetto.esegui({"comando": "missione_imposta", "id": _missione_scelta, "campo": campo, "valore": valore})["messaggio"])
	if rifai:
		_ricostruisci_pannello = true
		_aggiorna_pannello.call_deferred()

func _num_m(nome: String, campo: String, v: float, a: float, b: float, passo: float, intero := true) -> void:
	_etichetta(nome)
	var sb := _numero(_pannello, v, a, b, passo)
	sb.value_changed.connect(func(x): _mi(campo, int(x) if intero else x))

func _spunta_m(nome: String, campo: String, v: bool) -> void:
	var cb := CheckBox.new()
	cb.text = nome
	cb.button_pressed = v
	cb.toggled.connect(func(x): _mi(campo, x))
	_pannello.add_child(cb)

func _scelta_m(nome: String, campo: String, voci: Array, valori: Array, attuale, rifai := true) -> void:
	_etichetta(nome)
	var ob := OptionButton.new()
	for i in voci.size():
		ob.add_item(str(voci[i]))
		if str(valori[i]) == str(attuale):
			ob.select(i)
	ob.item_selected.connect(func(i): _mi(campo, valori[i], rifai))
	_pannello.add_child(ob)

## v0.15: azioni sui pezzi (porte e deviatori sul piano) all'inizio della missione o come premio.
func _azioni_pezzi(dove: String, a: Dictionary) -> void:
	var porte: Array = progetto.desc.get("porte", []).map(func(x): return str(x["id"]))
	var lame: Array = progetto.desc.get("lame", []).map(func(x): return str(x["id"]))
	if not porte.is_empty():
		_scelta_m("Apri la porta", dove + ".apri_porta", ["(nessuna)"] + porte, [""] + porte, str(a.get("apri_porta", "")), false)
		_scelta_m("Chiudi la porta", dove + ".chiudi_porta", ["(nessuna)"] + porte, [""] + porte, str(a.get("chiudi_porta", "")), false)
	if not lame.is_empty():
		_scelta_m("Muovi il deviatore", dove + ".lama", ["(nessuno)"] + lame, [""] + lame, str(a.get("lama", "")), false)
		_scelta_m("…verso", dove + ".lama_verso", ["l'altro lato", "posizione A", "posizione B"], ["alterna", "a", "b"], str(a.get("lama_verso", "alterna")), false)
	# v0.17: spettacolo di luce
	var sp_n: Array = _nomi_spettacoli()
	_scelta_m("Spettacolo di luce", dove + ".spettacolo", ["(nessuno)"] + sp_n, [""] + sp_n, str(a.get("spettacolo", "")), false)

func _pannello_missione() -> void:
	var i := progetto.indice_missione(_missione_scelta)
	var m: Dictionary = progetto.desc["missioni"][i]
	_titolo_pannello("MISSIONE %d" % (i + 1))
	_campo_testo("Nome (sul tabellone)", str(m.get("nome", "")), func(v): _mi("nome", v); _aggiorna_missioni())
	if str(progetto.desc.get("lingua", "it")) == "en":
		_campo_testo("Nome in inglese", str(m.get("nome_en", "")), func(v): _mi("nome_en", v))
	_spunta_m("Attiva", "attiva", bool(m.get("attiva", true)))
	_spunta_m("Si ripete quando le hai fatte tutte", "ripeti", bool(m.get("ripeti", true)))
	_num_m("Tempo massimo (secondi, 0 = senza limite)", "tempo", float(m.get("tempo", 0.0)), 0, 600, 5, false)
	# v0.18.3: ENERGIA (limite a luci che calano, ricarica con un tiro)
	var en: Dictionary = m.get("energia", {}) if m.get("energia") is Dictionary else {}
	var cb_en := CheckBox.new()
	cb_en.text = "Con ENERGIA (luci che calano: a zero la missione è persa)"
	cb_en.button_pressed = not en.is_empty()
	cb_en.toggled.connect(func(x): _mi("energia.attiva", x, true))
	_pannello.add_child(cb_en)
	if not en.is_empty():
		_num_m("Luci di energia", "energia.luci", float(en.get("luci", 6)), 1, 20, 1)
		_num_m("Una luce si spegne ogni (secondi)", "energia.cala", float(en.get("cala", 4.0)), 0.5, 60, 0.5, false)
		var ric: Dictionary = en.get("ricarica", {}) if en.get("ricarica") is Dictionary else {}
		_scelta_m("Si ricarica colpendo", "energia.ricarica.tipo", Mattoncini.EVENTI.map(func(x): return Mattoncini.NOMI_EVENTI.get(x, x)), Mattoncini.EVENTI, str(ric.get("tipo", "bumper")))
		_etichetta("(luci del piano: modo «energia» per mostrarla)")
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("MODALITÀ")
	var pri := int(m.get("priorita", 0))
	_scelta_m("Tipo", "priorita", ["missione normale (in fila con le altre)", "MODALITÀ: parte da sola appena sbloccata e mette in pausa la missione in corso", "MODALITÀ FORTE: interrompe anche le altre modalità"], [0, 1, 2], pri)
	if pri > 0:
		_etichetta("Una modalità si sblocca dopo N missioni normali completate (sotto); poi di nuovo dopo altre N.")
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("QUANDO SI SBLOCCA")
	var altre: Array = progetto.desc["missioni"].filter(func(x): return str(x.get("id", "")) != _missione_scelta)
	var sb: Dictionary = m.get("sblocco", {}) if m.get("sblocco") is Dictionary else {}
	_scelta_m("Dopo la missione", "sblocco.dopo", ["(nessuna)"] + altre.map(func(x): return str(x.get("nome", x["id"]))), [""] + altre.map(func(x): return str(x["id"])), str(sb.get("dopo", "")), false)
	_num_m("Dopo quante missioni completate (0 = subito)", "sblocco.completate", float(sb.get("completate", 0)), 0, 50, 1)
	if progetto.desc.get("collezione") is Dictionary:
		_num_m("Dopo quanti oggetti della collezione catturati", "sblocco.collezione", float(sb.get("collezione", 0)), 0, 50, 1)
	if progetto.desc.get("zone") is Array and not progetto.desc["zone"].is_empty():
		var zn: Array = progetto.desc["zone"]
		var dentro: Array = (m.get("zone", []) as Array).map(func(x): return int(x))
		_etichetta("Si gioca nelle zone (nessuna spunta = in tutte)")
		for z in zn.size():
			var zi := z
			var cbz := CheckBox.new()
			cbz.text = "%d. %s" % [z + 1, zn[z].get("nome", "")]
			cbz.button_pressed = dentro.has(z)
			cbz.toggled.connect(func(v):
				var l: Array = (progetto.desc["missioni"][progetto.indice_missione(_missione_scelta)].get("zone", []) as Array).map(func(x): return int(x))
				if v and not l.has(zi):
					l.append(zi)
				elif not v:
					l.erase(zi)
				_mi("zone", l))
			_pannello.add_child(cbz)
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("ALL'INIZIO")
	var ini: Dictionary = m.get("inizio", {}) if m.get("inizio") is Dictionary else {}
	_num_m("Salva-pallina (secondi)", "inizio.salva_pallina", float(ini.get("salva_pallina", 0)), 0, 120, 1, false)
	_num_m("Multiball: palline in più", "inizio.multiball", float(ini.get("multiball", 0)), 0, 5, 1)
	_num_m("Punti moltiplicati per (1 = normale)", "inizio.punti_x", float(ini.get("punti_x", 1)), 1, 10, 1)
	_azioni_pezzi("inizio", ini)
	var fasi: Array = m.get("fasi", [])
	for k in fasi.size():
		var f: Dictionary = fasi[k]
		var pre := "fasi.%d." % k
		_pannello.add_child(HSeparator.new())
		_titolo_pannello("FASE %d — %s" % [k + 1, Mattoncini.descrivi_fase(f)])
		var q: Dictionary = f.get("quando", {})
		var tipo := str(q.get("tipo", "qualsiasi"))
		_scelta_m("QUANDO: cosa colpire", pre + "quando.tipo", Mattoncini.EVENTI.map(func(x): return Mattoncini.NOMI_EVENTI.get(x, x)), Mattoncini.EVENTI, tipo)
		var pezzi: Array = [""]
		var nomi_p: Array = ["(uno qualsiasi)"]
		if tipo == "fila":
			var gr := {}
			for b in progetto.desc.get("bersagli", []):
				if str(b.get("gruppo", "")) != "":
					gr[str(b["gruppo"])] = true
			for g in gr:
				pezzi.append(g)
				nomi_p.append("fila «%s»" % g)
		else:
			for e in progetto.desc.get(LISTA_DEL_TIPO.get(tipo, "_"), []):
				if e is Dictionary and e.has("id") and (not e.has("da_nastro") or tipo in ["rampa", "rampa_entrata"]):
					pezzi.append(str(e["id"]))
					nomi_p.append(str(e["id"]))
		if pezzi.size() > 1:
			_scelta_m("Quale pezzo", pre + "quando.id", nomi_p, pezzi, str(q.get("id", "")))
		var modo := str(f.get("modo", "conta"))
		_scelta_m("COME si conta", pre + "modo", NOMI_MODI.values(), NOMI_MODI.keys(), modo)
		if modo in ["conta", "combo"]:
			_num_m("Quante volte", pre + "volte", float(f.get("volte", 1)), 1, 500, 1)
		if modo == "combo":
			_num_m("Secondi massimi tra un tiro e l'altro", pre + "finestra", float(f.get("finestra", 3.0)), 0.5, 20, 0.5, false)
		if modo == "stato":
			_num_m("Per quanti secondi tenerlo vivo", pre + "durata", float(f.get("durata", 15.0)), 3, 120, 1, false)
			_num_m("Un colpo almeno ogni (secondi)", pre + "finestra", float(f.get("finestra", 4.0)), 1, 30, 0.5, false)
		if modo in ["tutti", "sequenza"]:
			_campo_testo("Pezzi (nomi separati da virgola; vuoto = tutti quelli del tipo)" if modo == "tutti" else "Pezzi IN ORDINE (nomi separati da virgola)", ", ".join((f.get("ids", []) as Array).map(func(x): return str(x))), func(v): _mi(pre + "ids", Array(v.split(",", false)).map(func(x): return x.strip_edges()), true))
		if modo == "hurry_up":
			_num_m("Premio di partenza (punti)", pre + "premio.punti", float(f.get("premio", {}).get("punti", 300000)), 0, 10000000, 10000)
			_num_m("Quanto cala ogni secondo", pre + "cala", float(f.get("cala", 10000)), 0, 1000000, 1000, false)
			_num_m("Premio minimo", pre + "premio.minimo", float(f.get("premio", {}).get("minimo", 0)), 0, 10000000, 10000)
		else:
			_num_m("Premio della fase (punti)", pre + "premio.punti", float(f.get("premio", {}).get("punti", 0)), 0, 10000000, 1000)
		_num_m("Tempo per questa fase (s, 0 = senza)", pre + "entro", float(f.get("entro", 0)), 0, 600, 5, false)
		_campo_testo("Testo sul tabellone (vuoto = automatico)", str(f.get("testo", "")), func(v): _mi(pre + "testo", v))
		if str(progetto.desc.get("lingua", "it")) == "en":
			_campo_testo("Testo in inglese (vuoto = automatico)", str(f.get("testo_en", "")), func(v): _mi(pre + "testo_en", v))
		if fasi.size() > 1:
			var kk := k
			_bottone(_pannello, "Togli la fase %d" % (k + 1), func(): _comando_missione({"comando": "missione_fase", "id": _missione_scelta, "azione": "togli", "indice": kk}); _ricostruisci_pannello = true; _aggiorna_pannello(), "")
	_bottone(_pannello, "+ Aggiungi una fase", func(): _comando_missione({"comando": "missione_fase", "id": _missione_scelta}); _ricostruisci_pannello = true; _aggiorna_pannello(), "Una fase dopo l'altra: si passa alla successiva quando questa è fatta")
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("PREMIO FINALE")
	var pr: Dictionary = m.get("premio", {}) if m.get("premio") is Dictionary else {}
	_num_m("Punti", "premio.punti", float(pr.get("punti", 0)), 0, 50000000, 5000)
	_spunta_m("Pallina extra", "premio.pallina_extra", bool(pr.get("pallina_extra", false)))
	_num_m("Bonus: moltiplicatore in più", "premio.bonus_x", float(pr.get("bonus_x", 0)), 0, 10, 1)
	_num_m("Salva-pallina (secondi)", "premio.salva_pallina", float(pr.get("salva_pallina", 0)), 0, 120, 1, false)
	_num_m("Multiball: palline in più", "premio.multiball", float(pr.get("multiball", 0)), 0, 5, 1)
	_azioni_pezzi("premio", pr)
	if progetto.desc.get("collezione") is Dictionary:
		_spunta_m("Cattura un oggetto della collezione", "premio.cattura", bool(pr.get("cattura", false)))
	if progetto.desc.get("zone") is Array and not progetto.desc["zone"].is_empty():
		_spunta_m("Passa alla zona successiva (viaggio)", "premio.zona_avanti", bool(pr.get("zona_avanti", false)))
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("MUSICA DURANTE LA MISSIONE")
	var mm := str(m.get("musica", ""))
	_etichetta(mm if mm != "" else "(quella del tavolo)")
	var rmm := HBoxContainer.new()
	_pannello.add_child(rmm)
	_bottone(rmm, "Scegli…", func(): _scegli_musica("missione", _missione_scelta), "Una tua canzone solo per questa missione")
	if mm != "":
		_bottone(rmm, "Togli", func(): _comando_missione({"comando": "musica", "ruolo": "missione", "id": _missione_scelta, "togli": true}); _ricostruisci_pannello = true; _aggiorna_pannello(), "")
	_pannello.add_child(HSeparator.new())
	var rdu := HBoxContainer.new()
	_pannello.add_child(rdu)
	_bottone(rdu, "⧉ Duplica la missione", func():
		var rd := progetto.esegui({"comando": "missione_duplica", "id": _missione_scelta})
		_avviso(rd["messaggio"])
		_aggiorna_missioni()
		if rd["ok"]:
			_scegli_missione(str(rd["id"])), "Una copia da cambiare (es. la stessa missione più difficile)")
	_bottone(rdu, "Chiudi", func(): _scegli_missione(""), "Torna alle proprietà del tavolo")

# ================================================================ tracciatore (v0.9.5)
var _traccia_opz := {"tiri": 1, "variazione": 3.0, "secondi": 4.0, "livello": 0}
var _thread_traccia: Thread
var _traccia_ultima_richiesta: Array = []

func _pannello_traccia() -> void:
	_titolo_pannello("TRACCIA TIRO")
	var spieg := Label.new()
	spieg.text = "Clic = da dove parte la pallina; trascina = verso e forza; rilascia = tiro sul motore vero."
	spieg.autowrap_mode = TextServer.AUTOWRAP_WORD
	spieg.custom_minimum_size = Vector2(260, 0)
	_pannello.add_child(spieg)
	for voce in [["Quanti tiri", "tiri", 1, 20, 1], ["Variazione d'angolo tra i tiri (± gradi)", "variazione", 0, 20, 0.5], ["Secondi da seguire", "secondi", 1, 15, 0.5], ["Livello di partenza (0 = tavolo)", "livello", 0, 9, 1]]:
		_etichetta(voce[0])
		var sb := _numero(_pannello, float(_traccia_opz[voce[1]]), voce[2], voce[3], voce[4])
		var chiave: String = voce[1]
		sb.value_changed.connect(func(v): _traccia_opz[chiave] = v)
	var r := HBoxContainer.new()
	_pannello.add_child(r)
	_bottone(r, "Ripeti l'ultimo tiro", _ripeti_traccia, "Stesso punto e stessa forza, con le opzioni di adesso")
	_bottone(r, "Cancella", func(): progetto.ultima_traccia = {}; vista.queue_redraw(); _ricostruisci_pannello = true; _aggiorna_pannello(), "Toglie il percorso dal tavolo")
	# v0.18.1: TIRI DI RIFERIMENTO
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("TIRI DI RIFERIMENTO")
	_etichetta("Un tiro che funziona si salva; dopo le modifiche «Rifai e confronta» dice se ora va diversamente (anche CONTROLLA).")
	var rt := HBoxContainer.new()
	_pannello.add_child(rt)
	var le_t := LineEdit.new()
	le_t.placeholder_text = "nome (es. «paletta dx → rampa»)"
	le_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_child(le_t)
	_bottone(rt, "Salva l'ultimo tiro", func(): _menu_cmd({"comando": "tiro_salva", "nome": le_t.text}, true), "Salva il tiro appena fatto con quello che ha colpito")
	var tr_l: Array = progetto.desc.get("tiri_riferimento", []) if progetto.desc.get("tiri_riferimento") is Array else []
	for i in tr_l.size():
		var ri := HBoxContainer.new()
		_pannello.add_child(ri)
		var lt := Label.new()
		var at: Dictionary = tr_l[i].get("atteso", {})
		lt.text = "%s → %s" % [tr_l[i].get("nome", "tiro"), ", ".join(at.get("colpi", [])) if not at.get("colpi", []).is_empty() else at.get("fine", "")]
		lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lt.autowrap_mode = TextServer.AUTOWRAP_WORD
		ri.add_child(lt)
		var ii := i
		_bottone(ri, "✕", func(): _menu_cmd({"comando": "tiro_togli", "indice": ii}, true), "Toglie il tiro di riferimento")
	if not tr_l.is_empty():
		_bottone(_pannello, "Rifai e confronta", _verifica_tiri, "Rifà tutti i tiri salvati sul tavolo di adesso")
	# v0.16: VENTAGLIO dalla paletta e MAPPA DI CALORE
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("VENTAGLIO DALLA PALETTA")
	_etichetta("La pallina ferma in N punti della paletta: dove va ogni tiro.")
	var rv := HBoxContainer.new()
	_pannello.add_child(rv)
	var obp := OptionButton.new()
	var pids: Array = progetto.desc.get("palette", []).map(func(x): return str(x["id"]))
	for pid in pids:
		obp.add_item(pid)
	rv.add_child(obp)
	var spc := SpinBox.new()
	spc.min_value = 2
	spc.max_value = 12
	spc.value = 6
	spc.tooltip_text = "Quanti tiri (dalla base alla punta)"
	rv.add_child(spc)
	_bottone(rv, "Ventaglio", func(): _calcolo_traccia({"paletta": pids[obp.selected] if not pids.is_empty() else "", "colpi": int(spc.value)}, "Ventaglio dalla paletta…"), "Tiri dalla paletta scelta")
	_titolo_pannello("MAPPA DI CALORE")
	_etichetta("Il tavolo gioca da solo; i quadretti rossi = dove la pallina passa di più.")
	var rc := HBoxContainer.new()
	_pannello.add_child(rc)
	var sps := SpinBox.new()
	sps.min_value = 10
	sps.max_value = 300
	sps.step = 10
	sps.value = 60
	sps.suffix = "s"
	rc.add_child(sps)
	_bottone(rc, "Mappa di calore", func(): _calcolo_traccia({"calore": sps.value}, "Mappa di calore: il tavolo gioca da solo…"), "Gioco automatico (lancio e palette): conta i passaggi")
	if not progetto.ultima_traccia.is_empty():
		_pannello.add_child(HSeparator.new())
		_titolo_pannello("RISULTATO")
		var v: Vector2 = progetto.ultima_traccia.get("vel", Vector2.ZERO)
		_etichetta("Partenza %.0f × %.0f mm, %.0f mm/s" % [progetto.ultima_traccia["da"].x, progetto.ultima_traccia["da"].y, v.length()])
		var l := Label.new()
		l.text = Tracciatore.riassunto(progetto.ultima_traccia)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(260, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pannello.add_child(l)
	var n := Label.new()
	n.text = "Colori: blu = lenta, rosso = veloce. Linea spessa = sopra una rampa. Pallini = colpi. Croce rossa = ferma o uscita."
	n.autowrap_mode = TextServer.AUTOWRAP_WORD
	n.custom_minimum_size = Vector2(260, 0)
	n.add_theme_font_size_override("font_size", 12)
	_pannello.add_child(n)

## Ventaglio o mappa di calore in un thread (come il tiro).
func _calcolo_traccia(opz: Dictionary, msg: String) -> void:
	if _thread_traccia != null and _thread_traccia.is_alive():
		_avviso("Un calcolo è già in corso…")
		return
	if _thread_traccia != null:
		_thread_traccia.wait_to_finish()
	_avviso(msg)
	var copia := progetto.desc.duplicate(true)
	_thread_traccia = Thread.new()
	_thread_traccia.start(func(): _fine_traccia.call_deferred(Tracciatore.esegui(copia, opz)))

func _confronta_salvato() -> void:
	var r := progetto.esegui({"comando": "confronta"})
	_avviso(r["messaggio"])
	for d in r.get("differenze", []):
		_avviso("   " + str(d))

func _verifica_tiri() -> void:
	_avviso("Rifaccio i tiri di riferimento…")
	var r := progetto.esegui({"comando": "tiri_verifica"})
	_avviso(r["messaggio"])
	for e in r.get("esiti", []):
		_avviso(("✔ " if e["ok"] else "✖ ") + str(e["testo"]))

func _ripeti_traccia() -> void:
	if not _traccia_ultima_richiesta.is_empty():
		_su_traccia(_traccia_ultima_richiesta[0], _traccia_ultima_richiesta[1])

func _su_traccia(da: Vector2, vel: Vector2) -> void:
	if _thread_traccia != null and _thread_traccia.is_alive():
		_avviso("Il tiro precedente è ancora in corso…")
		return
	if _thread_traccia != null:
		_thread_traccia.wait_to_finish()
	_traccia_ultima_richiesta = [da, vel]
	var opz := {"da": da, "vel": vel, "tiri": int(_traccia_opz["tiri"]), "variazione": float(_traccia_opz["variazione"]),
		"secondi": float(_traccia_opz["secondi"]), "livello": int(_traccia_opz["livello"])}
	_avviso("Tiro da %.0f × %.0f mm a %.0f mm/s…" % [da.x, da.y, vel.length()])
	var copia := progetto.desc.duplicate(true)
	_thread_traccia = Thread.new()
	_thread_traccia.start(func(): _fine_traccia.call_deferred(Tracciatore.esegui(copia, opz)))

func _fine_traccia(r: Dictionary) -> void:
	if _thread_traccia != null:
		_thread_traccia.wait_to_finish()
	progetto.ultima_traccia = r
	_avviso(Tracciatore.riassunto(r).replace("\n", " · "))
	vista.queue_redraw()
	_ricostruisci_pannello = true
	_aggiorna_pannello()

# ================================================================ pannello delle proprietà
func _aggiorna_pannello() -> void:
	if not _ricostruisci_pannello:
		return
	_ricostruisci_pannello = false
	for c in _pannello.get_children():
		_pannello.remove_child(c)
		c.queue_free()
	if vista.da_inserire == "traccia":
		_pannello_traccia()
		return
	if _missione_scelta != "" and progetto.indice_missione(_missione_scelta) >= 0:
		_pannello_missione()
		return
	if _menu_aperto and vista.selezionato == "":
		_pannello_menu()
		return
	if _lic_aperto and vista.selezionato == "":
		_pannello_licenze()
		return
	if _cz_aperto and vista.selezionato == "":
		_pannello_cz()
		return
	var id := vista.selezionato
	var t := progetto.trova(id) if id != "" else []
	if vista.selezionati.size() > 1:
		_pannello_gruppo()
		return
	if t.is_empty():
		_pannello_tavolo()
		return
	var chiave: String = t[0]
	var e: Dictionary = progetto.desc[chiave][t[1]]
	var s := SchedeEditor.scheda(chiave)
	_titolo_pannello(str(s.get("nome", chiave)).to_upper())
	if pro:
		_campo_testo("Nome (id)", str(e["id"]), func(v): _imposta("id", v, true))
	var cp := SchedeEditor.campo_pos(chiave)
	for f in SchedeEditor.campi(chiave):
		if bool(f.get("pro", false)) and not pro:
			continue
		if bool(f.get("sempre", false)):
			if f.has("solo_se") and str(e.get(f["solo_se"], "")) == "":
				continue
			if f["k"] == "aspetto":
				_pannello.add_child(HSeparator.new())
				_etichetta("ASPETTO")
			var vs = e.get(f["k"], "")
			if f["k"] == "altezza_3d" and not e.has(f["k"]):
				vs = PittorePezzi.altezza(chiave, e)
			if f["k"] == "intensita_bordo" and not e.has(f["k"]):
				vs = 1.0
			if f["tipo"] == "colore" and not e.has(f["k"]):
				vs = PittorePezzi.colore_interno(e, progetto.desc) if f["k"] == "colore_2" else (PittorePezzi.colore_bordo(chiave, e, progetto.desc) if f["k"] == "colore_bordo" else PittorePezzi.colore(chiave, e, progetto.desc))
			_campo(f, vs)
			if bool(f.get("togli", false)) and e.has(f["k"]):
				var kk: String = f["k"]
				_bottone(_pannello, "Colore del tavolo", func(): _imposta(kk, "", true), "Togli il colore proprio: il pezzo torna col colore del tavolo")
			continue
		if f.has("solo_se_valore") and str(e.get(f["solo_se_valore"][0], "")) != str(f["solo_se_valore"][1]):
			continue
		# v0.19: "pred" = valore mostrato finché il pezzo non ha il campo; "pred_da" = lo prende da un altro campo
		if not e.has(f["k"]) and f["k"] != cp and not f.has("pred") and not f.has("pred_da"):
			if not s.has("nuovo") or not s["nuovo"].has(f["k"]):
				continue
		var v = e.get(f["k"], s.get("nuovo", {}).get(f["k"], e.get(str(f.get("pred_da", "")), f.get("pred"))))
		_campo(f, v)
	if chiave in PittorePezzi.TIPI or chiave in ["decorazioni", "rampe"]:
		_sezione_immagine(id, chiave, e)
	if chiave in ["muri", "piani"]:
		_pannello.add_child(HSeparator.new())
		_titolo_pannello("PUNTI (curvi o ad angolo)")
		var ip := vista.punto
		var curvi: Array = e.get("curvi", [])
		var fio: Array = e.get("fionda", [])
		if ip >= 0 and ip < curvi.size():
			_etichetta("Punto %d scelto (cerchio bianco)" % (ip + 1))
			var cb1 := CheckBox.new()
			cb1.text = "Curvo (la linea passa morbida)"
			cb1.button_pressed = bool(curvi[ip])
			cb1.toggled.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "indice": ip, "curvo": v})["messaggio"]))
			_pannello.add_child(cb1)
		if ip >= 0 and ip < curvi.size() and chiave == "muri":
			var cb2 := CheckBox.new()
			cb2.text = "Fionda: il tratto fino al punto dopo spinge la pallina"
			cb2.button_pressed = bool(fio[ip])
			cb2.toggled.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "indice": ip, "fionda": v})["messaggio"]))
			_pannello.add_child(cb2)
		if ip < 0 or ip >= curvi.size():
			_etichetta("Clicca un quadratino per scegliere un punto")
		var rp := HBoxContainer.new()
		_pannello.add_child(rp)
		_bottone(rp, "Tutti curvi", func(): _comando({"comando": "punto", "id": id, "indice": -1, "curvo": true}), "Tutta la forma morbida")
		_bottone(rp, "Tutti ad angolo", func(): _comando({"comando": "punto", "id": id, "indice": -1, "curvo": false}), "Tutta la forma a spigoli")
	if chiave == "nastri":
		_pannello.add_child(HSeparator.new())
		_titolo_pannello("INGRESSO, USCITA E CORSIA")
		var lg: Array = e["larghezze"]
		var al: Array = e["altezze"]
		var ultimo: int = lg.size() - 1
		for voce in [["Larghezza dell'ingresso (mm)", "ingresso", float(lg[0])], ["Larghezza dell'uscita (mm)", "uscita", float(lg[ultimo])], ["Larghezza di tutta la corsia (mm)", -1, float(lg[mini(1, ultimo)])]]:
			_etichetta(voce[0])
			var sl := _numero(_pannello, voce[2], 20, 200, 1)
			sl.value_changed.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "indice": voce[1], "larghezza": v})["messaggio"]); vista.queue_redraw())
		_etichetta("Altezza di tutto il nastro (0 = a terra, più alto = rampa) (mm)")
		var sa := _numero(_pannello, float(al[mini(1, ultimo)]), 0, 120, 1)
		sa.value_changed.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "indice": -1, "altezza": v})["messaggio"]); vista.queue_redraw())
		var ipn := vista.punto
		if ipn >= 0 and ipn < lg.size():
			_etichetta("Punto %d scelto%s" % [ipn + 1, " (ingresso)" if ipn == 0 else (" (uscita)" if ipn == ultimo else "")])
			_etichetta("  larghezza (mm)")
			var sl2 := _numero(_pannello, float(lg[ipn]), 20, 200, 1)
			sl2.value_changed.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "indice": ipn, "larghezza": v})["messaggio"]); vista.queue_redraw())
			_etichetta("  altezza (mm)")
			var sa2 := _numero(_pannello, float(al[ipn]), 0, 120, 1)
			sa2.value_changed.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "indice": ipn, "altezza": v})["messaggio"]); vista.queue_redraw())
			var cbn := CheckBox.new()
			cbn.text = "Curvo"
			cbn.button_pressed = bool(e["curvi"][ipn])
			cbn.toggled.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "indice": ipn, "curvo": v})["messaggio"]); vista.queue_redraw())
			_pannello.add_child(cbn)
		else:
			_etichetta("Clicca un punto per larghezza e altezza solo lì")
		var rpn := HBoxContainer.new()
		_pannello.add_child(rpn)
		_bottone(rpn, "Tutti curvi", func(): _comando({"comando": "punto", "id": id, "indice": -1, "curvo": true}), "Nastro morbido")
		_bottone(rpn, "Tutti ad angolo", func(): _comando({"comando": "punto", "id": id, "indice": -1, "curvo": false}), "Nastro a spigoli")
	if chiave == "inserti":
		_sezione_luce(id, e)
	if chiave == "rampe":
		_pannello.add_child(HSeparator.new())
		_titolo_pannello("ALTEZZA DEI PUNTI")
		var ipr := vista.punto
		var prr: Array = e["punti"]
		if ipr >= 0 and ipr < prr.size():
			_etichetta("Punto %d%s: altezza (mm)" % [ipr + 1, " (imbocco)" if ipr == 0 else (" (uscita)" if ipr == prr.size() - 1 else "")])
			var sh := _numero(_pannello, prr[ipr].z, 0, 120, 1)
			sh.value_changed.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "indice": ipr, "altezza": v})["messaggio"]); vista.queue_redraw())
		else:
			_etichetta("Clicca un punto della rampa per la sua altezza")
		_titolo_pannello("TUTTA LA RAMPA")
		var hmx := 0.0
		for q in prr:
			hmx = maxf(hmx, float(q.z))
		_etichetta("Altezza del punto più alto (gli altri in proporzione) (mm)")
		var sat := _numero(_pannello, hmx, 5, 120, 1)
		sat.value_changed.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "altezza_tutta": v})["messaggio"]); vista.queue_redraw())
		_etichetta("Larghezza dell'imbocco, a terra (mm; la corsia sopra resta 38)")
		var sim := _numero(_pannello, float(e.get("invito", 25.0)) * 2.0, 38, 90, 1)
		sim.value_changed.connect(func(v): _avviso(progetto.esegui({"comando": "punto", "id": id, "imbocco": v})["messaggio"]); vista.queue_redraw())
		var rp2 := HBoxContainer.new()
		_pannello.add_child(rp2)
		_bottone(rp2, "Sale e riscende", func(): _comando({"comando": "punto", "id": id, "profilo": "sale_scende"}); _ricostruisci_pannello = true; _aggiorna_pannello(), "Parte da terra, sale a 45 mm, finisce a terra")
		_bottone(rp2, "Uscita sospesa", func(): _comando({"comando": "punto", "id": id, "profilo": "resta_alta"}); _ricostruisci_pannello = true; _aggiorna_pannello(), "Finisce in alto a 32 mm: la pallina cade sul piano")
		var nr := Label.new()
		nr.text = "Il primo punto è l'imbocco e deve stare a 0 mm (a terra). Rampe e binari passano SOPRA gli altri pezzi."
		nr.autowrap_mode = TextServer.AUTOWRAP_WORD
		nr.custom_minimum_size = Vector2(260, 0)
		nr.add_theme_font_size_override("font_size", 12)
		_pannello.add_child(nr)
	if SchedeEditor.campo_punti(chiave) != "":
		var n := Label.new()
		n.text = "%d punti. Trascina i quadratini gialli. Doppio clic sulla linea = punto nuovo; clic destro su un quadratino = toglilo." % ProgettoEditor.punti_2d(chiave, e).size()
		n.autowrap_mode = TextServer.AUTOWRAP_WORD
		n.custom_minimum_size = Vector2(260, 0)
		n.add_theme_font_size_override("font_size", 12)
		_pannello.add_child(n)
	_pannello.add_child(HSeparator.new())
	_strumenti_pezzo(_pannello, false)

## Pulsanti che agiscono su tutti i pezzi scelti (anche uno solo).
func _gruppo(azione: String, extra := {}) -> void:
	if azione in ["sposta", "ruota", "scala", "capovolgi", "allinea", "distribuisci"] and vista.selezionati.any(func(i): return vista.bloccato(str(i))):
		_avviso("🔒 Tra i pezzi scelti ce n'è uno bloccato: prima «🔓 Sblocca».")
		return
	var c := {"comando": "gruppo", "ids": vista.selezionati.duplicate(), "azione": azione}
	c.merge(extra)
	var r := progetto.esegui(c)
	_avviso(r["messaggio"])
	if azione == "elimina" and r.get("ok", false):
		vista.seleziona("")
	elif not r.get("ids", []).is_empty():
		vista.scegli_tutti(r["ids"])
	_ricostruisci_pannello = true
	_aggiorna_pannello.call_deferred()

func _strumenti_pezzo(dove: Control, piu: bool) -> void:
	var r1 := HBoxContainer.new()
	dove.add_child(r1)
	_bottone(r1, "Duplica", func(): _gruppo("duplica"), "Ctrl+D")
	_bottone(r1, "⇋ Copia a specchio", func(): _gruppo("specchia"), "Ctrl+M: dall'altra parte del tavolo")
	var r2 := HBoxContainer.new()
	dove.add_child(r2)
	_bottone(r2, "Ingrandisci", func(): _gruppo("scala", {"fattore": 1.1}), "+ (10 % più grande)")
	_bottone(r2, "Rimpicciolisci", func(): _gruppo("scala", {"fattore": 1.0 / 1.1}), "− (10 % più piccolo)")
	var r3 := HBoxContainer.new()
	dove.add_child(r3)
	_bottone(r3, "Capovolgi ↔", func(): _gruppo("capovolgi", {"asse": "x"}), "Sinistra ↔ destra, sul posto")
	_bottone(r3, "Capovolgi ↕", func(): _gruppo("capovolgi", {"asse": "y"}), "Su ↕ giù, sul posto")
	_bottone(r3, "Ruota 15°", func(): _gruppo("ruota", {"gradi": 15}), "R (Maiusc+R al contrario)")
	if piu:
		var r4 := HBoxContainer.new()
		dove.add_child(r4)
		_bottone(r4, "In riga", func(): _gruppo("allinea", {"asse": "y"}), "Tutti alla stessa altezza")
		_bottone(r4, "In colonna", func(): _gruppo("allinea", {"asse": "x"}), "Tutti sulla stessa verticale")
		var r5 := HBoxContainer.new()
		dove.add_child(r5)
		_bottone(r5, "Distanze uguali ↔", func(): _gruppo("distribuisci", {"asse": "x"}), "Stessa distanza in orizzontale")
		_bottone(r5, "Distanze uguali ↕", func(): _gruppo("distribuisci", {"asse": "y"}), "Stessa distanza in verticale")
	var r6 := HBoxContainer.new()
	dove.add_child(r6)
	# v0.28: se i pezzi scelti sono già bloccati il pulsante diventa «Sblocca» (prima si sbloccava solo da Pezzi)
	if vista.selezionati.all(func(i): return vista.bloccato(str(i))):
		var sb := _bottone(r6, "🔓 Sblocca", func(): _gruppo("blocca", {"valore": false}), "Si torna a spostare e ridimensionare col mouse")
		sb.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	else:
		_bottone(r6, "🔒 Blocca", func(): _gruppo("blocca", {"valore": true}), "Non si sposta più per sbaglio: il clic sceglie prima i pezzi sotto; per riprenderlo cliccalo dove non c'è altro, poi «Sblocca»")
	var el := _bottone(r6, "Elimina", func(): _gruppo("elimina"), "Canc")
	el.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	# v0.19: salva il pezzo (con immagine, collisione e fisica) nella libreria
	if not piu and vista.selezionato != "":
		var rl := HBoxContainer.new()
		dove.add_child(rl)
		var le_l := LineEdit.new()
		le_l.placeholder_text = "nome (es. Zucca)"
		le_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.add_child(le_l)
		_bottone(rl, "⭐ Salva in I miei elementi", func(): _avviso(progetto.esegui({"comando": "elemento_salva", "id": vista.selezionato, "nome": le_l.text})["messaggio"]), "Lo ritrovi in ogni tavolo con «I miei elementi»")

func _pannello_gruppo() -> void:
	_titolo_pannello("%d PEZZI SCELTI" % vista.selezionati.size())
	var l := Label.new()
	l.text = "Trascinane uno per spostarli tutti. Maiusc+clic aggiunge o toglie un pezzo. Ctrl+C / Ctrl+V per copiarli dove punti il mouse."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(260, 0)
	l.add_theme_font_size_override("font_size", 12)
	_pannello.add_child(l)
	_strumenti_pezzo(_pannello, true)
	# v0.16: GRUPPO CON NOME
	_pannello.add_child(HSeparator.new())
	var gn := progetto.gruppo_di(str(vista.selezionati[0]))
	var tutti_nel_gruppo: bool = gn != "" and vista.selezionati.all(func(i): return progetto.gruppo_di(str(i)) == gn) and progetto.gruppi_editor()[gn].size() == vista.selezionati.size()
	if tutti_nel_gruppo:
		_etichetta("GRUPPO «%s» (un clic su un suo pezzo lo sceglie tutto; Alt+clic = un pezzo solo)" % gn)
		_campo_testo("Nome del gruppo", gn, func(v): _avviso(progetto.esegui({"comando": "gruppo_nome", "azione": "rinomina", "nome": gn, "nuovo": v})["messaggio"]))
		_bottone(_pannello, "Sciogli il gruppo", func(): _avviso(progetto.esegui({"comando": "gruppo_nome", "azione": "sciogli", "nome": gn})["messaggio"]); _ricostruisci_pannello = true; _aggiorna_pannello(), "I pezzi restano dove sono")
	else:
		_etichetta("FAI UN GRUPPO CON QUESTI PEZZI")
		var rg := HBoxContainer.new()
		_pannello.add_child(rg)
		var le := LineEdit.new()
		le.placeholder_text = "nome (es. Zona bassa)"
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rg.add_child(le)
		_bottone(rg, "Fai gruppo", func(): _avviso(progetto.esegui({"comando": "gruppo_nome", "azione": "crea", "ids": vista.selezionati.duplicate(), "nome": le.text})["messaggio"]); _ricostruisci_pannello = true; _aggiorna_pannello(), "Poi un clic su un pezzo sceglie tutto il gruppo")
	_pannello.add_child(HSeparator.new())
	_etichetta("ASPETTO DEI PEZZI SCELTI")
	var ob := OptionButton.new()
	var opz := ["— scegli —", "come il tavolo", "effetto 3D (ombre e fianchi)", "piatto"]
	var val := ["", "", "3d", "piatto"]
	for o in opz:
		ob.add_item(o)
	ob.item_selected.connect(func(i):
		if i > 0:
			_avviso(progetto.esegui({"comando": "gruppo", "ids": vista.selezionati.duplicate(), "azione": "aspetto", "valore": val[i]})["messaggio"]))
	_pannello.add_child(ob)
	_etichetta("Colore dei pezzi scelti")
	var cpb := ColorPickerButton.new()
	cpb.color = Color(1, 0.6, 0.2)
	cpb.custom_minimum_size = Vector2(0, 28)
	_al_chiudere(cpb, func(c: Color):
		_avviso(progetto.esegui({"comando": "gruppo", "ids": vista.selezionati.duplicate(), "azione": "colore", "valore": c})["messaggio"]))
	_pannello.add_child(cpb)
	_bottone(_pannello, "Colore del tavolo", func():
		_avviso(progetto.esegui({"comando": "gruppo", "ids": vista.selezionati.duplicate(), "azione": "colore", "valore": ""})["messaggio"]), "Tutti i pezzi scelti tornano col colore del tavolo")

## Pannello del TAVOLO (nessun pezzo scelto): nome, forma esterna (forme pronte + larghezza e curve), sponda a mano.
func _pannello_tavolo() -> void:
	_titolo_pannello("TAVOLO")
	_campo_testo("Nome del tavolo", str(progetto.desc.get("titolo", "")).capitalize(), func(v):
		_avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "titolo", "valore": v})["messaggio"]))
	_bottone(_pannello, "🎨 MENU E TABELLONE: colori, font, altezza tabellone, pagine…", func(): _apri_menu(true), "Il menu che si apre nel gioco con ☰: predefinito = quello di oggi")
	# v0.18.2: misuratore di peso
	var pz := ControlliEditor.peso(progetto.desc, progetto.cartella)
	var lp := Label.new()
	lp.text = ControlliEditor.testo_peso(pz)
	lp.autowrap_mode = TextServer.AUTOWRAP_WORD
	lp.custom_minimum_size = Vector2(260, 0)
	lp.add_theme_color_override("font_color", {"bene": Color(0.6, 0.9, 0.6), "pesante": Color(1, 0.75, 0.3), "troppo": Color(1, 0.4, 0.35)}[pz["giudizio"]])
	_pannello.add_child(lp)
	_bottone(_pannello, "⏱ Misura la velocità vera (circa 30 secondi)", _misura_velocita, "Gioca da solo il tavolo (normale e multiball) e misura fotogrammi, fisica e memoria su questo computer")
	_bottone(_pannello, "⇄ Cosa è cambiato dall'ultimo salvataggio", _confronta_salvato, "Elenco dei pezzi aggiunti, tolti, spostati o cambiati (nella scheda Diario)")
	var n_lic := progetto.avvisi_licenze().size()
	_bottone(_pannello, "📜 LICENZE di immagini e musiche" + ("  (%d da dichiarare)" % n_lic if n_lic > 0 else ""), func(): _apri_licenze(true), "Da dove viene ogni immagine e musica del tavolo (serve per pubblicare)")
	_etichetta("Lingua del tabellone (nel gioco)")
	var ob_l2 := OptionButton.new()
	ob_l2.add_item("italiano")
	ob_l2.add_item("inglese (English)")
	ob_l2.selected = 1 if str(progetto.desc.get("lingua", "it")) == "en" else 0
	ob_l2.item_selected.connect(func(i): _avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "lingua", "valore": ["it", "en"][i]})["messaggio"]))
	_pannello.add_child(ob_l2)
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("ASPETTO DEL TAVOLO")
	var ob := OptionButton.new()
	ob.add_item("effetto 3D (ombre e fianchi)")
	ob.add_item("piatto")
	ob.selected = 1 if str(progetto.desc.get("aspetto", "3d")) == "piatto" else 0
	ob.tooltip_text = "Vale per tutti i pezzi che hanno l'aspetto «come il tavolo»"
	ob.item_selected.connect(func(i): _avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "aspetto", "valore": ["3d", "piatto"][i]})["messaggio"]))
	_pannello.add_child(ob)
	_bottone(_pannello, "Uguale per tutti i pezzi", func():
		_avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "aspetto_tutti", "valore": str(progetto.desc.get("aspetto", "3d"))})["messaggio"]), "Anche i pezzi con un aspetto proprio tornano come il tavolo")
	var cc = progetto.desc.get("colori", {})
	for voce in [["colore_primario", "primario", "Colore 1 (palette, paletti, fionde)"], ["colore_secondario", "secondario", "Colore 2 (bumper, gomme)"], ["colore_piano", "piano", "Colore del piano"]]:
		_etichetta(voce[2])
		var cp2 := ColorPickerButton.new()
		cp2.color = cc.get(voce[1], Color.WHITE) if cc is Dictionary else Color.WHITE
		cp2.custom_minimum_size = Vector2(0, 28)
		var campo_c: String = voce[0]
		_al_chiudere(cp2, func(c: Color): _avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": campo_c, "valore": c})["messaggio"]))
		_pannello.add_child(cp2)
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("LUCE AMBIENTALE")
	var la: Dictionary = progetto.desc.get("luce_ambiente", {}) if progetto.desc.get("luce_ambiente") is Dictionary else {}
	var ob_l := OptionButton.new()
	var da_val := ["spenta", "alto", "basso", "lati", "ovunque"]
	for o in ["spenta", "dall'alto", "dal basso", "dai lati", "su tutto il piano"]:
		ob_l.add_item(o)
	ob_l.selected = maxi(0, da_val.find(str(la.get("da", "spenta"))))
	ob_l.item_selected.connect(func(i):
		_avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "luce_da", "valore": da_val[i]})["messaggio"])
		_ricostruisci_pannello = true
		_aggiorna_pannello.call_deferred())
	_pannello.add_child(ob_l)
	if da_val.find(str(la.get("da", "spenta"))) > 0:
		var riga_l := HBoxContainer.new()
		_pannello.add_child(riga_l)
		var cp_l := ColorPickerButton.new()
		cp_l.color = la.get("colore", Color(0.4, 0.6, 1.0))
		cp_l.custom_minimum_size = Vector2(80, 28)
		_al_chiudere(cp_l, func(c: Color): _avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "luce_colore", "valore": c})["messaggio"]))
		riga_l.add_child(cp_l)
		var sl_l := HSlider.new()
		sl_l.min_value = 0.05
		sl_l.max_value = 1.0
		sl_l.step = 0.05
		sl_l.value = float(la.get("intensita", 0.5))
		sl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl_l.tooltip_text = "Intensità della luce"
		sl_l.drag_ended.connect(func(cambiato):
			if cambiato:
				_avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "luce_intensita", "valore": sl_l.value})["messaggio"]))
		riga_l.add_child(sl_l)
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("FONDO DIPINTO")
	var riga_f := HBoxContainer.new()
	_pannello.add_child(riga_f)
	_bottone(riga_f, "Scegli immagine…" if not progetto.desc.has("fondo") else "Cambia…", func():
		_scegli_file("Scegli il fondo dipinto del tavolo", func(f): _avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "fondo", "valore": f})["messaggio"])),
		"Un'immagine che copre tutto il tavolo (meglio verticale, come il tavolo; ridotta a max 2048 px)")
	if progetto.desc.has("fondo"):
		var tf := _bottone(riga_f, "Togli fondo", func():
			_avviso(progetto.esegui({"comando": "imposta_tavolo", "campo": "fondo", "valore": ""})["messaggio"])
			_ricostruisci_pannello = true
			_aggiorna_pannello.call_deferred())
		tf.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	_pannello.add_child(HSeparator.new())
	_titolo_pannello("FORMA DEL TAVOLO")
	var griglia := GridContainer.new()
	griglia.columns = 3
	_pannello.add_child(griglia)
	var s_desc: Dictionary = {}
	for nome in FormaTavolo.FORME:
		var f: Dictionary = FormaTavolo.FORME[nome]
		var prova := LayoutBase.descrizione(nome)
		var b := IconeEditor.AnteprimaTavolo.new(prova, str(f["nome"]).split(" ")[0], Vector2(88, 150))
		b.tooltip_text = "%s: %s" % [f["nome"], f["testo"]]
		b.pressed.connect(func():
			_avviso(progetto.esegui({"comando": "forma", "forma": nome})["messaggio"])
			vista.adatta()
			_ricostruisci_pannello = true
			_aggiorna_pannello.call_deferred())
		griglia.add_child(b)
	var fa: Dictionary = FormaTavolo.limita(progetto.desc.get("forma", {"larghezza": float(progetto.desc.get("dimensioni", Vector2(635, 0)).x)}))
	var valori := {"larghezza": fa["larghezza"], "r_sx": fa["r_sx"], "r_dx": fa["r_dx"]}
	for voce in [["larghezza", "Larghezza (mm)", 560.0, 720.0], ["r_sx", "Curva dell'angolo sinistro (mm)", 30.0, 360.0], ["r_dx", "Curva dell'angolo destro (mm)", 150.0, 360.0]]:
		var l := Label.new()
		l.text = "%s: %.0f" % [voce[1], valori[voce[0]]]
		_pannello.add_child(l)
		var sl := HSlider.new()
		sl.min_value = voce[2]
		sl.max_value = voce[3]
		sl.step = 5.0
		sl.value = valori[voce[0]]
		sl.value_changed.connect(func(v): l.text = "%s: %.0f" % [voce[1], v]; valori[voce[0]] = v)
		sl.drag_ended.connect(func(cambiato):
			if cambiato:
				_avviso(progetto.esegui({"comando": "forma", "forma": valori.duplicate()})["messaggio"])
				vista.adatta()
				_ricostruisci_pannello = true
				_aggiorna_pannello.call_deferred())
		_pannello.add_child(sl)
	var riga := HBoxContainer.new()
	_pannello.add_child(riga)
	_bottone(riga, "Rendi simmetrico", func():
		var m := (float(valori["r_sx"]) + float(valori["r_dx"])) * 0.5
		var f2 := {"larghezza": valori["larghezza"], "r_sx": m, "r_dx": m}
		_avviso(progetto.esegui({"comando": "forma", "forma": f2})["messaggio"])
		_ricostruisci_pannello = true
		_aggiorna_pannello.call_deferred(), "I due angoli in alto con la stessa curva")
	_bottone(riga, "Sponda a mano", func():
		vista.seleziona("sponda")
		_avviso("Sponda scelta: trascina i quadratini gialli per disegnare la forma come vuoi (doppio clic = punto nuovo)."), "Modifica la sponda punto per punto")
	var nota := Label.new()
	nota.text = "Cambiando forma, la zona bassa (palette, fionde, corsie) si adatta da sola e gli altri pezzi restano. Si annulla con Ctrl+Z.\n\n" + progetto.riassunto()
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD
	nota.custom_minimum_size = Vector2(260, 0)
	nota.add_theme_font_size_override("font_size", 12)
	_pannello.add_child(nota)

## IMMAGINE PROPRIA del pezzo (v0.6): scegli un file, grande come il pezzo o solo al centro, misura, spostamento,
## rotazione, sopra il disegno o al posto del disegno, togli.
func _sezione_immagine(id: String, chiave: String, e: Dictionary) -> void:
	_pannello.add_child(HSeparator.new())
	_etichetta("IMMAGINE TUA")
	var cmd := func(extra: Dictionary, ricostruisci := true) -> void:
		var c := {"comando": "immagine", "id": id}
		c.merge(extra, true)
		_avviso(progetto.esegui(c)["messaggio"])
		if ricostruisci:
			_ricostruisci_pannello = true
			_aggiorna_pannello.call_deferred()
	_bottone(_pannello, "Scegli immagine…" if not PittorePezzi.ha_immagine(e) else "Cambia immagine…", func(): _scegli_immagine(id), "Un file PNG, JPG o WEBP: entra nel tavolo (ridotto a max 1024 px)")
	if not PittorePezzi.ha_immagine(e):
		return
	if chiave == "decorazioni":
		# immagine sul piano: misura, rotazione e posizione sono quelle del pezzo (sopra); qui solo le proporzioni
		_bottone(_pannello, "Proporzioni dell'immagine", func(): cmd.call({"misura": "pezzo"}), "Larghezza e altezza tornano nelle proporzioni del file")
		var tg := _bottone(_pannello, "Togli immagine", func(): cmd.call({"togli": true}))
		tg.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
		return
	var im: Dictionary = e["immagine"]
	var riga := HBoxContainer.new()
	_pannello.add_child(riga)
	_bottone(riga, "Come il pezzo", func(): cmd.call({"misura": "pezzo"}), "L'immagine copre tutto il pezzo")
	_bottone(riga, "Al centro", func(): cmd.call({"misura": "centro"}), "L'immagine piccola al centro del pezzo")
	_etichetta("Mostra")
	var ob := OptionButton.new()
	ob.add_item("sopra il disegno del pezzo")
	ob.add_item("al posto del disegno (solo l'immagine)")
	ob.selected = 1 if str(im.get("modo", "sopra")) == "sostituisce" else 0
	ob.item_selected.connect(func(i): cmd.call({"modo": ["sopra", "sostituisce"][i]}))
	_pannello.add_child(ob)
	_etichetta("Larghezza e altezza (mm)")
	var r1 := HBoxContainer.new()
	_pannello.add_child(r1)
	var dim: Vector2 = im.get("dim", Vector2(40, 40))
	var w := _numero(r1, dim.x, 1, 2000, 0.5)
	var h := _numero(r1, dim.y, 1, 2000, 0.5)
	var prop := dim.y / maxf(dim.x, 0.01)
	var lega := CheckBox.new()
	lega.text = "Mantieni le proporzioni"
	lega.button_pressed = true
	w.value_changed.connect(func(n):
		if lega.button_pressed:
			h.set_value_no_signal(n * prop)
		cmd.call({"dim": [n, h.value]}, false))
	h.value_changed.connect(func(n):
		if lega.button_pressed:
			w.set_value_no_signal(n / prop)
		cmd.call({"dim": [w.value, n]}, false))
	_pannello.add_child(lega)
	_etichetta("Spostamento dal centro (mm)")
	var r2 := HBoxContainer.new()
	_pannello.add_child(r2)
	var pos: Vector2 = im.get("pos", Vector2.ZERO)
	var px := _numero(r2, pos.x, -500, 500, 0.5)
	var py := _numero(r2, pos.y, -500, 500, 0.5)
	px.value_changed.connect(func(n): cmd.call({"pos": [n, py.value]}, false))
	py.value_changed.connect(func(n): cmd.call({"pos": [px.value, n]}, false))
	_etichetta("Rotazione dell'immagine (gradi)")
	var ro := _numero(_pannello, rad_to_deg(float(im.get("rot", 0.0))), -360, 360, 1.0)
	ro.value_changed.connect(func(n): cmd.call({"rot": n}, false))
	var togli := _bottone(_pannello, "Togli immagine", func(): cmd.call({"togli": true}), "Il pezzo torna col suo disegno")
	togli.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))

func _scegli_immagine(id: String) -> void:
	_scegli_file("Scegli l'immagine per il pezzo", func(f): _avviso(progetto.esegui({"comando": "immagine", "id": id, "file": f})["messaggio"]))

## Finestra per scegliere un'immagine dal disco (parte dalla cartella dell'editor); `fatto` riceve il percorso.
func _scegli_file(titolo: String, fatto: Callable, filtro := "*.png, *.jpg, *.jpeg, *.webp ; Immagini") -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray([filtro])
	fd.title = titolo
	fd.use_native_dialog = true
	fd.current_dir = cartella_progetti().get_base_dir()
	fd.file_selected.connect(func(f):
		fatto.call(f)
		_ricostruisci_pannello = true
		_aggiorna_pannello.call_deferred()
		fd.queue_free())
	fd.canceled.connect(func(): fd.queue_free())
	add_child(fd)
	fd.popup_centered_ratio(0.7)

func _titolo_pannello(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 18)
	_pannello.add_child(l)

func _etichetta(testo: String) -> void:
	var l := Label.new()
	l.text = testo
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	_pannello.add_child(l)

func _campo(f: Dictionary, v) -> void:
	var nome := str(f["nome"]) + (" (%s)" % f["unita"] if f.has("unita") and f["tipo"] != "angolo" else "")
	var k: String = f["k"]
	match str(f["tipo"]):
		"vec":
			_etichetta(nome)
			var riga := HBoxContainer.new()
			_pannello.add_child(riga)
			var vv: Vector2 = v if v is Vector2 else Vector2.ZERO
			var x := _numero(riga, vv.x, -2000, 3000, 0.5)
			var y := _numero(riga, vv.y, -2000, 3000, 0.5)
			x.value_changed.connect(func(n): _imposta(k, Vector2(n, y.value)))
			y.value_changed.connect(func(n): _imposta(k, Vector2(x.value, n)))
		"num", "int":
			_etichetta(nome)
			var sb := _numero(_pannello, float(v), float(f.get("min", 0.0)), float(f.get("max", 10000.0)), 1.0 if f["tipo"] == "int" else 0.5)
			sb.value_changed.connect(func(n): _imposta(k, n))
		"angolo":
			_etichetta(nome + " (gradi)")
			var sa := _numero(_pannello, rad_to_deg(float(v)), -360, 360, 1.0)
			sa.value_changed.connect(func(n): _imposta(k, deg_to_rad(n)))
		"bool":
			var cb := CheckBox.new()
			cb.text = nome
			cb.button_pressed = bool(v)
			cb.toggled.connect(func(n): _imposta(k, n))
			_pannello.add_child(cb)
		"testo":
			_campo_testo(nome, str(v), func(n): _imposta(k, n))
		"scelta":
			_etichetta(nome)
			var ob := OptionButton.new()
			var opz: Array = f["opzioni"]
			var val: Array = f.get("valori", opz)
			for o in opz:
				ob.add_item(str(o))
			var idx := 0
			for i in val.size():
				if str(val[i]) == str(v):
					idx = i
			ob.selected = idx
			var ric := bool(f.get("ricostruisci", false))
			ob.item_selected.connect(func(i): _imposta(k, val[i], ric))
			_pannello.add_child(ob)
		"colore":
			_etichetta(nome)
			var cpb := ColorPickerButton.new()
			cpb.color = v if v is Color else Color.WHITE
			cpb.custom_minimum_size = Vector2(0, 28)
			# v0.5: si applica quando si chiude la tavolozza (un solo passo di «annulla», non uno per ogni movimento)
			_al_chiudere(cpb, func(c: Color): _imposta(k, c, true))
			_pannello.add_child(cpb)

## Tavolozza dei colori: il colore si applica DOPO che la sua finestra si è chiusa del tutto (call_deferred). Prima si
## applicava subito e il pannello, ricostruito, cancellava il pulsante mentre chiudeva la finestra: il programma si
func _al_chiudere(cpb: ColorPickerButton, f: Callable) -> void:
	cpb.popup_closed.connect(func():
		var c := cpb.color
		f.call_deferred(c))

func _numero(dove: Control, v: float, a: float, b: float, passo: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = a
	sb.max_value = b
	sb.step = passo
	sb.value = v
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.select_all_on_focus = true
	dove.add_child(sb)
	return sb

func _campo_testo(nome: String, v: String, f: Callable) -> void:
	_etichetta(nome)
	var le := LineEdit.new()
	le.text = v
	le.text_submitted.connect(func(n): f.call(n))
	le.focus_exited.connect(func(): if le.text != v: f.call(le.text))
	_pannello.add_child(le)

func _imposta(campo: String, valore, ricostruisci := false) -> void:
	var id := vista.selezionato
	var r := progetto.esegui({"comando": "imposta", "id": id, "campo": campo, "valore": valore})
	if campo == "id" and r.get("ok", false):
		vista.selezionato = str(valore)
	_avviso(r["messaggio"])
	if ricostruisci or not r.get("ok", false):
		_ricostruisci_pannello = true
		_aggiorna_pannello.call_deferred()

# ================================================================ comandi della barra
func _comando(c: Dictionary, seleziona_nuovo := false) -> void:
	var r := progetto.esegui(c)
	_avviso(r["messaggio"])
	if seleziona_nuovo and r.has("id"):
		vista.seleziona(r["id"])
	if c["comando"] in ["annulla", "ripristina"]:
		if progetto.trova(vista.selezionato).is_empty():
			vista.seleziona("")
		_ricostruisci_pannello = true
		_aggiorna_pannello()

## NUOVO (v0.2): finestra con 1) la FORMA e 2) il TAVOLO PRONTO, ognuno con il disegno in piccolo.
func _nuovo() -> void:
	vista.chiudi_disegno()
	var dlg := ConfirmationDialog.new()
	dlg.title = "Nuovo tavolo"
	dlg.ok_button_text = "Crea il tavolo"
	dlg.cancel_button_text = "Annulla"
	var col := VBoxContainer.new()
	dlg.add_child(col)
	var scelta := {"forma": "classica", "modello": "base"}
	var l1 := Label.new()
	l1.text = "1. Scegli la FORMA del tavolo"
	col.add_child(l1)
	var r1 := HBoxContainer.new()
	col.add_child(r1)
	var b_forme: Array = []
	for nome in FormaTavolo.FORME:
		var f: Dictionary = FormaTavolo.FORME[nome]
		var b := IconeEditor.AnteprimaTavolo.new(LayoutBase.descrizione(nome), str(f["nome"]).split(" ")[0], Vector2(105, 185))
		b.tooltip_text = "%s: %s" % [f["nome"], f["testo"]]
		b.button_pressed = nome == "classica"
		b_forme.append(b)
		r1.add_child(b)
	var l2 := Label.new()
	l2.text = "2. Scegli un TAVOLO PRONTO (o «Solo zona bassa» per partire da zero)"
	col.add_child(l2)
	var r2 := HBoxContainer.new()
	col.add_child(r2)
	var b_modelli: Array = []
	var pronti := ProgettoEditor.tavoli_pronti()
	for m in pronti:
		var dm: Dictionary = LayoutBase.descrizione("classica") if m["id"] == "base" else FileTavolo.leggi(ProgettoEditor.CARTELLA_MODELLI + m["id"] + ".tavolo")
		var b2 := IconeEditor.AnteprimaTavolo.new(dm, str(m["nome"]).replace("Z Space Esempio", "Space"), Vector2(120, 200))
		b2.tooltip_text = "%s: %s" % [m["nome"], m["testo"]]
		b2.button_pressed = m["id"] == "base"
		b_modelli.append(b2)
		r2.add_child(b2)
	var nota := Label.new()
	nota.text = "Forma «Classica» + «Solo zona bassa» = tavolo vuoto come prima. Il tavolo Space è una copia d'esempio con la sua forma."
	nota.add_theme_font_size_override("font_size", 12)
	col.add_child(nota)
	for i in b_forme.size():
		b_forme[i].pressed.connect(func():
			scelta["forma"] = FormaTavolo.FORME.keys()[i]
			for j in b_forme.size():
				b_forme[j].button_pressed = j == i
				b_forme[j].queue_redraw())
	for i in b_modelli.size():
		b_modelli[i].pressed.connect(func():
			scelta["modello"] = pronti[i]["id"]
			for j in b_modelli.size():
				b_modelli[j].button_pressed = j == i
				b_modelli[j].queue_redraw())
	dlg.confirmed.connect(func():
		var modello: String = scelta["modello"]
		var nome := "Nuovo tavolo" if modello == "base" else str(pronti.filter(func(x): return x["id"] == modello)[0]["nome"])
		var r := progetto.esegui({"comando": "nuovo", "modello": modello, "nome": nome, "forma": scelta["forma"]})
		vista.seleziona("")
		vista.problemi.clear()
		_mostra_problemi()
		vista.adatta()
		_ricostruisci_pannello = true
		_aggiorna_pannello()
		_avviso(r["messaggio"] + ". Ricordati di SALVARE CON NOME.")
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()

func _salva() -> void:
	vista.chiudi_disegno()
	if progetto.cartella == "":
		_salva_con_nome()
		return
	var r := progetto.esegui({"comando": "salva", "cartella": progetto.cartella})
	_avviso(r["messaggio"])
	_ricorda_ultimo()

## Apri: elenco dei tavoli nella cartella «progetti» (doppio clic o Apri). «Altra cartella…» per cercarne uno altrove.
func _importa_flipper(f: String) -> void:
	vista.chiudi_disegno()
	var r := progetto.esegui({"comando": "importa_flipper", "file": f})
	if r.get("ok", false):
		vista.seleziona("")
		vista.problemi.clear()
		_mostra_problemi()
		vista.adatta()
		_ricostruisci_pannello = true
		_aggiorna_pannello()
	_avviso(r["messaggio"])

func _apri_elenco() -> void:
	vista.chiudi_disegno()
	var dlg := ConfirmationDialog.new()
	dlg.title = "Apri un tavolo"
	dlg.ok_button_text = "Apri"
	dlg.cancel_button_text = "Annulla"
	var box := VBoxContainer.new()
	var lista := ItemList.new()
	lista.custom_minimum_size = Vector2(420, 280)
	var nomi: Array = []
	for d in DirAccess.get_directories_at(cartella_progetti()):
		if d.ends_with(".pinproj"):
			nomi.append(d)
	nomi.sort()
	for n in nomi:
		lista.add_item(str(n).trim_suffix(".pinproj").replace("_", " "))
	if nomi.is_empty():
		lista.add_item("(nessun tavolo salvato)")
	else:
		lista.select(0)
	box.add_child(lista)
	var altra := Button.new()
	altra.text = "Altra cartella…"
	box.add_child(altra)
	dlg.add_child(box)
	add_child(dlg)
	var apri := func():
		var sel := lista.get_selected_items()
		if not nomi.is_empty() and not sel.is_empty():
			_scopo_dialogo = "apri"
			_su_cartella_scelta(cartella_progetti().path_join(str(nomi[sel[0]])))
		dlg.queue_free()
	dlg.confirmed.connect(apri)
	lista.item_activated.connect(func(_i): apri.call())
	dlg.canceled.connect(dlg.queue_free)
	altra.pressed.connect(func(): dlg.queue_free(); _apri_dialogo("apri"))
	dlg.popup_centered()

## Salva con nome: si scrive solo il nome; il progetto va in progetti/<Nome>.pinproj (niente cartelle da cercare).
func _salva_con_nome() -> void:
	vista.chiudi_disegno()
	var dlg := ConfirmationDialog.new()
	dlg.title = "Salva con nome"
	dlg.ok_button_text = "Salva"
	dlg.cancel_button_text = "Annulla"
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = "Nome del tavolo (es. Vulcano):"
	box.add_child(l)
	var le := LineEdit.new()
	le.text = str(progetto.desc.get("titolo", "Nuovo tavolo")).capitalize()
	le.custom_minimum_size = Vector2(360, 0)
	box.add_child(le)
	dlg.add_child(box)
	add_child(dlg)
	dlg.register_text_enter(le)
	dlg.confirmed.connect(func():
		var nome := le.text.strip_edges()
		var cartella_nome := nome.validate_filename().replace(" ", "_")
		if cartella_nome == "":
			_avviso("Scrivi un nome")
			return
		var dest := cartella_progetti().path_join(cartella_nome + ".pinproj")
		if DirAccess.dir_exists_absolute(dest) and dest != progetto.cartella:
			_avviso("Esiste già un tavolo «%s»: scegli un altro nome (non lo sovrascrivo)." % nome)
			return
		progetto.desc["titolo"] = nome.to_upper()
		progetto.desc["nome"] = cartella_nome.to_lower()
		var r := progetto.esegui({"comando": "salva", "cartella": dest})
		_avviso(r["messaggio"])
		_ricorda_ultimo()
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered()
	le.grab_focus()
	le.select_all()

func _apri_dialogo(scopo: String) -> void:
	_scopo_dialogo = scopo
	_dialogo.current_dir = cartella_progetti()
	if scopo == "apri":
		_dialogo.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialogo.title = "Apri un progetto: scegli la cartella .pinproj"
	else:
		_dialogo.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialogo.title = "Salva con nome: entra in «progetti», scrivi il nome della cartella nuova o scegline una"
	_dialogo.popup_centered()

func _su_cartella_scelta(dir: String) -> void:
	if _scopo_dialogo == "apri":
		var r := progetto.esegui({"comando": "apri", "cartella": dir})
		_avviso(r["messaggio"])
		if r.get("ok", false):
			vista.seleziona("")
			vista.problemi.clear()
			vista.adatta()
			_ricorda_ultimo()
	else:
		var dest := dir
		if not dest.ends_with(".pinproj"):
			dest = dir.path_join(str(progetto.desc.get("nome", "tavolo")) + ".pinproj")
		var r2 := progetto.esegui({"comando": "salva", "cartella": dest})
		_avviso(r2["messaggio"])
		_ricorda_ultimo()

func _cambia_modalita() -> void:
	pro = not pro
	_b_modalita.text = "Modalità: " + ("PRO" if pro else "SEMPLICE")
	_costruisci_libreria()
	_ricostruisci_pannello = true
	_aggiorna_pannello()

# ================================================================ GIOCA e CONTROLLA
# ================================================================ RENDERIZZA (v0.6)
## Salva il disegno finito in PNG nella cartella «renderizzati» del progetto: ogni pezzo da solo (6 px per mm, al
## massimo 2048 px) e, per tutto il tavolo, anche il tavolo intero (lo disegna il gioco con --prerendi: le stesse
## immagini che userà l'esportazione). Servono per vederle, ritoccarle o rimetterle come immagine propria.
func _renderizza(solo_scelto: bool) -> void:
	vista.chiudi_disegno()
	if progetto.cartella == "":
		_avviso("Prima salva il tavolo (Salva con nome): le immagini vanno nella sua cartella.")
		return
	var out := progetto.cartella.path_join("renderizzati")
	DirAccess.make_dir_recursive_absolute(out)
	var pezzi: Array = []                    # [chiave, pezzo]
	if solo_scelto:
		var t := progetto.trova(vista.selezionato) if vista.selezionato != "" else []
		if t.is_empty() or not (t[0] in PittorePezzi.TIPI or t[0] == "nastri"):
			_avviso("Scegli prima un pezzo (bumper, fionda, muro, nastro…).")
			return
		pezzi.append([t[0], progetto.desc[t[0]][t[1]]])
	else:
		for k in PittorePezzi.TIPI + ["nastri"]:
			for e in progetto.desc.get(k, []):
				if not e.has("da_nastro"):
					pezzi.append([k, e])
	_avviso("RENDERIZZA: preparo %d immagini…" % pezzi.size())
	var fatti := 0
	for v in pezzi:
		var img: Image = await rendi_pezzo(v[0], v[1], progetto.desc)
		if img and img.save_png(out.path_join(str(v[1]["id"]).validate_filename() + ".png")) == OK:
			fatti += 1
	var msg := "RENDERIZZA: %d immagini salvate in %s" % [fatti, out]
	if not solo_scelto:
		var f := _file_prova()
		progetto.salva_prova(f)
		var args := ["--path", ProjectSettings.globalize_path("res://"), "res://scenes/main.tscn", "--", "--tavolo_file=" + f, "--prerendi", "--rendi_in=" + out]
		OS.create_process(OS.get_executable_path(), args)
		msg += ". Il tavolo intero («tavolo_intero.png») lo disegna il gioco: si apre una finestra che si chiude da sola."
	_avviso(msg)

## Un pezzo da solo in un'immagine con lo sfondo trasparente (anche cima, ombra e immagine propria).
func rendi_pezzo(chiave: String, e: Dictionary, desc: Dictionary, px_mm := 6.0) -> Image:
	var r := riquadro_pezzo(chiave, e, desc)
	var k := minf(px_mm, 2048.0 / maxf(r.size.x, r.size.y))
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(r.size.x * k), ceili(r.size.y * k))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var n := Node2D.new()
	n.scale = Vector2(k, k)
	n.position = -r.position * k
	n.draw.connect(func():
		if chiave == "nastri":
			CurveEditor.disegna_nastro(n, e, func(q): return q, 1.0)
		else:
			PittorePezzi.disegna(n, chiave, e, desc)
			if chiave == "muri":
				PittorePezzi.gomme_tratti(n, e, PittorePezzi.piatto(e, desc)))
	vp.add_child(n)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img

## Riquadro (mm) che contiene tutto il disegno del pezzo: forma, cima alzata, ombra e immagine propria.
static func riquadro_pezzo(chiave: String, e: Dictionary, desc: Dictionary) -> Rect2:
	var r: Rect2
	var pts: Array = []
	match chiave:
		"palette":
			var L := float(e["lunghezza"])
			r = Rect2(Vector2(e["perno"]) - Vector2(L + 15, L + 15), Vector2(L + 15, L + 15) * 2.0)
		"nastri":
			pts = Array(CurveEditor.espandi_nastro(e)[0])
		_:
			pts = Array(e.get("punti", []))
	if not pts.is_empty():
		r = Rect2(Vector2(pts[0].x, pts[0].y), Vector2.ZERO)
		for q in pts:
			r = r.expand(Vector2(q.x, q.y))
		r = r.grow(60.0 if chiave == "nastri" else 12.0)
	elif chiave != "palette":
		var mp := PittorePezzi.misura_pezzo(chiave, e)
		var lato := maxf(mp.x, mp.y) + 20.0
		r = Rect2(Vector2(e["pos"]) - Vector2(lato, lato) * 0.5, Vector2(lato, lato))
	var h := 70.0 if chiave == "nastri" else PittorePezzi.altezza(chiave, e) + 4.0
	r = r.merge(Rect2(r.position + PittorePezzi.su(h), r.size))            # cima alzata
	r = r.merge(Rect2(r.position + PittorePezzi.OMBRA * h * 1.2, r.size))  # ombra
	if PittorePezzi.ha_immagine(e) and chiave != "palette":
		var im: Dictionary = e["immagine"]
		var c: Vector2 = PittorePezzi.ancora(chiave, e, desc) + Vector2(im.get("pos", Vector2.ZERO))
		var mezza := Vector2.ONE * Vector2(im.get("dim", Vector2(40, 40))).length() * 0.5
		r = r.merge(Rect2(c - mezza, mezza * 2.0))
	return r

func _file_prova() -> String:
	var dir := ProjectSettings.globalize_path("user://prove")
	DirAccess.make_dir_recursive_absolute(dir)
	return dir.path_join("prova.tavolo")

func _gioca() -> void:
	vista.chiudi_disegno()
	var f := _file_prova()
	if not progetto.salva_prova(f):
		_avviso("Non riesco a preparare la prova")
		return
	var args := ["--path", ProjectSettings.globalize_path("res://"), "res://scenes/main.tscn", "--", "--tavolo_file=" + f, "--finestra"]
	var pid := OS.create_process(OS.get_executable_path(), args)
	_avviso("GIOCA: si apre la finestra del gioco. Invio = start, Z/M o frecce = palette, Spazio = lancio, Esc = menu. Chiudi la finestra per tornare qui." if pid > 0 else "Non riesco ad avviare il gioco")

var _thread_misura: Thread
func _misura_velocita() -> void:
	if _thread_misura != null and _thread_misura.is_alive():
		_avviso("La misura è già in corso…")
		return
	if _thread_misura != null:
		_thread_misura.wait_to_finish()
	var f := _file_prova()
	if not progetto.salva_prova(f):
		_avviso("Non riesco a preparare la prova")
		return
	var rap := ProjectSettings.globalize_path("user://prove/misura_velocita.txt")
	_avviso("⏱ Misura in corso: si apre il gioco e gioca da solo per circa 30 secondi. Non chiudere la finestra.")
	var args := ["--path", ProjectSettings.globalize_path("res://"), "res://scenes/main.tscn", "--", "--tavolo_file=" + f, "--finestra", "--velocita=12", "--rapporto=" + rap]
	_thread_misura = Thread.new()
	_thread_misura.start(func():
		var out: Array = []
		OS.execute(OS.get_executable_path(), args, out, true)
		_fine_misura.call_deferred(rap))

func _fine_misura(rap: String) -> void:
	if _thread_misura != null:
		_thread_misura.wait_to_finish()
	if not FileAccess.file_exists(rap):
		_avviso("Misura non riuscita (la finestra è stata chiusa prima della fine?)")
		return
	var testo := FileAccess.get_file_as_string(rap)
	if progetto.cartella != "":
		DirAccess.copy_absolute(rap, progetto.cartella.path_join("misura_velocita.txt"))
	var ad := AcceptDialog.new()
	ad.title = "⏱ Misura della velocità"
	ad.dialog_text = testo + ("\n(Salvata anche nella cartella del tavolo: misura_velocita.txt)" if progetto.cartella != "" else "")
	add_child(ad)
	ad.confirmed.connect(func(): ad.queue_free())
	ad.popup_centered()
	_avviso("Misura finita: " + testo.get_slice("GIUDIZIO: ", 1).get_slice("  ", 0))

# ================================================================ 🪄 PRIMO FLIPPER: procedura guidata (v0.25)
## 5 passi (forma, tema, pezzi, missioni, nome) → un tavolo giocabile, controllato e sistemato da solo.
const PEZZI_GUIDATI := [
	["corsie_3", "3 corsie in alto (cambio corsia con le palette)", Vector2(300, 150), true],
	["bumper_3", "Triangolo di 3 bumper", Vector2(300, 330), true],
	["abbattibili_3", "Fila di 3 bersagli abbattibili", Vector2(150, 600), true, 20.0],   # inclinata: niente «mensola»
	["bersagli_buca", "Buca con 3 bersagli dietro", Vector2(470, 640), true],
	["spinner_corsia", "Spinner in una corsia", Vector2(160, 420), false],
	["scoop", "Scoop (prende e risputa la pallina)", Vector2(480, 420), false],
]

## Colore della scritta di un tema che si legga sul suo piano (secondario, o primario se il secondario è troppo simile).
static func _colore_leggibile(te: Dictionary) -> Color:
	var piano: Color = te["piano"]
	var sec: Color = te["secondario"]
	return sec if absf(sec.get_luminance() - piano.get_luminance()) > 0.3 else Color(te["primario"])

func _procedura_guidata() -> void:
	vista.chiudi_disegno()
	var scelta := {"forma": "classica", "tema": "spazio", "pezzi": {}, "missioni": true, "segreti": true, "classifica": true, "nome": "Il mio flipper"}
	for pz in PEZZI_GUIDATI:
		scelta["pezzi"][pz[0]] = pz[3]
	var w := AcceptDialog.new()
	w.title = "🪄 Il mio primo flipper"
	w.ok_button_text = "Avanti ▶"
	w.dialog_hide_on_ok = false
	var indietro := w.add_button("◀ Indietro", true, "indietro")
	var corpo := VBoxContainer.new()
	corpo.custom_minimum_size = Vector2(760, 440)
	w.add_child(corpo)
	var passo := [0]
	var mostra := func(): pass
	mostra = func():
		for c in corpo.get_children():
			c.queue_free()
		var t := Label.new()
		t.add_theme_font_size_override("font_size", 20)
		corpo.add_child(t)
		var spieg := Label.new()
		spieg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spieg.custom_minimum_size = Vector2(740, 0)     # (senza larghezza un testo a capo diventa altissimo)
		corpo.add_child(spieg)
		indietro.visible = passo[0] > 0
		w.ok_button_text = "Crea il mio flipper ✔" if passo[0] == 4 else "Avanti ▶"
		match passo[0]:
			0:
				t.text = "1 di 5 · La FORMA del tavolo"
				spieg.text = "Clicca la forma che ti piace. (Si cambia anche dopo.)"
				var r := HBoxContainer.new()
				corpo.add_child(r)
				for nome in FormaTavolo.FORME:
					var f: Dictionary = FormaTavolo.FORME[nome]
					var b := IconeEditor.AnteprimaTavolo.new(LayoutBase.descrizione(nome), str(f["nome"]).split(" ")[0], Vector2(120, 210))
					b.tooltip_text = str(f["testo"])
					b.button_pressed = scelta["forma"] == nome
					var n: String = nome
					b.pressed.connect(func(): scelta["forma"] = n; mostra.call())
					r.add_child(b)
			1:
				t.text = "2 di 5 · Il TEMA (colori, luce, font)"
				spieg.text = "Colori del tavolo e del menu già intonati. Si cambiano anche dopo da 🎨 Aspetto."
				var g := GridContainer.new()
				g.columns = 3
				corpo.add_child(g)
				for nome in ProgettoEditor.TEMI:
					var te: Dictionary = ProgettoEditor.TEMI[nome]
					var b := Button.new()
					b.text = "%s\n%s" % [te["nome"], te["testo"]]
					b.custom_minimum_size = Vector2(230, 70)
					b.toggle_mode = true
					b.button_pressed = scelta["tema"] == nome
					var sb := StyleBoxFlat.new()
					sb.bg_color = te["piano"]
					sb.border_color = te["primario"]
					sb.set_border_width_all(6 if scelta["tema"] == nome else 3)
					sb.set_corner_radius_all(8)
					b.add_theme_stylebox_override("normal", sb)
					b.add_theme_stylebox_override("pressed", sb)
					b.add_theme_stylebox_override("hover", sb)
					b.add_theme_color_override("font_color", _colore_leggibile(te))
					b.add_theme_color_override("font_pressed_color", _colore_leggibile(te))
					b.add_theme_color_override("font_hover_color", _colore_leggibile(te))
					var n: String = nome
					b.pressed.connect(func(): scelta["tema"] = n; mostra.call())
					g.add_child(b)
			2:
				t.text = "3 di 5 · I PEZZI sul tavolo"
				spieg.text = "Palette, fionde e lancio ci sono già. Scegli cosa aggiungere: l'editor li mette al posto giusto e poi controlla da solo che la pallina non si incastri."
				for pz in PEZZI_GUIDATI:
					var cb := CheckBox.new()
					cb.text = pz[1]
					cb.button_pressed = bool(scelta["pezzi"][pz[0]])
					var k: String = pz[0]
					cb.toggled.connect(func(v): scelta["pezzi"][k] = v)
					corpo.add_child(cb)
			3:
				t.text = "4 di 5 · MISSIONI e SFIDE"
				spieg.text = "Le missioni pronte usano i pezzi che hai scelto. Tutto si cambia dopo dalla scheda Missioni."
				for v in [["missioni", "Missioni pronte (una dopo l'altra, con la modalità finale)"], ["segreti", "Obiettivi segreti (si scoprono giocando)"], ["classifica", "Classifica dei 10 migliori con le iniziali"]]:
					var cb2 := CheckBox.new()
					cb2.text = v[1]
					cb2.button_pressed = bool(scelta[v[0]])
					var k2: String = v[0]
					cb2.toggled.connect(func(x): scelta[k2] = x)
					corpo.add_child(cb2)
			4:
				t.text = "5 di 5 · Il NOME del flipper"
				spieg.text = "Il nome va sul tabellone e nel menu del gioco. Poi premi «Crea il mio flipper»: alla fine puoi provarlo subito."
				var le := LineEdit.new()
				le.text = str(scelta["nome"])
				le.custom_minimum_size = Vector2(400, 0)
				le.text_changed.connect(func(v): scelta["nome"] = v)
				corpo.add_child(le)
	w.custom_action.connect(func(a):
		if a == "indietro" and passo[0] > 0:
			passo[0] -= 1
			mostra.call())
	w.confirmed.connect(func():
		if passo[0] < 4:
			passo[0] += 1
			mostra.call()
			return
		w.hide()
		w.queue_free()
		_crea_guidato(scelta))
	w.canceled.connect(func(): w.queue_free())
	add_child(w)
	mostra.call()
	w.popup_centered(Vector2i(800, 560))

func _crea_guidato(sc: Dictionary) -> void:
	var nome := str(sc["nome"]).strip_edges()
	if nome == "":
		nome = "Il mio flipper"
	var r := progetto.esegui({"comando": "nuovo", "modello": "base", "nome": nome, "forma": sc["forma"]})
	if not r.get("ok", false):
		_avviso(r["messaggio"])
		return
	progetto.esegui({"comando": "tema", "nome": sc["tema"]})
	var n_pezzi := 0
	for pz in PEZZI_GUIDATI:
		if not bool(sc["pezzi"].get(pz[0], false)):
			continue
		var rp := progetto.esegui({"comando": "aggiungi_composto", "nome": pz[0], "pos": pz[2]})
		if rp.get("ok", false):
			n_pezzi += 1
			if pz.size() > 4 and rp.has("ids"):
				progetto.esegui({"comando": "gruppo", "ids": rp["ids"] + rp.get("luci", []), "azione": "ruota", "gradi": pz[4]})
	if bool(sc["missioni"]):
		progetto.esegui({"comando": "missioni_pacchetto"})
	if bool(sc["segreti"]):
		for m in progetto.modelli_segreti():
			if m["ok"]:
				progetto.esegui({"comando": "segreto_aggiungi", "modello": m["id"]})
	progetto.esegui({"comando": "classifica", "attiva": bool(sc["classifica"])})
	var rs := progetto.esegui({"comando": "sistema_varchi"})
	vista.seleziona("")
	vista.problemi = ControlliEditor.varchi(progetto.desc)
	_mostra_problemi()
	vista.adatta()
	_ricostruisci_pannello = true
	_aggiorna_pannello()
	var fine := ConfirmationDialog.new()
	fine.title = "🪄 «%s» è pronto!" % nome
	fine.dialog_text = "Forma, tema «%s», %d gruppi di pezzi, %d missioni, %d segreti.\nControllo della pallina: %s\n\nVuoi provarlo subito? (Ricordati poi di SALVARE CON NOME.)" % [
		ProgettoEditor.TEMI[sc["tema"]]["nome"], n_pezzi, progetto.desc.get("missioni", []).size(), progetto.desc.get("segreti", []).size(),
		"nessuno spazio pericoloso" if int(rs.get("restano", 0)) == 0 else "%d spazi da guardare (scheda Problemi)" % int(rs["restano"])]
	fine.ok_button_text = "▶ Gioca adesso"
	fine.cancel_button_text = "Lo modifico prima"
	fine.confirmed.connect(func(): fine.queue_free(); _gioca())
	fine.canceled.connect(func(): fine.queue_free())
	add_child(fine)
	fine.popup_centered()

# ================================================================ 🚀 RILASCIO UFFICIALE (v0.26): 7 passi
## Il pinball si distribuisce SEMPRE con il suo sorgente pubblico: informazioni, verifica delle risorse, licenze,
## repository pubblico (con il consenso esplicito), crediti, esportazione, verifica finale.
var _thread_rilascio: Thread
func _rilascio_guidato() -> void:
	vista.chiudi_disegno()
	if progetto.cartella == "" or progetto.modificato:
		_avviso("Prima salva il tavolo (Salva): si rilascia il tavolo salvato.")
		return
	var st := {"passo": 0, "dest": {}, "consenso": false, "note": "", "esito": {}}
	var w := AcceptDialog.new()
	w.title = "🚀 Rilascio ufficiale"
	w.dialog_hide_on_ok = false
	var indietro := w.add_button("◀ Indietro", true, "indietro")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(800, 470)
	w.add_child(sc)
	var corpo := VBoxContainer.new()
	corpo.custom_minimum_size = Vector2(780, 0)
	sc.add_child(corpo)
	var lab := func(t: String, grande := false) -> Label:
		var l := Label.new()
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(760, 0)
		if grande:
			l.add_theme_font_size_override("font_size", 20)
		corpo.add_child(l)
		return l
	var mostra := func(): pass
	mostra = func():
		for c in corpo.get_children():
			c.queue_free()
		var i := LicenzeProgetto.info(progetto.desc)
		indietro.visible = st["passo"] > 0 and st["passo"] < 6
		w.get_ok_button().visible = true
		w.ok_button_text = "Avanti ▶"
		match int(st["passo"]):
			0:
				lab.call("1 di 7 · Informazioni sul gioco", true)
				lab.call("Questi dati vanno nei crediti, nel README e nel repository del gioco.")
				for v in [["nome", "Nome del pinball"], ["autore", "Autore (chi lo ha creato)"], ["descrizione", "Descrizione (una o due frasi)"], ["versione", "Versione (es. 1.0.0)"]]:
					lab.call(v[1])
					var le := LineEdit.new()
					le.text = str(i[v[0]])
					var k: String = v[0]
					le.text_changed.connect(func(x): progetto.esegui({"comando": "gioco_info", k: x}))
					corpo.add_child(le)
			1:
				lab.call("2 di 7 · Verifica delle risorse", true)
				var vr := LicenzeProgetto.verifica(progetto)
				for r in LicenzeProgetto.risorse(progetto):
					lab.call("%s %s — %s · autore: %s" % ["✔" if r["libera"] else "✖", r["nome"], r["licenza"], r["autore"] if r["autore"] != "" else "?"])
				if LicenzeProgetto.risorse(progetto).is_empty():
					lab.call("Il tavolo non usa immagini, musiche o font esterni: solo i suoni e i font liberi dell'editor (CC0, OFL).")
				for t in vr["problemi"]:
					lab.call("✖ " + t).add_theme_color_override("font_color", Color(1, 0.5, 0.45))
				for t in vr["avvisi"]:
					lab.call("⚠ " + t).add_theme_color_override("font_color", Color(1, 0.8, 0.4))
				if not vr["ok"]:
					lab.call("Sistema i punti in rosso (📜 LICENZE nelle proprietà del tavolo, o il passo 1) e riapri il rilascio.")
					w.get_ok_button().visible = false
			2:
				lab.call("3 di 7 · Licenze", true)
				lab.call("• CODICE del gioco: %s.\n• CONTENUTI originali (grafica, musica, testi, disegno del tavolo): %s.\n• Risorse di terzi: ognuna con la sua licenza (elenco nel LICENSE_MANIFEST.json).\n\nChiunque potrà giocarlo, studiarlo, modificarlo, ridistribuirlo e VENDERLO (anche modificato, anche in un cabinato), alle stesse condizioni e citando gli autori. Anche tu puoi venderlo: il prezzo lo decidi tu, ma chi lo compra mantiene questi diritti e può avere il sorgente." % [LicenzeProgetto.LICENZE["GPL-3.0-or-later"]["nome"], LicenzeProgetto.LICENZE["CC-BY-SA-4.0"]["nome"]])
			3:
				lab.call("4 di 7 · Repository pubblico", true)
				lab.call("Il sorgente completo del gioco va in un repository PUBBLICO, scaricabile gratis da chiunque.")
				var g := Rilascio.stato_github()
				lab.call(("✔ " if g["pronto"] else "✖ ") + str(g["messaggio"]))
				if g["pronto"]:
					lab.call("Nome del repository su GitHub (utente %s):" % g["utente"])
					var le2 := LineEdit.new()
					le2.text = str(st["dest"].get("repo", LicenzeProgetto.slug(i["nome"])))
					st["dest"] = {"tipo": "github", "utente": g["utente"], "repo": le2.text, "descrizione": i["descrizione"]}
					le2.text_changed.connect(func(x): st["dest"]["repo"] = LicenzeProgetto.slug(x))
					corpo.add_child(le2)
				else:
					_bottone(corpo, "Ricontrolla GitHub", func(): mostra.call(), "Dopo «gh auth login»")
				var cb := CheckBox.new()
				cb.text = "Autorizzo la pubblicazione PUBBLICA del sorgente di questo pinball (tutti potranno vederlo e scaricarlo)."
				cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				cb.custom_minimum_size = Vector2(760, 0)
				cb.button_pressed = bool(st["consenso"])
				cb.toggled.connect(func(x): st["consenso"] = x)
				corpo.add_child(cb)
			4:
				lab.call("5 di 7 · Crediti", true)
				lab.call("Collaboratori (separati da virgola, facoltativo):")
				var lc := LineEdit.new()
				lc.text = ", ".join(i["collaboratori"])
				lc.text_changed.connect(func(x): progetto.esegui({"comando": "gioco_info", "collaboratori": x}))
				corpo.add_child(lc)
				lab.call("Cosa c'è di nuovo in questa versione (va nel CHANGELOG):")
				var ln := LineEdit.new()
				ln.text = str(st["note"])
				ln.text_changed.connect(func(x): st["note"] = x)
				corpo.add_child(ln)
				lab.call("\n" + LicenzeProgetto.credits_md(progetto).left(1500))
			5:
				lab.call("6 di 7 · Esportazione", true)
				if not bool(st["consenso"]) or st["dest"].is_empty():
					lab.call("✖ Manca il repository o il consenso alla pubblicazione (passo 4).")
					w.get_ok_button().visible = false
				elif not Esportazione.modelli_presenti():
					lab.call("✖ Mancano i modelli di esportazione di Godot (servono per compilare il gioco).")
					_bottone(corpo, "⬇ Installa i modelli di esportazione", func(): _installa_modelli(), "Una volta sola, dal sito ufficiale di Godot")
					w.get_ok_button().visible = false
				else:
					lab.call("Premendo «Rilascia» l'editor: prepara il sorgente completo, lo pubblica in %s, controlla che sia pubblico, compila il gioco DA QUEL sorgente e prepara il pacchetto con licenze, crediti e istruzioni. Ci vogliono alcuni minuti." % ("https://github.com/%s/%s" % [st["dest"].get("utente", ""), st["dest"].get("repo", "")]))
					lab.call("Versioni del gioco da mettere nel pacchetto:")
					if not st.has("piattaforme"):
						st["piattaforme"] = Rilascio.PIATTAFORME_PREDEFINITE.filter(func(x): return x != "android")   # Android: spunta + conferma
					for k in Rilascio.PIATTAFORME_RILASCIO:
						var cbp := CheckBox.new()
						cbp.text = str(Rilascio.PIATTAFORME_RILASCIO[k]["nome"])
						cbp.button_pressed = k in st["piattaforme"]
						var kp: String = k
						cbp.toggled.connect(func(x):
							if x and not kp in st["piattaforme"]:
								st["piattaforme"].append(kp)
							elif not x:
								st["piattaforme"].erase(kp)
							if kp == "android" and x:
								# regola: l'APK si crea solo con una conferma a parte
								var ca := ConfirmationDialog.new()
								ca.dialog_text = "Creo anche l'APK Android?\nÈ firmato con la chiave di PROVA: si installa sui telefoni, ma per Google Play serve la tua chiave personale (vedi BUILD_INSTRUCTIONS)."
								ca.ok_button_text = "Sì, crea l'APK"
								ca.confirmed.connect(func(): st["android_confermato"] = true; ca.queue_free())
								ca.canceled.connect(func(): st["android_confermato"] = false; st["piattaforme"].erase("android"); ca.queue_free(); mostra.call())
								add_child(ca)
								ca.popup_centered()
							elif kp == "android":
								st["android_confermato"] = false)
						corpo.add_child(cbp)
					w.ok_button_text = "🚀 Rilascia"
			6:
				lab.call("7 di 7 · Verifica finale", true)
				var e: Dictionary = st["esito"]
				if e.is_empty():
					lab.call("⏳ Rilascio in corso… (non chiudere l'editor)")
					w.get_ok_button().visible = false
				else:
					for ps in e.get("passi", []):
						lab.call("%s %s — %s" % ["✔" if ps[1] else "✖", ps[0], ps[2]])
					lab.call("\n" + ("✅ " if e["ok"] else "❌ ") + str(e["messaggio"]), true)
					w.ok_button_text = "Apri la cartella del pacchetto" if e.get("pacchetto", "") != "" else "Chiudi"
	w.custom_action.connect(func(a):
		if a == "indietro" and st["passo"] > 0:
			st["passo"] -= 1
			mostra.call())
	w.confirmed.connect(func():
		if int(st["passo"]) == 6:
			if str(st["esito"].get("pacchetto", "")) != "":
				OS.shell_show_in_file_manager(str(st["esito"]["pacchetto"]).path_join("README.md"))
			w.queue_free()
			return
		if int(st["passo"]) == 5:
			progetto.esegui({"comando": "salva", "cartella": progetto.cartella})
			st["passo"] = 6
			mostra.call()
			if _thread_rilascio != null and _thread_rilascio.is_alive():
				return
			if _thread_rilascio != null:
				_thread_rilascio.wait_to_finish()
			var opz := {"consenso": st["consenso"], "dest": st["dest"], "note": st["note"],
				"piattaforme": st.get("piattaforme", Rilascio.PIATTAFORME_PREDEFINITE), "android_confermato": bool(st.get("android_confermato", false))}
			_thread_rilascio = Thread.new()
			_thread_rilascio.start(func():
				var r := Rilascio.rilascia(progetto, opz)
				(func():
					_thread_rilascio.wait_to_finish()
					st["esito"] = r
					_avviso(r["messaggio"])
					mostra.call()).call_deferred())
			return
		st["passo"] += 1
		mostra.call())
	w.canceled.connect(func(): w.queue_free())
	add_child(w)
	mostra.call()
	w.popup_centered(Vector2i(840, 580))

## v0.25 VIDEO PROMOZIONALE: il gioco si apre e gioca da solo 30 secondi; la finestra viene registrata (ffmpeg).
var _thread_video: Thread
func _video_promo() -> void:
	if _thread_video != null and _thread_video.is_alive():
		_avviso("Il video è già in registrazione…")
		return
	if _thread_video != null:
		_thread_video.wait_to_finish()
	var f := _file_prova()
	if not progetto.salva_prova(f):
		_avviso("Non riesco a preparare la prova")
		return
	var cart := progetto.cartella.path_join("video") if progetto.cartella != "" else ProjectSettings.globalize_path("user://video")
	DirAccess.make_dir_recursive_absolute(cart)
	var out := cart.path_join("promo_%s.mp4" % Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"))
	_avviso("🎬 Registro il video: si apre il gioco e gioca da solo per 30 secondi. Non coprire la finestra del gioco.")
	var args := ["--path", ProjectSettings.globalize_path("res://"), "res://scenes/main.tscn", "--", "--tavolo_file=" + f, "--finestra", "--registra=" + out, "--durata=30"]
	_thread_video = Thread.new()
	_thread_video.start(func():
		OS.execute(OS.get_executable_path(), args, [], true)
		OS.delay_msec(1500)
		_fine_video.call_deferred(out))

func _fine_video(out: String) -> void:
	if _thread_video != null:
		_thread_video.wait_to_finish()
	if FileAccess.file_exists(out) and FileAccess.open(out, FileAccess.READ).get_length() > 10000:
		_avviso("🎬 Video pronto: %s (senza audio: la musica si aggiunge al montaggio)" % out.get_file())
		OS.shell_show_in_file_manager(out)
	else:
		_avviso("Video NON riuscito: serve il programma ffmpeg e lo schermo del PC (X11)")

func _sistema_tu() -> void:
	vista.chiudi_disegno()
	var r := progetto.esegui({"comando": "sistema_varchi"})
	_avviso(r["messaggio"])
	vista.problemi = ControlliEditor.varchi(progetto.desc)
	_mostra_problemi()
	if r.has("ids") and not r["ids"].is_empty():
		vista.scegli_tutti(r["ids"])

func _controlla() -> void:
	vista.chiudi_disegno()
	if _thread != null and _thread.is_alive():
		_avviso("Il controllo è già in corso…")
		return
	vista.problemi = ControlliEditor.varchi(progetto.desc)
	vista.problemi.append_array(ControlliEditor.piatti(progetto.desc))
	vista.problemi.append_array(ControlliEditor.incroci(progetto.desc))
	# v0.18.1: tiri di riferimento rifatti sul tavolo di adesso
	for e in Tracciatore.verifica(progetto.desc):
		if not e["ok"]:
			vista.problemi.append({"tipo": "tiro", "livello": "potenziale", "pos": Vector2(-999, -999), "testo": "Tiro di riferimento " + str(e["testo"])})
	var pz := ControlliEditor.peso(progetto.desc, progetto.cartella)
	if pz["giudizio"] != "bene" or not pz["grandi"].is_empty():
		vista.problemi.append({"tipo": "peso", "livello": "avviso", "pos": Vector2(-999, -999), "testo": ControlliEditor.testo_peso(pz) + ("" if pz["grandi"].is_empty() else " · immagini oltre 2048 px: " + ", ".join(pz["grandi"]))})
	for t in progetto.avvisi_licenze():
		vista.problemi.append({"tipo": "licenza", "livello": "avviso", "pos": Vector2(-999, -999), "testo": t})
	for t in ModelliMissioni.controlla(progetto.desc):
		vista.problemi.append({"tipo": "missione", "livello": "avviso", "pos": Vector2(-999, -999), "testo": t})
	_mostra_problemi()
	var f := _file_prova()
	progetto.salva_prova(f)
	_b_controlla.disabled = true
	_avviso("CONTROLLA: varchi fatti (%d). Ora lancio %d palline per cercare gli incastri (circa %d secondi)…" % [vista.problemi.size(), _palline_controllo(), _palline_controllo() / 6])
	_thread = Thread.new()
	_thread.start(_caccia.bind(f, _palline_controllo()))

func _palline_controllo() -> int:
	return 300 if pro else 100

func _caccia(f: String, n: int) -> void:
	var out: Array = []
	OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"res://tools/caccia_incastri.tscn", "--", "--tavolo_file=" + f, "--palline=" + str(n)], out, true)
	_fine_caccia.call_deferred("\n".join(out))

func _fine_caccia(testo: String) -> void:
	_thread.wait_to_finish()
	_b_controlla.disabled = false
	var ferme := 0
	var fuori := -1
	for riga in testo.split("\n"):
		var p := riga.strip_edges().split(" ")
		if p.size() >= 3 and p[0] == "CACCIA_FERMA":
			ferme += 1
			var pos := Vector2(float(p[1]), float(p[2]))
			vista.problemi.append({"tipo": "incastro", "livello": "errore", "pos": pos,
				"testo": "Pallina FERMA a %.0f × %.0f mm per più di 2 secondi: qui si incastra." % [pos.x, pos.y]})
		elif p.size() >= 4 and p[0] == "CACCIA_INTERVENTO":
			var pos2 := Vector2(float(p[2]), float(p[3]))
			vista.problemi.append({"tipo": "sicurezza", "livello": "errore", "pos": pos2,
				"testo": "La sicurezza del motore ha dovuto spingere la pallina (%s) a %.0f × %.0f mm: zona da sistemare." % [p[1], pos2.x, pos2.y]})
		elif p.size() >= 4 and p[0] == "CACCIA_FINE":
			fuori = int(p[2])
	if fuori > 0:
		vista.problemi.append({"tipo": "fuori", "livello": "errore", "pos": Vector2(317, 20),
			"testo": "%d palline sono USCITE dal tavolo: c'è un buco nelle sponde." % fuori})
	_mostra_problemi()
	if fuori < 0:
		_avviso("La caccia agli incastri non è riuscita (il motore ha dato errore): prova GIOCA per vedere il problema.")
	else:
		var n_err := vista.problemi.filter(func(x): return x["livello"] == "errore").size()
		_avviso("CONTROLLA finito: %d da sistemare (rosso), %d da controllare (arancio)." % [n_err, vista.problemi.size() - n_err] if not vista.problemi.is_empty() else "CONTROLLA finito: nessun problema trovato. ✔")

func _mostra_problemi() -> void:
	_problemi.clear()
	for p in vista.problemi:
		var i := _problemi.add_item(("● " if p["livello"] == "errore" else "○ ") + str(p["testo"]))
		_problemi.set_item_custom_fg_color(i, Color(1, 0.45, 0.45) if p["livello"] == "errore" else Color(1, 0.75, 0.4))
	if vista.problemi.is_empty():
		_problemi.add_item("Nessun problema trovato.")
	vista.queue_redraw()

func _su_problema(i: int) -> void:
	if i < vista.problemi.size():
		var p: Dictionary = vista.problemi[i]
		if str(p.get("tipo", "")) == "missione":
			_avviso(str(p["testo"]) + "  (scheda Missioni)")
			return
		vista.evidenziato = p["pos"]
		vista.centra_su(p["pos"])
		_avviso(str(p["testo"]))

# ================================================================ aggiornamenti
func _su_cambiato() -> void:
	vista.queue_redraw()
	if vista.selezionato == "" or progetto.trova(vista.selezionato).is_empty():
		_ricostruisci_pannello = true
	_aggiorna_tutto()

func _aggiorna_tutto() -> void:
	_b_annulla.disabled = not progetto.si_puo_annullare()
	_b_ripristina.disabled = not progetto.si_puo_ripristinare()
	var nome := progetto.cartella.get_file() if progetto.cartella != "" else "(non salvato)"
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Pinball Editor 2D %s – %s%s" % [VERSIONE, nome, " *" if progetto.modificato else ""])
	_pezzi.clear()
	for e in progetto.elenco():
		var i := _pezzi.add_item("%s%s  (%s)  %s mm" % ["🔒 " if bool(progetto.pezzo(e["id"]).get("bloccato", false)) else "", e["id"], SchedeEditor.scheda(e["tipo"]).get("nome", e["tipo"]), e["pos"]])
		_pezzi.set_item_metadata(i, e["id"])
	_aggiorna_livelli()
	_aggiorna_missioni()
	if _schede != null and _schede.get_current_tab_control() != null and _schede.get_current_tab_control().name == "Suoni e luci":
		pass                         # la scheda aperta non si ricostruisce mentre si sceglie (resta il menu aperto)
	else:
		_aggiorna_regia()
	_aggiorna_pannello()

## Scheda LIVELLI: una riga per livello (0 = tavolo, poi i piani rialzati col loro nome).
## v0.21: riquadro d'aiuto con i passi (schede Missioni, Simulatore): si chiude e resta chiuso finché non riapri l'editor.
var _aiuti_chiusi := {}
func _box_aiuto(dove: Control, titolo: String, righe: Array) -> void:
	if _aiuti_chiusi.has(titolo):
		_bottone(dove, "❓ " + titolo.get_slice(" (", 0).get_slice(":", 0).capitalize(), func():
			_aiuti_chiusi.erase(titolo)
			_aggiorna_missioni()
			if _scheda_sim != null:
				_costruisci_sim(), "Riapre la spiegazione")
		return
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.2, 0.3)
	sb.border_color = Color(0.3, 0.7, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", sb)
	dove.add_child(pc)
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var rt := HBoxContainer.new()
	vb.add_child(rt)
	var t := Label.new()
	t.text = titolo
	t.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_child(t)
	_bottone(rt, "✕", func():
		_aiuti_chiusi[titolo] = true
		_aggiorna_missioni()
		if _scheda_sim != null:
			_costruisci_sim(), "Chiudi la spiegazione")
	for r in righe:
		var l := Label.new()
		l.text = str(r)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		vb.add_child(l)

func _aggiorna_livelli() -> void:
	if _livelli == null:
		return
	for c in _livelli.get_children():
		c.queue_free()
	if progetto.desc.is_empty():
		return
	# v0.21: spiegazione + «solo questo» + i pezzi di ogni livello (clic = scelto)
	var spieg := Label.new()
	spieg.text = "Livello 0 = il tavolo. Ogni PIANO RIALZATO è un livello in più: i pezzi messi DENTRO un piano salgono da soli sul suo livello.\n«Solo questo» nasconde gli altri livelli per lavorare comodo; «Bloccato» impedisce di spostare per sbaglio."
	spieg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_livelli.add_child(spieg)
	var tutti_liv := progetto.elenco_livelli()
	_bottone(_livelli, "👁 Mostra tutti i livelli", func():
		for x in tutti_liv:
			progetto.esegui({"comando": "livello_vista", "livello": int(x["livello"]), "nascosto": false})
		vista.queue_redraw()
		_aggiorna_livelli.call_deferred(), "Rende di nuovo visibili tutti i livelli")
	var per_livello := {}
	for v in progetto.elenco():
		if v["tipo"] == "piani" or str(v["id"]).contains("@"):
			continue
		var nl := ProgettoEditor.livello_di(v["tipo"], progetto.pezzo(v["id"]))
		if not per_livello.has(nl):
			per_livello[nl] = []
		per_livello[nl].append(str(v["id"]))
	for l in tutti_liv:
		_livelli.add_child(HSeparator.new())
		var riga := HBoxContainer.new()
		_livelli.add_child(riga)
		var n: int = l["livello"]
		_bottone(riga, "Solo questo", func():
			for x in tutti_liv:
				progetto.esegui({"comando": "livello_vista", "livello": int(x["livello"]), "nascosto": int(x["livello"]) != n})
			vista.seleziona("")
			vista.queue_redraw()
			_avviso("Si vede solo il livello %d (gli altri sono nascosti: «Mostra tutti» per rivederli)" % n)
			_aggiorna_livelli.call_deferred(), "Nasconde gli altri livelli")
		var occhio := CheckBox.new()
		occhio.text = "👁 Visibile"
		occhio.button_pressed = not bool(l["nascosto"])
		occhio.toggled.connect(func(v): _avviso(progetto.esegui({"comando": "livello_vista", "livello": n, "nascosto": not v})["messaggio"]); vista.queue_redraw())
		riga.add_child(occhio)
		var lucchetto := CheckBox.new()
		lucchetto.text = "🔒 Bloccato"
		lucchetto.button_pressed = bool(l["bloccato"])
		lucchetto.toggled.connect(func(v): _avviso(progetto.esegui({"comando": "livello_vista", "livello": n, "bloccato": v})["messaggio"]); vista.queue_redraw())
		riga.add_child(lucchetto)
		var et := Label.new()
		et.text = "  Livello %d – %s%s · %d pezzi" % [n, l["nome"], (" (%.0f mm)" % float(l["altezza"])) if n > 0 else "", int(l["pezzi"])]
		et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		riga.add_child(et)
		if str(l["piano"]) != "":
			var pid: String = l["piano"]
			_bottone(riga, "Rinomina / scegli", func(): vista.seleziona(pid), "Sceglie il piano: il nome si cambia a destra, in «Nome»")
		var flusso := HFlowContainer.new()
		_livelli.add_child(flusso)
		for pid2 in per_livello.get(n, []):
			var id_p: String = pid2
			_bottone(flusso, id_p, func(): vista.seleziona(id_p), "Sceglie «%s»" % id_p)
	# v0.16: gruppi con nome
	var gg := progetto.gruppi_editor()
	if not gg.is_empty():
		var tg := Label.new()
		tg.text = "GRUPPI:"
		_livelli.add_child(tg)
		for n in gg:
			var rgr := HBoxContainer.new()
			_livelli.add_child(rgr)
			var lg := Label.new()
			lg.text = "  %s · %d pezzi" % [n, gg[n].size()]
			lg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rgr.add_child(lg)
			var ids: Array = gg[n]
			_bottone(rgr, "Scegli", func(): vista.scegli_tutti(ids), "Sceglie tutti i pezzi del gruppo")

func _avviso(t: String) -> void:
	_stato.text = t
	_diario.append_text(Time.get_time_string_from_system() + "  " + t + "\n")

func _ricorda_ultimo() -> void:
	var c := ConfigFile.new()
	c.set_value("editor", "ultimo", progetto.cartella)
	c.save("user://editor.cfg")

func _ultimo_progetto() -> String:
	var c := ConfigFile.new()
	if c.load("user://editor.cfg") != OK:
		return ""
	return str(c.get_value("editor", "ultimo", ""))

# ================================================================ tastiera
func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is SpinBox:
		return
	var k: int = ev.keycode
	var ctrl: bool = ev.ctrl_pressed or ev.meta_pressed
	var scelti := not vista.selezionati.is_empty()
	if k == KEY_F1:
		_apri_guida("")
		return
	if ctrl and k == KEY_Z:
		_comando({"comando": "annulla"})
	elif ctrl and (k == KEY_Y or (k == KEY_Z and ev.shift_pressed)):
		_comando({"comando": "ripristina"})
	elif ctrl and k == KEY_S:
		_salva()
	elif ctrl and k == KEY_C and scelti:
		_appunti.clear()
		for sid in vista.selezionati:
			var t := progetto.trova(str(sid))
			if not t.is_empty():
				_appunti.append([t[0], progetto.desc[t[0]][t[1]].duplicate(true)])
		_avviso("Copiati %d pezzi: Ctrl+V per incollarli dove punti il mouse" % _appunti.size())
	elif ctrl and k == KEY_V:
		var r := progetto.esegui({"comando": "incolla", "pezzi": _appunti, "pos": vista._ultimo_mm})
		_avviso(r["messaggio"])
		if r.get("ok", false):
			vista.scegli_tutti(r["ids"])
	elif ctrl and k == KEY_A:
		var tutti: Array = progetto.elenco().map(func(x): return x["id"]).filter(func(i): return not bool(progetto.pezzo(i).get("bloccato", false)))
		vista.scegli_tutti(tutti)
	elif ctrl and k == KEY_D and scelti:
		_gruppo("duplica")
	elif ctrl and k == KEY_M and scelti:
		_gruppo("specchia")
	elif k == KEY_ESCAPE and vista.disegno_in_corso():
		vista.annulla_disegno()
		_avviso("Disegno annullato")
	elif k == KEY_ESCAPE:
		_scegli_pezzo("", null)
		vista.seleziona("")
	elif k in [KEY_ENTER, KEY_KP_ENTER] and vista.da_inserire in ["muri", "rampe", "nastri", "piani"]:
		vista.finisci_muro()
	elif scelti and k == KEY_DELETE:
		_gruppo("elimina")
	elif scelti and k == KEY_R:
		_gruppo("ruota", {"gradi": -15 if ev.shift_pressed else 15})
	elif scelti and k in [KEY_PLUS, KEY_KP_ADD, KEY_EQUAL]:
		_gruppo("scala", {"fattore": 1.1})
	elif scelti and k in [KEY_MINUS, KEY_KP_SUBTRACT]:
		_gruppo("scala", {"fattore": 1.0 / 1.1})
	elif scelti and k in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var passo := 10.0 if ev.shift_pressed else 1.0
		var di := {KEY_LEFT: Vector2(-passo, 0), KEY_RIGHT: Vector2(passo, 0), KEY_UP: Vector2(0, -passo), KEY_DOWN: Vector2(0, passo)}[k] as Vector2
		_gruppo("sposta", {"di": di})
	else:
		return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	if _thread_traccia != null and _thread_traccia.is_started():
		_thread_traccia.wait_to_finish()

# ================================================================ GUIDA (v0.18.2)
var _guida: GuidaEditor

func _apri_guida(argomento: String) -> void:
	if _guida == null:
		_guida = GuidaEditor.new()
		add_child(_guida)
	_guida.apri(argomento)

# ================================================================ SCHEMA DELLE MISSIONI (v0.18.3)
var _schema: Window

func _apri_schema() -> void:
	if _schema != null and is_instance_valid(_schema):
		_schema.queue_free()
	_schema = SchemaMissioni.finestra(progetto.desc.get("missioni", []) if progetto.desc.get("missioni") is Array else [])
	add_child(_schema)
	_schema.popup_centered()

# ================================================================ ELEMENTI DA IMMAGINE (v0.19)
func _elemento_da_immagine() -> void:
	_scegli_file("Scegli l'immagine del tuo elemento", func(f):
		var pm := PopupMenu.new()
		var cats: Array = ProgettoEditor.CATEGORIE_IMMAGINE.keys()
		for i in cats.size():
			pm.add_item(str(ProgettoEditor.CATEGORIE_IMMAGINE[cats[i]][0]), i)
		pm.id_pressed.connect(func(i):
			var r := progetto.esegui({"comando": "elemento_da_immagine", "file": f, "categoria": cats[i], "pos": vista.centro_vista() if vista.has_method("centro_vista") else Vector2(317, 560)})
			_avviso(r["messaggio"])
			if r.get("ok", false):
				vista.seleziona(str(r["id"]))
			pm.queue_free())
		pm.close_requested.connect(func(): pm.queue_free.call_deferred())
		add_child(pm)
		pm.popup_centered(Vector2i(420, 0))
		_avviso("Che cos'è la tua immagine? Scegli la categoria."))

var _finestra_lib: Window

func _apri_libreria_elementi() -> void:
	if _finestra_lib != null and is_instance_valid(_finestra_lib):
		_finestra_lib.queue_free()
	var w := Window.new()
	w.title = "⭐ I miei elementi"
	w.size = Vector2i(460, 420)
	w.close_requested.connect(w.queue_free)
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.add_child(pc)
	var col := VBoxContainer.new()
	pc.add_child(col)
	var spieg := Label.new()
	spieg.text = "Per salvare: scegli un pezzo sul tavolo e premi «Salva in I miei elementi» nel suo pannello."
	spieg.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(spieg)
	var el := ProgettoEditor.elenco_elementi()
	if el.is_empty():
		var vuoto := Label.new()
		vuoto.text = "(la libreria è vuota)"
		col.add_child(vuoto)
	for n in el:
		var r := HBoxContainer.new()
		col.add_child(r)
		var l := Label.new()
		l.text = str(n)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var nome: String = n
		_bottone(r, "Inserisci", func():
			var ri := progetto.esegui({"comando": "elemento_inserisci", "nome": nome, "pos": vista.centro_vista()})
			_avviso(ri["messaggio"])
			if ri.get("ok", false):
				vista.seleziona(str(ri["id"])), "Lo mette al centro della vista")
		_bottone(r, "✕", func(): _avviso(progetto.esegui({"comando": "elemento_togli", "nome": nome})["messaggio"]); _apri_libreria_elementi(), "Toglie l'elemento dalla libreria (va nel Cestino)")
	_finestra_lib = w
	add_child(w)
	w.popup_centered()

# ================================================================ ESPORTA (v0.20)
var _thread_esporta: Thread

## v0.26.1: MODELLI DI ESPORTAZIONE di Godot (servono per creare i giochi): download ufficiale, una volta sola.
var _http_modelli: HTTPRequest
func _installa_modelli() -> void:
	if Esportazione.modelli_presenti():
		_avviso("I modelli di esportazione sono già installati (%s)" % Esportazione.cartella_modelli())
		return
	var cd := ConfirmationDialog.new()
	cd.title = "Modelli di esportazione"
	cd.dialog_text = "Per creare i giochi (Linux, Windows, Raspberry Pi, Android) servono i «modelli di esportazione» ufficiali di Godot.\nSi scaricano UNA volta da github.com/godotengine (circa 1,3 GB, gratis) e si controlla che siano quelli ufficiali.\nScarico adesso?"
	cd.ok_button_text = "Sì, scarica"
	cd.confirmed.connect(func(): cd.queue_free(); _scarica_modelli())
	cd.canceled.connect(func(): cd.queue_free())
	add_child(cd)
	cd.popup_centered()

func _scarica_modelli() -> void:
	if _http_modelli != null:
		_avviso("Il download dei modelli è già in corso…")
		return
	var base := Esportazione.url_rilascio_godot()
	var tpz := ProjectSettings.globalize_path("user://modelli_godot.tpz")
	_http_modelli = HTTPRequest.new()
	_http_modelli.body_size_limit = -1
	add_child(_http_modelli)
	_avviso("⬇ Scarico l'elenco di controllo dei modelli…")
	_http_modelli.request_completed.connect(func(_r, codice, _h, corpo):
		if codice != 200:
			_fine_modelli({"ok": false, "messaggio": "Download non riuscito (codice %d): controlla la connessione" % codice}, tpz)
			return
		var somme: String = corpo.get_string_from_utf8()
		_http_modelli.queue_free()
		_http_modelli = HTTPRequest.new()
		_http_modelli.body_size_limit = -1
		_http_modelli.download_file = tpz
		add_child(_http_modelli)
		var avanz := Timer.new()
		avanz.wait_time = 2.0
		avanz.autostart = true
		avanz.timeout.connect(func():
			if is_instance_valid(_http_modelli) and _http_modelli.get_body_size() > 0:
				_avviso("⬇ Modelli di esportazione: %d %%" % int(100.0 * _http_modelli.get_downloaded_bytes() / _http_modelli.get_body_size())))
		add_child(avanz)
		_http_modelli.request_completed.connect(func(_r2, codice2, _h2, _c2):
			avanz.queue_free()
			if codice2 != 200:
				_fine_modelli({"ok": false, "messaggio": "Download dei modelli non riuscito (codice %d)" % codice2}, tpz)
				return
			_avviso("Controllo e installo i modelli…")
			var th := Thread.new()
			th.start(func():
				var r := Esportazione.installa_modelli(tpz, somme)
				(func(): th.wait_to_finish(); _fine_modelli(r, tpz)).call_deferred()))
		_http_modelli.request(base + Esportazione.nome_tpz()))
	_http_modelli.request(base + "SHA512-SUMS.txt")

func _fine_modelli(r: Dictionary, tpz: String) -> void:
	if is_instance_valid(_http_modelli):
		_http_modelli.queue_free()
	_http_modelli = null
	if FileAccess.file_exists(tpz):
		DirAccess.remove_absolute(tpz)
	_avviso(("✔ " if r["ok"] else "✖ ") + str(r["messaggio"]))

func _esporta(piattaforma: String) -> void:
	if piattaforma in ["linux", "windows", "pi", "android"] and not Esportazione.modelli_presenti():
		_avviso("Per creare il gioco servono i modelli di esportazione di Godot: 📦 ESPORTA → «Installa i modelli di esportazione».")
		_installa_modelli()
		return
	if progetto.cartella == "" or progetto.modificato:
		_avviso("Prima salva il tavolo (Salva): si esporta il tavolo salvato, con le sue musiche.")
		return
	if piattaforma == "android":
		var cd := ConfirmationDialog.new()
		cd.title = "APK Android di prova"
		cd.dialog_text = "Creo l'APK di PROVA (senza pubblicità)?\nRegola: l'APK si fa solo con il tuo ok. Per installarlo sul telefono serve un passaggio a parte."
		cd.ok_button_text = "Sì, crealo"
		cd.confirmed.connect(func(): _avvia_esportazione(piattaforma, true); cd.queue_free())
		cd.canceled.connect(func(): cd.queue_free())
		add_child(cd)
		cd.popup_centered()
		return
	_avvia_esportazione(piattaforma, false)

func _avvia_esportazione(piattaforma: String, ok: bool) -> void:
	if _thread_esporta != null and _thread_esporta.is_alive():
		_avviso("Un'esportazione è già in corso…")
		return
	if _thread_esporta != null:
		_thread_esporta.wait_to_finish()
	_avviso("ESPORTA: preparo il gioco per %s… (qualche decina di secondi)" % Esportazione.PIATTAFORME[piattaforma]["nome"])
	_thread_esporta = Thread.new()
	_thread_esporta.start(func(): _fine_esportazione.call_deferred(progetto.esegui({"comando": "esporta", "piattaforma": piattaforma, "conferma_utente": ok})))

func _fine_esportazione(r: Dictionary) -> void:
	if _thread_esporta != null:
		_thread_esporta.wait_to_finish()
	_avviso(r["messaggio"])
	if r.has("dettagli"):
		_avviso(str(r["dettagli"]))
	if r.get("ok", false) and str(r.get("file", "")).contains("progetto_godot"):
		# v0.22: progetto Godot: si può aprire subito nell'editor di Godot (lo stesso Godot dell'editor)
		var cd := ConfirmationDialog.new()
		cd.title = "Progetto Godot pronto"
		cd.dialog_text = "Il progetto completo è pronto:\n%s\n\nLo apro adesso in Godot? (Dentro c'è LEGGIMI_GODOT.md: dove sta ogni cosa.)" % str(r["file"])
		cd.ok_button_text = "Apri in Godot"
		cd.cancel_button_text = "Mostra la cartella"
		var dir_p := str(r["file"])
		cd.confirmed.connect(func():
			OS.create_process(OS.get_executable_path(), ["-e", "--path", dir_p])
			cd.queue_free())
		cd.canceled.connect(func():
			OS.shell_show_in_file_manager(dir_p.path_join("project.godot"))
			cd.queue_free())
		add_child(cd)
		cd.popup_centered()
	elif r.get("ok", false):
		OS.shell_show_in_file_manager(str(r["file"]))
