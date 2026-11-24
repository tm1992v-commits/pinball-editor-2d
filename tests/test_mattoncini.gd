## Prove dell'interprete delle MISSIONI A MATTONCINI (v0.10), senza fisica: i colpi si simulano uno per uno.
## Uso: godot --headless --path . res://tests/test_mattoncini.tscn
extends Node

var ok := 0
var falliti := 0
var messaggi: Array = []

func _prova(nome: String, vero: bool) -> void:
	if vero:
		ok += 1
		print("OK       ", nome)
	else:
		falliti += 1
		print("FALLITO  ", nome)

func _regole() -> RegoleBase:
	var r := RegoleBase.new()
	r.salva_record = false
	r.stato = RegoleBase.GIOCO
	# tavolo finto (non messo in scena: niente fisica), serve solo per leggere «tilt» quando si danno i punti
	r.tavolo = TavoloFisico.new(load("res://tests/test_motore.gd").descrizione())
	add_child(r)
	r.messaggio.connect(func(a, b, _d): messaggi.append(a + " | " + b))
	return r

func _m(desc: Dictionary) -> Array:
	var r := _regole()
	var m := Mattoncini.new(desc, r)
	m.nuova_partita()
	m.inizio_pallina(0.0)
	m.tick(2.0)
	return [m, r]

func _ready() -> void:
	var base := {"bumper": [{"id": "b1"}, {"id": "b2"}], "bersagli": [{"id": "t1", "gruppo": "g"}, {"id": "t2", "gruppo": "g"}, {"id": "t3", "gruppo": "g"}, {"id": "x", "gruppo": ""}],
		"rampe": [{"id": "r1"}, {"id": "r2"}], "buche": [{"id": "k"}]}
	# 1) conta
	var d := base.duplicate()
	d["missioni"] = [{"id": "m1", "nome": "Meteore", "fasi": [{"quando": {"tipo": "bumper"}, "volte": 3}], "premio": {"punti": 10000}}]
	var mr := _m(d)
	var m: Mattoncini = mr[0]
	var r: RegoleBase = mr[1]
	_prova("la prima missione parte da sola", m.corrente == 0)
	for i in 2:
		m.evento("bumper", "b1", Vector2.ZERO, 3.0)
	m.evento("bersaglio", "t1", Vector2.ZERO, 3.0)
	_prova("conta: 2/3 (il bersaglio non conta)", m.conta == 2 and m.riga().ends_with("2/3"))
	m.evento("bumper", "b2", Vector2.ZERO, 3.5)
	_prova("conta: completata con il premio", m.completate.has("m1") and r.punti == 10000 and m.corrente == -1)
	m.tick(4.0)
	_prova("dopo la pausa non riparte subito", m.corrente == -1)
	m.tick(6.5)
	_prova("missione ripetibile riparte dopo la pausa", m.corrente == 0)
	# 2) tutti del gruppo
	d = base.duplicate()
	d["missioni"] = [{"id": "m2", "fasi": [{"quando": {"tipo": "bersaglio", "gruppo": "g"}, "modo": "tutti"}]}]
	mr = _m(d)
	m = mr[0]
	m.evento("bersaglio", "t1", Vector2.ZERO, 3.0)
	m.evento("bersaglio", "t1", Vector2.ZERO, 3.1)
	m.evento("bersaglio", "x", Vector2.ZERO, 3.2)
	m.evento("bersaglio", "t2", Vector2.ZERO, 3.3)
	_prova("tutti: doppioni e altri gruppi non contano (2/3)", m.conta == 2 and m.corrente == 0)
	m.evento("bersaglio", "t3", Vector2.ZERO, 3.4)
	_prova("tutti: completata", m.completate.has("m2"))
	# 3) sequenza
	d = base.duplicate()
	d["missioni"] = [{"id": "m3", "fasi": [{"quando": {"tipo": "qualsiasi"}, "modo": "sequenza", "ids": ["r1", "k", "r2"]}]}]
	mr = _m(d)
	m = mr[0]
	m.evento("rampa", "r1", Vector2.ZERO, 3.0)
	m.evento("rampa", "r2", Vector2.ZERO, 3.1)
	_prova("sequenza: ordine sbagliato riparte da capo", m.passo_seq == 0)
	m.evento("rampa", "r1", Vector2.ZERO, 3.2)
	m.evento("bumper", "b1", Vector2.ZERO, 3.25)
	m.evento("buca", "k", Vector2.ZERO, 3.3)
	m.evento("rampa", "r2", Vector2.ZERO, 3.4)
	_prova("sequenza: r1 → buca → r2 completata (gli altri colpi non disturbano)", m.completate.has("m3"))
	# 4) combo
	d = base.duplicate()
	d["missioni"] = [{"id": "m4", "fasi": [{"quando": {"tipo": "rampa"}, "modo": "combo", "volte": 3, "finestra": 2.0}]}]
	mr = _m(d)
	m = mr[0]
	m.evento("rampa", "r1", Vector2.ZERO, 3.0)
	m.evento("rampa", "r2", Vector2.ZERO, 4.0)
	m.evento("rampa", "r1", Vector2.ZERO, 7.0)
	_prova("combo: troppo lento riparte da 1", m.conta == 1)
	m.evento("rampa", "r1", Vector2.ZERO, 8.0)
	m.evento("rampa", "r2", Vector2.ZERO, 9.5)
	_prova("combo ×3 entro 2 s: completata", m.completate.has("m4"))
	# 5) hurry-up
	d = base.duplicate()
	d["missioni"] = [{"id": "m5", "fasi": [{"quando": {"tipo": "buca"}, "modo": "hurry_up", "cala": 10000, "premio": {"punti": 300000, "minimo": 50000}}]}]
	mr = _m(d)
	m = mr[0]
	r = mr[1]
	m.tick(12.0)
	_prova("hurry-up: il valore cala col tempo (300.000 → 200.000 in 10 s)", absf(m.hurry_valore - 200000.0) < 1.0)
	m.evento("buca", "k", Vector2.ZERO, 12.0)
	_prova("hurry-up: preso, vale quanto mostrato", r.punti == 200000)
	# 6) tempo scaduto e fasi
	d = base.duplicate()
	d["missioni"] = [{"id": "m6", "tempo": 20.0, "fasi": [{"quando": {"tipo": "bumper"}, "volte": 2, "premio": {"punti": 1000}}, {"quando": {"tipo": "rampa"}, "volte": 1}], "premio": {"punti": 5000}}]
	mr = _m(d)
	m = mr[0]
	r = mr[1]
	m.evento("bumper", "b1", Vector2.ZERO, 3.0)
	m.evento("bumper", "b1", Vector2.ZERO, 3.0)
	_prova("fasi: la fase 1 dà il suo premio e passa alla 2", m.fase == 1 and r.punti == 1000 and m.riga().contains("fase 2/2"))
	m.tick(23.0)
	_prova("tempo scaduto: missione fallita", m.corrente == -1 and not m.completate.has("m6") and messaggi.back().contains("FALLITA"))
	# 7) sblocco (wizard) e avvio con un tiro
	d = base.duplicate()
	d["missioni_avvio"] = {"tipo": "buca", "id": "k"}
	d["missioni"] = [{"id": "a", "ripeti": false, "fasi": [{"quando": {"tipo": "bumper"}, "volte": 1}]},
		{"id": "w", "nome": "Wizard", "sblocco": {"completate": 1}, "fasi": [{"quando": {"tipo": "rampa"}, "volte": 1}], "premio": {"pallina_extra": true}}]
	mr = _m(d)
	m = mr[0]
	r = mr[1]
	_prova("avvio con un tiro: missione pronta, non ancora partita", m.pronta == 0 and m.corrente == -1)
	m.evento("bumper", "b1", Vector2.ZERO, 3.0)
	_prova("prima del tiro i colpi non contano", m.corrente == -1)
	m.evento("buca", "k", Vector2.ZERO, 3.1)
	m.evento("bumper", "b1", Vector2.ZERO, 3.2)
	_prova("il tiro nella buca la fa partire", m.completate.has("a"))
	m.tick(10.0)
	_prova("sblocco: il wizard è pronto dopo 1 missione", m.pronta == 1)
	m.evento("buca", "k", Vector2.ZERO, 10.1)
	m.evento("rampa", "r1", Vector2.ZERO, 10.2)
	_prova("premio pallina extra", r.extra_palline == 1)
	m.tick(20.0)
	_prova("missione non ripetibile non torna: il wizard si ripete", m.pronta == 1)
	_luci()
	_palette()
	_modalita()
	_collezione_zone()
	await _partita_vera()
	await _pezzi_nuovi()
	await _piano_staccato()
	await _nastro_solido()
	await _prigioniera()
	await _bumper_ovale()
	await _rampa_da_immagine()
	_segreti_e_classifica()
	print("==== MATTONCINI: %d OK, %d FALLITI ====" % [ok, falliti])
	get_tree().quit(0 if falliti == 0 else 1)

## PARTITA VERA (motore e regole dei tavoli nuovi): tavolo Base + 1 bumper, missione «bumper ×3»; palline lanciate
## contro il bumper finché la missione si completa. Avvio con --fixed-fps 60 (fisica più veloce del tempo reale).
func _partita_vera() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Partita"})
	p.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "bb", "pos": [317, 400]})
	p.esegui({"comando": "missione_aggiungi", "missione": {"nome": "Tre colpi", "fasi": [{"quando": {"tipo": "bumper", "id": "bb"}, "volte": 3}], "premio": {"punti": 70000}}})
	var tavolo := TavoloFisico.new(p.desc)
	add_child(tavolo)
	var regole: RegoleBase = load(FileTavolo.REGOLE_BASE).new()
	regole.salva_record = false
	add_child(regole)
	regole.collega(tavolo)
	regole.nuova_partita()
	for i in 480:
		await get_tree().physics_frame
	_prova("partita vera: la missione è partita da sola", regole.missioni.corrente == 0 and regole.riga_missioni().begins_with("TRE COLPI"))
	for k in 6:
		if regole.missioni.completate.has(p.desc["missioni"][0]["id"]):
			break
		var b := tavolo.genera_pallina(Vector2(317, 600), Vector2(randf_range(-30, 30), -1400))
		b.dal_lancio = 9.0
		for i in 240:
			await get_tree().physics_frame
	_prova("partita vera: 3 colpi sul bumper = missione completata, premio dato (punti %d)" % regole.punti, regole.missioni.completate.has(p.desc["missioni"][0]["id"]) and regole.punti >= 70000)
	# v0.23: fine partita con un punteggio da classifica = si scrivono le iniziali (classifica senza file nei test)
	_prova("classifica: nelle prove non si scrive il file", regole.classifica != null and not regole.classifica.salva)
	regole._fine_partita()
	_prova("classifica: a fine partita si scrivono le iniziali", regole.scrive_iniziali() and regole.iniziali == "AAA")
	regole.iniziali_cambia(1)
	regole.iniziali_conferma()
	regole.iniziali_cambia(-1)
	regole.iniziali_conferma()
	regole.iniziali_conferma()
	_prova("classifica: iniziali «B A» al primo posto (A indietro = spazio)", not regole.scrive_iniziali() and regole.classifica.voci[0][0] == "B A")
	regole.queue_free()
	tavolo.queue_free()

## v0.11: luci che seguono il gioco (RegiaDati.stato_luce) e suoni/effetti scelti per evento.
func _luci() -> void:
	var d := {"bumper": [{"id": "b1"}, {"id": "b2"}], "bersagli": [{"id": "t1", "gruppo": "g"}],
		"missioni": [{"id": "m", "fasi": [{"quando": {"tipo": "bumper", "id": "b2"}, "volte": 3}]}]}
	var r: RegoleBase = load(FileTavolo.REGOLE_BASE).new()
	r.tavolo = TavoloFisico.new(load("res://tests/test_motore.gd").descrizione())
	r.stato = RegoleBase.GIOCO
	add_child(r)
	r.missioni = Mattoncini.new(d, r)
	r.missioni.nuova_partita()
	r.missioni.inizio_pallina(0.0)
	r.missioni.tick(2.0)
	var barra := func(k): return RegiaDati.stato_luce({"luce_modo": "progresso", "luce_parte": k, "luce_su": 3}, r)
	_prova("luci: barra spenta a inizio missione", barra.call(1) == 0)
	r.missioni.evento("bumper", "b2", Vector2.ZERO, 3.0)
	r.missioni.evento("bumper", "b2", Vector2.ZERO, 3.0)
	_prova("luci: barra 2/3 = due luci accese, la terza no", barra.call(1) == 1 and barra.call(2) == 1 and barra.call(3) == 0)
	_prova("luci: guida al tiro lampeggia sul pezzo chiesto, non sugli altri", RegiaDati.stato_luce({"luce_modo": "tiro", "luce_rif": "b2"}, r) == 2 and RegiaDati.stato_luce({"luce_modo": "tiro", "luce_rif": "b1"}, r) == 0)
	_prova("luci: missione in corso", RegiaDati.stato_luce({"luce_modo": "missione_in_corso"}, r) == 2)
	r.missioni.evento("bumper", "b2", Vector2.ZERO, 3.0)
	_prova("luci: missione fatta accesa, in corso spenta", RegiaDati.stato_luce({"luce_modo": "missione_fatta", "luce_rif": "m"}, r) == 1 and RegiaDati.stato_luce({"luce_modo": "missione_in_corso"}, r) == 0)
	r.colpiti = {"t1": true}
	r.multiball = true
	_prova("luci: pezzo colpito e multiball", RegiaDati.stato_luce({"luce_modo": "colpito", "luce_rif": "t1"}, r) == 1 and RegiaDati.stato_luce({"luce_modo": "multiball"}, r) == 1)
	var ds := {"suoni": {"bumper": "", "rampa": "combo"}, "luci_eventi": {"bumper": {"effetto": "flash", "colore": "viola"}}}
	_prova("suoni: scelto, nessuno, come prima", RegiaDati.suono(ds, "rampa") == "combo" and RegiaDati.suono(ds, "bumper") == "" and RegiaDati.suono(ds, "fionda") == null)
	var ef = RegiaDati.effetto_luce(ds, "bumper")
	_prova("luci: effetto scelto per evento (lampo viola)", ef is Array and ef[0]["tipo"] == "flash" and ef[0]["col"] == RegiaDati.COLORI["viola"] and RegiaDati.effetto_luce(ds, "rampa") == null)
	r.queue_free()
	# v0.18.3: modo «stato» (tieni vivo) ed ENERGIA
	var dst := {"bumper": [{"id": "b1"}], "missioni": [{"id": "ms", "fasi": [{"quando": {"tipo": "bumper"}, "modo": "stato", "durata": 10.0, "finestra": 3.0}], "premio": {"punti": 7000}}]}
	var rst := _m(dst)
	var mst: Mattoncini = rst[0]
	var r_st: RegoleBase = rst[1]
	mst.evento("bumper", "b1", Vector2.ZERO, 3.0)
	mst.tick(5.0)
	mst.evento("bumper", "b1", Vector2.ZERO, 5.5)
	mst.tick(9.0)                     # 3,5 s senza colpi: si spegne
	_prova("stato: troppo tempo senza colpi = si spegne", mst.stato_da < 0.0 and mst.corrente == 0)
	for k in 5:
		mst.evento("bumper", "b1", Vector2.ZERO, 10.0 + k * 2.5)
		mst.tick(10.0 + k * 2.5 + 0.1)
	_prova("stato: tenuto vivo 10 s = fase fatta", mst.completate.has("ms") and r_st.punti >= 7000)
	r_st.queue_free()
	var den := {"bumper": [{"id": "b1"}], "spinner": [{"id": "s1"}], "missioni": [{"id": "me", "energia": {"luci": 3, "cala": 2.0, "ricarica": {"tipo": "spinner"}},
		"fasi": [{"quando": {"tipo": "bumper"}, "volte": 50}]}]}
	var ren := _m(den)
	var men: Mattoncini = ren[0]
	men.tick(4.1)
	_prova("energia: cala col tempo", men.energia == 2.0 and men.riga().contains("⚡2/3"))
	men.evento("spinner", "s1", Vector2.ZERO, 4.5)
	_prova("energia: si ricarica con il tiro scelto", men.energia == 3.0)
	men.tick(6.6)
	men.tick(8.7)
	men.tick(10.8)
	_prova("energia: a zero la missione è persa", men.corrente == -1 and not men.completate.has("me"))
	ren[1].queue_free()
	# v0.17.2: evoluzioni nella collezione
	var de := {"bumper": [{"id": "b1"}], "collezione": {"nome": "Bestie", "premio_completa": 50000, "oggetti": [
		{"id": "uovo", "nome": "Uovo", "rarita": 1, "punti": 100, "evolve_in": "drago", "evolve_dopo": 3},
		{"id": "drago", "nome": "Drago", "rarita": 3, "punti": 1000}]},
		"missioni": [{"id": "mc", "fasi": [{"quando": {"tipo": "bumper"}, "volte": 99}]}]}
	var re := _m(de)
	var me: Mattoncini = re[0]
	var r_e: RegoleBase = re[1]
	var evoluto := []
	r_e.effetto.connect(func(n, _q): evoluto.append(n))
	for i in 2:
		me.cattura(Vector2.ZERO)
	_prova("evoluzione: il drago non esce mai a caso", me.presi.get("uovo", 0) == 2 and not me.presi.has("drago"))
	me.cattura(Vector2.ZERO)
	_prova("evoluzione: alla 3ª cattura l'uovo diventa drago", me.presi.has("drago") and evoluto.has("evoluzione"))
	_prova("evoluzione: così la collezione si completa", evoluto.has("collezione_completa"))
	r_e.queue_free()
	# v0.17: spettacoli di luce
	var dsp := {"spettacoli": {"Mio": {"passi": [{"dopo": 0.0, "effetto": "flash", "colore": "rosso", "dur": 0.3}, {"dopo": 0.5, "effetto": "spazzata", "colore": "verde", "dur": 0.8, "verso": "giu", "grande": true}]}},
		"luci_eventi": {"rampa": {"effetto": "spettacolo:Mio"}, "bumper": {"effetto": "spettacolo:Festa"}}}
	var es: Array = RegiaDati.effetto_luce(dsp, "rampa")
	_prova("spettacolo: due passi a tempo per l'evento", es.size() == 2 and es[1]["dopo"] == 0.5 and es[1]["verso"] == 1.0 and es[1]["grande"] and es[0]["col"] == RegiaDati.COLORI["rosso"])
	_prova("spettacolo pronto usabile senza copiarlo", RegiaDati.effetto_luce(dsp, "bumper").size() == RegiaDati.SPETTACOLI_PRONTI["Festa"].size())
	_prova("spettacolo: durata", is_equal_approx(RegiaDati.durata_spettacolo(dsp["spettacoli"]["Mio"]["passi"]), 1.3))
	var dm: Dictionary = {"bumper": [{"id": "b1"}]}
	dm["missioni"] = [{"id": "ms", "inizio": {"spettacolo": "Mio"}, "fasi": [{"quando": {"tipo": "bumper"}, "volte": 9}]}]
	var rr := _regole()
	var visti_sp: Array = []
	rr.effetto.connect(func(n, _q): visti_sp.append(n))
	var mm := Mattoncini.new(dm, rr)
	mm.nuova_partita()
	mm.inizio_pallina(0.0)
	mm.tick(2.0)
	_prova("missione: azione «spettacolo di luce»", visti_sp.has("spettacolo:Mio"))
	rr.queue_free()
	r.queue_free()

## v0.12: cambio corsia e scelta della missione con le palette.
func _palette() -> void:
	var dt: Dictionary = load("res://tests/test_motore.gd").descrizione()
	dt["sensori"] = [{"id": "c3", "pos": Vector2(300, 100), "dim": Vector2(30, 8), "gruppo": "alte"},
		{"id": "c1", "pos": Vector2(100, 100), "dim": Vector2(30, 8), "gruppo": "alte"},
		{"id": "c2", "pos": Vector2(200, 100), "dim": Vector2(30, 8), "gruppo": "alte"}]
	dt["cambio_corsie"] = [{"gruppo": "alte", "premio": {"punti": 25000, "bonus_x": 1}}]
	dt["missioni_avvio"] = {"tipo": "buca", "id": "vuk", "scelta": true}
	dt["missioni"] = [{"id": "a", "nome": "Alfa", "fasi": [{"quando": {"tipo": "corsie"}, "volte": 1}]},
		{"id": "b", "nome": "Beta", "fasi": [{"quando": {"tipo": "bumper"}, "volte": 1}]}]
	var r: RegoleBase = load(FileTavolo.REGOLE_BASE).new()
	r.tavolo = TavoloFisico.new(dt)
	r.stato = RegoleBase.GIOCO
	add_child(r)
	r.missioni = Mattoncini.new(dt, r)
	r.missioni.nuova_partita()
	r._inizio_pallina()
	r.missioni.tick(2.0)
	_prova("corsie: ordinate da sinistra a destra", r._ordine_corsie["alte"] == ["c1", "c2", "c3"])
	r._evento_tavolo("sensore", "c1", Vector2.ZERO)
	_prova("corsie: passaggio = luce accesa", r.corsia_accesa("c1") and not r.corsia_accesa("c2"))
	r.palette_premuta(1)
	_prova("corsie: paletta destra sposta la luce a destra", r.corsia_accesa("c2") and not r.corsia_accesa("c1"))
	r.palette_premuta(-1)
	r.palette_premuta(-1)
	_prova("corsie: paletta sinistra, giro completo", r.corsia_accesa("c3"))
	# le 3 palette di prima hanno anche girato la scelta: 0 → 1 → 0 → 1
	var prima_sc: int = r.missioni.pronta
	r.missioni.cambia_scelta(1)
	_prova("scelta: missione pronta, la paletta la cambia (Beta → Alfa)", prima_sc == 1 and r.missioni.pronta == 0)
	r._evento_tavolo("buca", "vuk", Vector2.ZERO)
	_prova("scelta: il tiro fa partire quella scelta (Alfa)", r.missioni.corrente == 0)
	var p0 := r.punti
	r._evento_tavolo("sensore", "c1", Vector2.ZERO)
	r._evento_tavolo("sensore", "c2", Vector2.ZERO)
	_prova("corsie: tutte accese = premio, si spengono, e la missione «corsie» è fatta", r.punti - p0 >= 25000 and r.moltiplicatore == 2 and not r.corsia_accesa("c3") and r.missioni.completate.has("a"))
	r.queue_free()

## v0.13: MODALITÀ con priorità (interrompe la missione, poi questa riprende) e tabellone in inglese.
func _modalita() -> void:
	var d := {"bumper": [{"id": "b1"}], "rampe": [{"id": "r1"}],
		"missioni": [{"id": "n1", "nome": "Normale", "fasi": [{"quando": {"tipo": "bumper"}, "volte": 1}]},
			{"id": "n2", "nome": "Lunga", "tempo": 30.0, "fasi": [{"quando": {"tipo": "bumper"}, "volte": 5}]},
			{"id": "w", "nome": "Finale", "nome_en": "Wizard", "priorita": 1, "sblocco": {"completate": 1}, "fasi": [{"quando": {"tipo": "rampa"}, "volte": 1}]}]}
	var mr := _m(d)
	var m: Mattoncini = mr[0]
	_prova("modalità: non entra nella fila delle missioni normali", m.corrente == 0)
	m.evento("bumper", "b1", Vector2.ZERO, 3.0)
	m.tick(6.0)
	_prova("modalità: dopo 1 missione normale parte da sola", m.corrente == 2)
	m.evento("rampa", "r1", Vector2.ZERO, 7.0)
	m.tick(10.0)
	_prova("modalità finita: si torna alle missioni normali", m.corrente == 1)
	m.evento("bumper", "b1", Vector2.ZERO, 10.5)
	m.evento("bumper", "b1", Vector2.ZERO, 10.6)
	m.tick(20.0)
	_prova("la modalità non riparte finché non si completa un'altra missione normale", m.corrente == 1 and m.conta == 2)
	m.normali_fatte += 1          # come se si fosse completata un'altra missione normale
	m.tick(21.0)
	_prova("modalità di nuovo sbloccata: interrompe la missione in corso", m.corrente == 2 and m.sospese.size() == 1)
	m.tick(40.0)
	m.evento("rampa", "r1", Vector2.ZERO, 40.0)
	_prova("la missione interrotta riprende da dov'era (2/5) e la pausa non consuma il suo tempo", m.corrente == 1 and m.conta == 2 and m.obiettivo(40.0).ends_with("s") and 40.0 - m.inizio_missione < 30.0)
	Testi.lingua = "en"
	_prova("inglese: nome inglese della missione e testi del tabellone", Mattoncini.nome_di(d["missioni"][2]) == "Wizard" and m.riga().begins_with("LUNGA") and Testi.t("PALLINA %d") % 2 == "BALL 2" and m.testo_fase() == "a bumper ×5")
	Testi.lingua = "it"

## v0.14: catture (collezione con rarità) e viaggi tra zone.
func _collezione_zone() -> void:
	var d := {"bumper": [{"id": "b1"}], "buche": [{"id": "k"}],
		"collezione": {"nome": "Creature", "premio_completa": 500000, "oggetti": [{"id": "a", "nome": "Drago", "rarita": 3, "punti": 1000},
			{"id": "b", "nome": "Gatto", "rarita": 1, "punti": 1000}]},
		"zone": [{"nome": "Terra"}, {"nome": "Luna"}],
		"missioni": [{"id": "c", "nome": "Cattura", "zone": [0], "fasi": [{"quando": {"tipo": "buca"}, "volte": 1}], "premio": {"cattura": true}},
			{"id": "v", "nome": "Viaggio", "zone": [0], "sblocco": {"collezione": 2}, "fasi": [{"quando": {"tipo": "bumper"}, "volte": 1}], "premio": {"zona_avanti": true}},
			{"id": "l", "nome": "Lunare", "zone": [1], "fasi": [{"quando": {"tipo": "bumper"}, "volte": 2}]}]}
	var mr := _m(d)
	var m: Mattoncini = mr[0]
	var r: RegoleBase = mr[1]
	_prova("zone: si parte dalla prima, il tabellone la mostra", m.zona == 0 and m.nome_zona() == "Terra")
	m.evento("buca", "k", Vector2.ZERO, 3.0)
	_prova("cattura: un oggetto preso, con i suoi punti", m.presi.size() == 1 and r.punti >= 1000)
	m.tick(6.0)
	_prova("sblocco «collezione»: il viaggio aspetta 2 oggetti (si ripete la cattura)", m.corrente == 0)
	m.evento("buca", "k", Vector2.ZERO, 6.5)
	_prova("cattura: prima gli oggetti mancanti → collezione completa con il premio", m.presi.size() == 2 and r.punti >= 502000)
	m.tick(10.0)
	_prova("viaggio sbloccato", m.corrente == 1)
	m.evento("bumper", "b1", Vector2.ZERO, 10.5)
	m.tick(14.0)
	_prova("viaggio: zona 2, e partono solo le missioni della Luna", m.zona == 1 and m.corrente == 2 and m.riga().begins_with("LUNARE"))
	var rr: RegoleBase = load(FileTavolo.REGOLE_BASE).new()
	rr.missioni = m
	_prova("luci: zona 2 accesa, oggetto preso acceso", RegiaDati.stato_luce({"luce_modo": "zona", "luce_parte": 2}, rr) == 1 and RegiaDati.stato_luce({"luce_modo": "preso", "luce_rif": "a"}, rr) == 1)
	rr.free()

## v0.15: scoop, deviatore sul piano e porta comandata da una missione, sul motore vero.
func _pezzi_nuovi() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Pezzi"})
	p.esegui({"comando": "aggiungi_composto", "nome": "scoop", "pos": [200, 400]})
	p.esegui({"comando": "aggiungi", "tipo": "lame", "id": "dev", "pos": [430, 420], "valori": {"angolo_a": 2.3562, "angolo_b": 0.7854}})
	p.esegui({"comando": "aggiungi", "tipo": "porte", "id": "porta1", "pos": [317, 250]})
	p.esegui({"comando": "missione_aggiungi", "missione": {"nome": "Apri", "inizio": {"apri_porta": "porta1", "lama": "dev", "lama_verso": "b"}, "fasi": [{"quando": {"tipo": "buca"}, "volte": 9}]}})
	var t := TavoloFisico.new(p.desc)
	add_child(t)
	var ev: Array = []
	t.evento.connect(func(tipo, id, _q): ev.append(tipo + ":" + id))
	await get_tree().physics_frame
	# scoop: la pallina sale dentro l'apertura, viene presa e risputata verso il basso
	var b := t.genera_pallina(Vector2(200, 560), Vector2(0, -900))
	b.dal_lancio = 9.0
	var uscita := false
	for i in 600:
		await get_tree().physics_frame
		if ev.has("buca:buca_1") and is_instance_valid(b) and not b.tenuta and b.linear_velocity.y > 300.0:
			uscita = true
			break
	_prova("scoop: presa (evento buca) e risputata verso il basso", ev.has("buca:buca_1") and uscita)
	t.togli_tutte()
	await get_tree().physics_frame
	# deviatore: la pallina lo colpisce → evento e cambio di lato
	var prima: bool = t.lame_in_b["dev"]
	var b2 := t.genera_pallina(Vector2(408, 560), Vector2(0, -1200))
	b2.dal_lancio = 9.0
	for i in 720:
		await get_tree().physics_frame
		if t.lame_in_b["dev"] != prima:
			break
	_prova("deviatore: colpito, cambia lato", ev.has("lama:dev") and t.lame_in_b["dev"] != prima)
	t.togli_tutte()
	t.queue_free()
	# porta e deviatore comandati dalla missione (regole vere)
	var t2 := TavoloFisico.new(p.desc)
	add_child(t2)
	var regole: RegoleBase = load(FileTavolo.REGOLE_BASE).new()
	regole.salva_record = false
	add_child(regole)
	regole.collega(t2)
	regole.nuova_partita()
	for i in 600:
		await get_tree().physics_frame
	_prova("missione: all'inizio apre la porta e porta il deviatore in B", t2.porte_aperte["porta1"] and t2.lame_in_b["dev"])
	regole.queue_free()
	t2.queue_free()

func _piano_staccato() -> void:
	for sotto in [false, true]:
		var p := ProgettoEditor.new()
		p.esegui({"comando": "nuovo", "modello": "base", "nome": "Piano"})
		p.esegui({"comando": "aggiungi", "tipo": "piani", "id": "pz", "punti": [[180, 300], [450, 300], [450, 480], [180, 480]]})
		if sotto:
			p.esegui({"comando": "imposta", "id": "pz", "campo": "passa_sotto", "valore": true})
		var t := TavoloFisico.new(p.desc)
		add_child(t)
		await get_tree().physics_frame
		var b := t.genera_pallina(Vector2(315, 620), Vector2(0, -1400))
		b.dal_lancio = 9.0
		var dentro := false
		var rimbalzo := false
		for i in 240:
			await get_tree().physics_frame
			if not is_instance_valid(b):
				break
			if b.livello == 0 and Geometry2D.is_point_in_polygon(b.global_position, PackedVector2Array([Vector2(190, 310), Vector2(440, 310), Vector2(440, 470), Vector2(190, 470)])):
				dentro = true
			if b.global_position.y > 490.0 and b.linear_velocity.y > 200.0 and i > 5:
				rimbalzo = true
		if sotto:
			_prova("piano sui pilastri: la pallina del tavolo ci passa sotto", dentro)
		else:
			_prova("piano staccato: la pallina del tavolo ci sbatte contro (non entra)", not dentro and rimbalzo)
			# sul piano: la pallina messa lassù resta sul piano e non cade attraverso il fianco
			t.togli_tutte()
			await get_tree().physics_frame
			var c := t.genera_pallina(Vector2(315, 400), Vector2(500, -300))
			c.dal_lancio = 9.0
			c.imposta_livello(int(p.pezzo("pz")["livello"]), 40.0)
			for i in 240:
				await get_tree().physics_frame
			_prova("piano staccato: la pallina sul piano resta sul piano", is_instance_valid(c) and c.livello > 0)
			t.queue_free()
			await get_tree().physics_frame
			# con una RAMPA che finisce dentro il piano la pallina ci sale (il fianco non la ferma)
			p.esegui({"comando": "aggiungi", "tipo": "rampe", "id": "rs", "punti": [[120, 760], [110, 560], [220, 420]]})
			t = TavoloFisico.new(p.desc)
			add_child(t)
			await get_tree().physics_frame
			var salite := 0
			for k in 3:
				var d := t.genera_pallina(Vector2(122, 830), Vector2(0, -1500.0 - 250.0 * k))
				d.dal_lancio = 9.0
				var su := false
				for i in 300:
					await get_tree().physics_frame
					if is_instance_valid(d) and d.livello > 0 and not d.sul_binario() and Geometry2D.is_point_in_polygon(d.global_position, PackedVector2Array([Vector2(180, 300), Vector2(450, 300), Vector2(450, 480), Vector2(180, 480)])):
						su = true
						break
				if su:
					salite += 1
				t.togli_tutte()
				await get_tree().physics_frame
			_prova("piano staccato: con la rampa la pallina sale sul piano (%d/3)" % salite, salite >= 2)
		t.queue_free()
		await get_tree().physics_frame

## dove è basso le sue pareti fermano la pallina del tavolo; si sale solo dalla bocca, larga come l'ingresso.
func _nastro_solido() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Nastro"})
	var rn := p.esegui({"comando": "aggiungi", "tipo": "nastri", "punti": [[315, 1005], [105, 315]]})
	var idn := str(rn.get("id", "nastro_1"))
	p.esegui({"comando": "punto", "id": idn, "indice": "ingresso", "larghezza": 200.0})
	p.esegui({"comando": "punto", "id": idn, "indice": 1, "altezza": 90.0})
	var t := TavoloFisico.new(p.desc)
	add_child(t)
	var ev: Array = []
	t.evento.connect(func(tipo, id, _q): ev.append(tipo + ":" + id))
	await get_tree().physics_frame
	# di lato, dove il nastro è basso: la pallina ci sbatte e non arriva alla linea centrale
	var centro := Vector2(315, 1005).lerp(Vector2(105, 315), 0.25)
	var b := t.genera_pallina(centro + Vector2(150, 0), Vector2(-1500, 0))
	b.dal_lancio = 9.0
	var passata := false
	for i in 120:
		await get_tree().physics_frame
		if is_instance_valid(b) and not b.sul_binario() and b.global_position.x < centro.x:
			passata = true
	_prova("nastro alzato: di lato la pallina ci sbatte (non lo attraversa)", not passata)
	t.togli_tutte()
	await get_tree().physics_frame
	# dalla bocca larga, anche lontano dal centro: la pallina sale sul nastro
	var dir := (Vector2(105, 315) - Vector2(315, 1005)).normalized()
	var lato := dir.orthogonal()
	var salite := 0
	for off in [-70.0, 0.0, 70.0]:
		ev.clear()
		var c := t.genera_pallina(Vector2(315, 1005) - dir * 60.0 + lato * off, dir * 1900.0)
		c.dal_lancio = 9.0
		var su := false
		for i in 240:
			await get_tree().physics_frame
			if is_instance_valid(c) and c.sul_binario() and c.altezza > 40.0:
				su = true
				break
		if su:
			salite += 1
		t.togli_tutte()
		await get_tree().physics_frame
	_prova("nastro alzato: dalla bocca larga si sale anche di lato (%d/3)" % salite, salite == 3)
	t.queue_free()
	await get_tree().physics_frame

## v0.17.2: pallina prigioniera aggiunta dall'editor, sul motore vero.
func _prigioniera() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Prigioniera"})
	var r := p.esegui({"comando": "aggiungi", "tipo": "captive", "pos": [317, 420]})
	var id := str(r.get("id", ""))
	_prova("prigioniera: aggiunta con canale, fermo e bersaglio", r["ok"] and p.pezzo(id).has("bersaglio") and p.desc["muri"].filter(func(m): return str(m.get("da_captive", "")) == id).size() == 1)
	_prova("prigioniera: il canale non dà varchi pericolosi", ControlliEditor.varchi(p.desc).filter(func(v): return id + "@canale" in v["pezzi"]).is_empty())
	var t := TavoloFisico.new(p.desc)
	add_child(t)
	var ev: Array = []
	t.evento.connect(func(tipo, i, _q): ev.append(tipo + ":" + i))
	await get_tree().physics_frame
	var b := t.genera_pallina(Vector2(317, 600), Vector2(0, -1600))
	b.dal_lancio = 9.0
	for i in 240:
		await get_tree().physics_frame
		if ev.has("captive:" + id):
			break
	_prova("prigioniera: colpita, corre al bersaglio in fondo (evento)", ev.has("captive:" + id))
	var dentro := false
	for i in 240:
		await get_tree().physics_frame
		if is_instance_valid(b) and b.global_position.distance_to(Vector2(317, 420 - 45)) < 30.0:
			dentro = true
	var cb: Node2D = t.captive[id]
	_prova("prigioniera: la pallina di gioco non entra nel canale, la prigioniera torna a casa", not dentro and cb.global_position.distance_to(Vector2(317, 420)) < 20.0)
	t.queue_free()
	await get_tree().physics_frame

## v0.19: bumper OVALE (elemento da immagine): la pallina sbatte sulla forma vera, non sul cerchio.
func _bumper_ovale() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Ovale"})
	p.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "ov", "pos": [317, 400], "valori": {"raggio": 60.0, "raggio_y": 15.0, "forza": 900.0}})
	var t := TavoloFisico.new(p.desc)
	add_child(t)
	var ev: Array = []
	t.evento.connect(func(tipo, id, _q): ev.append(tipo + ":" + id))
	await get_tree().physics_frame
	var b := t.genera_pallina(Vector2(357, 600), Vector2(0, -1500))
	b.dal_lancio = 9.0
	var min_y := 9999.0
	for i in 200:
		await get_tree().physics_frame
		if is_instance_valid(b):
			min_y = minf(min_y, b.global_position.y)
	_prova("bumper ovale: colpito sulla forma ovale (non sul cerchio grande)", ev.has("bumper:ov") and min_y > 400.0 + 15.0 and min_y < 400.0 + 45.0)
	t.queue_free()
	await get_tree().physics_frame

## v0.19: rampa da immagine: pareti larghe come il disegno, la pallina sale entrando di lato e arriva in cima.
func _rampa_da_immagine() -> void:
	var img := Image.create(120, 300, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.5, 0.9))
	var f := ProjectSettings.globalize_path("user://rampa_prova.png")
	img.save_png(f)
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "RampaImg"})
	var r := p.esegui({"comando": "elemento_da_immagine", "file": f, "categoria": "rampa", "pos": [200, 600]})
	var ra := p.pezzo(str(r.get("id", "")))
	_prova("rampa da immagine: creata con immagine e larghezza del disegno", r["ok"] and PittorePezzi.sostituisce(ra) and float(ra["larghezza"]) >= 34.0)
	var t := TavoloFisico.new(p.desc)
	add_child(t)
	await get_tree().physics_frame
	var bin: Binario = t.rampe[ra["id"]]
	_prova("rampa da immagine: il motore usa la sua larghezza", bin.larga() and is_equal_approx(bin.mezza(0.0), float(ra["larghezza"]) * 0.5))
	var a: Vector3 = ra["punti"][0]
	var b: Vector3 = ra["punti"][1]
	var dir := (Vector2(b.x, b.y) - Vector2(a.x, a.y)).normalized()
	var bp := t.genera_pallina(Vector2(a.x, a.y) - dir * 50.0 + dir.orthogonal() * float(ra["larghezza"]) * 0.3, dir * 2200.0)
	bp.dal_lancio = 9.0
	var su := false
	for i in 300:
		await get_tree().physics_frame
		if is_instance_valid(bp) and bp.sul_binario() and bp.altezza > 30.0:
			su = true
			break
	_prova("rampa da immagine: la pallina entra di lato e sale", su)
	t.queue_free()
	await get_tree().physics_frame


func _segreti_e_classifica() -> void:
	var d := {"segreti": [
		{"id": "raf", "nome": "Raffica", "tipo": "raffica", "quando": {"tipo": "bumper"}, "volte": 3, "secondi": 2.0, "punti": 100},
		{"id": "fila", "nome": "Fila", "tipo": "di_fila", "ids": ["r1", "b1", "r1"], "punti": 100},
		{"id": "entro", "nome": "Entro", "tipo": "entro", "primo": "kb", "poi": "r1", "secondi": 5.0, "punti": 100},
		{"id": "tutti", "nome": "Tutti", "tipo": "tutti", "ids": ["s1", "s2"], "punti": 100}]}
	var sg := Segreti.new(d)
	sg.azzera_partita()
	sg.evento("bumper", "x", 0.0)
	sg.evento("bumper", "y", 3.0)
	_prova("segreto raffica: colpi lenti non bastano", sg.evento("bumper", "x", 3.5).is_empty())
	_prova("segreto raffica: 3 colpi in 2 s lo scoprono", sg.evento("bumper", "x", 4.0).size() == 1 and sg.scoperti.has("raf"))
	_prova("segreto: una volta sola per partita", sg.evento("bumper", "x", 4.1).is_empty() and sg.evento("bumper", "x", 4.2).is_empty())
	sg.evento("rampa", "r1", 5.0)
	sg.evento("buca", "zz", 5.5)                         # (pezzo fuori elenco: non interrompe)
	sg.evento("rampa", "r1", 6.0)                        # sbagliato: riparte da r1
	sg.evento("buca", "b1", 6.5)
	_prova("segreto di fila: rampa, buca, rampa", sg.evento("rampa", "r1", 7.0).any(func(x): return x["id"] == "fila"))
	sg.evento("kickback", "kb", 10.0)
	_prova("segreto entro: troppo tardi non vale", not sg.evento("rampa", "r1", 16.0).any(func(x): return x["id"] == "entro"))
	sg.evento("kickback", "kb", 20.0)
	_prova("segreto entro: rampa entro 5 s dal kickback", sg.evento("rampa", "r1", 22.0).any(func(x): return x["id"] == "entro"))
	sg.evento("sensore", "s1", 30.0)
	sg.azzera_pallina()
	_prova("segreto tutti: la pallina nuova ricomincia", sg.evento("sensore", "s2", 31.0).is_empty())
	_prova("segreto tutti: tutti nella stessa pallina", sg.evento("sensore", "s1", 32.0).size() == 1)
	sg.azzera_partita()
	_prova("partita nuova: i segreti si possono riscoprire", sg.scoperti.is_empty())
	# classifica (senza file)
	var cl := ClassificaTavolo.new("prova_test", false)
	_prova("classifica: vuota = 10 posti liberi, 0 punti fuori", cl.voci.size() == 10 and cl.posizione(0) == -1 and cl.posizione(500) == 0)
	cl.inserisci("ABC", 5000)
	cl.inserisci("XYZ", 9000)
	_prova("classifica: in ordine dal migliore", cl.voci[0][0] == "XYZ" and cl.voci[1][0] == "ABC" and cl.posizione(6000) == 1)
	_prova("classifica: testo per il menu", cl.testo().begins_with(" 1.  XYZ"))
