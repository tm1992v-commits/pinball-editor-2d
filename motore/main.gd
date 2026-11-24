## Scena principale: collega tavolo fisico, regole, vista 2D, tabellone, comandi e audio.
## Argomenti (dopo "--"): --prova=SECONDI (partita automatica senza grafica, stampa il collaudo)
##   --gioca (partita automatica con grafica) --foto=FILE --dopo=SECONDI (foto della finestra e chiude)
##   --debug (F6 nuova pallina, F8 multiball, F9 completa missione, F11 nuova partita)
##   --luce=NOME (prova di un effetto di luce ogni 3 s, es. --luce=festa)
##   --menu (apre il menu dopo 1 s, per le foto)  --partita (partita vera senza giocatore automatico) --debug_lancio (dove sta la pallina in corsia sullo schermo)
extends Node

var desc: Dictionary
var tavolo: TavoloFisico
var regole: RegoleBase
var vista: Vista2D
var hud: Hud
var menu: MenuGioco
var pubblicita: Pubblicita
var _strisce := {}                   # tocco -> [posizione e tempo di partenza] (strisciata = scossa)
var _gravita := Vector3.ZERO         # accelerometro medio (per riconoscere un colpo secco)
var _attesa_scossa := 0.0
var _tocchi := {}                    # dito -> azione tenuta premuta (palette, lancio)
var _prova := -1.0
var _t := 0.0
var conteggio := {}
var partite := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# tavolo: --tavolo=NOME dalla riga di comando, altrimenti [sistema] tavolo nel file dei parametri
	var nome_tavolo: String = Parametri.arg("tavolo") if Parametri.arg("tavolo") != "" else str(Parametri.valore("sistema", "tavolo", "base"))
	var script_regole := "res://tavoli/%s/regole_%s.gd" % [nome_tavolo, nome_tavolo]
	# v0.20 (Pinball Editor 2D, ESPORTA): un gioco esportato porta il suo tavolo dentro (res://gioco/tavolo.tavolo)
	var tavolo_file := Parametri.arg("tavolo_file")
	if tavolo_file == "" and FileAccess.file_exists("res://gioco/tavolo.tavolo"):
		tavolo_file = "res://gioco/tavolo.tavolo"
	if tavolo_file != "":
		# Pinball Editor 2D: tavolo da un file salvato dall'editor (GIOCA, prove, esportazione)
		desc = FileTavolo.leggi(tavolo_file)
		if desc.is_empty():
			push_error("FILE TAVOLO NON LEGGIBILE: " + tavolo_file)
			get_tree().quit(1)
			return
		if tavolo_file.begins_with("res://gioco/"):
			desc["cartella_musica"] = "res://gioco/musica"
			DisplayServer.window_set_title(str(desc.get("titolo", desc.get("nome", "Pinball"))).capitalize())
		nome_tavolo = str(desc.get("nome", "tavolo"))
		script_regole = str(desc.get("regole", FileTavolo.REGOLE_BASE))
		if not ResourceLoader.exists(script_regole):
			script_regole = FileTavolo.REGOLE_BASE
		if not ResourceLoader.exists(str(desc.get("luci", ""))):
			desc["luci"] = FileTavolo.LUCI_BASE
	else:
		desc = load("res://tavoli/%s/layout_%s.gd" % [nome_tavolo, nome_tavolo]).descrizione()
	# v0.13: lingua del tabellone scelta nell'editor (i tavoli finiti restano in italiano)
	Testi.lingua = str(desc.get("lingua", "it"))
	tavolo = TavoloFisico.new(desc)
	tavolo.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(tavolo)
	regole = load(script_regole).new()
	regole.titolo = str(desc.get("titolo", nome_tavolo.to_upper()))
	regole.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(regole)
	regole.collega(tavolo)
	regole.effetto.connect(_suono)
	tavolo.evento.connect(_suono_tavolo)
	tavolo.evento.connect(func(tipo, id, _p): conteggio[tipo + ":" + id] = int(conteggio.get(tipo + ":" + id, 0)) + 1)
	var headless := DisplayServer.get_name() == "headless"
	if Parametri.argomenti.has("prova"):
		_prova = float(Parametri.arg("prova"))
		tavolo.autoplay = true
		regole.salva_record = false
		regole.nuova_partita()
	if not headless and Parametri.argomenti.has("finestra"):
		_finestra_nello_schermo()
	if not headless and not Parametri.senza("vista"):
		vista = Vista2D.new()
		add_child(vista)
		vista.prepara(desc, tavolo, regole)
		if not Parametri.senza("hud"):
			hud = Hud.new()
			add_child(hud)
			hud.prepara(regole)
		menu = MenuGioco.new()
		add_child(menu)
		menu.prepara(vista, regole)
		if Parametri.argomenti.has("menu"):
			# --menu apre il menu; --menu=tour_1 apre direttamente quella pagina (foto e prove sul telefono)
			var p_menu: String = Parametri.arg("menu")
			get_tree().create_timer(1.0).timeout.connect(func(): menu.apri("principale" if p_menu == "1" else p_menu))
		if Pubblicita.disponibile():
			_prepara_pubblicita()
		Engine.max_fps = int(Parametri.valore("grafica", "fps_massimi", 60))
		if bool(Parametri.valore("sistema", "schermo_intero", false)) and not Parametri.argomenti.has("finestra"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# musica: brano principale in gioco, versione d'attesa fuori partita, più veloce nel multiball
	if not headless:
		Audio.musica(_musica("attract"))
		regole.stato_cambiato.connect(func(st):
			if st == RegoleBase.GIOCO:
				Audio.musica(_musica("multiball" if regole.multiball else "main"))
			elif st == RegoleBase.GAME_OVER or st == RegoleBase.ATTESA:
				Audio.musica(_musica("attract")))
		regole.effetto.connect(func(nome, _p):
			if nome == "multiball" or nome == "eruzione":
				Audio.musica(_musica("multiball"))
			elif nome == "fine_multiball" or nome == "fine_eruzione":
				Audio.musica(_musica("main"))
			elif nome == "missione_inizio" and _musica_missione() != "":
				Audio.musica(_musica_missione())
			elif nome in ["missione_completa", "missione_fallita"] and desc.get("musica") is Dictionary:
				Audio.musica(_musica("multiball" if regole.multiball else "main")))
	if Parametri.argomenti.has("partita"):
		# partita vera senza giocatore automatico (prove della telecamera del lancio)
		regole.salva_record = false
		regole.nuova_partita()
	if Parametri.argomenti.has("gioca"):
		tavolo.autoplay = true
		regole.salva_record = false
		regole.nuova_partita()
	if Parametri.argomenti.has("luce") and vista and vista.regia:
		# prova delle luci (sviluppo): --luce=NOME fa partire quell'effetto ogni 3 secondi
		var t_luce := Timer.new()
		t_luce.wait_time = 3.0
		t_luce.autostart = true
		t_luce.timeout.connect(func(): vista.regia.evento(Parametri.arg("luce"), Vector2.ZERO))
		add_child(t_luce)
	if Parametri.argomenti.has("memoria"):
		# diagnosi: memoria e oggetti ogni 5 secondi (per trovare perdite di memoria)
		var t_mem := Timer.new()
		t_mem.wait_time = 5.0
		t_mem.autostart = true
		t_mem.timeout.connect(func(): print("MEMORIA t=%d statica %.1f MB | oggetti %d | risorse %d | nodi %d | orfani %d | video %.1f MB" % [
			Time.get_ticks_msec() / 1000, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]))
		add_child(t_mem)
	if Parametri.argomenti.has("foto"):
		_foto.call_deferred()
	if Parametri.argomenti.has("bench"):
		_bench.call_deferred(float(Parametri.arg("bench")))
	if Parametri.argomenti.has("prova_iniziali"):
		# foto di controllo (v0.23): fine partita con un punteggio da classifica, iniziali da scrivere
		regole.salva_record = false
		get_tree().create_timer(1.0).timeout.connect(func():
			regole.punti = 123450
			regole._fine_partita()
			regole.iniziali_cambia(2)
			regole.iniziali_conferma())
	if Parametri.argomenti.has("registra") and not headless:
		_registra.call_deferred(Parametri.arg("registra"), float(Parametri.arg("durata")) if Parametri.arg("durata") != "" else 30.0)
	if Parametri.argomenti.has("velocita"):
		# v0.23: misura della velocità in 2 fasi con rapporto (pulsante «Misura la velocità» dell'editor)
		var mv := MisuraVelocita.new()
		add_child(mv)
		mv.avvia(self, float(Parametri.arg("velocita")), Parametri.arg("rapporto"))
	if Parametri.argomenti.has("multiball"):
		_prova_multiball.call_deferred(float(Parametri.arg("multiball")))
	if Parametri.argomenti.has("misura"):
		_misura.call_deferred(float(Parametri.arg("misura")))

## Prova sul telefono (21/11, solo APK di sviluppo con user://argomenti.txt): dopo `attesa` s dall'inizio della
## partita parte il multiball pieno; ogni secondo scrive FPS, palline e stato della corsia di lancio (adb logcat).
func _prova_multiball(attesa: float) -> void:
	while regole.stato != RegoleBase.GIOCO or tavolo.pallina_in_corsia != null:
		await get_tree().create_timer(0.5).timeout
	while true:
		await get_tree().create_timer(attesa).timeout
		if regole.stato != RegoleBase.GIOCO or tavolo.pallina_in_corsia != null:
			await get_tree().create_timer(0.5).timeout
			continue
		regole.avvia_multiball_pieno()
		print("PROVA_MB avviato")
		var i := 0
		while regole.multiball and regole.stato == RegoleBase.GIOCO:
			var f0 := Engine.get_frames_drawn()
			await get_tree().create_timer(1.0).timeout
			print("PROVA_MB s=%d fps=%d palline=%d corsia=%s molla=%s sx=%s dx=%s" % [i, Engine.get_frames_drawn() - f0,
				tavolo.palline.size(), tavolo.pallina_in_corsia != null, tavolo.aspetta_molla(),
				Input.is_action_pressed("paletta_sx"), Input.is_action_pressed("paletta_dx")])
			i += 1

## Misura in partita vera (22/11, prova di 60 FPS stabili sul Pixel): limiti normali (60 FPS, vsync), partita
## automatica; ogni 10 s scrive nel registro (adb logcat) FPS, tempo medio e 1% peggiore dei fotogrammi, fotogrammi
## oltre 16,7 / 20 / 33 ms, tempo di fisica e di disegno, memoria, disegni, palline. Ogni 60 s un multiball pieno
## (5 palline, luci della festa) per mettere sotto sforzo il tavolo. Alla fine un riepilogo e il gioco si chiude.
func _misura(durata: float) -> void:
	await get_tree().create_timer(3.0).timeout
	var t0 := Time.get_ticks_usec()
	var prec := t0
	var blocco: Array[float] = []
	var tutti: Array[float] = []
	var ultimo_mb := 0.0
	var ultimo_log := 0.0
	var fis := 0.0
	var dis := 0.0
	var n := 0
	while (Time.get_ticks_usec() - t0) / 1e6 < durata:
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		var ms := (ora - prec) / 1000.0
		prec = ora
		blocco.append(ms)
		tutti.append(ms)
		fis += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		dis += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		n += 1
		var sec := (ora - t0) / 1e6
		if sec - ultimo_mb > 60.0 and regole.stato == RegoleBase.GIOCO and not regole.multiball:
			ultimo_mb = sec
			regole.avvia_multiball_pieno()
			if vista and vista.regia:
				vista.regia.evento("festa", Vector2.ZERO)
		if sec - ultimo_log >= 10.0:
			ultimo_log = sec
			print("MISURA " + _riassunto_tempi(blocco) + " | fisica %.2f ms | processo+attesa %.2f ms | palline %d | memoria %.0f MB | video %.0f MB | disegni %d | t=%d s" % [
				fis / maxf(n, 1), dis / maxf(n, 1), tavolo.palline.size(), OS.get_static_memory_usage() / 1048576.0,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), int(sec)])
			blocco.clear()
			fis = 0.0
			dis = 0.0
			n = 0
	print("MISURA_FINE " + _riassunto_tempi(tutti) + " | durata %d s" % int(durata))
	get_tree().quit()

func _riassunto_tempi(t: Array[float]) -> String:
	if t.is_empty():
		return "-"
	var o := t.duplicate()
	o.sort()
	var somma := 0.0
	var c16 := 0
	var c20 := 0
	var c33 := 0
	for x in o:
		somma += x
		c16 += 1 if x > 17.5 else 0
		c20 += 1 if x > 20.0 else 0
		c33 += 1 if x > 33.4 else 0
	return "fps %.1f | medio %.2f ms | 1%% peggiore %.1f ms | max %.1f ms | oltre 16,7 ms %d | oltre 20 ms %d | oltre 33 ms %d | fotogrammi %d" % [
		1000.0 * o.size() / somma, somma / o.size(), o[int(o.size() * 0.99)], o[-1], c16, c20, c33, o.size()]

## Misura dei fotogrammi (con la grafica): FPS medi, 1% peggiore, fotogrammi oltre 20 ms.
func _bench(durata: float) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(2.0).timeout
	var tempi: Array[float] = []
	var t0 := Time.get_ticks_usec()
	var prec := t0
	var multi := false
	while (Time.get_ticks_usec() - t0) / 1e6 < durata:
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		tempi.append((ora - prec) / 1000.0)
		prec = ora
		if not multi and (ora - t0) / 1e6 > durata * 0.5:
			multi = true
			regole.avvia_multiball(2)
	tempi.sort()
	var somma := 0.0
	for x in tempi:
		somma += x
	var peggiori := tempi.slice(int(tempi.size() * 0.99))
	var p1 := 0.0
	for x in peggiori:
		p1 += x
	p1 /= maxf(1.0, peggiori.size())
	var oltre := 0
	for x in tempi:
		if x > 20.0:
			oltre += 1
	print("BENCH %d fotogrammi: FPS medi %.0f | 1%% peggiore %.0f FPS | oltre 20 ms: %d | disegni %d | memoria %.0f MB" % [tempi.size(), 1000.0 * tempi.size() / somma, 1000.0 / p1, oltre, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), OS.get_static_memory_usage() / 1048576.0])
	get_tree().quit()

func _foto() -> void:
	await get_tree().create_timer(float(Parametri.arg("dopo")) if Parametri.arg("dopo") != "" else 1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Parametri.arg("foto"))
	print("FOTO ", Parametri.arg("foto"))
	get_tree().quit()

## v0.12: musica del tavolo scelta nell'editor (desc["musica"] = {"main"|"multiball"|"attract": file} nella cartella
## desc["cartella_musica"]); senza scelta resta quella di prima.
func _musica(ruolo: String) -> String:
	var m = desc.get("musica", {})
	if m is Dictionary and str(m.get(ruolo, "")) != "":
		return "file:" + str(desc.get("cartella_musica", "")).path_join(str(m[ruolo]))
	if m is Dictionary and ruolo != "main" and str(m.get("main", "")) != "":
		return "file:" + str(desc.get("cartella_musica", "")).path_join(str(m["main"]))
	return ruolo

func _musica_missione() -> String:
	var mm = regole.get("missioni")
	if mm == null or mm.corrente < 0:
		return ""
	var f := str(mm.missioni[mm.corrente].get("musica", ""))
	return "file:" + str(desc.get("cartella_musica", "")).path_join(f) if f != "" else ""

func _suono(nome: String, _pos: Vector2) -> void:
	# v0.11: suono scelto nell'editor per questo tavolo ("" = nessuno)
	var scelto = RegiaDati.suono(desc, nome)
	if scelto != null:
		if scelto != "":
			Audio.suona(scelto)
		return
	match nome:
		"multiball", "promozione": Audio.suona("multiball_spazio")
		"jackpot", "skill_shot": Audio.suona("jackpot_spazio")
		"missione_completa": Audio.suona("missione_completa")
		"missione_inizio": Audio.suona("missione_inizio")
		"missione_fallita": Audio.suona("missione_fallita")
		"tilt": Audio.suona("tilt")
		"avviso": Audio.suona("avviso")
		"salva_pallina": Audio.suona("pallina_extra")
		"pallina_extra": Audio.suona("pallina_extra", 2.0)
		"extra_accesa": Audio.suona("pallina_extra", -2.0, 0.8)
		"kicker_alto": Audio.suona("lock")
		"kickback": Audio.suona("lancio")
		"orbita": Audio.suona("combo")
		"corsia": Audio.suona("corsia_spazio")
		"spinner": Audio.suona("spinner")

func _suono_tavolo(tipo: String, _id: String, _pos: Vector2) -> void:
	var scelto = RegiaDati.suono(desc, tipo)
	if scelto != null:
		if scelto != "":
			Audio.suona(scelto)
		return
	match tipo:
		"bumper": Audio.suona("bumper", 0.0, randf_range(0.95, 1.05))
		"fionda": Audio.suona("fionda")
		"bersaglio", "captive": Audio.suona("bersaglio")
		"rampa_entrata": Audio.suona("rampa")
		"rampa": Audio.suona("rampa_fine")
		"lancio": Audio.suona("lancio")
		"campo_acceso", "buca":
			if _id == "pozzo" or _id == "pozzo_centro":
				Audio.suona("pozzo")
		"magnete_presa", "magnete_lancio": Audio.suona("magnete")

func _prepara_pubblicita() -> void:
	pubblicita = Pubblicita.new()
	pubblicita.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pubblicita)
	menu.pubblicita = pubblicita
	var c = Pubblicita.consenso_scelto()
	if c == null:
		menu.chiedi_consenso(func(si): pubblicita.cambia_consenso(si))
	else:
		pubblicita.avvia(bool(c))
	regole.offri_premio = pubblicita.premio_pronto
	regole.stato_cambiato.connect(func(st):
		if st == RegoleBase.PREMIO:
			menu.proponi_premio(func():
				pubblicita.mostra_premio(func(visto: bool):
					if visto:
						regole.premio_ricevuto()
					else:
						regole.premio_rifiutato(true)),
				func(): regole.premio_rifiutato())
		if st == RegoleBase.GAME_OVER:
			# un attimo per vedere il punteggio; se intanto è ripartita una partita, niente pubblicità
			get_tree().create_timer(2.5).timeout.connect(func():
				if regole.stato == RegoleBase.GAME_OVER or regole.stato == RegoleBase.ATTESA:
					pubblicita.fine_partita()))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_tocco(e)
		return
	# v0.23: iniziali della classifica: palette = lettera, START o lancio = conferma
	if regole.scrive_iniziali():
		if e.is_action_pressed("paletta_sx"):
			regole.iniziali_cambia(-1)
		elif e.is_action_pressed("paletta_dx"):
			regole.iniziali_cambia(1)
		elif e.is_action_pressed("start") or e.is_action_pressed("lancio"):
			regole.iniziali_conferma()
		if not e.is_action_pressed("pausa"):
			return
	if e.is_action_pressed("start") and (regole.stato == RegoleBase.ATTESA or regole.stato == RegoleBase.GAME_OVER):
		regole.nuova_partita()
	elif e.is_action_pressed("lancio"):
		tavolo.inizia_carica()
	elif e.is_action_released("lancio"):
		tavolo.rilascia_carica()
	elif e.is_action_pressed("spinta"):
		_spinta(Vector2(0, -1))
	elif e.is_action_pressed("spinta_sx"):
		_spinta(Vector2(1, -0.3))
	elif e.is_action_pressed("spinta_dx"):
		_spinta(Vector2(-1, -0.3))
	elif e is InputEventKey and e.pressed and e.keycode == KEY_V and vista:
		if menu:
			menu.visuale_successiva()
		else:
			vista.cambia_visuale()
	elif e.is_action_pressed("pausa"):
		if menu:
			if menu.aperto:
				menu.chiudi()
			else:
				menu.apri()
		else:
			get_tree().paused = not get_tree().paused
	elif (e.is_action_pressed("paletta_sx") or e.is_action_pressed("paletta_dx")) and regole.in_gioco():
		Audio.suona("paletta")
	elif e is InputEventKey and e.pressed and Parametri.debug_attivo():
		match e.keycode:
			KEY_F6: tavolo.genera_pallina(Vector2(240, 600), Vector2(0, -900))
			KEY_F8: regole.avvia_multiball(2)
			KEY_F11: regole.nuova_partita()

## Comandi touch (telefono): metà sinistra = paletta sinistra, metà destra = paletta destra; con la pallina nella
## corsia di lancio, la metà destra in basso carica la molla (tieni premuto) e lancia (lascia). Fuori partita: START.
## (I pulsanti del menu e della telecamera prendono il tocco prima: questa funzione riceve solo il resto.)
func _tocco(e: InputEvent) -> void:
	var dim := get_viewport().get_visible_rect().size
	if e is InputEventScreenTouch:
		if e.pressed:
			if regole.scrive_iniziali():
				# v0.23: tocco in alto = conferma la lettera; a sinistra / a destra = lettera prima / dopo
				if e.position.y < dim.y * 0.3:
					regole.iniziali_conferma()
				else:
					regole.iniziali_cambia(-1 if e.position.x < dim.x * 0.5 else 1)
				return
			if regole.stato == RegoleBase.ATTESA or regole.stato == RegoleBase.GAME_OVER:
				regole.nuova_partita()
				return
			var destra: bool = e.position.x > dim.x * 0.5
			var azione := "paletta_dx" if destra else "paletta_sx"
			if destra and tavolo.aspetta_molla() and e.position.y > dim.y * 0.45:
				azione = "lancio"
				tavolo.inizia_carica()
			else:
				Input.action_press(azione)
				if regole.in_gioco():
					Audio.suona("paletta")
			_tocchi[e.index] = azione
			if Parametri.argomenti.has("multiball"):
				print("PROVA_MB tocco %s a %s" % [azione, e.position.round()])
			_strisce[e.index] = [e.position, Time.get_ticks_msec()]
		elif _tocchi.has(e.index):
			_strisce.erase(e.index)
			var azione: String = _tocchi[e.index]
			_tocchi.erase(e.index)
			if azione == "lancio":
				tavolo.rilascia_carica()
			elif not _tocchi.values().has(azione):
				Input.action_release(azione)

	elif e is InputEventScreenDrag and _strisce.has(e.index):
		# strisciata veloce del dito = scossa (nudge): in su = frontale, a sinistra/destra = laterale. Una per tocco.
		var inizio: Vector2 = _strisce[e.index][0]
		var spostamento: Vector2 = e.position - inizio
		var tempo := Time.get_ticks_msec() - int(_strisce[e.index][1])
		if spostamento.length() > dim.x * 0.12 and tempo < 300:
			_strisce.erase(e.index)
			if absf(spostamento.x) > absf(spostamento.y):
				_spinta(Vector2(signf(spostamento.x), -0.3))
			elif spostamento.y < 0.0:
				_spinta(Vector2(0, -1))
		elif tempo >= 300:
			_strisce.erase(e.index)

## Scossa del telefono (accelerometro): un colpo secco del telefono = nudge, come sul flipper vero.
func _scossa_telefono(delta: float) -> void:
	if not OS.has_feature("mobile") or Parametri.senza("accelerometro") or not bool(Parametri.valore("comandi", "scossa_telefono", true)):
		return
	var a := Input.get_accelerometer()
	if a == Vector3.ZERO:
		return
	if _gravita == Vector3.ZERO:
		_gravita = a
	var colpo := a - _gravita
	_gravita = _gravita.lerp(a, minf(1.0, delta * 3.0))
	_attesa_scossa -= delta
	if _attesa_scossa <= 0.0 and colpo.length() > float(Parametri.valore("comandi", "soglia_scossa", 11.0)):
		_attesa_scossa = 0.5
		# telefono spinto di lato: la pallina va dall'altra parte; spinto in avanti/su: scossa frontale
		if absf(colpo.x) > absf(colpo.y) and absf(colpo.x) > absf(colpo.z):
			_spinta(Vector2(-signf(colpo.x), -0.3))
		else:
			_spinta(Vector2(0, -1))

func _spinta(dir: Vector2) -> void:
	regole.spinta(dir)
	if vista:
		vista.scossa(dir)

func _physics_process(delta: float) -> void:
	_scossa_telefono(delta)
	if _prova < 0.0:
		return
	_t += delta
	if regole.stato == RegoleBase.GAME_OVER:
		partite += 1
		regole.nuova_partita()
	if _t >= _prova:
		print("COLLAUDO %d s: interventi delle sicurezze = %d %s" % [int(_t), tavolo.incastri, str(tavolo.registro_incastri.slice(0, 30))])
		var chiavi := conteggio.keys()
		chiavi.sort()
		for k in chiavi:
			print("  ", k, " = ", conteggio[k])
		print("partite finite ", partite)
		print("punti ", regole.punti, "  missioni ", regole.missioni_fatte if "missioni_fatte" in regole else [])
		get_tree().quit()

## v0.21: finestra di prova (GIOCA dall'editor) alta quanto lo schermo libero, in proporzione da telefono (9:16),
## al centro: su un portatile basso la finestra da 800 px usciva dallo schermo e il tabellone copriva il tavolo.
func _finestra_nello_schermo() -> void:
	var sc := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(sc)
	var h := int(minf(area.size.y * 0.9, 1280.0))
	var w := int(h * 9.0 / 16.0)
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position(area.position + Vector2i((area.size.x - w) / 2, (area.size.y - h) / 2))

## v0.25 VIDEO PROMOZIONALE: partita automatica registrata in tempo reale dalla finestra del gioco con ffmpeg
## (cattura dello schermo X11: veloce come il gioco, non come il Movie Maker). Senza audio: la musica si aggiunge al
## montaggio. Uso: -- --tavolo_file=F --finestra --registra=FILE.mp4 [--durata=30]
func _registra(file: String, durata: float) -> void:
	tavolo.autoplay = true
	regole.salva_record = false
	regole.nuova_partita()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	await get_tree().create_timer(2.0).timeout
	var p := DisplayServer.window_get_position()
	var d := DisplayServer.window_get_size()
	d = Vector2i(d.x - d.x % 2, d.y - d.y % 2)
	var schermo := OS.get_environment("DISPLAY") if OS.get_environment("DISPLAY") != "" else ":0"
	var args := ["-y", "-loglevel", "error", "-f", "x11grab", "-draw_mouse", "0", "-framerate", "30", "-video_size", "%dx%d" % [d.x, d.y],
		"-i", "%s+%d,%d" % [schermo, p.x, p.y], "-t", str(durata), "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", file]
	var pid := OS.create_process("ffmpeg", args)
	print("REGISTRA ", "avviato" if pid > 0 else "ffmpeg non trovato", " ", file)
	await get_tree().create_timer(durata + 1.5).timeout
	get_tree().quit()
