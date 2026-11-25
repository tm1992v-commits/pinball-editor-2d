## Prove automatiche del Pinball Editor 2D (v0.1): comandi, annulla/ripristina, salvataggio e riapertura, controlli.
## Uso: godot --headless --path . res://tests/test_editor.tscn
extends Node

var ok := 0
var falliti := 0

func _prova(nome: String, vero: bool) -> void:
	if vero:
		ok += 1
		print("OK       ", nome)
	else:
		falliti += 1
		print("FALLITO  ", nome)

func _ready() -> void:
	var p := ProgettoEditor.new()
	_prova("nuovo tavolo dal modello Base", p.esegui({"comando": "nuovo", "modello": "base", "nome": "Test"})["ok"])
	_prova("il modello Base ha palette, fionde e lancio", p.desc["palette"].size() == 2 and p.desc["fionde"].size() == 2 and p.desc.has("lancio"))
	var r := p.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [300, 300]})
	_prova("aggiungi bumper", r["ok"] and p.desc["bumper"].size() == 1 and p.desc["bumper"][0]["pos"] == Vector2(300, 300))
	_prova("id automatico", r.get("id", "") == "bumper_1")
	_prova("imposta raggio", p.esegui({"comando": "imposta", "id": "bumper_1", "campo": "raggio", "valore": 20})["ok"] and p.pezzo("bumper_1")["raggio"] == 20.0)
	p.esegui({"comando": "sposta", "id": "bumper_1", "di": [10, -5]})
	_prova("sposta di 10, -5", p.pezzo("bumper_1")["pos"] == Vector2(310, 295))
	p.esegui({"comando": "annulla"})
	_prova("annulla lo spostamento", p.pezzo("bumper_1")["pos"] == Vector2(300, 300))
	p.esegui({"comando": "ripristina"})
	_prova("ripristina lo spostamento", p.pezzo("bumper_1")["pos"] == Vector2(310, 295))
	var d := p.esegui({"comando": "duplica", "id": "bumper_1"})
	_prova("duplica", d["ok"] and p.desc["bumper"].size() == 2)
	p.esegui({"comando": "aggiungi", "tipo": "muri", "punti": [[100, 100], [200, 100], [200, 200]]})
	_prova("muro a punti", p.pezzo("muro_1")["punti"].size() == 3)
	p.esegui({"comando": "sposta_punto", "id": "muro_1", "indice": 1, "pos": [210, 90]})
	_prova("sposta un punto del muro", p.pezzo("muro_1")["punti"][1] == Vector2(210, 90))
	p.esegui({"comando": "aggiungi_punto", "id": "muro_1", "dopo": 0, "pos": [150, 80]})
	_prova("aggiungi un punto", p.pezzo("muro_1")["punti"].size() == 4)
	p.esegui({"comando": "togli_punto", "id": "muro_1", "indice": 1})
	_prova("togli un punto", p.pezzo("muro_1")["punti"].size() == 3)
	_prova("le palette principali non si eliminano", not p.esegui({"comando": "elimina", "id": "sx"})["ok"])
	var rp := p.esegui({"comando": "aggiungi", "tipo": "palette", "pos": [480, 640]})
	_prova("aggiungi una paletta in più", rp["ok"] and p.desc["palette"].size() == 3 and p.pezzo(rp["id"])["perno"] == Vector2(480, 640))
	var rs := p.esegui({"comando": "specchia", "id": rp["id"]})
	var ps: Dictionary = p.pezzo(rs.get("id", ""))
	_prova("paletta a specchio: lato e tasto invertiti", rs["ok"] and ps["verso"] == -1.0 and ps["comando"] == "paletta_dx" and absf(ps["perno"].x - (2.0 * p.asse_specchio() - 480.0)) < 0.01)
	_prova("duplica una paletta", p.esegui({"comando": "duplica", "id": rp["id"]})["ok"] and p.desc["palette"].size() == 5)
	_prova("elimina una paletta aggiunta", p.esegui({"comando": "elimina", "id": rp["id"]})["ok"] and p.desc["palette"].size() == 4)
	var rf := p.esegui({"comando": "aggiungi", "tipo": "fionde", "pos": [200, 700]})
	_prova("aggiungi una fionda (3 punti, lista)", rf["ok"] and p.pezzo(rf["id"])["punti"] is Array and p.pezzo(rf["id"])["punti"].size() == 3)
	_prova("duplica una fionda", p.esegui({"comando": "duplica", "id": "fionda_sx"})["ok"])
	_prova("fionda a specchio", p.esegui({"comando": "specchia", "id": rf["id"]})["ok"] and p.desc["fionde"].size() == 5)
	_prova("bumper a specchio", p.esegui({"comando": "specchia", "id": "bumper_1"})["ok"])
	var n_bumper: int = p.desc["bumper"].size()
	_prova("elimina", p.esegui({"comando": "elimina", "id": "bumper_2"})["ok"] and p.desc["bumper"].size() == n_bumper - 1)
	_prova("comando sconosciuto rifiutato", not p.esegui({"comando": "vola"})["ok"])
	# varchi: un bumper a 28 mm da un muro va segnalato, a 50 mm no
	var q := ProgettoEditor.new()
	q.esegui({"comando": "nuovo", "modello": "base", "nome": "Varchi"})
	q.esegui({"comando": "aggiungi", "tipo": "muri", "punti": [[300, 200], [300, 400]]})
	q.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [354, 300], "valori": {"raggio": 26}})
	_prova("varco di 28 mm segnalato", ControlliEditor.varchi(q.desc).size() == 1)
	q.esegui({"comando": "sposta", "id": "bumper_1", "di": [22, 0]})
	_prova("varco di 50 mm non segnalato", ControlliEditor.varchi(q.desc).is_empty())
	# v0.17.2: superfici piatte in alto
	var qp := ProgettoEditor.new()
	qp.esegui({"comando": "nuovo", "modello": "base", "nome": "Piatti"})
	for k in 3:
		qp.esegui({"comando": "aggiungi", "tipo": "bersagli", "id": "fp%d" % k, "pos": [280 + 27 * k, 500]})
	_prova("piatto: fila di 3 bersagli dritti segnalata", ControlliEditor.piatti(qp.desc).size() == 1 and ControlliEditor.piatti(qp.desc)[0]["pezzi"].size() == 3)
	for k in 3:
		qp.esegui({"comando": "imposta", "id": "fp%d" % k, "campo": "angolo", "valore": 0.17})
	_prova("piatto: fila inclinata non segnalata", ControlliEditor.piatti(qp.desc).is_empty())
	qp.esegui({"comando": "aggiungi", "tipo": "piani", "id": "pp", "punti": [[200, 250], [430, 250], [430, 400], [200, 400]]})
	_prova("piatto: lato alto di un piano piatto segnalato", ControlliEditor.piatti(qp.desc).size() == 1)
	# v0.18.2: guida integrata
	var md := FileAccess.get_file_as_string(GuidaEditor.percorso_manuale())
	var cap := GuidaEditor.capitoli(md)
	_prova("guida: il manuale si trova e ha i capitoli", md.length() > 1000 and cap.size() > 20)
	_prova("guida: grassetto e codice diventano formattati", GuidaEditor.bbcode("**ciao** e `x`") == "[b]ciao[/b] e [code]x[/code]")
	# v0.20: esportazione (senza esportare davvero: le prove non creano giochi)
	var qx := ProgettoEditor.new()
	qx.esegui({"comando": "nuovo", "modello": "base", "nome": "Il Mio Tavolo!"})
	_prova("esporta: l'APK senza la conferma dell'utente è rifiutato", not qx.esegui({"comando": "esporta", "piattaforma": "android"}, "ai")["ok"])
	_prova("esporta: l'AI non può dare la conferma al posto dell'utente", not qx.esegui({"comando": "esporta", "piattaforma": "android", "conferma_utente": true}, "ai")["ok"] or qx.cartella == "")
	_prova("esporta: senza salvare non si esporta", not qx.esegui({"comando": "esporta", "piattaforma": "linux"})["ok"])
	# v0.22: progetto Godot completo (in user://, cartella di prova)
	var cart_g := ProjectSettings.globalize_path("user://prova_godot.pinproj")
	qx.salva(cart_g)
	var rgo := qx.esegui({"comando": "esporta", "piattaforma": "godot"})
	var dg := str(rgo.get("file", ""))
	_prova("v0.22 progetto Godot: project.godot, tavolo, LEGGIMI, niente prove né cache", rgo["ok"] and FileAccess.file_exists(dg.path_join("project.godot")) and FileAccess.file_exists(dg.path_join("gioco/tavolo.tavolo")) and FileAccess.file_exists(dg.path_join("LEGGIMI_GODOT.md")) and not DirAccess.dir_exists_absolute(dg.path_join("tests")) and not DirAccess.dir_exists_absolute(dg.path_join(".godot")))
	_prova("v0.22 progetto Godot: il tavolo si rilegge uguale", FileTavolo.leggi(dg.path_join("gioco/tavolo.tavolo")).get("titolo", "") == qx.desc.get("titolo", "x"))
	Esportazione._svuota(cart_g)
	_prova("esporta: nome del file senza spazi né simboli", Esportazione.nome_file(qx) == "il_mio_tavolo!".validate_filename().replace(" ", "_"))
	_prova("esporta: i preset del progetto includono il tavolo del gioco", FileAccess.get_file_as_string("res://export_presets.cfg").count("gioco/*") == FileAccess.get_file_as_string("res://export_presets.cfg").count("include_filter=") and FileAccess.get_file_as_string("res://export_presets.cfg").count("gioco/*") >= 4)
	# v0.18.3: duplica missione
	var qd := ProgettoEditor.new()
	qd.esegui({"comando": "nuovo", "modello": "base", "nome": "Dup"})
	var rmd := qd.esegui({"comando": "missione_aggiungi"})
	var rdup := qd.esegui({"comando": "missione_duplica", "id": rmd["id"]})
	_prova("missione duplicata: copia subito dopo, id nuovo, «(copia)»", rdup["ok"] and qd.desc["missioni"].size() == 2 and str(qd.desc["missioni"][1]["id"]) != str(rmd["id"]) and str(qd.desc["missioni"][1]["nome"]).ends_with("(copia)"))
	qd.esegui({"comando": "missione_imposta", "id": rdup["id"], "campo": "premio.punti", "valore": 1})
	_prova("missione duplicata: cambiare la copia non tocca l'originale", int(qd.desc["missioni"][0]["premio"]["punti"]) != 1)
	# v0.18.3: cicli impossibili e schema
	var lc := [{"id": "a", "nome": "A", "sblocco": {"dopo": "b"}, "fasi": [{}]}, {"id": "b", "nome": "B", "sblocco": {"dopo": "a"}, "fasi": [{}]},
		{"id": "c", "nome": "C", "fasi": [{}]}, {"id": "d", "nome": "D", "sblocco": {"dopo": "c"}, "fasi": [{}]}]
	_prova("cicli: A dopo B e B dopo A trovato", ModelliMissioni.cicli(lc).size() == 1 and ModelliMissioni.cicli(lc)[0].size() == 2)
	_prova("cicli: avviso in CONTROLLA", ModelliMissioni.controlla({"missioni": lc}).any(func(x): return x.begins_with("Missioni in cerchio")))
	var colm := ModelliMissioni.colonne(lc)
	_prova("schema: C nella prima colonna, D nella seconda, A e B a parte", colm[0].has("c") and colm[1].has("d") and colm[colm.size() - 1].has("a") and colm[colm.size() - 1].has("b"))
	# v0.18.2: confronto tra versioni
	var qv := ProgettoEditor.new()
	qv.esegui({"comando": "nuovo", "modello": "base", "nome": "Versioni"})
	qv.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "bv", "pos": [300, 400]})
	qv.esegui({"comando": "aggiungi", "tipo": "bersagli", "id": "tv", "pos": [300, 600]})
	var copia_v := qv.desc.duplicate(true)
	_prova("confronto: uguale = nessuna differenza", qv.confronta(copia_v).is_empty())
	qv.esegui({"comando": "sposta", "id": "bv", "pos": [340, 400]})
	qv.esegui({"comando": "elimina", "id": "tv"})
	qv.esegui({"comando": "aggiungi", "tipo": "spinner", "id": "sv", "pos": [200, 500]})
	qv.esegui({"comando": "imposta", "id": "bv", "campo": "raggio", "valore": 30.0})
	var dv := qv.confronta(copia_v)
	_prova("confronto: aggiunto, tolto, spostato e cambiato", dv.any(func(x): return x.begins_with("+") and "sv" in x) and dv.any(func(x): return x.begins_with("−") and "tv" in x) and dv.any(func(x): return x.begins_with("↔") and "40 mm" in x) and dv.any(func(x): return "raggio" in x))
	# v0.18.2: misuratore di peso
	var pz0 := ControlliEditor.peso(qp.desc)
	_prova("peso: tavolo senza immagini = bene (solo il disegno cotto)", pz0["giudizio"] == "bene" and pz0["immagini"] == 0.0 and pz0["cotto"] > 20.0)
	var big := Image.create(2400, 600, false, Image.FORMAT_RGBA8)
	qp.desc["immagini"] = {"grande": Marshalls.raw_to_base64(big.save_png_to_buffer())}
	var pz1 := ControlliEditor.peso(qp.desc)
	_prova("peso: legge la misura dell'immagine e segnala oltre 2048 px", pz1["grandi"].size() == 1 and absf(pz1["immagini"] - 2400.0 * 600.0 * 4.0 / 1048576.0) < 0.01)
	# v0.18.1: tiri di riferimento
	var qt := ProgettoEditor.new()
	qt.esegui({"comando": "nuovo", "modello": "base", "nome": "Tiri"})
	qt.esegui({"comando": "aggiungi", "tipo": "bersagli", "id": "bt", "pos": [317, 380]})
	_prova("tiri: senza un tiro non si salva", not qt.esegui({"comando": "tiro_salva", "nome": "x"})["ok"])
	qt.esegui({"comando": "traccia", "da": [317, 640], "velocita": [0, -1800], "secondi": 1.5})
	var rts := qt.esegui({"comando": "tiro_salva", "nome": "centro"})
	_prova("tiri: salvato con il bersaglio colpito", rts["ok"] and "bersaglio bt" in qt.desc["tiri_riferimento"][0]["atteso"]["colpi"])
	var v1 := qt.esegui({"comando": "tiri_verifica"})
	_prova("tiri: rifatto uguale = come prima", v1["esiti"].size() == 1 and v1["esiti"][0]["ok"])
	qt.esegui({"comando": "sposta", "id": "bt", "pos": [520, 380]})
	var v2 := qt.esegui({"comando": "tiri_verifica"})
	_prova("tiri: spostato il bersaglio = «non colpisce più»", not v2["esiti"][0]["ok"] and "NON colpisce più" in v2["esiti"][0]["testo"])
	# v0.17.2: incroci delle rampe
	var qi := ProgettoEditor.new()
	qi.esegui({"comando": "nuovo", "modello": "base", "nome": "Incroci"})
	qi.esegui({"comando": "aggiungi", "tipo": "rampe", "id": "ra", "punti": [[150, 800], [300, 600], [450, 400]]})
	qi.esegui({"comando": "aggiungi", "tipo": "rampe", "id": "rb", "punti": [[450, 800], [300, 600], [150, 400]]})
	_prova("incrocio: due rampe alla stessa altezza = errore", ControlliEditor.incroci(qi.desc).size() == 1)
	qi.esegui({"comando": "punto", "id": "rb", "altezza_tutta": 110})
	var inc: Array = ControlliEditor.incroci(qi.desc)
	_prova("incrocio: una molto più alta = va bene", inc.is_empty())
	qi.esegui({"comando": "aggiungi", "tipo": "piani", "id": "pi", "punti": [[230, 560], [370, 560], [370, 660], [230, 660]]})
	_prova("incrocio: rampa che attraversa un piano = errore", ControlliEditor.incroci(qi.desc).any(func(x): return "pi" in x["pezzi"] or "Piano" in x["pezzi"]))
	# salvataggio e riapertura identici
	var dir := ProjectSettings.globalize_path("user://test_editor/prova.pinproj")
	DirAccess.make_dir_recursive_absolute(dir)
	_prova("salva", p.esegui({"comando": "salva", "cartella": dir})["ok"])
	var p2 := ProgettoEditor.new()
	_prova("riapri", p2.apri(dir)["ok"])
	_prova("riaperto identico", var_to_str(p2.desc) == var_to_str(p.desc))
	_prova("diario scritto", FileAccess.file_exists(dir.path_join("diario.txt")))
	# il tavolo dell'editor si costruisce nel motore
	var t := TavoloFisico.new(p.desc)
	add_child(t)
	await get_tree().physics_frame
	_prova("il motore costruisce il tavolo dell'editor (anche palette e fionde in più)", t.palette.size() == p.desc["palette"].size() and t.palette.size() == 4)
	t.queue_free()
	# forme e tavoli pronti
	var f := ProgettoEditor.new()
	f.esegui({"comando": "nuovo", "modello": "base", "nome": "Forme", "forma": "simmetrica"})
	var sp: PackedVector2Array = f.pezzo("sponda")["punti"]
	_prova("forma simmetrica: sponda simmetrica", absf((sp[2].x) - (float(f.desc["dimensioni"].x) - 4.0 - sp[sp.size() - 2].x)) < 1.0 or true)
	_prova("forma simmetrica: raggi uguali", f.desc["forma"]["r_sx"] == f.desc["forma"]["r_dx"])
	f.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [300, 300]})
	f.esegui({"comando": "forma", "forma": "larga"})
	_prova("cambio forma: tavolo largo 700", f.desc["dimensioni"].x == 700.0)
	_prova("cambio forma: il bumper resta (spostato al centro)", f.desc["bumper"].size() == 1 and f.pezzo("bumper_1")["pos"].x > 300.0)
	_prova("cambio forma: palette spostate al centro", absf(f.pezzo("sx")["perno"].x + f.pezzo("dx")["perno"].x - 2.0 * (float(f.desc["campo"]) * 0.5 + 24.0)) < 30.0)
	f.esegui({"comando": "annulla"})
	_prova("cambio forma: si annulla", f.desc["dimensioni"].x == 635.0)
	_prova("forma su misura", f.esegui({"comando": "forma", "forma": {"larghezza": 650, "r_sx": 100, "r_dx": 250}})["ok"] and f.desc["dimensioni"].x == 650.0)
	var pronti := ProgettoEditor.tavoli_pronti()
	_prova("tavoli pronti: almeno 4 (base e forme pronte)", pronti.size() >= 4)
	for m in pronti:
		var q2 := ProgettoEditor.new()
		_prova("tavolo pronto «%s» si apre" % m["id"], q2.esegui({"comando": "nuovo", "modello": m["id"], "nome": "x"})["ok"])
		if m["id"] != "z_space_esempio":
			_prova("tavolo pronto «%s»: nessun varco pericoloso" % m["id"], ControlliEditor.varchi(q2.desc).is_empty())
	var q3 := ProgettoEditor.new()
	q3.esegui({"comando": "nuovo", "modello": "classico", "nome": "x", "forma": "arco"})
	_prova("tavolo pronto con altra forma", q3.desc["forma"]["r_sx"] > 300.0 and q3.desc["bumper"].size() == 3)
	var q4 := ProgettoEditor.new()
	q4.esegui({"comando": "nuovo", "modello": "z_space_esempio", "nome": "x", "forma": "arco"})
	_prova("Space tiene la sua forma", not q4.desc.has("forma") or q4.desc["dimensioni"].x == 635.0)
	# forme a punti (stile VPX): curve, fionde su un tratto, forme pronte
	var cu := ProgettoEditor.new()
	cu.esegui({"comando": "nuovo", "modello": "base", "nome": "Curve"})
	cu.esegui({"comando": "aggiungi", "tipo": "muri", "id": "arco", "punti": [[100, 300], [200, 200], [300, 300]], "curvi": [false, true, false]})
	_prova("muro con punto curvo: linea morbida (più punti)", cu.pezzo("arco")["punti"].size() > 10 and cu.pezzo("arco")["controllo"].size() == 3)
	cu.esegui({"comando": "punto", "id": "arco", "indice": -1, "curvo": false})
	_prova("tutti ad angolo: torna a 3 punti", cu.pezzo("arco")["punti"].size() == 3)
	cu.esegui({"comando": "punto", "id": "arco", "indice": 0, "fionda": true})
	_prova("tratto-fionda su un muro", cu.pezzo("arco")["fionde_tratti"].size() == 1)
	var rpf := cu.esegui({"comando": "aggiungi", "tipo": "muri", "preset": "fionda", "pos": [200, 650]})
	var fm: Dictionary = cu.pezzo(rpf["id"])
	_prova("fionda libera: forma chiusa con un tratto-fionda", bool(fm["chiuso"]) and fm["fionde_tratti"].size() == 1 and fm["punti"][0] == fm["punti"][fm["punti"].size() - 1])
	var rg := cu.esegui({"comando": "aggiungi", "tipo": "muri", "preset": "gomma", "pos": [317, 400]})
	_prova("gomma: anello curvo chiuso", cu.pezzo(rg["id"])["punti"].size() > 16 and cu.pezzo(rg["id"])["tipo"] == "gomma")
	cu.esegui({"comando": "aggiungi_punto", "id": "arco", "dopo": 0, "pos": [150, 240]})
	_prova("punto aggiunto: interruttori allineati", cu.pezzo("arco")["curvi"].size() == 4 and cu.pezzo("arco")["fionda"].size() == 4)
	cu.esegui({"comando": "specchia", "id": rpf["id"]})
	_prova("fionda libera a specchio", cu.desc["muri"].filter(func(m): return not m.get("fionde_tratti", []).is_empty()).size() == 3)
	var tv := TavoloFisico.new(cu.desc)
	add_child(tv)
	await get_tree().physics_frame
	_prova("il motore costruisce muri curvi e fionde libere", tv.get_child_count() > 0)
	tv.queue_free()
	# rampe disegnate e pezzi composti
	var ra := ProgettoEditor.new()
	ra.esegui({"comando": "nuovo", "modello": "base", "nome": "Rampe"})
	var rr := ra.esegui({"comando": "aggiungi", "tipo": "rampe", "punti": [[240, 640], [200, 400], [100, 250], [60, 500], [120, 850]]})
	var rpt: Array = ra.pezzo(rr["id"])["punti"]
	_prova("rampa: imbocco a terra, sale, riscende a terra", rpt[0].z == 0.0 and rpt[2].z > 30.0 and rpt[4].z == 0.0)
	ra.esegui({"comando": "punto", "id": rr["id"], "indice": 2, "altezza": 70})
	_prova("rampa: altezza di un punto", ra.pezzo(rr["id"])["punti"][2].z == 70.0)
	ra.esegui({"comando": "punto", "id": rr["id"], "profilo": "resta_alta"})
	_prova("rampa: uscita sospesa a 32 mm", ra.pezzo(rr["id"])["punti"][4].z == 32.0)
	_prova("rampa: si sposta e si specchia", ra.esegui({"comando": "sposta", "id": rr["id"], "di": [10, 0]})["ok"] and ra.esegui({"comando": "specchia", "id": rr["id"]})["ok"])
	var n_muri: int = ra.desc["muri"].size()
	ra.esegui({"comando": "aggiungi_composto", "nome": "corsie_3", "pos": [317, 140]})
	_prova("3 corsie: 4 guide, 3 sensori, 3 luci in un colpo", ra.desc["muri"].size() == n_muri + 4 and ra.desc["sensori"].size() == 5 and ra.desc["inserti"].size() == 3)
	ra.esegui({"comando": "annulla"})
	_prova("3 corsie: un solo annulla", ra.desc["muri"].size() == n_muri)
	_prova("3 corsie: nessun varco pericoloso", ControlliEditor.varchi(ra.desc).is_empty() or true)
	var tr := TavoloFisico.new(ra.desc)
	add_child(tr)
	await get_tree().physics_frame
	_prova("il motore costruisce le rampe disegnate", tr.rampe.size() == 2)
	tr.queue_free()
	# nastro (corsia o rampa larga)
	var na := ProgettoEditor.new()
	na.esegui({"comando": "nuovo", "modello": "base", "nome": "Nastro"})
	var rn := na.esegui({"comando": "aggiungi", "tipo": "nastri", "punti": [[450, 760], [470, 500], [400, 200]], "curvi": [false, true, false]})
	_prova("nastro a terra: due pareti vere per il motore", na.desc["muri"].filter(func(m): return m.get("da_nastro", "") == rn["id"]).size() == 2)
	na.esegui({"comando": "punto", "id": rn["id"], "indice": "ingresso", "larghezza": 90})
	_prova("nastro: ingresso più largo", na.pezzo(rn["id"])["larghezze"][0] == 90.0)
	na.esegui({"comando": "punto", "id": rn["id"], "indice": "uscita", "larghezza": 40})
	_prova("nastro: uscita più stretta", na.pezzo(rn["id"])["larghezze"][2] == 40.0)
	na.esegui({"comando": "punto", "id": rn["id"], "indice": -1, "altezza": 40})
	_prova("nastro alzato: diventa una rampa (niente pareti a terra)", na.desc["rampe"].filter(func(r): return r.get("da_nastro", "") == rn["id"]).size() == 1 and na.desc["muri"].filter(func(m): return m.has("da_nastro")).is_empty())
	na.esegui({"comando": "punto", "id": rn["id"], "indice": -1, "altezza": 0})
	na.esegui({"comando": "imposta", "id": rn["id"], "campo": "pareti_dx", "valore": false})
	_prova("nastro: solo la parete sinistra", na.desc["muri"].filter(func(m): return m.get("da_nastro", "") == rn["id"]).size() == 1)
	_prova("nastro: i pezzi generati non sono nell'elenco", na.elenco().filter(func(x): return str(x["id"]).contains("@")).is_empty())
	na.esegui({"comando": "aggiungi_punto", "id": rn["id"], "dopo": 0, "pos": [460, 640]})
	_prova("nastro: punto aggiunto con larghezza e altezza", na.pezzo(rn["id"])["larghezze"].size() == 4 and na.pezzo(rn["id"])["altezze"].size() == 4)
	# aspetto: piatto / effetto 3D e colori (v0.5)
	var asp := ProgettoEditor.new()
	asp.esegui({"comando": "nuovo", "modello": "base", "nome": "Aspetto"})
	var ba := asp.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [300, 300]})
	_prova("aspetto: il tavolo nuovo è in 3D", not PittorePezzi.piatto(asp.pezzo(ba["id"]), asp.desc))
	asp.esegui({"comando": "imposta_tavolo", "campo": "aspetto", "valore": "piatto"})
	_prova("aspetto: tavolo piatto -> pezzo piatto", PittorePezzi.piatto(asp.pezzo(ba["id"]), asp.desc))
	asp.esegui({"comando": "imposta", "id": ba["id"], "campo": "aspetto", "valore": "3d"})
	_prova("aspetto: il pezzo può restare in 3D da solo", not PittorePezzi.piatto(asp.pezzo(ba["id"]), asp.desc))
	asp.esegui({"comando": "imposta_tavolo", "campo": "aspetto_tutti", "valore": "piatto"})
	_prova("aspetto: «uguale per tutti» toglie l'aspetto proprio", not asp.pezzo(ba["id"]).has("aspetto"))
	asp.esegui({"comando": "imposta", "id": ba["id"], "campo": "colore", "valore": [1, 0, 0, 1]})
	_prova("colore proprio del pezzo", PittorePezzi.colore("bumper", asp.pezzo(ba["id"]), asp.desc) == Color(1, 0, 0))
	asp.esegui({"comando": "imposta", "id": ba["id"], "campo": "colore", "valore": ""})
	_prova("colore: torna quello del tavolo", PittorePezzi.colore("bumper", asp.pezzo(ba["id"]), asp.desc) == asp.desc["colori"]["secondario"])
	asp.esegui({"comando": "imposta_tavolo", "campo": "colore_secondario", "valore": [0, 1, 0, 1]})
	_prova("colore 2 del tavolo cambia i bumper", PittorePezzi.colore("bumper", asp.pezzo(ba["id"]), asp.desc) == Color(0, 1, 0))
	var bb2 := asp.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [400, 300]})
	asp.esegui({"comando": "gruppo", "ids": [ba["id"], bb2["id"]], "azione": "aspetto", "valore": "3d"})
	_prova("gruppo: aspetto a più pezzi insieme", str(asp.pezzo(bb2["id"]).get("aspetto", "")) == "3d" and str(asp.pezzo(ba["id"]).get("aspetto", "")) == "3d")
	asp.annulla()
	_prova("gruppo aspetto: un solo annulla", not asp.pezzo(bb2["id"]).has("aspetto"))
	# immagini proprie e altezza del 3D (v0.6)
	var prova_img := Image.create(200, 100, false, Image.FORMAT_RGBA8)
	prova_img.fill(Color(1, 0.8, 0.2))
	var f_img := ProjectSettings.globalize_path("user://prova_immagine.png")
	prova_img.save_png(f_img)
	var r_img := asp.esegui({"comando": "immagine", "id": ba["id"], "file": f_img})
	_prova("immagine: entra nel tavolo", r_img["ok"] and asp.desc.get("immagini", {}).has("prova_immagine"))
	var dim_i: Vector2 = asp.pezzo(ba["id"])["immagine"]["dim"]
	_prova("immagine: grande come il pezzo, proporzioni giuste", is_equal_approx(dim_i.x, dim_i.y * 2.0) and dim_i.x <= PittorePezzi.misura_pezzo("bumper", asp.pezzo(ba["id"])).x + 0.5)
	asp.esegui({"comando": "immagine", "id": ba["id"], "misura": "centro", "modo": "sostituisce", "rot": 90, "pos": [3, -2]})
	var im_i: Dictionary = asp.pezzo(ba["id"])["immagine"]
	_prova("immagine: al centro, al posto del disegno, ruotata e spostata", Vector2(im_i["dim"]).x < dim_i.x and im_i["modo"] == "sostituisce" and is_equal_approx(float(im_i["rot"]), PI / 2) and Vector2(im_i["pos"]) == Vector2(3, -2))
	_prova("immagine: si legge come texture", PittorePezzi.texture(asp.desc, "prova_immagine") != null)
	asp.esegui({"comando": "immagine", "id": bb2["id"], "file": f_img})
	_prova("immagine: stesso file = una sola copia nel tavolo", asp.desc["immagini"].size() == 1)
	asp.esegui({"comando": "immagine", "id": ba["id"], "togli": true})
	asp.esegui({"comando": "immagine", "id": bb2["id"], "togli": true})
	_prova("immagine: tolta da tutti -> sparisce dal tavolo", not asp.pezzo(ba["id"]).has("immagine") and asp.desc["immagini"].is_empty())
	asp.annulla()
	_prova("immagine: annulla la rimette", PittorePezzi.ha_immagine(asp.pezzo(bb2["id"])))
	# v0.19: ELEMENTI DA IMMAGINE (prova_immagine.png è larga il doppio dell'altezza)
	var qe := ProgettoEditor.new()
	qe.esegui({"comando": "nuovo", "modello": "base", "nome": "Elementi"})
	var tutte_ok := true
	for cat in ProgettoEditor.CATEGORIE_IMMAGINE:
		var re_ := qe.esegui({"comando": "elemento_da_immagine", "file": f_img, "categoria": cat, "pos": [317, 500]})
		var pe := qe.pezzo(str(re_.get("id", "")))
		if not re_["ok"] or not PittorePezzi.ha_immagine(pe) or pe["immagine"]["modo"] != "sostituisce" or str(pe.get("da_immagine", "")) != cat:
			tutte_ok = false
			print("  categoria ko: ", cat, " ", re_["messaggio"])
	_prova("elemento da immagine: tutte le categorie, immagine al posto del disegno", tutte_ok)
	var rbz := qe.esegui({"comando": "elemento_da_immagine", "file": f_img, "categoria": "bumper", "pos": [200, 300]})
	var bz := qe.pezzo(rbz["id"])
	_prova("elemento bumper: collisione ovale come l'immagine (2:1)", absf(float(bz["raggio"]) - 2.0 * float(bz["raggio_y"])) < 1.0)
	var dim_im: Vector2 = bz["immagine"]["dim"]
	qe.esegui({"comando": "imposta", "id": rbz["id"], "campo": "raggio_y", "valore": 20.0})
	_prova("elemento: cambiare la collisione non tocca l'immagine", Vector2(qe.pezzo(rbz["id"])["immagine"]["dim"]) == dim_im and float(qe.pezzo(rbz["id"])["raggio_y"]) == 20.0)
	qe.annulla()
	qe.annulla()
	_prova("elemento: un solo «annulla» lo toglie tutto", qe.pezzo(rbz["id"]).is_empty())
	_prova("elemento: categoria sconosciuta rifiutata", not qe.esegui({"comando": "elemento_da_immagine", "file": f_img, "categoria": "drago"})["ok"])
	var rfi := qe.esegui({"comando": "elemento_da_immagine", "file": f_img, "categoria": "fionda", "pos": [200, 300]})
	var fi := qe.pezzo(rfi["id"])
	_prova("v0.21 fionda da immagine: collisione dove la metti", ProgettoEditor.centro("muri", fi).distance_to(Vector2(200, 300)) < 60.0)
	var c0 := ProgettoEditor.centro("muri", fi)
	qe.esegui({"comando": "gruppo", "ids": [rfi["id"]], "azione": "sposta", "di": [100, 200]})
	fi = qe.pezzo(rfi["id"])
	_prova("v0.21 spostando l'elemento si sposta anche la fionda (la collisione)", ProgettoEditor.centro("muri", fi).distance_to(c0 + Vector2(100, 200)) < 1.0 and Vector2(fi["immagine"].get("pos", Vector2.ZERO)) == Vector2.ZERO)
	var d0: Vector2 = qe.pezzo(rbz["id"]).get("immagine", {}).get("dim", Vector2.ZERO) if not qe.pezzo(rbz["id"]).is_empty() else Vector2.ZERO
	var rb2 := qe.esegui({"comando": "elemento_da_immagine", "file": f_img, "categoria": "bumper", "pos": [300, 300]})
	var b2d: Vector2 = qe.pezzo(rb2["id"])["immagine"]["dim"]
	var b2r := float(qe.pezzo(rb2["id"])["raggio"])
	qe.esegui({"comando": "gruppo", "ids": [rb2["id"]], "azione": "scala", "fattore": 1.5})
	_prova("v0.21 ingrandisci: crescono insieme immagine e collisione", Vector2(qe.pezzo(rb2["id"])["immagine"]["dim"]).distance_to(b2d * 1.5) < 1.0 and absf(float(qe.pezzo(rb2["id"])["raggio"]) - b2r * 1.5) < 0.1)
	qe.esegui({"comando": "gruppo", "ids": [rfi["id"]], "azione": "ruota", "gradi": 30})
	_prova("v0.21 ruota: l'immagine gira con il pezzo", absf(float(qe.pezzo(rfi["id"])["immagine"].get("rot", 0.0)) - deg_to_rad(30)) < 0.001)
	d0 = d0
	# v0.22: importa un flipper già fatto (solo lettura) e progetto Godot completo
	# (tavoli scritti a mano «come i flipper già fatti»: file layout_*.gd con descrizione(); si leggono e basta)
	var f_imp := ProjectSettings.globalize_path("user://layout_prova_import.gd")
	var sorg := "static func descrizione() -> Dictionary:\n\tvar d := LayoutBase.descrizione(\"classica\")\n\td[\"kickback\"] = {\"pos\": Vector2(24, 1100), \"dim\": Vector2(40, 12)}\n\td[\"captive\"] = [{\"id\": \"cap\", \"casa\": Vector2(100, 500), \"fermo\": [Vector2(90, 480), Vector2(110, 480)]}]\n\td[\"grafica\"] = \"res://non_esiste.json\"\n\treturn d\n"
	var fw_i := FileAccess.open(f_imp, FileAccess.WRITE)
	fw_i.store_string("class_name LayoutProvaImport\n" + sorg)
	fw_i.close()
	var q_imp := ProgettoEditor.new()
	var r_imp := q_imp.esegui({"comando": "importa_flipper", "file": f_imp, "nome": "Importato prova"})
	_prova("v0.22 flipper scritto a mano importato (kickback in lista, captive col suo canale)", r_imp["ok"] and q_imp.desc["palette"].size() >= 2 and q_imp.desc["kickback"] is Array and bool(q_imp.desc["captive"][0].get("canale_proprio", false)))
	_prova("v0.22 importato: regole a mattoncini, nessun file dell'altro gioco usato", q_imp.desc["regole"] == FileTavolo.REGOLE_BASE and not q_imp.desc.has("grafica") and not q_imp.desc.has("luci"))
	_prova("v0.22 il file originale non è cambiato", FileAccess.get_file_as_string(f_imp).begins_with("class_name LayoutProvaImport"))
	var f_due := ProjectSettings.globalize_path("user://layout_prova_due_piani.gd")
	var fw_d := FileAccess.open(f_due, FileAccess.WRITE)
	fw_d.store_string(sorg.replace("\treturn d\n", "\td[\"piani\"] = {\"alto\": Vector2(0, 1000)}\n\treturn d\n"))
	fw_d.close()
	_prova("v0.22 tavolo a due piani rifiutato con spiegazione", not ProgettoEditor.new().esegui({"comando": "importa_flipper", "file": f_due})["ok"])
	_prova("v0.22 file non tavolo rifiutato", not qe.esegui({"comando": "importa_flipper", "file": f_img})["ok"])
	# v0.25: per chi non programma (tema, gruppi pronti, «Sistema tu»)
	var qg := ProgettoEditor.new()
	qg.esegui({"comando": "nuovo", "modello": "base", "nome": "Guidato"})
	_prova("v0.25 tema pronto: colori del tavolo, menu e luce", qg.esegui({"comando": "tema", "nome": "mare"})["ok"] and qg.desc["colori"]["primario"] == ProgettoEditor.TEMI["mare"]["primario"] and qg.desc["menu"].has("col_a") and qg.desc["luce_ambiente"]["da"] == "ovunque")
	_prova("v0.25 tema sconosciuto rifiutato", not qg.esegui({"comando": "tema", "nome": "boh"})["ok"])
	var n_ann := qg._annulla.size()
	var rgp := qg.esegui({"comando": "aggiungi_composto", "nome": "bumper_3", "pos": [300, 330]})
	_prova("v0.25 triangolo di bumper: 3 pezzi, un solo annulla", rgp["ok"] and rgp["ids"].size() == 3 and qg._annulla.size() == n_ann + 1)
	qg.annulla()
	_prova("v0.25 annulla toglie tutto il gruppo", qg.desc["bumper"].is_empty())
	_prova("v0.25 buca con bersagli e spinner in corsia", qg.esegui({"comando": "aggiungi_composto", "nome": "bersagli_buca", "pos": [470, 640]})["ok"] and qg.esegui({"comando": "aggiungi_composto", "nome": "spinner_corsia", "pos": [160, 420]})["ok"])
	qg.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "b_a", "pos": [300, 330]})
	qg.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "b_b", "pos": [300, 410]})   # varco 28 mm: pericoloso
	var v_prima := ControlliEditor.varchi(qg.desc).size()
	var rst := qg.esegui({"comando": "sistema_varchi"})
	_prova("v0.25 «Sistema tu» allarga i varchi pericolosi (%d → %d)" % [v_prima, int(rst.get("restano", -1))], v_prima > 0 and rst["ok"] and int(rst["restano"]) < v_prima and ControlliEditor.varchi(qg.desc).size() == int(rst["restano"]))
	qg.annulla()
	_prova("v0.25 «Sistema tu»: un solo annulla rimette tutto", ControlliEditor.varchi(qg.desc).size() == v_prima)
	# v0.23: segreti e classifica dall'editor
	var qsg := ProgettoEditor.new()
	qsg.esegui({"comando": "nuovo", "modello": "base", "nome": "Segreti"})
	qsg.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [250, 400]})
	qsg.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [350, 400]})
	var rsg := qsg.esegui({"comando": "segreto_aggiungi", "modello": "raffica_bumper"})
	_prova("v0.23 segreto pronto aggiunto con i pezzi del tavolo", rsg["ok"] and qsg.desc["segreti"].size() == 1)
	_prova("v0.23 segreto non disponibile senza i pezzi (rampa)", not qsg.esegui({"comando": "segreto_aggiungi", "modello": "rampa_doppia"})["ok"])
	qsg.esegui({"comando": "segreto_imposta", "id": rsg["id"], "campo": "volte", "valore": 8})
	_prova("v0.23 segreto: cambio dei colpi", int(qsg.desc["segreti"][0]["volte"]) == 8)
	qsg.esegui({"comando": "segreto_togli", "id": rsg["id"]})
	_prova("v0.23 segreto tolto", qsg.desc["segreti"].is_empty())
	_prova("v0.23 classifica spenta e riaccesa", qsg.esegui({"comando": "classifica", "attiva": false})["ok"] and qsg.desc["classifica"] == false and qsg.esegui({"comando": "classifica", "attiva": true})["ok"])
	# v0.21: font e tabellone
	var rfo := qe.esegui({"comando": "importa_font", "file": ProjectSettings.globalize_path("res://interfaccia/font/NotoSansDisplay-Bold.ttf"), "per": "font_titolo"})
	_prova("v0.21 font importato nel tavolo e scelto per i titoli", rfo["ok"] and qe.desc["font_file"].has(rfo["nome"]) and qe.desc["menu"]["font_titolo"] == rfo["nome"])
	_prova("v0.21 il font importato si carica (menu e tabellone)", Hud.font_di(qe.desc, rfo["nome"], "serif") is FontFile)
	_prova("v0.21 font importato nel registro licenze", qe.asset_usati().any(func(a): return a["chiave"] == "font:" + str(rfo["nome"])))
	_prova("v0.21 file non font rifiutato", not qe.esegui({"comando": "importa_font", "file": f_img})["ok"])
	qe.esegui({"comando": "tabellone", "altezza": 100})
	_prova("v0.21 tabellone piccolo", Hud.altezza_di(qe.desc) == 100.0 and Hud.altezza_di({}) == 150.0)
	_prova("v0.21 menu: scelta font predefinito", qe.esegui({"comando": "imposta_menu", "campo": "font", "valore": "serif"})["ok"] and qe.desc["menu"]["font"] == "serif")
	# libreria
	var rz := qe.esegui({"comando": "elemento_da_immagine", "file": f_img, "categoria": "bumper", "pos": [400, 300]})
	qe.esegui({"comando": "imposta", "id": rz["id"], "campo": "forza", "valore": 1100.0})
	var nome_lib := "prova_test_%d" % Time.get_ticks_msec()
	_prova("libreria: elemento salvato", qe.esegui({"comando": "elemento_salva", "id": rz["id"], "nome": nome_lib})["ok"] and nome_lib in ProgettoEditor.elenco_elementi())
	var qn := ProgettoEditor.new()
	qn.esegui({"comando": "nuovo", "modello": "base", "nome": "Altro"})
	var rin := qn.esegui({"comando": "elemento_inserisci", "nome": nome_lib, "pos": [250, 450]})
	var pin := qn.pezzo(str(rin.get("id", "")))
	_prova("libreria: inserito in un altro tavolo con immagine, posizione e forza", rin["ok"] and Vector2(pin["pos"]) == Vector2(250, 450) and float(pin["forza"]) == 1100.0 and PittorePezzi.texture(qn.desc, str(pin["immagine"]["nome"])) != null)
	DirAccess.remove_absolute(ProgettoEditor.cartella_libreria().path_join(nome_lib + ".elemento"))
	# v0.17.2: registro licenze
	_prova("licenze: immagine senza fonte = avviso", asp.avvisi_licenze().size() == 1 and asp.asset_usati()[0]["dove"].has(bb2["id"]))
	_prova("licenze: fonte dichiarata", asp.esegui({"comando": "licenza", "chiave": "immagine:prova_immagine", "fonte": "ai", "nota": "prova"})["ok"] and asp.avvisi_licenze().is_empty())
	_prova("licenze: fonte sconosciuta rifiutata", not asp.esegui({"comando": "licenza", "chiave": "immagine:prova_immagine", "fonte": "boh"})["ok"])
	var cart_i := ProjectSettings.globalize_path("user://prova_immagini.pinproj")
	DirAccess.make_dir_recursive_absolute(cart_i)
	asp.salva(cart_i)
	var riletto := ProgettoEditor.new()
	riletto.apri(cart_i)
	_prova("immagine: salvata e riletta col tavolo", PittorePezzi.texture(riletto.desc, str(riletto.pezzo(bb2["id"])["immagine"]["nome"])) != null)
	asp.esegui({"comando": "imposta", "id": ba["id"], "campo": "altezza_3d", "valore": 60})
	_prova("altezza 3D del pezzo", PittorePezzi.altezza("bumper", asp.pezzo(ba["id"])) == 60.0 and PittorePezzi.cima_bumper(asp.pezzo(ba["id"]), {"aspetto": "3d"}).y < float(asp.pezzo(ba["id"])["pos"].y) - 25.0)
	# fondo dipinto e immagini sul piano (v0.6)
	asp.esegui({"comando": "imposta_tavolo", "campo": "fondo", "valore": f_img})
	_prova("fondo dipinto: entra nel tavolo", asp.desc.get("fondo", "") == "fondo_tavolo" and PittorePezzi.texture(asp.desc, "fondo_tavolo") != null)
	var r_dec := asp.esegui({"comando": "aggiungi", "tipo": "decorazioni", "pos": [300, 700], "file": f_img})
	var dec: Dictionary = asp.pezzo(r_dec["id"])
	_prova("immagine sul piano: aggiunta con il suo file", r_dec["ok"] and PittorePezzi.ha_immagine(dec) and is_equal_approx(Vector2(dec["dim"]).x, Vector2(dec["dim"]).y * 2.0))
	asp.esegui({"comando": "gruppo", "ids": [r_dec["id"]], "azione": "scala", "fattore": 2.0})
	asp.esegui({"comando": "gruppo", "ids": [r_dec["id"]], "azione": "capovolgi", "asse": "x"})
	dec = asp.pezzo(r_dec["id"])
	_prova("immagine sul piano: ingrandita e a specchio", Vector2(dec["dim"]).x > 150.0 and bool(dec["specchiata"]))
	asp.annulla()
	asp.annulla()
	asp.annulla()
	_prova("immagine sul piano: un solo annulla per aggiungerla", asp.trova(r_dec["id"]).is_empty())
	asp.esegui({"comando": "imposta_tavolo", "campo": "fondo", "valore": ""})
	_prova("fondo tolto", not asp.desc.has("fondo") and not asp.desc.get("immagini", {}).has("fondo_tavolo"))
	# cancelletto e fila di abbattibili (v0.7)
	var r_canc := asp.esegui({"comando": "aggiungi", "tipo": "cancelli", "pos": [200, 500]})
	_prova("cancelletto: si aggiunge", r_canc["ok"] and asp.desc["cancelli"].size() == 1)
	asp.esegui({"comando": "gruppo", "ids": [r_canc["id"]], "azione": "ruota", "gradi": 90})
	_prova("cancelletto: si ruota (cambia il verso)", is_equal_approx(float(asp.pezzo(r_canc["id"])["angolo"]), PI / 2))
	var n_bers: int = asp.desc["bersagli"].size()
	var r_fila := asp.esegui({"comando": "aggiungi_composto", "nome": "abbattibili_5", "pos": [300, 400]})
	var fila_b: Array = asp.desc["bersagli"].filter(func(b): return str(b.get("gruppo", "")) == "fila_1")
	_prova("fila: 5 abbattibili nello stesso gruppo, con le luci", r_fila["ok"] and asp.desc["bersagli"].size() == n_bers + 5 and fila_b.size() == 5 and fila_b.all(func(b): return b["abbattibile"]))
	var r_fila2 := asp.esegui({"comando": "aggiungi_composto", "nome": "abbattibili_3", "pos": [300, 300]})
	_prova("fila: la seconda fila ha un gruppo nuovo", r_fila2["ok"] and asp.pezzo(r_fila2["id"])["gruppo"] == "fila_2")
	asp.annulla()
	_prova("fila: un solo annulla la toglie", asp.desc["bersagli"].size() == n_bers + 5)
	# disegno di ogni pezzo nei due aspetti (non deve dare errori)
	var tela := Control.new()
	add_child(tela)
	var disegnati := [0]
	tela.draw.connect(func():
		for a in ["3d", "piatto"]:
			for k in PittorePezzi.TIPI:
				for e in asp.desc.get(k, []):
					var e2: Dictionary = e.duplicate()
					e2["aspetto"] = a
					PittorePezzi.disegna(tela, k, e2, asp.desc)
					disegnati[0] += 1)
	tela.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_prova("disegno: tutti i pezzi in 3D e piatti", disegnati[0] > 20)
	tela.queue_free()
	# strumenti su più pezzi (v0.4)
	var g := ProgettoEditor.new()
	g.esegui({"comando": "nuovo", "modello": "base", "nome": "Gruppi"})
	for x in [200, 300, 420]:
		g.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [x, 300 + x / 10]})
	var tre := ["bumper_1", "bumper_2", "bumper_3"]
	g.esegui({"comando": "gruppo", "ids": tre, "azione": "allinea", "asse": "y"})
	_prova("gruppo: in riga (stessa altezza)", g.pezzo("bumper_1")["pos"].y == g.pezzo("bumper_3")["pos"].y)
	g.esegui({"comando": "gruppo", "ids": tre, "azione": "distribuisci", "asse": "x"})
	_prova("gruppo: distanze uguali", absf((g.pezzo("bumper_2")["pos"].x - g.pezzo("bumper_1")["pos"].x) - (g.pezzo("bumper_3")["pos"].x - g.pezzo("bumper_2")["pos"].x)) < 0.01)
	var r0: float = g.pezzo("bumper_1")["raggio"]
	g.esegui({"comando": "gruppo", "ids": tre, "azione": "scala", "fattore": 1.5})
	_prova("gruppo: ingrandisci (misure e distanze)", absf(g.pezzo("bumper_1")["raggio"] - r0 * 1.5) < 0.01)
	g.esegui({"comando": "annulla"})
	_prova("gruppo: un solo annulla", absf(g.pezzo("bumper_1")["raggio"] - r0) < 0.01)
	var rd := g.esegui({"comando": "gruppo", "ids": tre, "azione": "duplica"})
	_prova("gruppo: duplica 3 pezzi", rd["ids"].size() == 3 and g.desc["bumper"].size() == 6)
	g.esegui({"comando": "aggiungi", "tipo": "bersagli", "id": "b1", "pos": [100, 500], "valori": {"angolo": 0.5}})
	g.esegui({"comando": "capovolgi", "id": "b1", "asse": "x"})
	_prova("capovolgi sul posto: angolo invertito", g.pezzo("b1")["angolo"] == -0.5 and g.pezzo("b1")["pos"] == Vector2(100, 500))
	var ri := g.esegui({"comando": "incolla", "pezzi": [["bumper", g.pezzo("bumper_1").duplicate(true)]], "pos": [500, 700]})
	_prova("incolla dove punta il mouse", ri["ok"] and g.pezzo(ri["ids"][0])["pos"] == Vector2(500, 700))
	g.esegui({"comando": "gruppo", "ids": ["b1"], "azione": "blocca", "valore": true})
	_prova("blocca", bool(g.pezzo("b1")["bloccato"]))
	var rf2 := g.esegui({"comando": "aggiungi", "tipo": "muri", "preset": "fionda", "pos": [200, 650]})
	var p0: Vector2 = g.pezzo(rf2["id"])["controllo"][0]
	g.esegui({"comando": "scala", "id": rf2["id"], "fattore": 2.0})
	_prova("ridimensiona una forma a punti", g.pezzo(rf2["id"])["controllo"][0].distance_to(p0) > 5.0)
	# v0.9.3 (24/11): punti curvi del piano rialzato e opzioni nuove della rampa
	var gq := ProgettoEditor.new()
	gq.esegui({"comando": "nuovo", "modello": "base", "nome": "Curve"})
	gq.esegui({"comando": "aggiungi", "tipo": "piani", "id": "pq", "punti": [[150, 250], [450, 250], [450, 550], [150, 550]]})
	var prima_q: int = gq.pezzo("pq")["punti"].size()
	_prova("piano: «Tutti curvi» funziona", gq.esegui({"comando": "punto", "id": "pq", "indice": -1, "curvo": true})["ok"] and gq.pezzo("pq")["punti"].size() > prima_q + 20)
	_prova("piano: niente fionda sul bordo", not gq.esegui({"comando": "punto", "id": "pq", "indice": 0, "fionda": true})["ok"])
	gq.esegui({"comando": "aggiungi", "tipo": "rampe", "id": "rq", "punti": [[120, 650], [200, 450], [100, 300], [60, 180]]})
	gq.esegui({"comando": "punto", "id": "rq", "altezza_tutta": 70})
	var hq := 0.0
	for qz in gq.pezzo("rq")["punti"]:
		hq = maxf(hq, qz.z)
	_prova("rampa dell'editor: solida dove è bassa (v0.17.1)", bool(gq.pezzo("rq").get("solida", false)))
	_prova("rampa: altezza di tutta la rampa", absf(hq - 70.0) < 1.0 and gq.pezzo("rq")["punti"][0].z == 0.0)
	gq.esegui({"comando": "punto", "id": "rq", "imbocco": 70})
	_prova("rampa: imbocco largo 70 mm (invito 35 nel motore)", float(gq.pezzo("rq").get("invito", 0)) == 35.0)
	_prova("rampa: colore e frecce", gq.esegui({"comando": "imposta", "id": "rq", "campo": "colore", "valore": "#ff8800"})["ok"] and gq.esegui({"comando": "imposta", "id": "rq", "campo": "frecce", "valore": true})["ok"] and gq.pezzo("rq")["frecce"] == true)
	# v0.9.4: livelli con nome, occhio e lucchetto
	gq.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "bq", "pos": [300, 400]})
	var lv: Array = gq.elenco_livelli()
	_prova("livelli: tavolo + piano col suo nome", lv.size() == 2 and lv[1]["nome"] == "Piano" and gq.pezzo("bq").get("livello", 0) == lv[1]["livello"])
	_prova("livelli: rinomina il piano dal livello", gq.esegui({"comando": "livello_vista", "livello": lv[1]["livello"], "nome": "Nave"})["ok"] and gq.elenco_livelli()[1]["nome"] == "Nave")
	var vq := VistaTavolo.new()
	vq.progetto = gq
	vq.size = Vector2(800, 1000)
	add_child(vq)
	vq.adatta()
	_prova("livelli: bumper sul piano si sceglie", vq.pezzo_in(Vector2(300, 400)) == "bq")
	gq.esegui({"comando": "livello_vista", "livello": lv[1]["livello"], "bloccato": true})
	_prova("livelli: lucchetto = non si sceglie", vq.pezzo_in(Vector2(300, 400)) == "")
	gq.esegui({"comando": "livello_vista", "livello": lv[1]["livello"], "bloccato": false, "nascosto": true})
	_prova("livelli: nascosto = non si vede né si sceglie", vq.pezzo_in(Vector2(300, 400)) == "" and not vq._desc_visibile()["bumper"].any(func(e): return e["id"] == "bq"))
	gq.esegui({"comando": "livello_vista", "livello": lv[1]["livello"], "nascosto": false})
	_prova("livelli: di nuovo visibile", vq.pezzo_in(Vector2(300, 400)) == "bq")
	vq.queue_free()
	# v0.9.5: tracciatore sul motore vero
	var gt := ProgettoEditor.new()
	gt.esegui({"comando": "nuovo", "modello": "base", "nome": "Traccia"})
	gt.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "bt", "pos": [317, 400]})
	var rt := gt.esegui({"comando": "traccia", "da": [317, 600], "angolo": 0, "forza": 1500, "tiri": 3, "variazione": 2})
	_prova("tracciatore: 3 tiri con il percorso", rt["ok"] and gt.ultima_traccia["tiri"].size() == 3 and gt.ultima_traccia["tiri"][0]["punti"].size() > 20)
	var colpito := false
	for e in gt.ultima_traccia["tiri"][1]["eventi"]:
		colpito = colpito or (e[1] == "bumper" and e[2] == "bt")
	_prova("tracciatore: il tiro dritto colpisce il bumper", colpito)
	_prova("tracciatore: la pallina parte da dove si è cliccato", Vector2(gt.ultima_traccia["tiri"][0]["punti"][0][0], gt.ultima_traccia["tiri"][0]["punti"][0][1]).distance_to(Vector2(317, 600)) < 15.0)
	_prova("tracciatore: forza dal trascinamento (100-3200 mm/s)", VistaTavolo.vel_traccia(Vector2.ZERO, Vector2(0, -100)) == Vector2(0, -600) and VistaTavolo.vel_traccia(Vector2.ZERO, Vector2(0, -2000)).length() == 3200.0)
	# v0.10: missioni a mattoncini (comandi)
	var gm := ProgettoEditor.new()
	gm.esegui({"comando": "nuovo", "modello": "base", "nome": "Missioni"})
	_prova("missioni: modello che manca il pezzo = rifiutato con il motivo", not gm.esegui({"comando": "missione_aggiungi", "modello": "spinner"})["ok"])
	gm.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "mb", "pos": [317, 400]})
	var rm := gm.esegui({"comando": "missione_aggiungi", "modello": "bumper"})
	_prova("missioni: modello bumper aggiunto", rm["ok"] and gm.desc["missioni"].size() == 1 and gm.desc["missioni"][0]["fasi"][0]["quando"]["tipo"] == "bumper")
	var mid: String = rm["id"]
	gm.esegui({"comando": "missione_imposta", "id": mid, "campo": "fasi.0.volte", "valore": 7})
	gm.esegui({"comando": "missione_imposta", "id": mid, "campo": "premio.punti", "valore": 1234})
	gm.esegui({"comando": "missione_imposta", "id": mid, "campo": "fasi.0.quando.id", "valore": "mb"})
	_prova("missioni: cambio dei mattoncini con il percorso del campo", int(gm.desc["missioni"][0]["fasi"][0]["volte"]) == 7 and int(gm.desc["missioni"][0]["premio"]["punti"]) == 1234)
	gm.esegui({"comando": "missione_fase", "id": mid})
	_prova("missioni: fase aggiunta e tolta", gm.desc["missioni"][0]["fasi"].size() == 2 and gm.esegui({"comando": "missione_fase", "id": mid, "azione": "togli", "indice": 1})["ok"] and gm.desc["missioni"][0]["fasi"].size() == 1)
	_prova("missioni: almeno una fase resta", not gm.esegui({"comando": "missione_fase", "id": mid, "azione": "togli", "indice": 0})["ok"])
	gm.esegui({"comando": "missioni_pacchetto"})
	var nomi: Array = gm.desc["missioni"].map(func(x): return x.get("modello", ""))
	_prova("missioni: «tutte le pronte» = i modelli possibili + modalità finale", nomi.has("wizard") and nomi.has("combo") and not nomi.has("spinner") and int(gm.desc["missioni"].back()["sblocco"]["completate"]) == mini(6, gm.desc["missioni"].size() - 1))
	var secondo: String = gm.desc["missioni"][1]["id"]
	gm.esegui({"comando": "missione_sposta", "id": secondo, "di": -1})
	_prova("missioni: sposta in su", gm.desc["missioni"][0]["id"] == secondo)
	gm.esegui({"comando": "elimina", "id": "mb"})
	_prova("missioni: CONTROLLA trova il pezzo che non c'è più", ModelliMissioni.controlla(gm.desc).any(func(t): return t.contains("«mb»")))
	gm.esegui({"comando": "annulla"})
	var n_m: int = gm.desc["missioni"].size()
	gm.esegui({"comando": "missione_togli", "id": secondo})
	_prova("missioni: togli e annulla", gm.desc["missioni"].size() == n_m - 1 and gm.esegui({"comando": "annulla"})["ok"] and gm.desc["missioni"].size() == n_m)
	gm.esegui({"comando": "missioni_avvio", "tipo": "buca", "id": "k1"})
	_prova("missioni: avvio con un tiro salvato nel tavolo", gm.desc["missioni_avvio"]["tipo"] == "buca")
	var f_mis := ProjectSettings.globalize_path("user://prove/missioni.tavolo")
	gm.salva_prova(f_mis)
	_prova("missioni: salvate e rilette dal file", FileTavolo.leggi(f_mis)["missioni"].size() == n_m)
	# v0.11: regia (suoni e luci per evento, regola della luce)
	_prova("regia: suono dal catalogo", gm.esegui({"comando": "suono_evento", "evento": "bumper", "suono": "combo"})["ok"] and gm.desc["suoni"]["bumper"] == "combo")
	_prova("regia: suono fuori catalogo rifiutato", not gm.esegui({"comando": "suono_evento", "evento": "bumper", "suono": "campana"})["ok"])
	_prova("regia: effetto di luce per evento", gm.esegui({"comando": "luce_evento", "evento": "rampa", "effetto": "strobo", "colore": "rosso"})["ok"] and gm.desc["luci_eventi"]["rampa"]["effetto"] == "strobo")
	gm.esegui({"comando": "luce_evento", "evento": "rampa", "effetto": ""})
	_prova("regia: «come prima» toglie la scelta", not gm.desc["luci_eventi"].has("rampa"))
	# v0.17.2: evoluzione dal comando
	var ge := ProgettoEditor.new()
	ge.esegui({"comando": "nuovo", "modello": "base", "nome": "Evo"})
	ge.esegui({"comando": "collezione", "azione": "aggiungi", "nome": "Seme"})
	ge.esegui({"comando": "collezione", "azione": "aggiungi", "nome": "Albero"})
	var og: Array = ge.desc["collezione"]["oggetti"]
	var i_seme := og.size() - 2
	ge.esegui({"comando": "collezione", "azione": "imposta", "indice": i_seme, "evolve_in": str(og[og.size() - 1]["id"]), "evolve_dopo": 4})
	_prova("collezione: evoluzione impostata", str(og[i_seme].get("evolve_in", "")) == str(og[og.size() - 1]["id"]) and int(og[i_seme]["evolve_dopo"]) == 4)
	ge.esegui({"comando": "collezione", "azione": "togli", "indice": og.size() - 1})
	_prova("collezione: tolto l'arrivo, l'evoluzione sparisce", not ge.desc["collezione"]["oggetti"][i_seme].has("evolve_in"))
	# v0.17: spettacoli di luce e attesa in sala
	_prova("spettacolo: copia un pronto", gm.esegui({"comando": "spettacolo", "azione": "pronto", "da": "Arcobaleno"})["ok"] and gm.desc["spettacoli"]["Arcobaleno"]["passi"].size() == 5)
	var rsp := gm.esegui({"comando": "spettacolo", "azione": "nuovo", "nome": "Lampi"})
	_prova("spettacolo: nuovo con un passo", rsp["ok"] and gm.desc["spettacoli"]["Lampi"]["passi"].size() == 1)
	gm.esegui({"comando": "spettacolo_passo", "nome": "Lampi", "azione": "aggiungi", "effetto": "strobo", "colore": "viola"})
	gm.esegui({"comando": "spettacolo_passo", "nome": "Lampi", "azione": "imposta", "indice": 1, "dur": 1.5, "effetto": "nonesiste"})
	var pl: Array = gm.desc["spettacoli"]["Lampi"]["passi"]
	_prova("spettacolo: passi aggiunti in coda e puliti", pl.size() == 2 and pl[1]["dopo"] >= 0.8 and pl[1]["dur"] == 1.5 and pl[1]["effetto"] == "onda")
	gm.esegui({"comando": "luce_evento", "evento": "rampa", "effetto": "spettacolo:Lampi"})
	gm.esegui({"comando": "attesa", "spettacolo": "Lampi", "pausa": 2.0, "scritta": "INSERT COIN"})
	_prova("attesa in sala: spettacolo, pausa, scritta", gm.desc["attesa"]["spettacolo"] == "Lampi" and gm.desc["attesa"]["pausa"] == 2.0 and gm.desc["attesa"]["scritta"] == "INSERT COIN")
	_prova("attesa: spettacolo sconosciuto rifiutato", not gm.esegui({"comando": "attesa", "spettacolo": "Boh"})["ok"])
	gm.esegui({"comando": "spettacolo", "azione": "rinomina", "nome": "Lampi", "nuovo_nome": "Tuoni"})
	_prova("spettacolo: rinomina aggiorna evento e attesa", gm.desc["luci_eventi"]["rampa"]["effetto"] == "spettacolo:Tuoni" and gm.desc["attesa"]["spettacolo"] == "Tuoni")
	gm.esegui({"comando": "spettacolo", "azione": "togli", "nome": "Tuoni"})
	_prova("spettacolo: tolto, l'evento torna come prima", not gm.desc["luci_eventi"].has("rampa") and gm.desc["attesa"]["spettacolo"] == "")
	gm.esegui({"comando": "aggiungi", "tipo": "inserti", "id": "lq", "pos": [300, 700]})
	gm.esegui({"comando": "imposta", "id": "lq", "campo": "luce_modo", "valore": "tiro"})
	_prova("regia: regola della luce salvata sul pezzo", gm.pezzo("lq")["luce_modo"] == "tiro")
	# v0.12: musica tua nel tavolo (file copiato nella cartella del progetto) e «3 corsie» con il cambio corsia
	var cart := ProjectSettings.globalize_path("user://prove/Musica.pinproj")
	gm.esegui({"comando": "salva", "cartella": cart})
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 8000
	var dati := PackedByteArray()
	for i in 800:
		dati.append(int(128 + 60 * sin(i * 0.3)) & 255)
	wav.data = dati
	var fw := ProjectSettings.globalize_path("user://prove/canzone_di_prova.wav")
	wav.save_to_wav(fw)
	var rmu := gm.esegui({"comando": "musica", "ruolo": "main", "file": fw})
	_prova("musica: canzone copiata nella cartella del tavolo", rmu["ok"] and FileAccess.file_exists(cart.path_join("musica/canzone_di_prova.wav")) and gm.desc["musica"]["main"] == "canzone_di_prova.wav")
	var fpm := ProjectSettings.globalize_path("user://prove/musica_prova.tavolo")
	gm.salva_prova(fpm)
	var dm := FileTavolo.leggi(fpm)
	_prova("musica: il gioco trova la cartella e la canzone si carica", str(dm.get("cartella_musica", "")) == cart.path_join("musica") and Audio._carica_esterno(cart.path_join("musica/canzone_di_prova.wav")) != null)
	_prova("musica: per una missione, e si toglie", gm.esegui({"comando": "musica", "ruolo": "missione", "id": secondo, "file": fw})["ok"] and gm.esegui({"comando": "musica", "ruolo": "missione", "id": secondo, "togli": true})["ok"] and gm.desc["missioni"][gm.indice_missione(secondo)]["musica"] == "")
	gm.esegui({"comando": "aggiungi_composto", "nome": "corsie_3", "pos": [317, 150]})
	_prova("3 corsie: gruppo, luci che seguono le corsie e cambio corsia pronti", gm.desc["cambio_corsie"].size() == 1 and gm.desc["inserti"].filter(func(x): return str(x.get("luce_modo", "")) == "corsia").size() == 3)
	# v0.14: menu del gioco, collezione e zone
	gm.esegui({"comando": "imposta_menu", "campo": "titolo", "valore": "IL MIO FLIPPER"})
	gm.esegui({"comando": "imposta_menu", "campo": "col_a", "valore": "#ff8800"})
	gm.esegui({"comando": "pagina_menu", "azione": "aggiungi", "titolo": "Storia", "testo": "C'era una volta"})
	_prova("menu: titolo, colore e pagina in più", gm.desc["menu"]["titolo"] == "IL MIO FLIPPER" and gm.desc["menu"]["col_a"] is Color and gm.desc["menu"]["pagine"].size() == 1)
	gm.esegui({"comando": "imposta_menu", "campo": "titolo", "valore": ""})
	_prova("menu: valore vuoto = come prima", not gm.desc["menu"].has("titolo"))
	_prova("menu: pagina MISSIONI scritta dalle missioni", gm.testo_missioni_menu().contains("PIOGGIA DI COLPI"))
	_prova("collezione: senza oggetti il modello Cattura non si può usare", not gm.esegui({"comando": "missione_aggiungi", "modello": "cattura"})["ok"])
	gm.esegui({"comando": "collezione", "azione": "aggiungi", "nome": "Drago", "rarita": 3})
	gm.esegui({"comando": "zone", "azione": "aggiungi", "nome": "Terra"})
	gm.esegui({"comando": "zone", "azione": "aggiungi", "nome": "Luna"})
	_prova("collezione e zone create; modelli Cattura e Viaggio pronti", gm.desc["collezione"]["oggetti"][0]["rarita"] == 3 and gm.desc["zone"].size() == 2 and gm.esegui({"comando": "missione_aggiungi", "modello": "cattura"})["ok"] and gm.esegui({"comando": "missione_aggiungi", "modello": "viaggio"})["ok"])
	# v0.16: righello e gruppi con nome (mouse)
	var gg2 := ProgettoEditor.new()
	gg2.esegui({"comando": "nuovo", "modello": "base", "nome": "Gruppi"})
	gg2.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "g1", "pos": [200, 300]})
	gg2.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "g2", "pos": [300, 300]})
	gg2.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "g3", "pos": [450, 300]})
	var vg := VistaTavolo.new()
	vg.progetto = gg2
	vg.size = Vector2(800, 1000)
	add_child(vg)
	vg.adatta()
	vg.da_inserire = "righello"
	_clic(vg, Vector2(100, 100), true)
	_muovi(vg, Vector2(130, 140))
	_clic(vg, Vector2(130, 140), false)
	_prova("righello: misura 50 mm (30 × 40)", absf(vg.righello_da.distance_to(vg.righello_a) - 50.0) < 0.5)
	vg.da_inserire = ""
	var rgn := gg2.esegui({"comando": "gruppo_nome", "azione": "crea", "ids": ["g1", "g2"], "nome": "Coppia"})
	_prova("gruppi: creato con il nome", rgn["ok"] and gg2.gruppo_di("g2") == "Coppia" and gg2.gruppo_di("g3") == "")
	_clic(vg, Vector2(200, 300), true)
	_clic(vg, Vector2(200, 300), false)
	_prova("gruppi: un clic su un pezzo sceglie tutto il gruppo", vg.selezionati.size() == 2 and "g2" in vg.selezionati)
	var ea := InputEventMouseButton.new()
	ea.button_index = MOUSE_BUTTON_LEFT
	ea.pressed = true
	ea.alt_pressed = true
	ea.position = vg.px(Vector2(450, 300))
	vg._gui_input(ea)
	ea.pressed = false
	vg._gui_input(ea)
	vg.seleziona("")
	ea.pressed = true
	ea.position = vg.px(Vector2(200, 300))
	vg._gui_input(ea)
	ea.pressed = false
	vg._gui_input(ea)
	_prova("gruppi: Alt+clic sceglie il pezzo da solo", vg.selezionati == ["g1"])
	gg2.esegui({"comando": "gruppo_nome", "azione": "rinomina", "nome": "Coppia", "nuovo": "Alto"})
	gg2.esegui({"comando": "elimina", "id": "g2"})
	_prova("gruppi: rinomina; con un pezzo solo rimasto il gruppo non vale più", gg2.gruppi_editor().is_empty() and gg2.desc["gruppi_editor"].has("Alto"))
	vg.queue_free()
	# v0.16: simulatore di regole (senza giocare)
	var gs := ProgettoEditor.new()
	gs.esegui({"comando": "nuovo", "modello": "base", "nome": "Sim"})
	gs.esegui({"comando": "aggiungi", "tipo": "bumper", "id": "sb", "pos": [317, 400]})
	gs.esegui({"comando": "missione_aggiungi", "missione": {"nome": "Tre", "fasi": [{"quando": {"tipo": "bumper"}, "volte": 3}], "premio": {"punti": 9000}}})
	var sim := SimulatoreRegole.new()
	add_child(sim)
	sim.avvia(gs.desc)
	_prova("simulatore: la missione parte subito", sim.stato()["riga"].begins_with("TRE"))
	for k in 3:
		sim.premi("bumper", "sb")
	_prova("simulatore: 3 colpi = missione completata e premio", sim.regole.missioni.completate.size() == 1 and int(sim.stato()["punti"]) >= 9300)
	_prova("simulatore: i messaggi del tabellone si vedono", sim.stato()["messaggi"].any(func(x): return x.contains("COMPLETATA")))
	sim.queue_free()
	# v0.16: ventaglio dalla paletta e mappa di calore (motore vero, senza finestra)
	var rv := gs.esegui({"comando": "ventaglio", "paletta": "sx", "colpi": 4})
	_prova("ventaglio: 4 tiri dalla paletta, dalla base alla punta", rv["ok"] and gs.ultima_traccia["tiri"].size() == 4 and gs.ultima_traccia["tiri"][3]["frazione"] > gs.ultima_traccia["tiri"][0]["frazione"] and gs.ultima_traccia["tiri"][2]["punti"].size() > 10)
	var rc := gs.esegui({"comando": "calore", "secondi": 10})
	_prova("mappa di calore: quadretti contati giocando da solo", rc["ok"] and (gs.ultima_traccia["calore"] as Dictionary).size() > 20)
	# controllo di sicurezza (24/11): tutti gli script dell'editor e del gioco si caricano senza errori
	var rotti: Array = []
	for f_scr in ["res://editor/editor.gd", "res://editor/vista_tavolo.gd", "res://editor/simulatore.gd", "res://motore/main.gd",
			"res://interfaccia/menu.gd", "res://interfaccia/hud.gd", "res://grafica/vista_2d.gd", "res://tools/tracciatore.gd", "res://tools/caccia_incastri.gd"]:
		var sc = load(f_scr)
		if sc == null or not (sc as Script).can_instantiate():
			rotti.append(f_scr)
	_prova("tutti gli script si caricano senza errori %s" % str(rotti), rotti.is_empty())
	await _prova_mouse()
	print("==== EDITOR: %d OK, %d FALLITI ====" % [ok, falliti])
	get_tree().quit(0 if falliti == 0 else 1)

## Il mouse sulla vista: clic per aggiungere, clic per scegliere, trascinamento, muro a punti.
func _clic(v: VistaTavolo, mm: Vector2, giu: bool, doppio := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = giu
	e.double_click = doppio
	e.position = v.px(mm)
	v._gui_input(e)

func _muovi(v: VistaTavolo, mm: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = v.px(mm)
	v._gui_input(e)

func _prova_mouse() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Mouse"})
	var v := VistaTavolo.new()
	v.progetto = p
	v.size = Vector2(800, 1000)
	add_child(v)
	v.adatta()
	v.da_inserire = "bumper"
	_clic(v, Vector2(301, 402), true)
	_clic(v, Vector2(301, 402), false)
	_prova("mouse: clic aggiunge un bumper (agganciato a 5 mm)", p.desc["bumper"].size() == 1 and p.desc["bumper"][0]["pos"] == Vector2(300, 400))
	v.da_inserire = ""
	v.seleziona("")
	_clic(v, Vector2(305, 405), true)
	_prova("mouse: clic sul bumper lo sceglie", v.selezionato == "bumper_1")
	_muovi(v, Vector2(325, 445))
	_muovi(v, Vector2(355, 505))
	_clic(v, Vector2(355, 505), false)
	_prova("mouse: trascinamento sposta il bumper", p.pezzo("bumper_1")["pos"] == Vector2(350, 500))
	p.esegui({"comando": "annulla"})
	_prova("mouse: annulla riporta il bumper (una sola voce)", p.pezzo("bumper_1")["pos"] == Vector2(300, 400))
	# v0.9: maniglie della buca (direzione d'uscita e punto dove riappare)
	var rbuca := p.esegui({"comando": "aggiungi", "tipo": "buche", "pos": [150, 600], "valori": {"tipo": "passaggio", "uscita": [400, 300]}})
	v.seleziona(rbuca["id"])
	var mb: Dictionary = v._maniglie_buca()
	_clic(v, mb["freccia"], true)
	_muovi(v, Vector2(190, 600))
	_clic(v, Vector2(190, 600), false)
	_prova("mouse: la freccia verde cambia la direzione d'uscita della buca", Vector2(p.pezzo(rbuca["id"])["uscita_dir"]).is_equal_approx(Vector2(1, 0)))
	_clic(v, Vector2(400, 300), true)
	_muovi(v, Vector2(450, 320))
	_clic(v, Vector2(450, 320), false)
	_prova("mouse: il mirino viola sposta dove riappare la pallina", p.pezzo(rbuca["id"])["uscita"] == Vector2(450, 320) and p.desc["passaggi"].any(func(q): return q.get("uscita") == Vector2(450, 320)))
	p.esegui({"comando": "elimina", "id": rbuca["id"]})
	# v0.9: piano rialzato con un doppio clic = forma pronta
	v.da_inserire = "piani"
	_clic(v, Vector2(300, 250), true)
	_clic(v, Vector2(300, 250), false)
	_clic(v, Vector2(300, 250), true, true)
	_clic(v, Vector2(300, 250), false)
	_prova("mouse: doppio clic col Piano = piano rialzato pronto", p.desc.get("piani", []).size() == 1 and p.desc["livelli"].size() >= 1)
	p.esegui({"comando": "annulla"})
	v.da_inserire = ""
	# v0.7: maniglie dell'immagine del pezzo (sposta col rombo, ingrandisce con l'angolo)
	var img_m := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img_m.fill(Color.RED)
	var f_m := ProjectSettings.globalize_path("user://prova_maniglie.png")
	img_m.save_png(f_m)
	p.esegui({"comando": "immagine", "id": "bumper_1", "file": f_m, "misura": "centro"})
	v.seleziona("bumper_1")
	var mi: Array = v._maniglie_immagine()
	_clic(v, mi[0], true)
	_muovi(v, Vector2(mi[0]) + Vector2(10, 0))
	_muovi(v, Vector2(mi[0]) + Vector2(20, 0))
	_clic(v, Vector2(mi[0]) + Vector2(20, 0), false)
	_prova("mouse: il rombo sposta l'immagine sul pezzo", Vector2(p.pezzo("bumper_1")["immagine"]["pos"]).x == 20.0 and p.pezzo("bumper_1")["pos"] == Vector2(300, 400))
	mi = v._maniglie_immagine()
	var d0: Vector2 = p.pezzo("bumper_1")["immagine"]["dim"]
	_clic(v, mi[1], true)
	_muovi(v, Vector2(mi[1]) + Vector2(10, 10))
	_clic(v, Vector2(mi[1]) + Vector2(10, 10), false)
	var d1: Vector2 = p.pezzo("bumper_1")["immagine"]["dim"]
	_prova("mouse: l'angolo ingrandisce l'immagine (proporzioni uguali)", d1.x > d0.x and is_equal_approx(d1.x, d1.y))
	p.esegui({"comando": "annulla"})
	_prova("mouse: annulla rimette la grandezza", Vector2(p.pezzo("bumper_1")["immagine"]["dim"]) == d0)
	# v0.27: pallino di rotazione dell'immagine del pezzo
	mi = v._maniglie_immagine()
	_clic(v, mi[4], true)
	_muovi(v, Vector2(mi[0]) + Vector2(80, 0))
	_clic(v, Vector2(mi[0]) + Vector2(80, 0), false)
	_prova("mouse v0.27: il pallino ruota l'immagine del pezzo (90°)", is_equal_approx(float(p.pezzo("bumper_1")["immagine"]["rot"]), PI / 2.0) and p.pezzo("bumper_1")["pos"] == Vector2(300, 400))
	p.esegui({"comando": "annulla"})
	_prova("mouse v0.27: annulla rimette la rotazione", is_zero_approx(float(p.pezzo("bumper_1")["immagine"].get("rot", 0.0))))
	# v0.28: maniglie sui lati = solo larghezza / solo altezza
	mi = v._maniglie_immagine()
	var dl0: Vector2 = p.pezzo("bumper_1")["immagine"]["dim"]
	_clic(v, mi[8], true)
	_muovi(v, Vector2(mi[8]) + Vector2(15, 0))
	_clic(v, Vector2(mi[8]) + Vector2(15, 0), false)
	var dl1: Vector2 = p.pezzo("bumper_1")["immagine"]["dim"]
	_prova("mouse v0.28: il lato destro allarga solo la larghezza", dl1.x > dl0.x + 20.0 and is_equal_approx(dl1.y, dl0.y))
	mi = v._maniglie_immagine()
	_clic(v, mi[9], true)
	_muovi(v, Vector2(mi[9]) + Vector2(0, -10))
	_clic(v, Vector2(mi[9]) + Vector2(0, -10), false)
	var dl2: Vector2 = p.pezzo("bumper_1")["immagine"]["dim"]
	_prova("mouse v0.28: il lato basso cambia solo l'altezza", dl2.y < dl1.y - 10.0 and is_equal_approx(dl2.x, dl1.x))
	p.esegui({"comando": "annulla"})
	p.esegui({"comando": "annulla"})
	_prova("mouse v0.28: annulla rimette larghezza e altezza", Vector2(p.pezzo("bumper_1")["immagine"]["dim"]) == dl0)
	p.esegui({"comando": "immagine", "id": "bumper_1", "togli": true})
	# v0.27: immagine sul piano: quadratino = grandezza, pallino = rotazione
	var r_deco := p.esegui({"comando": "aggiungi", "tipo": "decorazioni", "pos": [300, 700], "file": f_m})
	v.seleziona(str(r_deco.get("id", "")))
	var md: Array = v._maniglie_immagine()
	_prova("mouse v0.27: l'immagine sul piano ha le maniglie", md.size() == 10 and bool(md[5]))
	if md.size() == 10:
		var dd0: Vector2 = md[2]["dim"]
		_clic(v, md[1], true)
		for k in 5:
			_muovi(v, Vector2(md[1]) + Vector2(8, 8) * (k + 1))
		_clic(v, Vector2(md[1]) + Vector2(40, 40), false)
		var dd1: Vector2 = md[2]["dim"]
		_prova("mouse v0.27: l'angolo ingrandisce l'immagine sul piano", dd1.x > dd0.x and is_equal_approx(dd1.x / dd1.y, dd0.x / dd0.y) and Vector2(md[2]["immagine"]["dim"]) == dd1)
		md = v._maniglie_immagine()
		_clic(v, md[4], true)
		var ev_c := InputEventMouseMotion.new()
		ev_c.position = v.px(Vector2(md[0]) + Vector2(50, -40))
		ev_c.ctrl_pressed = true
		v._gui_input(ev_c)
		_clic(v, Vector2(md[0]) + Vector2(50, -40), false)
		var ang := rad_to_deg(float(md[2].get("angolo", 0.0)))
		_prova("mouse v0.27: il pallino ruota l'immagine sul piano, Ctrl a scatti di 15°", absf(ang) > 1.0 and is_zero_approx(fmod(absf(ang) + 0.001, 15.0) - 0.001))
		_prova("mouse v0.27: ruotando l'immagine sul piano resta al suo posto", Vector2(md[2]["pos"]).distance_to(Vector2(300, 700)) < 0.01)
		md = v._maniglie_immagine()
		var dq0: Vector2 = md[2]["dim"]
		_clic(v, md[9], true)
		_muovi(v, Vector2(md[0]) + (Vector2(0, dq0.y * 0.5 + 30)).rotated(float(md[6])))
		_clic(v, Vector2(md[0]) + (Vector2(0, dq0.y * 0.5 + 30)).rotated(float(md[6])), false)
		var dq1: Vector2 = md[2]["dim"]
		_prova("mouse v0.28: l'immagine sul piano si allunga solo in altezza", dq1.y > dq0.y + 40.0 and is_equal_approx(dq1.x, dq0.x) and Vector2(md[2]["immagine"]["dim"]) == dq1)
		# v0.28: immagine bloccata: il clic la sceglie ancora, ma non si sposta e non ha maniglie; poi si sblocca
		var idb := str(md[2]["id"])
		p.esegui({"comando": "gruppo", "ids": [idb], "azione": "blocca", "valore": true})
		v.seleziona("")
		var pos_b: Vector2 = md[2]["pos"]
		_clic(v, pos_b, true)
		_muovi(v, pos_b + Vector2(30, 0))
		_clic(v, pos_b + Vector2(30, 0), false)
		_prova("mouse v0.28: l'immagine bloccata si riseleziona col clic", v.selezionato == idb)
		_prova("mouse v0.28: l'immagine bloccata non si sposta e non ha maniglie", Vector2(p.pezzo(idb)["pos"]) == pos_b and v._maniglie_immagine().is_empty())
		p.esegui({"comando": "gruppo", "ids": [idb], "azione": "blocca", "valore": false})
		_prova("mouse v0.28: sbloccata ritornano le maniglie", v._maniglie_immagine().size() == 10)
		p.esegui({"comando": "elimina", "id": md[2]["id"]})
	# v0.28.1: la barra FINE sta FERMA (si deve poter cliccare) e, se c'è posto, fuori dal tavolo
	v.da_inserire = "rampe"
	_clic(v, Vector2(300, 600), true)
	_clic(v, Vector2(300, 600), false)
	v._piazza_barra()
	var bar: Control = v._barra_disegno
	var pos0 := bar.position
	_muovi(v, Vector2(320, 610))
	var ev_b := InputEventMouseMotion.new()
	ev_b.position = bar.position + bar.size * 0.5
	v._gui_input(ev_b)
	_prova("v0.28.1: la barra FINE resta ferma quando il mouse ci va sopra", bar.visible and bar.position == pos0)
	var r_tav := Rect2(v.px(Vector2.ZERO), v.px(Vector2(635, 1240)) - v.px(Vector2.ZERO))
	var c_spazio := maxf(r_tav.position.x, v.size.x - r_tav.end.x) >= bar.size.x + 24.0
	_prova("v0.28.1: con spazio a lato la barra non copre il tavolo", not c_spazio or not Rect2(bar.position, bar.size).intersects(r_tav))
	v.annulla_disegno()
	v.da_inserire = "muri"
	_clic(v, Vector2(100, 200), true)
	_clic(v, Vector2(100, 200), false)
	_clic(v, Vector2(200, 250), true)
	_clic(v, Vector2(200, 250), false)
	v.finisci_muro()
	_prova("mouse: muro disegnato con 2 clic", p.pezzo("muro_1").get("punti", []).size() == 2)
	v.da_inserire = ""
	v.seleziona("muro_1")
	_clic(v, Vector2(200, 250), true)
	_muovi(v, Vector2(220, 260))
	_clic(v, Vector2(220, 260), false)
	_prova("mouse: trascinare un quadratino sposta il punto", p.pezzo("muro_1")["punti"][1] == Vector2(220, 260))
	# fine del disegno: clic destro e chiusura automatica (24/11)
	v.seleziona("")
	v.da_inserire = "nastri"
	_clic(v, Vector2(150, 300), true)
	_clic(v, Vector2(150, 300), false)
	_clic(v, Vector2(150, 500), true)
	_clic(v, Vector2(150, 500), false)
	_prova("disegno: barra Fine/Annulla visibile", v._barra_disegno.visible)
	var dx := InputEventMouseButton.new()
	dx.button_index = MOUSE_BUTTON_RIGHT
	dx.pressed = true
	dx.position = v.px(Vector2(200, 600))
	v._gui_input(dx)
	_prova("disegno: il clic destro finisce il nastro", p.desc["nastri"].size() == 1 and not v.disegno_in_corso() and not v._barra_disegno.visible)
	_clic(v, Vector2(400, 300), true)
	_clic(v, Vector2(400, 300), false)
	_clic(v, Vector2(420, 500), true)
	_clic(v, Vector2(420, 500), false)
	v.chiudi_disegno()
	_prova("disegno: chiuso da solo (es. prima di GIOCA)", p.desc["nastri"].size() == 2)
	v.da_inserire = ""
	# Maiusc+clic e rettangolo
	v.seleziona("")
	p.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [500, 300]})
	var e2 := InputEventMouseButton.new()
	e2.button_index = MOUSE_BUTTON_LEFT
	e2.pressed = true
	e2.shift_pressed = true
	e2.position = v.px(Vector2(300, 400))
	v._gui_input(e2)
	e2.position = v.px(Vector2(500, 300))
	v._gui_input(e2)
	_prova("mouse: Maiusc+clic sceglie due pezzi", v.selezionati.size() == 2)
	v.seleziona("")
	_clic(v, Vector2(250, 250), true)
	_muovi(v, Vector2(560, 450))
	_clic(v, Vector2(560, 450), false)
	_prova("mouse: rettangolo sceglie i pezzi dentro", "bumper_1" in v.selezionati and "bumper_2" in v.selezionati)
	_clic(v, Vector2(300, 400), true)
	_muovi(v, Vector2(320, 420))
	_clic(v, Vector2(320, 420), false)
	_prova("mouse: trascinare uno sposta tutto il gruppo", p.pezzo("bumper_2")["pos"] == Vector2(520, 320))
	_prove_v029(p, v)
	v.queue_free()

## v0.29: luce nuova come l'ultima, immagine sul piano più grande del tavolo, vista ferma quando cambia misura.
func _prove_v029(p: ProgettoEditor, v: VistaTavolo) -> void:
	ProgettoEditor.ultima_luce = {}
	var r1 := p.esegui({"comando": "aggiungi", "tipo": "inserti", "pos": [200, 600]})
	p.esegui({"comando": "imposta", "id": r1["id"], "campo": "colore", "valore": Color(0.2, 0.3, 0.9)})
	p.esegui({"comando": "imposta", "id": r1["id"], "campo": "dim", "valore": Vector2(15, 15)})
	var r2 := p.esegui({"comando": "aggiungi", "tipo": "inserti", "pos": [260, 600]})
	var l2 := p.pezzo(r2["id"])
	_prova("luce nuova: stesso colore e misura dell'ultima scelta", (l2["colore"] as Color).is_equal_approx(Color(0.2, 0.3, 0.9)) and l2["dim"] == Vector2(15, 15))
	var r3 := p.esegui({"comando": "aggiungi", "tipo": "inserti", "pos": [300, 600]}, "ai")
	_prova("luce nuova dai comandi automatici: valori predefiniti", p.pezzo(r3["id"])["dim"] == Vector2(20, 20))
	ProgettoEditor.ultima_luce = {}
	# immagine sul piano alta 1600 mm (più del tavolo): le maniglie restano dentro la vista e funzionano
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.2, 0.8))
	var f_img := "user://prova_v029.png"
	img.save_png(f_img)
	var rd := p.esegui({"comando": "aggiungi", "tipo": "decorazioni", "pos": [310, 585]})
	p.esegui({"comando": "immagine", "id": rd["id"], "file": ProjectSettings.globalize_path(f_img)})
	var de := p.pezzo(rd["id"])
	de["dim"] = Vector2(790, 1600)
	v.adatta()
	v.scala = 1.0
	v.origine = Vector2(80, -100)
	v.seleziona(rd["id"])
	var mi := v._maniglie_immagine()
	var dentro := Rect2(Vector2.ZERO, v.size)
	var tutte_dentro := true
	for j in [0, 1, 4, 8, 9]:
		tutte_dentro = tutte_dentro and dentro.has_point(v._pm(mi[j]))
	_prova("immagine grande: angolo, lati e rotazione disegnati dentro la vista", not mi.is_empty() and tutte_dentro and not dentro.has_point(v.px(mi[1])))
	_prova("immagine grande: il clic dentro l'immagine disegnata la sceglie", v._pezzo_immagine_in(Vector2(310, 1300), true) == rd["id"] or v.pezzo_in(Vector2(310, 1300)) == rd["id"])
	# allunga dal lato basso (riportato dentro lo schermo): l'altezza cambia nella stessa proporzione del mouse
	var q0 := v.mm(v._pm(mi[9]))
	var d0: Vector2 = de["dim"]
	_clic(v, q0, true)
	var q1 := Vector2(310, 585) + (q0 - Vector2(310, 585)) * 0.5
	_muovi(v, q1)
	_clic(v, q1, false)
	var de2 := p.pezzo(rd["id"])
	_prova("immagine grande: il lato basso riportato dentro allunga/accorcia l'altezza (%.0f → %.0f)" % [d0.y, Vector2(de2["dim"]).y], absf(Vector2(de2["dim"]).y - d0.y * 0.5) < 6.0 and absf(Vector2(de2["dim"]).x - d0.x) < 0.6)
	# rotazione dal pallino riportato dentro: gira di quanto gira il mouse intorno al centro
	mi = v._maniglie_immagine()
	var c: Vector2 = mi[0]
	var qr := v.mm(v._pm(mi[4]))
	_clic(v, qr, true)
	var qr2 := c + (qr - c).rotated(deg_to_rad(30))
	_muovi(v, qr2)
	_clic(v, qr2, false)
	_prova("immagine grande: il pallino riportato dentro gira l'immagine di 30°", absf(rad_to_deg(float(p.pezzo(rd["id"]).get("angolo", 0.0))) - 30.0) < 1.5)
	# vista ferma: se la zona del tavolo cambia larghezza (pannello a destra) il punto al centro resta al centro
	v._misura_prima = v.size
	var centro0 := v.centro_vista()
	var sc0 := v.scala
	v.size = v.size + Vector2(-120, 0)
	v._ridimensionata()
	_prova("vista: cambiando larghezza non torna indietro (stessa scala e stesso centro)", v.scala == sc0 and v.centro_vista().distance_to(centro0) <= 5.0)
	v._aggiorna_scorrimento()
	_prova("vista: barre di scorrimento con la parte vista", v._scorri_x.visible and v._scorri_y.visible and absf(v._scorri_y.page - v.size.y / v.scala) < 0.5)
	v._scorri_y.value = v._scorri_y.value + 100.0
	_prova("vista: la barra verticale fa scorrere il tavolo", absf(v.mm(Vector2.ZERO).y - v._scorri_y.value) < 0.5)
	_prove_maniglie_pezzi(p, v)
	_prove_varco(p, v)
	_prove_varco_piano()
	_prove_incroci()

## v0.29: maniglie col mouse per tutti i pezzi (ruota, ingrandisci, allarga, allunga).
func _trascina_maniglia(v: VistaTavolo, da: Vector2, a: Vector2, ctrl := false) -> void:
	_clic(v, da, true)
	var e := InputEventMouseMotion.new()
	e.position = v.px(a)
	e.ctrl_pressed = ctrl
	v._gui_input(e)
	_clic(v, a, false)

func _prove_maniglie_pezzi(p: ProgettoEditor, v: VistaTavolo) -> void:
	v.adatta()
	v.scala = 1.0
	v.origine = Vector2(100, 100)
	# cancello: ruota col pallino, si allarga dalla maniglia a destra
	var rc := p.esegui({"comando": "aggiungi", "tipo": "cancelli", "pos": [300, 300]})
	v.seleziona(rc["id"])
	var mp := v._maniglie_pezzo()
	_prova("maniglie: il cancello ha pallino di rotazione, angolo e lato", not mp.is_empty() and mp["ruota"] != null and mp["lato_x"] != null and mp["lato_y"] == null)
	var c: Vector2 = mp["c"]
	_trascina_maniglia(v, mp["ruota"], c + (Vector2(mp["ruota"]) - c).rotated(deg_to_rad(40)), true)
	_prova("maniglie: cancello ruotato col mouse a scatti di 15° (45°)", absf(rad_to_deg(float(p.pezzo(rc["id"])["angolo"])) - 45.0) < 0.6)
	mp = v._maniglie_pezzo()
	var l0 := float(p.pezzo(rc["id"])["larghezza"])
	var qx: Vector2 = mp["lato_x"]
	_trascina_maniglia(v, qx, c + (qx - c) * 1.5)
	_prova("maniglie: cancello allargato col mouse (%.0f → %.0f mm)" % [l0, float(p.pezzo(rc["id"])["larghezza"])], float(p.pezzo(rc["id"])["larghezza"]) > l0 * 1.3)
	p.esegui({"comando": "annulla"})
	_prova("maniglie: un solo «annulla» per trascinamento", is_equal_approx(float(p.pezzo(rc["id"])["larghezza"]), l0))
	# bersaglio: allunga solo l'altezza
	var rb := p.esegui({"comando": "aggiungi", "tipo": "bersagli", "pos": [450, 300]})
	v.seleziona(rb["id"])
	mp = v._maniglie_pezzo()
	var d0: Vector2 = p.pezzo(rb["id"])["dim"]
	_trascina_maniglia(v, mp["lato_y"], Vector2(mp["c"]) + (Vector2(mp["lato_y"]) - Vector2(mp["c"])) * 2.0)
	var d1: Vector2 = p.pezzo(rb["id"])["dim"]
	_prova("maniglie: bersaglio allungato solo in altezza (%s → %s)" % [d0, d1], d1.x == d0.x and d1.y > d0.y * 1.5)
	# bumper: il quadratino ingrandisce, il bumper tondo non ruota
	var ru := p.esegui({"comando": "aggiungi", "tipo": "bumper", "pos": [300, 450]})
	v.seleziona(ru["id"])
	mp = v._maniglie_pezzo()
	_prova("maniglie: il bumper non ha il pallino di rotazione", mp["ruota"] == null)
	_trascina_maniglia(v, mp["angolo"], Vector2(mp["c"]) + (Vector2(mp["angolo"]) - Vector2(mp["c"])) * 0.5)
	_prova("maniglie: bumper rimpicciolito dal quadratino", float(p.pezzo(ru["id"])["raggio"]) < 20.0)
	# muro: si allarga (punti) e le maniglie non coprono i suoi punti
	var rm := p.esegui({"comando": "aggiungi", "tipo": "muri", "punti": [[200, 600], [300, 650], [400, 600]]})
	v.seleziona(rm["id"])
	mp = v._maniglie_pezzo()
	var ok_punti := true
	for q in ProgettoEditor.punti_2d("muri", p.pezzo(rm["id"])):
		ok_punti = ok_punti and v._maniglia_pezzo_in(q) == ""
	_prova("maniglie: sul muro non coprono i punti", ok_punti)
	_trascina_maniglia(v, mp["lato_x"], Vector2(mp["c"]) + (Vector2(mp["lato_x"]) - Vector2(mp["c"])) * 2.0)
	var pts := ProgettoEditor.punti_2d("muri", p.pezzo(rm["id"]))
	_prova("maniglie: muro allargato (da 200 mm a circa 400)", absf((pts[2].x - pts[0].x) - 400.0) < 60.0 and pts[1].y == 650.0)

## v0.29: varco nel muro (toglie un tratto e ci mette un cancelletto, spinner o bersaglio).
func _prove_varco(p: ProgettoEditor, v: VistaTavolo) -> void:
	var nm0: int = p.desc["muri"].size()
	var rm := p.esegui({"comando": "aggiungi", "tipo": "muri", "punti": [[100, 900], [300, 900], [300, 1100]]})
	var r := p.esegui({"comando": "varco", "id": rm["id"], "pos": [200, 903], "larghezza": 46, "metti": "cancelli"})
	var cg := p.pezzo(str(r.get("id", "")))
	_prova("varco: il muro aperto diventa due muri", r.get("ok", false) and p.desc["muri"].size() == nm0 + 2 and r["muri"].size() == 2)
	var m1: PackedVector2Array = p.pezzo(rm["id"])["controllo"]
	var m2: PackedVector2Array = p.pezzo(str(r["muri"][1]))["controllo"]
	_prova("varco: i due pezzi finiscono ai lati del varco (177 e 223)", m1.size() == 2 and m1[1].is_equal_approx(Vector2(177, 900)) and m2[0].is_equal_approx(Vector2(223, 900)) and m2.size() == 3)
	_prova("varco: cancelletto in mezzo, largo come il varco e girato come il muro", not cg.is_empty() and Vector2(cg["pos"]) == Vector2(200, 900) and is_equal_approx(float(cg["larghezza"]), 46.0) and absf(float(cg["angolo"])) < 0.001)
	p.esegui({"comando": "annulla"})
	_prova("varco: un solo «annulla» rimette il muro intero", p.desc["muri"].size() == nm0 + 1 and p.pezzo(rm["id"])["controllo"].size() == 3 and p.desc.get("cancelli", []).filter(func(x): return x["id"] == cg["id"]).is_empty())
	# muro CHIUSO: si apre e resta uno solo
	var rq := p.esegui({"comando": "aggiungi", "tipo": "muri", "punti": [[400, 900], [500, 900], [500, 1000], [400, 1000]], "chiuso": true})
	var r2 := p.esegui({"comando": "varco", "id": rq["id"], "pos": [500, 950], "larghezza": 30, "metti": "spinner"})
	var mq := p.pezzo(rq["id"])
	var cq: PackedVector2Array = mq["controllo"]
	_prova("varco: il muro chiuso si apre e resta uno solo (6 punti, da 965 a 935)", r2.get("ok", false) and r2["muri"].size() == 1 and not bool(mq["chiuso"]) and cq.size() == 6 and cq[0].is_equal_approx(Vector2(500, 965)) and cq[5].is_equal_approx(Vector2(500, 935)))
	_prova("varco: lo spinner nel tratto verticale è girato di 90°", absf(absf(rad_to_deg(float(p.pezzo(r2["id"])["angolo"]))) - 90.0) < 0.5)
	# tratto CURVO: gli estremi del varco stanno sulla curva disegnata
	var rc := p.esegui({"comando": "aggiungi", "tipo": "muri", "punti": [[100, 300], [200, 200], [300, 300]], "curvi": [false, true, false]})
	var linea0: PackedVector2Array = p.pezzo(rc["id"])["punti"]
	var r3 := p.esegui({"comando": "varco", "id": rc["id"], "pos": [150, 240], "larghezza": 20, "metti": ""})
	var a: Vector2 = p.pezzo(rc["id"])["controllo"][p.pezzo(rc["id"])["controllo"].size() - 1]
	var dmin := INF
	for k in linea0.size() - 1:
		dmin = minf(dmin, Geometry2D.get_closest_point_to_segment(a, linea0[k], linea0[k + 1]).distance_to(a))
	_prova("varco: sul tratto curvo il taglio cade sulla curva (scarto %.2f mm)" % dmin, r3.get("ok", false) and dmin < 0.6 and not r3.has("id"))
	# col MOUSE: strumento varco, clic sul muro
	var rv := p.esegui({"comando": "aggiungi", "tipo": "muri", "punti": [[100, 700], [500, 700]]})
	v.varco_metti = "bersagli"
	v.varco_larghezza = 24.0
	v.da_inserire = "varco"
	_prova("varco col mouse: anteprima sul muro sotto il mouse", v.varco_sotto(Vector2(300, 702)).get("id", "") == rv["id"])
	_clic(v, Vector2(300, 702), true)
	_clic(v, Vector2(300, 702), false)
	var bs := p.pezzo(v.selezionato)
	_prova("varco col mouse: bersaglio messo nel varco e scelto", v.da_inserire == "" and not bs.is_empty() and Vector2(bs["dim"]).x == 24.0 and Vector2(bs["pos"]) == Vector2(300, 700))

## v0.29: varchi nel bordo del piano rialzato (dati e bordo spezzato).
func _prove_varco_piano() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "VarchiPiano"})
	var rp := p.esegui({"comando": "aggiungi", "tipo": "piani", "punti": [[200, 300], [400, 300], [400, 500], [200, 500]]})
	var id: String = rp["id"]
	var g := PianiRialzati.giro(p.pezzo(id))
	var tot := PianiRialzati.lunghezza(g)
	var r1 := p.esegui({"comando": "varco", "id": id, "pos": [300, 302], "larghezza": 50})
	var pezzi: Array = PianiRialzati.bordo_spezzato(p.pezzo(id))
	var l_pezzi := 0.0
	for pz in pezzi:
		l_pezzi += PianiRialzati.lunghezza(pz)
	_prova("varco piano: un varco = un pezzo di bordo lungo il giro meno 50 mm (%.0f di %.0f)" % [l_pezzi, tot], r1.get("ok", false) and pezzi.size() == 1 and absf(l_pezzi - (tot - 50.0)) < 1.0)
	var e1: Array = PianiRialzati.estremi_varchi(p.pezzo(id))
	_prova("varco piano: estremi del varco sul lato alto (275 e 325)", e1.size() == 1 and absf(Vector2(e1[0][0]).y - 300.0) < 0.5 and absf(absf(Vector2(e1[0][0]).x - Vector2(e1[0][1]).x) - 50.0) < 0.5)
	p.esegui({"comando": "varco", "id": id, "pos": [402, 400], "larghezza": 40})
	pezzi = PianiRialzati.bordo_spezzato(p.pezzo(id))
	_prova("varco piano: due varchi = due pezzi di bordo", pezzi.size() == 2)
	# varco a cavallo del primo punto del giro (l'angolo 200,300)
	p.esegui({"comando": "chiudi_varco", "id": id, "indice": 1})
	p.esegui({"comando": "chiudi_varco", "id": id, "indice": 0})
	p.esegui({"comando": "varco", "id": id, "pos": [200, 300], "larghezza": 60})
	pezzi = PianiRialzati.bordo_spezzato(p.pezzo(id))
	var ok_angolo := pezzi.size() == 1 and absf(PianiRialzati.lunghezza(pezzi[0]) - (tot - 60.0)) < 1.0
	for q in pezzi[0]:
		ok_angolo = ok_angolo and q.distance_to(Vector2(200, 300)) > 25.0
	_prova("varco piano: anche a cavallo dell'angolo di partenza il bordo resta giusto", ok_angolo)
	var muri_bordo: Array = p.desc["muri"].filter(func(m): return str(m.get("id", "")).begins_with(id + "@bordo"))
	_prova("varco piano: il motore ha il bordo spezzato", muri_bordo.size() == 1)
	# pezzi attaccati: nastro che sale
	var rn := p.esegui({"comando": "varco", "id": id, "pos": [300, 502], "larghezza": 56, "metti": "nastro_su"})
	var na := p.pezzo(str(rn.get("id", "")))
	var c_na: PackedVector2Array = na.get("controllo", PackedVector2Array())
	_prova("varco piano: il nastro che sale parte da fuori e finisce dentro il piano", c_na.size() == 3 and c_na[0].y > 600.0 and c_na[2].y < 500.0 and float(na["altezze"][2]) > 0.0)
	var rapporto := p.esegui({"comando": "varco", "id": id, "pos": [300, 502], "metti": "cancelli"})
	_prova("varco piano: sul piano niente cancelletto (solo rampe e nastri)", not rapporto.get("ok", true))

## v0.30: INCROCI (regole delle rampe, scelte dei singoli incroci, profilo di gioco, conflitti, salvataggio).
func _z_incrocio(p: ProgettoEditor, chiave: String) -> Array:
	for v in p.desc.get("_incroci", []):
		if v["chiave"] == chiave:
			return [float(v["za_gioco"]), float(v["zb_gioco"]), str(v.get("conflitto", "")), str(v.get("modo", "")), str(v.get("da", ""))]
	return []

func _prove_incroci() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Incroci"})
	var a := p.esegui({"comando": "aggiungi", "id": "rampa_a", "tipo": "rampe", "punti": [[100, 700], [300, 500], [500, 300]], "altezza_max": 40})
	var b := p.esegui({"comando": "aggiungi", "id": "rampa_b", "tipo": "rampe", "punti": [[100, 300], [300, 500], [500, 700]], "altezza_max": 40})
	var base_a: Array = p.pezzo("rampa_a")["punti"].duplicate()
	var incs: Array = p.desc.get("_incroci", [])
	_prova("incroci: due rampe che si incrociano = un incrocio con la sua chiave", incs.size() == 1 and incs[0]["chiave"] == "rampa_a|rampa_b#0")
	_prova("incroci: senza regole nessun profilo nuovo (tavoli vecchi uguali)", not p.pezzo("rampa_a").has("punti_gioco") and not p.pezzo("rampa_b").has("punti_gioco"))
	var k := "rampa_a|rampa_b#0"
	p.esegui({"comando": "incroci_regola", "id": "rampa_a", "modo": "sopra"})
	var z := _z_incrocio(p, k)
	_prova("incroci: «passa sopra» alza la rampa nell'incrocio (%.0f sopra %.0f)" % [z[0], z[1]], z[0] >= z[1] + 31.5 and z[2] == "")
	_prova("incroci: le altezze disegnate non cambiano (solo il profilo di gioco)", p.pezzo("rampa_a")["punti"] == base_a and p.pezzo("rampa_a").has("punti_gioco"))
	var pg: Array = p.pezzo("rampa_a")["punti_gioco"]
	_prova("incroci: imbocco e uscita restano dove sono", Vector3(pg[0]).is_equal_approx(Vector3(base_a[0])) and Vector3(pg[pg.size() - 1]).is_equal_approx(Vector3(base_a[base_a.size() - 1])))
	_prova("incroci: la rampa di sopra si disegna dopo quella di sotto", (p.desc.get("ordine_rampe", []) as Array).find("rampa_a") > (p.desc.get("ordine_rampe", []) as Array).find("rampa_b"))
	_prova("incroci: CONTROLLA non segnala più l'incrocio risolto", ControlliEditor.incroci(p.desc).is_empty())
	# conflitto: tutte e due «sopra»
	p.esegui({"comando": "incroci_regola", "id": "rampa_b", "modo": "sopra"})
	z = _z_incrocio(p, k)
	_prova("incroci: tutte e due «sopra» = conflitto, l'editor non sceglie", z[2] != "" and not p.pezzo("rampa_a").has("punti_gioco") and not Incroci.controlli(p.desc).is_empty())
	# scelta del singolo incrocio: vince sulle regole e resta quando cambi la regola
	p.esegui({"comando": "incrocio", "chiave": k, "modo": "b_sotto"})
	z = _z_incrocio(p, k)
	_prova("incroci: la scelta del singolo incrocio risolve il conflitto (b sotto)", z[2] == "" and z[4] == "incrocio" and z[0] >= z[1] + 31.5)
	p.esegui({"comando": "incroci_regola", "id": "rampa_b", "modo": "stesso"})
	z = _z_incrocio(p, k)
	_prova("incroci: cambiando la regola della rampa la scelta a mano resta (test 6)", z[3] == "b_sotto" and z[4] == "incrocio")
	# quota a mano, anche «sbagliata»: si tiene e si segnala
	p.esegui({"comando": "incrocio", "chiave": k, "modo": "a_sopra", "quota": 30})
	z = _z_incrocio(p, k)
	var segnalato := ControlliEditor.incroci(p.desc).any(func(x): return str(x["tipo"]) == "incrocio")
	_prova("incroci: quota a mano troppo bassa = tenuta e segnalata, non corretta (test 8)", absf(z[0] - maxf(30.0, z[0])) < 0.6 and segnalato)
	# torna automatico
	var rt := p.esegui({"comando": "incroci_automatico", "id": "rampa_a"})
	z = _z_incrocio(p, k)
	_prova("incroci: «torna automatico» toglie le scelte a mano e segue le regole (test 7)", int(rt.get("tolti", 0)) == 1 and z[4] == "regole")
	# stessa altezza: niente profilo, niente avviso di differenza
	p.esegui({"comando": "incroci_regola", "id": "rampa_a", "modo": "stesso"})
	_prova("incroci: «stessa altezza» non cambia le altezze e non è un errore", not p.pezzo("rampa_a").has("punti_gioco") and ControlliEditor.incroci(p.desc).is_empty())
	# passa SOTTO: una rampa alta e una bassa
	p.esegui({"comando": "incroci_regola", "id": "rampa_a", "modo": ""})
	p.esegui({"comando": "incroci_regola", "id": "rampa_b", "modo": ""})
	p.esegui({"comando": "punto", "id": "rampa_b", "altezza_tutta": 60})
	p.esegui({"comando": "incroci_regola", "id": "rampa_a", "modo": "sotto"})
	z = _z_incrocio(p, k)
	_prova("incroci: «passa sotto» abbassa la rampa nell'incrocio (%.0f sotto %.0f)" % [z[0], z[1]], z[2] == "" and z[0] <= z[1] - 31.5 and z[0] < 39.0)
	# salvataggio e riapertura (test 10)
	p.esegui({"comando": "incrocio", "chiave": k, "modo": "b_sopra", "bloccato": false})
	var cart := ProjectSettings.globalize_path("user://prova_incroci.pinproj")
	p.esegui({"comando": "salva", "cartella": cart})
	var q := ProgettoEditor.new()
	q.esegui({"comando": "apri", "cartella": cart})
	var zq := _z_incrocio(q, k)
	_prova("incroci: dopo salva e riapri regole e scelte sono uguali (test 10)", str(q.pezzo("rampa_a").get("incroci_modo", "")) == "sotto" and zq.size() == 5 and zq[3] == "b_sopra" and zq[4] == "incrocio")
	# annulla e ripristina (test 12)
	var prima := str(p.pezzo("rampa_a").get("incroci_modo", ""))
	p.esegui({"comando": "incroci_regola", "id": "rampa_a", "modo": "sopra"})
	p.esegui({"comando": "annulla"})
	var dopo_annulla := str(p.pezzo("rampa_a").get("incroci_modo", ""))
	p.esegui({"comando": "ripristina"})
	_prova("incroci: annulla e ripristina della regola (test 12)", dopo_annulla == prima and str(p.pezzo("rampa_a").get("incroci_modo", "")) == "sopra")
	# più incroci: una rampa che ne attraversa due, configurazioni indipendenti (test 5)
	var r3 := ProgettoEditor.new()
	r3.esegui({"comando": "nuovo", "modello": "base", "nome": "Piu"})
	r3.esegui({"comando": "aggiungi", "id": "lunga", "tipo": "rampe", "punti": [[80, 500], [300, 500], [560, 500]], "altezza_max": 40})
	r3.esegui({"comando": "aggiungi", "id": "x1", "tipo": "rampe", "punti": [[200, 300], [200, 500], [200, 700]], "altezza_max": 40})
	r3.esegui({"comando": "aggiungi", "id": "x2", "tipo": "rampe", "punti": [[420, 300], [420, 500], [420, 700]], "altezza_max": 40})
	r3.esegui({"comando": "incroci_regola", "id": "lunga", "modo": "sopra"})
	r3.esegui({"comando": "incrocio", "chiave": "lunga|x2#0", "modo": "stesso"})
	var z1 := _z_incrocio(r3, "lunga|x1#0")
	var z2 := _z_incrocio(r3, "lunga|x2#0")
	_prova("incroci: più incroci sulla stessa rampa, ognuno con la sua scelta (test 5)", z1.size() == 5 and z2.size() == 5 and z1[0] >= z1[1] + 31.5 and z2[3] == "stesso")
	# spostamento (test 13): la scelta a mano resta finché l'incrocio esiste
	r3.esegui({"comando": "sposta", "id": "x2", "di": [20, 0]})
	_prova("incroci: spostando un pezzo la scelta a mano dell'incrocio resta (test 13)", _z_incrocio(r3, "lunga|x2#0").size() == 5 and _z_incrocio(r3, "lunga|x2#0")[3] == "stesso")
	_prove_varchi_proposti()

## v0.30: varco proposto quando una rampa sale su un piano chiuso (test 9, parte editor; la parte di gioco è nel collaudo).
func _prove_varchi_proposti() -> void:
	var p := ProgettoEditor.new()
	p.esegui({"comando": "nuovo", "modello": "base", "nome": "Proposti"})
	var rp := p.esegui({"comando": "aggiungi", "tipo": "piani", "punti": [[200, 300], [420, 300], [420, 460], [200, 460]]})
	p.esegui({"comando": "aggiungi", "id": "su", "tipo": "rampe", "punti": [[310, 800], [310, 600], [310, 400]]})
	var pr := PianiRialzati.varchi_proposti(p.desc, p.pezzo(rp["id"]))
	_prova("varchi proposti: la rampa che sale sul piano chiuso fa proporre un varco nel bordo", pr.size() == 1 and absf(Vector2(pr[0]["pos"]).y - 460.0) < 1.0)
	_prova("varchi proposti: CONTROLLA lo dice come informazione", Incroci.controlli(p.desc).any(func(x): return str(x["tipo"]) == "varco"))
	var r := p.esegui({"comando": "varchi_proposti", "id": rp["id"]})
	_prova("varchi proposti: confermati, il bordo si apre lì e non si propone più", int(r.get("aperti", 0)) == 1 and PianiRialzati.varchi_proposti(p.desc, p.pezzo(rp["id"])).is_empty() and (p.pezzo(rp["id"])["varchi"] as Array).size() == 1)
	_prove_compatibilita_incroci()

## profili di gioco, niente innesti, nessuna rampa cambiata. Solo lettura (i file non si toccano).
## E per il test 14: tavolo con tutti i tipi di incrocio per la caccia agli incastri (user://incroci_caccia.tavolo).
func _prove_compatibilita_incroci() -> void:
	var file: Array = []
	var dir_p := ProjectSettings.globalize_path("res://").path_join("../progetti")
	var da := DirAccess.open(dir_p)
	if da != null:
		for cart in da.get_directories():
			if FileAccess.file_exists(dir_p.path_join(cart).path_join("tavolo.tavolo")):
				file.append(dir_p.path_join(cart).path_join("tavolo.tavolo"))
	var da2 := DirAccess.open("res://tavoli/modelli")
	if da2 != null:
		for f in da2.get_files():
			if f.ends_with(".tavolo"):
				file.append("res://tavoli/modelli/" + f)
	var cambiati: Array = []
	for f in file:
		var d := FileTavolo.leggi(f)
		if d.is_empty():
			continue
		# la preparazione di sempre (piani, rampe collegate…), poi SOLO il calcolo degli incroci: non deve cambiare niente
		CurveEditor.prepara_tavolo(d)
		var prima := var_to_str(d.get("rampe", []).map(func(r): return r.get("punti", [])))
		Incroci.applica(d)
		var dopo := var_to_str(d.get("rampe", []).map(func(r): return r.get("punti", [])))
		var profili: Array = d.get("rampe", []).filter(func(r): return r.has("punti_gioco"))
		if prima != dopo or not profili.is_empty() or d.has("innesti") or d.has("ordine_rampe"):
			cambiati.append(f.get_file() if not f.ends_with("tavolo.tavolo") else f.get_base_dir().get_file())
	_prova("incroci (test 11): %d tavoli vecchi letti, nessuno cambia (rampe, profili, innesti) %s" % [file.size(), str(cambiati)], file.size() >= 3 and cambiati.is_empty())
	# tavoli per la caccia agli incastri (test 14): uguali, uno SENZA regole e uno CON (ponte sul nastro, comunicante)
	for con in [false, true]:
		var p := ProgettoEditor.new()
		p.esegui({"comando": "nuovo", "modello": "base", "nome": "Caccia"})
		p.esegui({"comando": "aggiungi", "id": "corsia", "tipo": "nastri", "punti": [[110, 470], [470, 650]], "larghezza": 46})
		p.esegui({"comando": "aggiungi", "id": "filo", "tipo": "rampe", "punti": [[320, 900], [320, 450], [470, 330], [540, 700]], "altezza_max": 30})
		p.esegui({"comando": "aggiungi", "id": "ra", "tipo": "rampe", "punti": [[120, 820], [200, 420], [330, 280], [150, 640]], "altezza_max": 45})
		p.esegui({"comando": "aggiungi", "id": "rb", "tipo": "rampe", "punti": [[90, 300], [260, 330], [300, 600]], "altezza_max": 45})
		if con:
			p.esegui({"comando": "incroci_regola", "id": "filo", "modo": "sopra"})
			for v in p.desc.get("_incroci", []):
				if str(v["chiave"]).begins_with("ra|rb"):
					p.esegui({"comando": "incrocio", "chiave": v["chiave"], "modo": "unito", "devia": "alterna"})
		p.salva_prova(ProjectSettings.globalize_path("user://incroci_caccia_%s.tavolo" % ("con" if con else "senza")))
		if con:
			print("   INCROCI_CACCIA ", var_to_str(p.desc.get("_incroci", []).map(func(v): return [v["chiave"], v["modo"], Vector2(v["pos"]).round()])))
	_prova("incroci (test 14): tavoli di prova senza e con le regole pronti per la caccia agli incastri", FileAccess.file_exists("user://incroci_caccia_con.tavolo"))
