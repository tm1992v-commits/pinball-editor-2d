## Progetto aperto nel Pinball Editor 2D (v0.1, 23/11/2026) e COMANDI che lo modificano.
## Ogni modifica passa da `esegui(comando)`: la usano i pulsanti, la tastiera e l'AI (file di comandi). Prima di ogni
## modifica si salva una copia del tavolo (annulla), e ogni comando va nel diario del progetto.
## Cartella di progetto: <nome>.pinproj/ con tavolo.tavolo (il tavolo in mm) e diario.txt.
class_name ProgettoEditor
extends RefCounted

signal cambiato()

const FILE_TAVOLO := "tavolo.tavolo"
const MAX_ANNULLA := 200
const MODELLI := {"base": "res://tavoli/base/layout_base.gd", "spazio": "res://tavoli/spazio/layout_spazio.gd"}
## Tavoli pronti: file .tavolo nella cartella dei modelli (nome del file = nome del modello).
const CARTELLA_MODELLI := "res://tavoli/modelli/"
## Liste del tavolo che contengono pezzi con un id (quelle che l'editor conosce).
## ultimo risultato del tracciatore (v0.9.5): la vista lo disegna
var ultima_traccia: Dictionary = {}
const LISTE := ["muri", "palette", "fionde", "bumper", "bersagli", "buche", "spinner", "sensori", "elastici",
	"kickback", "campi", "inserti", "porte", "rampe", "captive", "passaggi", "nastri", "decorazioni", "cancelli", "piani", "lame"]

var desc: Dictionary = {}
## per l'ultima luce (forma, misura, colore, bordo…) vale per le luci NUOVE finché l'editor resta aperto, anche
## cambiando tavolo. Solo per i comandi dell'utente, non per quelli automatici.
const RICORDA_LUCE := ["forma", "dim", "colore", "aspetto", "altezza_3d", "bordo", "colore_bordo", "intensita_bordo"]
static var ultima_luce: Dictionary = {}
var _chi := "utente"
var cartella := ""                     # percorso assoluto della cartella .pinproj ("" = mai salvato)
var modificato := false
var _annulla: Array = []
var _ripeti: Array = []

# ================================================================ comandi
## Esegue un comando {"comando": nome, ...parametri}. Restituisce {"ok": bool, "messaggio": testo, ...}.
func esegui(c: Dictionary, chi := "utente") -> Dictionary:
	_chi = chi
	var nome := str(c.get("comando", ""))
	var r: Dictionary
	match nome:
		"importa_flipper":
			r = _importa_flipper(c)
		"gioco_info":
			r = _gioco_info(c)
		"verifica_rilascio":
			var vr := LicenzeProgetto.verifica(self)
			r = {"ok": vr["ok"], "messaggio": "Pronto per il rilascio" if vr["ok"] else "Da sistemare: " + "; ".join(vr["problemi"]), "problemi": vr["problemi"], "avvisi": vr["avvisi"]}
		"rilascio":
			# pubblicare su un servizio esterno (GitHub) richiede il consenso della PERSONA: mai dai comandi automatici
			if chi == "ai" and str(c.get("dest", {}).get("tipo", "")) == "github":
				r = {"ok": false, "messaggio": "La pubblicazione su GitHub si fa solo dall'editor, con il consenso dell'utente"}
			else:
				r = Rilascio.rilascia(self, c)
		"tema":
			r = _tema(str(c.get("nome", "")))
		"sistema_varchi":
			r = _sistema_varchi(int(c.get("giri", 6)))
		"segreto_aggiungi", "segreto_imposta", "segreto_togli":
			r = _segreti_cmd(c)
		"classifica":
			_ricorda()
			desc["classifica"] = bool(c.get("attiva", true))
			_fatto()
			r = {"ok": true, "messaggio": "Classifica dei 10 migliori %s" % ("accesa: a fine partita si scrivono le iniziali" if desc["classifica"] else "spenta: resta solo il record")}
		"nuovo":
			r = _nuovo(str(c.get("modello", "base")), str(c.get("nome", "nuovo")), c.get("forma", "classica"))
		"forma":
			r = _forma(c.get("forma", "classica"))
		"imposta_tavolo":
			r = _imposta_tavolo(str(c.get("campo", "")), c.get("valore"))
		"apri":
			r = apri(str(c.get("cartella", "")))
		"salva":
			r = salva(str(c.get("cartella", cartella)))
		"annulla":
			r = annulla()
		"ripristina":
			r = ripristina()
		"aggiungi":
			r = _aggiungi(c)
		"varco":
			r = _varco(c)
		"chiudi_varco":
			r = _chiudi_varco_piano(c)
		"varchi_proposti":
			# v0.30: apre nel bordo del piano i varchi dove passano le sue rampe (proposti dall'editor, confermati qui)
			var tp := trova(str(c.get("id", "")))
			if tp.is_empty() or tp[0] != "piani":
				r = {"ok": false, "messaggio": "Scegli un piano rialzato"}
			else:
				var pp: Dictionary = desc["piani"][tp[1]]
				var prop := PianiRialzati.varchi_proposti(desc, pp)
				if prop.is_empty():
					r = {"ok": true, "messaggio": "Nessun varco da aprire: le rampe di questo piano passano già da un varco", "aperti": 0}
				else:
					_ricorda()
					var vv: Array = pp.get("varchi", []) if pp.get("varchi") is Array else []
					for pr in prop:
						vv.append({"t": snappedf(float(pr["t"]), 0.0001), "larghezza": float(c.get("larghezza", 50.0))})
					pp["varchi"] = vv
					_fatto()
					r = {"ok": true, "messaggio": "Aperti %d varchi nel bordo dove passano le rampe (spostali o chiudili dal pannello del piano)" % prop.size(), "aperti": prop.size()}
		"incroci_regola", "incrocio", "incroci_automatico":
			r = _incroci_cmd(c)
		"elimina":
			r = _modifica(c, func(lista: Array, i: int): lista.remove_at(i))
		"imposta":
			r = _imposta(c)
		"sposta":
			r = _sposta(c)
		"sposta_punto":
			r = _sposta_punto(c)
		"aggiungi_punto":
			r = _aggiungi_punto(c)
		"togli_punto":
			r = _togli_punto(c)
		"duplica":
			r = _duplica(c)
		"specchia":
			r = _specchia(c)
		"gruppo":
			r = _gruppo(c)
		"scala":
			r = _gruppo({"ids": [c.get("id", "")], "azione": "scala", "fattore": c.get("fattore", 1.1)})
		"capovolgi":
			r = _gruppo({"ids": [c.get("id", "")], "azione": "capovolgi", "asse": c.get("asse", "x")})
		"incolla":
			r = _incolla(c.get("pezzi", []), _vec(c.get("pos", Vector2(317, 600))))
		"aggiungi_composto":
			r = _composto(str(c.get("nome", "")), _vec(c.get("pos", Vector2(317, 150))))
		"punto":
			r = _punto(c)
		"livello_vista":
			r = _livello_vista(c)
		"collezione", "zone":
			r = _collezione_zone(c)
		"gruppo_nome":
			r = _gruppo_nome(c)
		"imposta_menu", "pagina_menu":
			r = _menu_cmd(c)
		"importa_font":
			r = _importa_font(c)
		"tabellone":
			r = _imposta_tabellone(c)
		"spettacolo", "spettacolo_passo", "attesa":
			r = _spettacoli_cmd(c)
		"licenza", "registro_licenze":
			r = _licenze_cmd(c)
		"tiro_salva", "tiro_togli", "tiri_verifica":
			r = _tiri_cmd(c)
		"esporta":
			# v0.20: {"comando": "esporta", "piattaforma": linux|pi|android, "conferma_utente"?: true}. L'APK solo con la
			# conferma dell'utente (dall'editor, con una finestra di conferma); i comandi automatici non possono darla.
			r = Esportazione.esporta(self, str(c.get("piattaforma", "linux")), bool(c.get("conferma_utente", false)) and chi != "ai")
		"elemento_da_immagine":
			r = _elemento_da_immagine(c)
		"elemento_salva", "elemento_inserisci", "elementi_elenco", "elemento_togli":
			r = _libreria_cmd(c)
		"confronta":
			# v0.18.2: {"comando": "confronta", "file"?: tavolo da confrontare (vuoto = l'ultimo salvataggio)}
			var fc := str(c.get("file", cartella.path_join(FILE_TAVOLO) if cartella != "" else ""))
			var altro := FileTavolo.leggi(fc) if fc != "" else {}
			if altro.is_empty():
				r = {"ok": false, "messaggio": "Non c'è un salvataggio da confrontare (salva prima il tavolo)"}
			else:
				CurveEditor.prepara_tavolo(altro)
				var dif := confronta(altro)
				r = {"ok": true, "messaggio": ("Nessuna differenza dall'ultimo salvataggio" if dif.is_empty() else "%d differenze dall'ultimo salvataggio" % dif.size()), "differenze": dif}
		"musica":
			r = _musica_cmd(c)
		"cambio_corsie":
			# v0.12: {"gruppo", "punti"?, "bonus_x"?} aggiunge o cambia; {"gruppo", "togli": true} toglie
			var g := str(c.get("gruppo", ""))
			var lane: Array = desc.get("sensori", []).filter(func(x): return str(x.get("gruppo", "")) == g)
			if g == "" or (lane.size() < 2 and not bool(c.get("togli", false))):
				r = {"ok": false, "messaggio": "Servono almeno 2 sensori con il gruppo «%s» (campo Gruppo del sensore)" % g}
			else:
				_ricorda()
				if not desc.get("cambio_corsie") is Array:
					desc["cambio_corsie"] = []
				desc["cambio_corsie"] = desc["cambio_corsie"].filter(func(x): return str(x.get("gruppo", "")) != g)
				if not bool(c.get("togli", false)):
					desc["cambio_corsie"].append({"gruppo": g, "premio": {"punti": int(c.get("punti", 25000)), "bonus_x": int(c.get("bonus_x", 1))}})
				_fatto()
				r = {"ok": true, "messaggio": ("Cambio corsia tolto: " + g) if bool(c.get("togli", false)) else "Cambio corsia sulle %d corsie del gruppo «%s»" % [lane.size(), g]}
		"suono_evento", "luce_evento":
			# v0.11 regia: {"evento", "suono"} oppure {"evento", "effetto", "colore"}; "togli": true = come prima
			var ev := str(c.get("evento", ""))
			if not RegiaDati.EVENTI.has(ev):
				r = {"ok": false, "messaggio": "Evento sconosciuto: " + ev}
			else:
				var chiave_r := "suoni" if c["comando"] == "suono_evento" else "luci_eventi"
				if c["comando"] == "suono_evento" and not bool(c.get("togli", false)) and not RegiaDati.SUONI.has(str(c.get("suono", ""))):
					r = {"ok": false, "messaggio": "Suono non nel catalogo: " + str(c.get("suono", ""))}
				else:
					_ricorda()
					if not desc.get(chiave_r) is Dictionary:
						desc[chiave_r] = {}
					if bool(c.get("togli", false)) or (chiave_r == "luci_eventi" and str(c.get("effetto", "")) == ""):
						desc[chiave_r].erase(ev)
					elif chiave_r == "suoni":
						desc[chiave_r][ev] = str(c.get("suono", ""))
					else:
						desc[chiave_r][ev] = {"effetto": str(c.get("effetto", "onda")), "colore": str(c.get("colore", "caldo"))}
					_fatto()
					r = {"ok": true, "messaggio": "%s: %s" % [RegiaDati.EVENTI[ev][0], "come prima" if not desc[chiave_r].has(ev) else str(desc[chiave_r][ev])]}
		"missione_aggiungi", "missioni_pacchetto", "missione_imposta", "missione_fase", "missione_sposta", "missione_togli", "missioni_avvio", "missione_duplica":
			r = _missioni_cmd(c)
		"ventaglio", "calore":
			# v0.16: {"comando": "ventaglio", "paletta": id, "colpi": N} · {"comando": "calore", "secondi": S}
			var opz := {"paletta": str(c.get("paletta", "sx")), "colpi": int(c.get("colpi", 5))} if c["comando"] == "ventaglio" else {"calore": float(c.get("secondi", 40.0))}
			ultima_traccia = Tracciatore.esegui(desc, opz)
			r = {"ok": bool(ultima_traccia.get("ok", false)), "messaggio": Tracciatore.riassunto(ultima_traccia), "traccia": ultima_traccia}
		"traccia":
			# tracciatore (v0.9.5): {"da":[x,y], "velocita":[vx,vy]} oppure {"da", "angolo" (gradi, 0 = in alto), "forza" (mm/s)}
			var vel := _vec(c.get("velocita", Vector2.ZERO))
			if vel == Vector2.ZERO:
				vel = Vector2(0, -1).rotated(deg_to_rad(float(c.get("angolo", 0.0)))) * float(c.get("forza", 1500.0))
			ultima_traccia = Tracciatore.esegui(desc, {"da": _vec(c.get("da", Vector2(317, 600))), "vel": vel, "tiri": int(c.get("tiri", 1)),
				"variazione": float(c.get("variazione", 0.0)), "secondi": float(c.get("secondi", 4.0)), "livello": int(c.get("livello", 0))})
			r = {"ok": bool(ultima_traccia.get("ok", false)), "messaggio": Tracciatore.riassunto(ultima_traccia), "traccia": ultima_traccia}
		"immagine":
			r = _immagine(c)
		"ruota":
			r = _ruota(c)
		"stato":
			r = {"ok": true, "messaggio": riassunto(), "pezzi": elenco()}
		"elenco":
			r = {"ok": true, "messaggio": "", "pezzi": elenco(str(c.get("tipo", "")))}
		"controlla_varchi":
			var p := ControlliEditor.varchi(desc)
			p.append_array(ControlliEditor.piatti(desc))
			p.append_array(ControlliEditor.incroci(desc))
			p.append_array(Incroci.controlli(desc))
			var pz := ControlliEditor.peso(desc, cartella)
			r = {"ok": true, "messaggio": "%d punti da controllare (varchi, superfici piatte, incroci delle rampe) · %s" % [p.size(), ControlliEditor.testo_peso(pz)], "problemi": p, "peso": pz}
		_:
			r = {"ok": false, "messaggio": "comando sconosciuto: " + nome}
	_diario(chi, c, r)
	return r

## Riassunto in parole semplici: quanti pezzi di ogni tipo.
func riassunto() -> String:
	var parti: Array = []
	for k in LISTE:
		var n: int = desc.get(k, []).size() if desc.get(k, []) is Array else 0
		if n > 0:
			parti.append("%s %d" % [SchedeEditor.scheda(k).get("nome", k), n])
	return "Tavolo «%s» %s mm: %s" % [str(desc.get("titolo", "")), _vec_testo(desc.get("dimensioni", Vector2.ZERO)), ", ".join(parti)]

## Elenco dei pezzi [{id, tipo, pos}] (tipo "" = tutti).
func elenco(tipo := "") -> Array:
	var out: Array = []
	for k in LISTE:
		if tipo != "" and k != tipo:
			continue
		for e in desc.get(k, []):
			if e is Dictionary and e.has("id") and not e.has("da_nastro") and not e.has("da_captive"):
				out.append({"id": e["id"], "tipo": k, "pos": _vec_testo(centro(k, e))})
	return out

# ================================================================ apertura e salvataggio
## Tavoli pronti disponibili: [{id, nome, descrizione}] (il modello Base, poi i file in tavoli/modelli/).
static func tavoli_pronti() -> Array:
	var out: Array = [{"id": "base", "nome": "Solo zona bassa", "testo": "tavolo vuoto con palette, fionde e corsie: lo riempi tu"}]
	var file: Array = Array(DirAccess.get_files_at(CARTELLA_MODELLI)) if DirAccess.dir_exists_absolute(CARTELLA_MODELLI) else []
	file.sort()
	for f in file:
		if str(f).ends_with(".tavolo"):
			var d := FileTavolo.leggi(CARTELLA_MODELLI + f)
			out.append({"id": str(f).get_basename(), "nome": str(d.get("titolo", f)).capitalize(), "testo": str(d.get("descrizione", ""))})
	return out

func _nuovo(modello: String, nome: String, forma = "classica") -> Dictionary:
	var nuovo: Dictionary
	if modello == "base":
		nuovo = LayoutBase.descrizione(forma)
	elif MODELLI.has(modello):
		nuovo = load(MODELLI[modello]).descrizione()
	elif FileAccess.file_exists(CARTELLA_MODELLI + modello + ".tavolo"):
		nuovo = FileTavolo.leggi(CARTELLA_MODELLI + modello + ".tavolo")
		# i tavoli pronti fatti con le forme si possono rifare con un'altra forma (Space ha una forma sua: resta com'è)
		var altra: bool = (forma is String and forma != "classica" and FormaTavolo.FORME.has(forma)) or forma is Dictionary
		if altra and nuovo.has("forma"):
			FormaTavolo.applica(nuovo, FormaTavolo.FORME[forma] if forma is String else forma)
	else:
		return {"ok": false, "messaggio": "modello sconosciuto: " + modello}
	_ricorda()
	CurveEditor.prepara_tavolo(nuovo)
	desc = nuovo
	desc["titolo"] = nome.to_upper()
	desc["nome"] = nome.to_lower().replace(" ", "_")
	# la grafica del gioco viene disegnata dal motore (niente immagini pronte di un altro tavolo)
	desc["cartella_grafica"] = "res://grafica/_editor/"
	if not desc.has("regole"):
		desc["regole"] = "res://tavoli/%s/regole_%s.gd" % [modello, modello] if modello != "base" else FileTavolo.REGOLE_BASE
	cartella = ""
	modificato = true
	_annulla.clear()
	_ripeti.clear()
	cambiato.emit()
	return {"ok": true, "messaggio": "Nuovo tavolo «%s» dal modello %s" % [nome, modello]}

# ================================================================ INFORMAZIONI DEL GIOCO (v0.26, rilascio libero)
func _gioco_info(c: Dictionary) -> Dictionary:
	_ricorda()
	if not desc.get("gioco_info") is Dictionary:
		desc["gioco_info"] = {}
	var gi: Dictionary = desc["gioco_info"]
	for campo in ["nome", "autore", "descrizione", "versione", "repository"]:
		if c.has(campo):
			gi[campo] = str(c[campo]).strip_edges().substr(0, 500)
	if c.has("collaboratori"):
		var lc = c["collaboratori"]
		gi["collaboratori"] = (lc if lc is Array else str(lc).split(",")).map(func(x): return str(x).strip_edges()).filter(func(x): return x != "")
	_fatto()
	var i := LicenzeProgetto.info(desc)
	return {"ok": true, "messaggio": "Gioco: %s %s di %s" % [i["nome"], i["versione"], i["autore"] if i["autore"] != "" else "(autore da scrivere)"]}

# ================================================================ PER CHI NON PROGRAMMA (v0.25)
## TEMI PRONTI: colori del tavolo, del menu, luce ambientale e font in un clic. Colori NOSTRI (mai quelli di un altro
const TEMI := {
	"spazio": {"nome": "Spazio", "testo": "viola profondo e argento", "primario": Color(0.55, 0.3, 0.95), "secondario": Color(0.78, 0.82, 0.9), "piano": Color(0.08, 0.06, 0.2), "luce": [Color(0.5, 0.4, 1.0), "alto"], "font_titolo": "serif"},
	"lava": {"nome": "Lava", "testo": "arancio fuoco e nero", "primario": Color(1.0, 0.45, 0.05), "secondario": Color(1.0, 0.8, 0.2), "piano": Color(0.12, 0.05, 0.03), "luce": [Color(1.0, 0.4, 0.1), "basso"], "font_titolo": "serif"},
	"mare": {"nome": "Mare", "testo": "blu profondo e turchese", "primario": Color(0.05, 0.35, 0.8), "secondario": Color(0.2, 0.9, 0.85), "piano": Color(0.02, 0.12, 0.25), "luce": [Color(0.2, 0.8, 1.0), "ovunque"], "font_titolo": "sans"},
	"giungla": {"nome": "Giungla", "testo": "verde foglia e giallo", "primario": Color(0.2, 0.65, 0.2), "secondario": Color(0.98, 0.85, 0.2), "piano": Color(0.05, 0.15, 0.06), "luce": [Color(0.6, 1.0, 0.4), "lati"], "font_titolo": "serif"},
	"neon": {"nome": "Notte neon", "testo": "fucsia e verde acido", "primario": Color(1.0, 0.15, 0.6), "secondario": Color(0.6, 1.0, 0.2), "piano": Color(0.04, 0.03, 0.08), "luce": [Color(1.0, 0.2, 0.8), "lati"], "font_titolo": "sans"},
	"classico": {"nome": "Classico", "testo": "crema e verde bottiglia, anni '70", "primario": Color(0.1, 0.4, 0.25), "secondario": Color(0.95, 0.88, 0.7), "piano": Color(0.85, 0.8, 0.68), "luce": [Color(1.0, 0.9, 0.7), "spenta"], "font_titolo": "serif"},
}

func _tema(nome: String) -> Dictionary:
	if not TEMI.has(nome):
		return {"ok": false, "messaggio": "Tema sconosciuto: " + nome}
	var t: Dictionary = TEMI[nome]
	_ricorda()
	if not desc.get("colori") is Dictionary:
		desc["colori"] = {}
	desc["colori"]["primario"] = t["primario"]
	desc["colori"]["secondario"] = t["secondario"]
	desc["colori"]["piano"] = t["piano"]
	desc["luce_ambiente"] = {"colore": t["luce"][0], "intensita": 0.5, "da": t["luce"][1]}
	if not desc.get("menu") is Dictionary:
		desc["menu"] = {}
	var m: Dictionary = desc["menu"]
	m["col_a"] = t["secondario"]
	m["col_b"] = t["primario"]
	m["col_fondo"] = Color(Color(t["piano"]).darkened(0.5), 0.92)
	m["col_pannello"] = Color(Color(t["piano"]).darkened(0.3), 0.97)
	m["font_titolo"] = t["font_titolo"]
	m["font"] = "sans"
	desc["tema"] = nome
	_fatto()
	return {"ok": true, "messaggio": "Tema «%s»: colori del tavolo e del menu, luce e font" % t["nome"]}

## GRUPPI DI PEZZI PRONTI: un clic, un solo «annulla».
const GRUPPI_PRONTI := {"bumper_3": "Triangolo di 3 bumper", "bersagli_buca": "3 bersagli davanti a una buca",
	"spinner_corsia": "Spinner in una corsia con due guide"}

func _gruppo_pronto(nome: String, pos: Vector2) -> Dictionary:
	var n0 := _annulla.size()
	var ids: Array = []
	var cmds: Array = []
	match nome:
		"bumper_3":
			for q in [Vector2(-50, -35), Vector2(50, -35), Vector2(0, 50)]:
				cmds.append({"comando": "aggiungi", "tipo": "bumper", "pos": pos + q})
		"bersagli_buca":
			cmds.append({"comando": "aggiungi", "tipo": "buche", "pos": pos})
			for a in [-0.6, 0.0, 0.6]:
				var q := Vector2(0, -62).rotated(a)       # ad arco DIETRO la buca
				cmds.append({"comando": "aggiungi", "tipo": "bersagli", "pos": pos + q, "valori": {"angolo": a}})
		"spinner_corsia":
			cmds.append({"comando": "aggiungi", "tipo": "spinner", "pos": pos})
			for dx in [-26.0, 26.0]:
				cmds.append({"comando": "aggiungi", "tipo": "muri", "punti": [pos + Vector2(dx, -60), pos + Vector2(dx, 60)], "valori": {"tipo": "metallo"}})
	for c in cmds:
		var r := esegui(c, "editor")
		if not r.get("ok", false):
			return r
		ids.append(r["id"])
	if _annulla.size() > n0 + 1:
		_annulla.resize(n0 + 1)                 # un solo «annulla» per tutto il gruppo
	return {"ok": true, "messaggio": "%s aggiunto (%d pezzi)" % [GRUPPI_PRONTI[nome], ids.size()], "id": ids[0], "ids": ids}

## «SISTEMA TU»: allarga da solo i varchi pericolosi trovati da CONTROLLA (spazi tra 20 e 36 mm dove la pallina si può
## incastrare), spostando il pezzo più piccolo finché lo spazio è 40 mm. Non tocca la sponda, i pezzi bloccati, quelli
## fatti dall'editor (bordi dei piani, nastri) né le palette. Un solo «annulla».
func _sistema_varchi(giri: int) -> Dictionary:
	var prima := ControlliEditor.varchi(desc).size()
	if prima == 0:
		return {"ok": true, "messaggio": "Nessun varco pericoloso: niente da sistemare", "sistemati": 0, "restano": 0}
	_ricorda()
	var mossi := {}
	for g in giri:
		var vv := ControlliEditor.varchi(desc)
		if vv.is_empty():
			break
		var cambiato := false
		for v in vv:
			var pz: Array = v.get("pezzi", [])
			if pz.size() < 2:
				continue
			var scelta := _da_spostare(str(pz[0]), str(pz[1]))
			if scelta < 0:
				continue
			var id := str(pz[scelta])
			var t := trova(id)
			var e: Dictionary = desc[t[0]][t[1]]
			var mio: Vector2 = v["a"] if scelta == 0 else v["b"]
			var altro: Vector2 = v["b"] if scelta == 0 else v["a"]
			var dir := (mio - altro).normalized() if mio.distance_to(altro) > 0.1 else (centro(t[0], e) - altro).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2(0, -1)
			trasla(t[0], e, dir * (40.5 - float(v["d"])))
			if t[0] == "muri":
				CurveEditor.rigenera(e)
			mossi[id] = true
			cambiato = true
		if not cambiato:
			break
	CurveEditor.genera_nastri(desc)
	PianiRialzati.genera(desc)
	var dopo := ControlliEditor.varchi(desc).size()
	_fatto()
	return {"ok": true, "messaggio": "Sistemati %d varchi spostando %d pezzi (%s)%s. Rifai CONTROLLA e prova a giocare." % [maxi(0, prima - dopo), mossi.size(), ", ".join(mossi.keys()),
		"" if dopo == 0 else "; ne restano %d da sistemare a mano" % dopo], "sistemati": prima - dopo, "restano": dopo, "ids": mossi.keys()}

## Quale dei due pezzi spostare: 0, 1 oppure -1 (nessuno spostabile). Si preferisce il pezzo che non è un muro.
func _da_spostare(id0: String, id1: String) -> int:
	var ok := [_spostabile(id0), _spostabile(id1)]
	if not ok[0] and not ok[1]:
		return -1
	if ok[0] != ok[1]:
		return 0 if ok[0] else 1
	var t0 := trova(id0)
	var t1 := trova(id1)
	if t0[0] == "muri" and t1[0] != "muri":
		return 1
	return 0 if t1[0] == "muri" and t0[0] != "muri" else 1

func _spostabile(id: String) -> bool:
	var t := trova(id)
	if t.is_empty() or id == "sponda" or id.contains("@") or t[0] in ["palette", "piani"]:
		return false
	var e: Dictionary = desc[t[0]][t[1]]
	if bool(e.get("bloccato", false)) or e.has("da_nastro") or e.has("da_piano") or e.has("da_captive"):
		return false
	if t[0] == "muri" and desc.get("muri", []).size() > 0 and desc["muri"][0] == e:
		return false                            # (il primo muro è la sponda del tavolo)
	return true

## Modelli pronti: usano i pezzi del tavolo. Ritorna [{id, nome, testo, ok, perche, segreto}].
func modelli_segreti() -> Array:
	var ids := func(k: String) -> Array: return desc.get(k, []).filter(func(e): return e is Dictionary and e.has("id") and not e.has("da_nastro")).map(func(e): return str(e["id"]))
	var bumper: Array = ids.call("bumper")
	var spinner: Array = ids.call("spinner")
	var rampe: Array = ids.call("rampe")
	var buche: Array = ids.call("buche")
	var kick: Array = ids.call("kickback")
	var sensori: Array = ids.call("sensori")
	var out: Array = []
	out.append({"id": "raffica_bumper", "nome": "Raffica di bumper", "testo": "6 colpi sui bumper in 2 secondi", "ok": bumper.size() >= 2, "perche": "servono almeno 2 bumper",
		"segreto": {"tipo": "raffica", "quando": {"tipo": "bumper"}, "volte": 6, "secondi": 2.0, "punti": 50000}})
	out.append({"id": "vortice", "nome": "Vortice", "testo": "30 giri dello spinner in 5 secondi", "ok": not spinner.is_empty(), "perche": "serve uno spinner",
		"segreto": {"tipo": "raffica", "quando": {"tipo": "spinner"}, "volte": 30, "secondi": 5.0, "punti": 50000}})
	out.append({"id": "rampa_doppia", "nome": "Doppia rampa", "testo": "la stessa rampa due volte di fila", "ok": not rampe.is_empty(), "perche": "serve una rampa",
		"segreto": {"tipo": "di_fila", "ids": [rampe[0], rampe[0]] if not rampe.is_empty() else [], "punti": 75000}})
	out.append({"id": "giro_completo", "nome": "Giro completo", "testo": "rampa, poi buca, poi di nuovo rampa", "ok": not rampe.is_empty() and not buche.is_empty(), "perche": "servono una rampa e una buca",
		"segreto": {"tipo": "di_fila", "ids": [rampe[0], buche[0], rampe[0]] if not rampe.is_empty() and not buche.is_empty() else [], "punti": 100000}})
	out.append({"id": "salvataggio", "nome": "Salvati e vola", "testo": "rampa entro 5 secondi dal kickback", "ok": not kick.is_empty() and not rampe.is_empty(), "perche": "servono un kickback e una rampa",
		"segreto": {"tipo": "entro", "primo": kick[0] if not kick.is_empty() else "", "poi": rampe[0] if not rampe.is_empty() else "", "secondi": 5.0, "punti": 75000}})
	out.append({"id": "tutti_sensori", "nome": "Esploratore", "testo": "passa su tutti i sensori nella stessa pallina", "ok": sensori.size() >= 2, "perche": "servono almeno 2 sensori",
		"segreto": {"tipo": "tutti", "ids": sensori, "punti": 25000}})
	return out

func _segreti_cmd(c: Dictionary) -> Dictionary:
	if not desc.get("segreti") is Array:
		desc["segreti"] = []
	var l: Array = desc["segreti"]
	var cmd := str(c["comando"])
	if cmd == "segreto_aggiungi":
		var mod := str(c.get("modello", ""))
		var trovato := modelli_segreti().filter(func(x): return x["id"] == mod)
		if trovato.is_empty() or not trovato[0]["ok"]:
			return {"ok": false, "messaggio": "Segreto non disponibile: " + (str(trovato[0]["perche"]) if not trovato.is_empty() else mod)}
		_ricorda()
		var sg: Dictionary = trovato[0]["segreto"].duplicate(true)
		var n := 1
		while l.any(func(x): return str(x.get("id", "")) == "%s_%d" % [mod, n]):
			n += 1
		sg["id"] = "%s_%d" % [mod, n]
		sg["nome"] = str(trovato[0]["nome"])
		l.append(sg)
		_fatto()
		return {"ok": true, "messaggio": "Segreto «%s» aggiunto: %s" % [sg["nome"], Segreti.testo(sg)], "id": sg["id"]}
	var i := -1
	for k in l.size():
		if str(l[k].get("id", "")) == str(c.get("id", "")):
			i = k
	if i < 0:
		return {"ok": false, "messaggio": "Segreto inesistente: " + str(c.get("id", ""))}
	_ricorda()
	if cmd == "segreto_togli":
		var nome := str(l[i].get("nome", ""))
		l.remove_at(i)
		_fatto()
		return {"ok": true, "messaggio": "Segreto «%s» tolto" % nome}
	var campo := str(c.get("campo", ""))
	if not campo in ["nome", "volte", "secondi", "punti"]:
		return {"ok": false, "messaggio": "Campo del segreto sconosciuto: " + campo}
	l[i][campo] = str(c.get("valore", "")) if campo == "nome" else (int(c.get("valore", 0)) if campo in ["volte", "punti"] else float(c.get("valore", 1.0)))
	_fatto()
	return {"ok": true, "messaggio": "Segreto: %s = %s" % [campo, str(l[i][campo])]}

# ================================================================ IMPORTA UN FLIPPER GIÀ FATTO (v0.22)
## «tavoli/NOME/layout_NOME.gd» con lo stesso formato del motore dell'editor. Il file si LEGGE soltanto (mai
## modificato): se ne fa una copia nel nuovo progetto. Si importano forma, pezzi, rampe, livelli e colori; NON le
## regole scritte a mano (missioni e punteggi di quel gioco: qui si rifanno a mattoncini) né le immagini del gioco.
static func flipper_trovati() -> Array:
	var base := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()   # 03_VIDEOGIOCHI_E_APP
	var out: Array = []
	for d1 in DirAccess.get_directories_at(base):
		if d1 == "Pinball_Editor_2D":
			continue
		for d2 in DirAccess.get_directories_at(base.path_join(d1)):
			var tav := base.path_join(d1).path_join(d2).path_join("tavoli")
			if not DirAccess.dir_exists_absolute(tav):
				continue
			for d3 in DirAccess.get_directories_at(tav):
				var f := tav.path_join(d3).path_join("layout_%s.gd" % d3)
				if FileAccess.file_exists(f):
					out.append({"nome": "%s (%s)" % [d3.capitalize(), d2], "file": f})
	return out

func _importa_flipper(c: Dictionary) -> Dictionary:
	var f := str(c.get("file", ""))
	if not FileAccess.file_exists(f) or f.get_extension() != "gd":
		return {"ok": false, "messaggio": "Serve il file del tavolo (tavoli/NOME/layout_NOME.gd)"}
	var righe := FileAccess.get_file_as_string(f).split("\n")
	for i in righe.size():
		if righe[i].begins_with("class_name "):
			righe[i] = ""                 # copia anonima: il nome di classe è già del suo gioco
	var sc := GDScript.new()
	sc.source_code = "\n".join(righe)
	if sc.reload() != OK or not sc.has_method("descrizione"):
		return {"ok": false, "messaggio": "Questo tavolo è scritto in un modo che l'editor non sa leggere"}
	var d = sc.call("descrizione")
	if not d is Dictionary or not d.has("muri") or not d.has("palette") or not d.has("dimensioni"):
		return {"ok": false, "messaggio": "Questo file non descrive un tavolo da flipper 2D"}
	if d.get("piani") is Dictionary:
		return {"ok": false, "messaggio": "Questo flipper è a DUE PIANI con la telecamera che segue la pallina: l'editor per ora fa tavoli a una schermata. Non importato."}
	var nuovo: Dictionary = (d as Dictionary).duplicate(true)
	if nuovo.get("kickback") is Dictionary:
		var kb: Dictionary = nuovo["kickback"]
		if not kb.has("id"):
			kb["id"] = "kickback"
		nuovo["kickback"] = [kb]
	for cb in nuovo.get("captive", []):
		if cb is Dictionary:
			cb["canale_proprio"] = true       # il canale c'è già nei muri del tavolo: l'editor non lo rifà
	for k in ["grafica", "luci", "cartella_grafica"]:
		nuovo.erase(k)
	nuovo["regole"] = FileTavolo.REGOLE_BASE
	nuovo["importato_da"] = f.get_file()
	_ricorda()
	CurveEditor.prepara_tavolo(nuovo)
	desc = nuovo
	var nome := str(c.get("nome", str(desc.get("titolo", "Importato"))))
	desc["titolo"] = nome.to_upper()
	desc["nome"] = nome.to_lower().validate_filename().replace(" ", "_")
	desc["cartella_grafica"] = "res://grafica/_editor/"
	cartella = ""
	modificato = true
	_annulla.clear()
	_ripeti.clear()
	cambiato.emit()
	return {"ok": true, "messaggio": "Importato «%s»: forma, pezzi, rampe e livelli. Le regole e le immagini di quel gioco restano lì: qui le missioni si rifanno a mattoncini. Salva con nome per tenerlo." % nome}

## Proprietà del tavolo intero: titolo (nome sul tabellone), descrizione, aspetto ("3d"/"piatto", v0.5) e colori
## (colore_primario, colore_secondario, colore_piano). Con "aspetto_tutti" l'aspetto vale anche per i pezzi che ne
## avevano uno proprio (tornano «come il tavolo»).
const COLORI_TAVOLO := {"colore_primario": "primario", "colore_secondario": "secondario", "colore_piano": "piano"}
func _imposta_tavolo(campo: String, v) -> Dictionary:
	if campo in ["luce_da", "luce_colore", "luce_intensita"]:
		# v0.8: luce ambientale del tavolo
		var la: Dictionary = desc.get("luce_ambiente", {}).duplicate() if desc.get("luce_ambiente") is Dictionary else {"colore": Color(0.4, 0.6, 1.0), "intensita": 0.5, "da": "spenta"}
		match campo:
			"luce_da":
				if not str(v) in ["spenta", "alto", "basso", "lati", "ovunque"]:
					return {"ok": false, "messaggio": "Luce ambientale: spenta, alto, basso, lati oppure ovunque"}
				la["da"] = str(v)
			"luce_colore":
				la["colore"] = v if v is Color else (Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0) if v is Array else Color(str(v)))
			"luce_intensita":
				la["intensita"] = clampf(float(v), 0.0, 1.0)
		_ricorda()
		desc["luce_ambiente"] = la
		_fatto()
		return {"ok": true, "messaggio": "Luce ambientale: %s, intensità %.2f" % [la["da"], float(la["intensita"])]}
	if campo == "fondo":
		# v0.6: fondo dipinto del tavolo (valore = percorso dell'immagine; "" = toglierlo)
		if v == null or str(v) == "":
			_ricorda()
			desc.erase("fondo")
			_pulisci_immagini()
			_fatto()
			return {"ok": true, "messaggio": "Fondo del tavolo tolto"}
		var dati := PittorePezzi.importa(str(v), 2048)
		if dati == "":
			return {"ok": false, "messaggio": "Non riesco a leggere l'immagine (va bene PNG, JPG o WEBP)"}
		_ricorda()
		if not desc.get("immagini") is Dictionary:
			desc["immagini"] = {}
		desc["immagini"]["fondo_tavolo"] = dati
		desc["fondo"] = "fondo_tavolo"
		_fatto()
		return {"ok": true, "messaggio": "Fondo del tavolo: «%s» (copre tutto il tavolo)" % str(v).get_file()}
	if campo == "lingua":
		# v0.13: lingua del tabellone del gioco di questo tavolo
		if not str(v) in ["it", "en"]:
			return {"ok": false, "messaggio": "Lingua: «it» (italiano) oppure «en» (inglese)"}
		_ricorda()
		desc["lingua"] = str(v)
		_fatto()
		return {"ok": true, "messaggio": "Tabellone in " + ("inglese" if str(v) == "en" else "italiano")}
	if campo in ["aspetto", "aspetto_tutti"]:
		var a := str(v)
		if not a in ["3d", "piatto"]:
			return {"ok": false, "messaggio": "Aspetto del tavolo: «3d» oppure «piatto»"}
		_ricorda()
		desc["aspetto"] = a
		var tolti := 0
		if campo == "aspetto_tutti":
			for k in PittorePezzi.TIPI:
				for e in desc.get(k, []):
					if e.has("aspetto"):
						e.erase("aspetto")
						tolti += 1
			for nn in desc.get("nastri", []):
				nn["aspetto"] = a
		_fatto()
		return {"ok": true, "messaggio": "Aspetto del tavolo: %s%s" % ["effetto 3D" if a == "3d" else "piatto", " (anche %d pezzi che l'avevano proprio)" % tolti if tolti > 0 else ""]}
	if COLORI_TAVOLO.has(campo):
		var col: Color
		if v is Color:
			col = v
		elif v is Array:
			col = Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0)
		else:
			col = Color(str(v))
		_ricorda()
		if not desc.get("colori") is Dictionary:
			desc["colori"] = {}
		desc["colori"][COLORI_TAVOLO[campo]] = col
		_fatto()
		return {"ok": true, "messaggio": "Colore del tavolo (%s): %s" % [COLORI_TAVOLO[campo], col.to_html(false)]}
	if not campo in ["titolo", "descrizione"]:
		return {"ok": false, "messaggio": "Proprietà del tavolo non modificabile: " + campo}
	_ricorda()
	desc[campo] = str(v).to_upper() if campo == "titolo" else str(v)
	_fatto()
	return {"ok": true, "messaggio": "%s del tavolo: %s" % [campo, desc[campo]]}

## Cambia la forma del tavolo (sponda, corsia di lancio, zona bassa). Gli altri pezzi restano.
func _forma(f) -> Dictionary:
	var forma: Dictionary
	if f is String:
		if not FormaTavolo.FORME.has(f):
			return {"ok": false, "messaggio": "forma sconosciuta: " + f}
		forma = FormaTavolo.FORME[f]
	elif f is Dictionary:
		forma = f
	else:
		return {"ok": false, "messaggio": "forma non valida"}
	_ricorda()
	FormaTavolo.applica(desc, forma)
	_fatto()
	var fl := FormaTavolo.limita(forma)
	return {"ok": true, "messaggio": "Forma: larghezza %.0f mm, angolo sinistro %.0f, angolo destro %.0f" % [fl["larghezza"], fl["r_sx"], fl["r_dx"]]}

func apri(dir: String) -> Dictionary:
	var d := FileTavolo.leggi(dir.path_join(FILE_TAVOLO))
	if d.is_empty():
		return {"ok": false, "messaggio": "Non trovo un tavolo in " + dir}
	CurveEditor.prepara_tavolo(d)
	desc = d
	cartella = dir
	modificato = false
	_annulla.clear()
	_ripeti.clear()
	cambiato.emit()
	return {"ok": true, "messaggio": "Aperto " + dir.get_file()}

func salva(dir: String) -> Dictionary:
	_pulisci_immagini()
	if dir == "":
		return {"ok": false, "messaggio": "Scegli dove salvare (Salva con nome)"}
	if not dir.ends_with(".pinproj"):
		dir += ".pinproj"
	DirAccess.make_dir_recursive_absolute(dir)
	var err := FileTavolo.salva(desc, dir.path_join(FILE_TAVOLO))
	if err != OK:
		return {"ok": false, "messaggio": "Salvataggio NON riuscito (errore %d): il file di prima è intatto" % err}
	cartella = dir
	modificato = false
	cambiato.emit()
	return {"ok": true, "messaggio": "Salvato in " + dir.get_file()}

## Copia del tavolo per una prova (GIOCA, CONTROLLA): non tocca il progetto salvato.
func salva_prova(percorso: String) -> bool:
	# v0.12: il gioco trova la musica del tavolo nella cartella «musica» del progetto
	var d := desc
	if cartella != "":
		d = desc.duplicate(false)
		d["cartella_musica"] = cartella.path_join("musica")
	return FileTavolo.salva(d, percorso) == OK

# ================================================================ annulla / ripristina
func _ricorda() -> void:
	if not desc.is_empty():
		_annulla.append(desc.duplicate(true))
		if _annulla.size() > MAX_ANNULLA:
			_annulla.pop_front()
	_ripeti.clear()

func annulla() -> Dictionary:
	if _annulla.is_empty():
		return {"ok": false, "messaggio": "Niente da annullare"}
	_ripeti.append(desc.duplicate(true))
	desc = _annulla.pop_back()
	modificato = true
	cambiato.emit()
	return {"ok": true, "messaggio": "Annullato"}

func ripristina() -> Dictionary:
	if _ripeti.is_empty():
		return {"ok": false, "messaggio": "Niente da ripristinare"}
	_annulla.append(desc.duplicate(true))
	desc = _ripeti.pop_back()
	modificato = true
	cambiato.emit()
	return {"ok": true, "messaggio": "Ripristinato"}

func si_puo_annullare() -> bool:
	return not _annulla.is_empty()

func si_puo_ripristinare() -> bool:
	return not _ripeti.is_empty()

# ================================================================ ricerca dei pezzi
## [lista, indice] del pezzo con questo id, oppure [].
func trova(id: String) -> Array:
	for k in LISTE:
		var lista = desc.get(k, [])
		if lista is Array:
			for i in lista.size():
				if lista[i] is Dictionary and str(lista[i].get("id", "")) == id:
					return [k, i]
	return []

func pezzo(id: String) -> Dictionary:
	var t := trova(id)
	return desc[t[0]][t[1]] if not t.is_empty() else {}

## Centro di un pezzo (mm): la sua posizione, o il centro dei suoi punti.
static func centro(chiave: String, e: Dictionary) -> Vector2:
	var cp := SchedeEditor.campo_pos(chiave)
	if cp != "" and e.has(cp):
		return e[cp]
	var pts := punti_2d(chiave, e)
	if pts.is_empty():
		return Vector2.ZERO
	var s := Vector2.ZERO
	for p in pts:
		s += p
	return s / pts.size()

## Punti (x, y) di un pezzo fatto di punti (le rampe hanno x, y, altezza).
static func punti_2d(chiave: String, e: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var k := SchedeEditor.campo_punti(chiave)
	if k == "" or not e.has(k):
		return out
	for p in e[k]:
		out.append(Vector2(p.x, p.y))
	return out

func nuovo_id(chiave: String) -> String:
	var base: String = {"bumper": "bumper", "bersagli": "bersaglio", "buche": "buca", "spinner": "spinner", "sensori": "sensore",
		"elastici": "paletto", "kickback": "kickback", "campi": "campo", "inserti": "luce", "muri": "muro", "rampe": "rampa", "nastri": "nastro",
		"fionde": "fionda", "palette": "paletta", "lame": "deviatore", "porte": "porta", "captive": "prigioniera"}.get(chiave, chiave)
	var n := 1
	while not trova("%s_%d" % [base, n]).is_empty():
		n += 1
	return "%s_%d" % [base, n]

# ================================================================ modifiche
func _aggiungi(c: Dictionary) -> Dictionary:
	var k := str(c.get("tipo", ""))
	var s := SchedeEditor.scheda(k)
	if s.is_empty() or s.get("senza_nuovo", false):
		return {"ok": false, "messaggio": "Questo pezzo non si può ancora aggiungere: " + k}
	var pos := _vec(c.get("pos", Vector2(317, 600)))
	var e: Dictionary = s["nuovo"].duplicate(true)
	if k == "inserti" and _chi != "ai":
		e.merge(ultima_luce.duplicate(true), true)
	if k == "muri" and c.has("preset"):
		var pr := CurveEditor.preset(str(c["preset"]), pos)
		if pr.is_empty():
			return {"ok": false, "messaggio": "Forma pronta sconosciuta: " + str(c["preset"])}
		e.merge(pr, true)
	e["id"] = str(c.get("id", nuovo_id(k)))
	if not trova(e["id"]).is_empty():
		return {"ok": false, "messaggio": "Esiste già un pezzo con id " + e["id"]}
	if k == "muri" and e.has("controllo"):
		pass
	elif s.has("punti"):
		var rel: Array = e.get("punti_rel", [Vector2.ZERO, Vector2(60, 0)])
		e.erase("punti_rel")
		var pts = c.get("punti", rel.map(func(q): return pos + q))
		var pv := PackedVector2Array()
		for p in pts:
			pv.append(_vec(p))
		# le fionde nel motore sono una lista di 3 punti, i muri una PackedVector2Array, le rampe punti con altezza
		e[s["punti"]] = Array(pv) if k == "fionde" else pv
		if k == "rampe":
			e["punti"] = profilo_rampa(pv, c.get("altezze", []), float(c.get("altezza_max", 45.0)), bool(c.get("resta_alta", false)))
		if k == "muri":
			var curvi_c: Array = c.get("curvi", [])
			var fio_c: Array = c.get("fionda", [])
			e["curvi"] = curvi_c.map(func(x): return bool(x)) if not curvi_c.is_empty() else CurveEditor._lista(pv.size(), false)
			e["fionda"] = fio_c.map(func(x): return bool(x)) if not fio_c.is_empty() else CurveEditor._lista(pv.size(), false)
			e["chiuso"] = bool(c.get("chiuso", e.get("chiuso", false)))
		if k == "piani":
			# piano rialzato (v0.9): forma chiusa; con meno di 3 punti (un clic) la forma pronta intorno al punto
			if pv.size() < 3:
				e.merge(PianiRialzati.forma_pronta(pos if pv.is_empty() else pv[0]), true)
			else:
				var curvi_p: Array = c.get("curvi", [])
				e["curvi"] = curvi_p.map(func(x): return bool(x)) if not curvi_p.is_empty() else CurveEditor._lista(pv.size(), false)
			e["chiuso"] = true
		if k == "nastri":
			var curvi_n: Array = c.get("curvi", [])
			e["curvi"] = curvi_n.map(func(x): return bool(x)) if not curvi_n.is_empty() else CurveEditor._lista(pv.size(), false)
			var lg: Array = c.get("larghezze", [])
			var al: Array = c.get("altezze", [])
			e["larghezze"] = lg.map(func(x): return float(x)) if not lg.is_empty() else Array(range(pv.size())).map(func(_x): return float(c.get("larghezza", 46.0)))
			e["altezze"] = al.map(func(x): return float(x)) if not al.is_empty() else Array(range(pv.size())).map(func(_x): return 0.0)
	else:
		e[SchedeEditor.campo_pos(k)] = pos
	for campo in c.get("valori", {}):
		e[campo] = _converti(k, campo, c["valori"][campo])
	_ricorda()
	if not desc.get(k) is Array:
		desc[k] = []
	desc[k].append(e)
	_fatto()
	if c.has("file"):
		# v0.6: pezzo con la sua immagine in un solo passo (un solo «annulla»)
		var ri := _immagine({"id": e["id"], "file": c["file"]})
		if ri.get("ok", false):
			_annulla.pop_back()
	return {"ok": true, "messaggio": "Aggiunto %s «%s»" % [s["nome"], e["id"]], "id": e["id"]}

func _modifica(c: Dictionary, f: Callable) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if t.is_empty():
		return {"ok": false, "messaggio": "Non trovo il pezzo " + str(c.get("id", ""))}
	if c.get("comando") == "elimina" and t[0] == "palette" and desc["palette"].size() <= 2 and str(c.get("id")) in ["sx", "dx"]:
		return {"ok": false, "messaggio": "Le due palette principali restano (si spostano). Si possono togliere quelle aggiunte."}
	_ricorda()
	f.call(desc[t[0]], t[1])
	_fatto()
	return {"ok": true, "messaggio": "Fatto"}

func _imposta(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if t.is_empty():
		return {"ok": false, "messaggio": "Non trovo il pezzo " + str(c.get("id", ""))}
	var campo := str(c.get("campo", ""))
	if campo == "id":
		var nuovo := str(c.get("valore", ""))
		if nuovo == "" or not trova(nuovo).is_empty():
			return {"ok": false, "messaggio": "Nome non valido o già usato"}
	_ricorda()
	if campo in ["colore", "colore_2", "aspetto", "bordo", "colore_bordo"] and (c.get("valore") == null or str(c.get("valore")) == "") and t[0] != "nastri":
		desc[t[0]][t[1]].erase(campo)          # torna come il tavolo
		if t[0] == "inserti":
			ultima_luce.erase(campo)
		_fatto()
		return {"ok": true, "messaggio": "%s: come il tavolo" % campo}
	var v = _converti(t[0], campo, c.get("valore"))
	desc[t[0]][t[1]][campo] = v
	if t[0] == "inserti" and campo in RICORDA_LUCE and _chi != "ai":
		ultima_luce[campo] = v
	_fatto()
	return {"ok": true, "messaggio": "%s = %s" % [campo, str(v)]}

## devo sempre cancellare e ridisegnare i muri»): VARCO NEL MURO.
## {"comando": "varco", "id": muro, "pos": punto vicino al muro (mm), "larghezza": mm (40), "metti": "" | "cancelli" |
##  "spinner" | "bersagli"}. Toglie dal muro un tratto largo «larghezza» centrato dove hai cliccato (anche su un tratto
## curvo): il muro aperto diventa uno solo, quello chiuso si apre. Nel varco mette il pezzo scelto, girato come il muro
## e largo come il varco. Un solo «annulla».
const VARCO_PEZZI := ["cancelli", "spinner", "bersagli"]

## Punti fitti di un tratto del muro (dal punto di controllo i al successivo), come li disegna CurveEditor.rigenera.
static func punti_tratto(m: Dictionary, i: int) -> PackedVector2Array:
	var c: PackedVector2Array = m["controllo"]
	var n := c.size()
	var curvi: Array = m.get("curvi", [])
	var chiuso: bool = bool(m.get("chiuso", false)) and n >= 3
	var j := (i + 1) % n
	var cv := func(k: int) -> bool: return k < curvi.size() and bool(curvi[k])
	var out := PackedVector2Array([c[i]])
	if cv.call(i) or cv.call(j):
		var i0 := i - 1 if cv.call(i) else i
		if i0 < 0:
			i0 = n - 1 if chiuso else 0
		var i3 := j + 1 if cv.call(j) else j
		if i3 >= n:
			i3 = i3 - n if chiuso else n - 1
		var passi := maxi(2, int(ceil(c[i].distance_to(c[j]) / CurveEditor.PASSO)))
		for k in range(1, passi):
			out.append(CurveEditor.catmull(c[i0], c[i], c[j], c[i3], float(k) / float(passi)))
	out.append(c[j])
	return out

## Punto a distanza «s» (mm, lungo la linea) su una linea spezzata.
static func _punto_a(pts: PackedVector2Array, s: float) -> Vector2:
	for k in pts.size() - 1:
		var l := pts[k].distance_to(pts[k + 1])
		if s <= l:
			return pts[k].lerp(pts[k + 1], s / maxf(l, 0.0001))
		s -= l
	return pts[pts.size() - 1]

## Dove cadrebbe il varco: {"tratto": i, "dist": distanza dal muro, "a", "b": estremi, "s1", "s2", "lung": lunghezza del
## tratto, "linea": punti del muro tolti (per l'anteprima)} oppure {} se il muro non ha tratti.
static func trova_varco(m: Dictionary, pos: Vector2, larghezza: float) -> Dictionary:
	if not m.has("controllo") or m["controllo"].size() < 2:
		return {}
	var n: int = m["controllo"].size()
	var ultimo := n if (bool(m.get("chiuso", false)) and n >= 3) else n - 1
	var meglio := {}
	for i in ultimo:
		var pts := punti_tratto(m, i)
		var acc := 0.0
		for k in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(pos, pts[k], pts[k + 1])
			var d := q.distance_to(pos)
			if meglio.is_empty() or d < float(meglio["dist"]):
				meglio = {"tratto": i, "dist": d, "s": acc + pts[k].distance_to(q), "pts": pts}
			acc += pts[k].distance_to(pts[k + 1])
	if meglio.is_empty():
		return {}
	var pts2: PackedVector2Array = meglio["pts"]
	var lung := 0.0
	for k in pts2.size() - 1:
		lung += pts2[k].distance_to(pts2[k + 1])
	var mezzo := minf(larghezza, lung) * 0.5
	var s1 := clampf(float(meglio["s"]) - mezzo, 0.0, lung - 2.0 * mezzo)
	var s2 := s1 + 2.0 * mezzo
	var linea := PackedVector2Array([_punto_a(pts2, s1)])
	var acc2 := 0.0
	for k in range(1, pts2.size() - 1):
		acc2 += pts2[k - 1].distance_to(pts2[k])
		if acc2 > s1 and acc2 < s2:
			linea.append(pts2[k])
	linea.append(_punto_a(pts2, s2))
	return {"tratto": meglio["tratto"], "dist": meglio["dist"], "a": linea[0], "b": linea[linea.size() - 1], "s1": s1, "s2": s2, "lung": lung, "linea": linea}

## v0.29: varco nel BORDO di un PIANO RIALZATO. Dove cadrebbe: {"dist", "t" (0-1 sul giro), "a", "b", "linea",
## "fuori" (direzione verso l'esterno del piano, a metà varco)} oppure {}.
const VARCO_PIANO := ["rampa_giu", "rampa_su", "nastro_giu", "nastro_su"]
static func trova_varco_piano(p: Dictionary, pos: Vector2, larghezza: float) -> Dictionary:
	var g := PianiRialzati.giro(p)
	if g.size() < 4:
		return {}
	var tot := PianiRialzati.lunghezza(g)
	var meglio := {}
	var acc := 0.0
	for k in g.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(pos, g[k], g[k + 1])
		var d := q.distance_to(pos)
		if meglio.is_empty() or d < float(meglio["dist"]):
			meglio = {"dist": d, "s": acc + g[k].distance_to(q)}
		acc += g[k].distance_to(g[k + 1])
	var mezzo := minf(larghezza, tot * 0.9) * 0.5
	var sc := float(meglio["s"])
	var linea := PackedVector2Array([PianiRialzati.punto_giro(g, sc - mezzo)])
	var cum := 0.0
	for giri in [-tot, 0.0, tot]:
		cum = giri
		for k in g.size() - 1:
			if cum > sc - mezzo and cum < sc + mezzo:
				linea.append(g[k])
			cum += g[k].distance_to(g[k + 1])
	linea.append(PianiRialzati.punto_giro(g, sc + mezzo))
	var a := linea[0]
	var b := linea[linea.size() - 1]
	var m := (a + b) * 0.5
	var dirv := (b - a).normalized() if a.distance_to(b) > 0.1 else Vector2.RIGHT
	var fuori := Vector2(dirv.y, -dirv.x)
	var zona := g.slice(0, g.size() - 1)
	if Geometry2D.is_point_in_polygon(m + fuori * 6.0, zona):
		fuori = -fuori
	return {"dist": meglio["dist"], "t": fposmod(sc / maxf(tot, 0.001), 1.0), "a": a, "b": b, "linea": linea, "fuori": fuori}

func _varco_piano(c: Dictionary, t: Array) -> Dictionary:
	var e: Dictionary = desc["piani"][t[1]]
	var metti := str(c.get("metti", ""))
	if metti != "" and not metti in VARCO_PIANO:
		return {"ok": false, "messaggio": "Nel varco del piano si può attaccare: rampa o nastro, in salita o in discesa"}
	var larghezza := maxf(float(c.get("larghezza", 50.0)), 10.0)
	var v := trova_varco_piano(e, _vec(c.get("pos", Vector2.ZERO)), larghezza)
	if v.is_empty():
		return {"ok": false, "messaggio": "Non trovo il bordo del piano"}
	_ricorda()
	var varchi: Array = e.get("varchi", []) if e.get("varchi") is Array else []
	varchi.append({"t": snappedf(float(v["t"]), 0.0001), "larghezza": larghezza})
	e["varchi"] = varchi
	var out := {"ok": true, "piano": e["id"]}
	var a: Vector2 = v["a"]
	var b: Vector2 = v["b"]
	var m := (a + b) * 0.5
	var fuori: Vector2 = v["fuori"]
	var h := float(e.get("altezza", 40.0))
	var testo := ""
	if metti != "":
		# il pezzo attaccato: parte 25 mm dentro il piano e arriva 170 mm fuori (poi lo allunghi o lo pieghi tu)
		var dentro := (m - fuori * 25.0).snapped(Vector2(0.5, 0.5))
		var mezzo_p := (m + fuori * 70.0).snapped(Vector2(0.5, 0.5))
		var lontano := (m + fuori * 170.0).snapped(Vector2(0.5, 0.5))
		var giu := metti.ends_with("_giu")
		var pts: Array = [dentro, mezzo_p, lontano] if giu else [lontano, mezzo_p, dentro]
		var cmd := {"tipo": "rampe" if metti.begins_with("rampa") else "nastri", "punti": pts}
		if metti.begins_with("rampa"):
			cmd["altezza_max"] = h
		else:
			cmd["larghezza"] = maxf(larghezza - 6.0, 30.0)
			cmd["altezze"] = [h, h * 0.5, 0.0] if giu else [0.0, h * 0.5, h]
		var ra := _aggiungi(cmd)
		if ra.get("ok", false):
			_annulla.pop_back()          # un solo «annulla» per varco e pezzo attaccato
			out["id"] = ra["id"]
			testo = {"rampa_giu": " con una RAMPA che scende", "rampa_su": " con una RAMPA che sale sul piano", "nastro_giu": " con un NASTRO che scende", "nastro_su": " con un NASTRO che sale sul piano"}[metti]
	_fatto()
	out["messaggio"] = "Varco di %.0f mm aperto nel bordo del piano «%s»%s. Allunga o piega il pezzo coi suoi quadratini." % [a.distance_to(b), str(e.get("nome", e["id"])), testo]
	return out

## v0.30: INCROCI (Incroci.gd).
##  {"comando": "incroci_regola", "id": rampa/binario/nastro, "modo": ""|"sopra"|"sotto"|"stesso",
##   "margine"?, "salita"?, "piano"?: mm} = regola generale del percorso (le scelte dei singoli incroci restano);
##  {"comando": "incrocio", "chiave": "A|B#n", "modo"?: "a_sopra"|"a_sotto"|"b_sopra"|"b_sotto"|"stesso"|"" (""= torna
##   automatico), "quota"?: mm o null (null = toglie la quota a mano), "bloccato"?: bool};
##  {"comando": "incroci_automatico", "id"?: percorso} = toglie le scelte a mano dei suoi incroci (senza id: di tutti).
func _incroci_cmd(c: Dictionary) -> Dictionary:
	var nome := str(c["comando"])
	if nome == "incroci_regola":
		var t := trova(str(c.get("id", "")))
		if t.is_empty() or not t[0] in ["rampe", "nastri"]:
			return {"ok": false, "messaggio": "La regola degli incroci vale per rampe, binari a fili e nastri"}
		var modo := str(c.get("modo", ""))
		if not modo in ["", "sopra", "sotto", "stesso"]:
			return {"ok": false, "messaggio": "Regola sconosciuta: " + modo}
		_ricorda()
		var e: Dictionary = desc[t[0]][t[1]]
		if modo == "":
			e.erase("incroci_modo")
		else:
			e["incroci_modo"] = modo
		for k in [["margine", "incroci_margine", 5.0, 200.0], ["salita", "incroci_salita", 20.0, 600.0], ["piano", "incroci_piano", 0.0, 400.0]]:
			if c.has(k[0]):
				e[k[1]] = clampf(float(c[k[0]]), k[2], k[3])
		_fatto()
		var testo: String = {"": "nessuna regola (altezze come le hai disegnate)", "sopra": "passa SOPRA gli altri percorsi", "sotto": "passa SOTTO gli altri percorsi", "stesso": "si incrocia alla STESSA ALTEZZA"}[modo]
		return {"ok": true, "messaggio": "«%s»: %s. Gli incroci che hai deciso uno per uno restano come sono." % [e["id"], testo]}
	if not desc.get("incroci") is Dictionary:
		desc["incroci"] = {}
	if nome == "incroci_automatico":
		var id := str(c.get("id", ""))
		var via: Array = desc["incroci"].keys().filter(func(k): return id == "" or str(k).begins_with(id + "|") or str(k).contains("|" + id + "#"))
		if via.is_empty():
			return {"ok": true, "messaggio": "Nessun incrocio deciso a mano" + (" per «%s»" % id if id != "" else ""), "tolti": 0}
		_ricorda()
		for k in via:
			desc["incroci"].erase(k)
		_fatto()
		return {"ok": true, "messaggio": "%d incroci tornati automatici (seguono di nuovo le regole delle rampe)" % via.size(), "tolti": via.size()}
	var chiave := str(c.get("chiave", ""))
	if chiave == "" or not chiave.contains("|"):
		return {"ok": false, "messaggio": "Incrocio sconosciuto"}
	var sc: Dictionary = desc["incroci"].get(chiave, {}).duplicate() if desc["incroci"].get(chiave) is Dictionary else {}
	if c.has("modo"):
		var m := str(c["modo"])
		if not m in ["", "a_sopra", "a_sotto", "b_sopra", "b_sotto", "stesso", "unito"]:
			return {"ok": false, "messaggio": "Scelta sconosciuta: " + m}
		if m == "":
			sc.erase("modo")
			sc.erase("quota")
		else:
			sc["modo"] = m
	if c.has("devia"):
		var dv := str(c["devia"])
		if not dv in ["alterna", "sempre", "mai", "comandato"]:
			return {"ok": false, "messaggio": "Deviatore: alterna, sempre, mai o comandato"}
		sc["devia"] = dv
	if c.has("quota"):
		if c["quota"] == null or str(c["quota"]) == "":
			sc.erase("quota")
		else:
			sc["quota"] = clampf(float(c["quota"]), 0.0, 300.0)
	if c.has("bloccato"):
		if bool(c["bloccato"]):
			sc["bloccato"] = true
		else:
			sc.erase("bloccato")
	_ricorda()
	if sc.is_empty():
		desc["incroci"].erase(chiave)
	else:
		desc["incroci"][chiave] = sc
	_fatto()
	var parti := chiave.split("#")[0].split("|")
	var testo2 := "torna automatico (segue le regole delle rampe)"
	match str(sc.get("modo", "")):
		"a_sopra": testo2 = "«%s» passa SOPRA «%s»" % [parti[0], parti[1]]
		"a_sotto": testo2 = "«%s» passa SOTTO «%s»" % [parti[0], parti[1]]
		"b_sopra": testo2 = "«%s» passa SOPRA «%s»" % [parti[1], parti[0]]
		"b_sotto": testo2 = "«%s» passa SOTTO «%s»" % [parti[1], parti[0]]
		"stesso": testo2 = "alla stessa altezza (ognuna resta sulla sua strada)"
		"unito": testo2 = "COMUNICANTI: la pallina può cambiare strada (deviatore: %s)" % str(sc.get("devia", "alterna"))
	if bool(sc.get("bloccato", false)):
		testo2 += " · bloccato: l'automatico non lo tocca"
	return {"ok": true, "messaggio": "Incrocio: " + testo2}

## v0.29: chiude un varco del piano (il più vicino al punto).
func _chiudi_varco_piano(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if t.is_empty() or t[0] != "piani":
		return {"ok": false, "messaggio": "Scegli un piano rialzato"}
	var e: Dictionary = desc["piani"][t[1]]
	var varchi: Array = e.get("varchi", []) if e.get("varchi") is Array else []
	var indice := int(c.get("indice", varchi.size() - 1))
	if indice < 0 or indice >= varchi.size():
		return {"ok": false, "messaggio": "Questo piano non ha varchi"}
	_ricorda()
	varchi.remove_at(indice)
	e["varchi"] = varchi
	_fatto()
	return {"ok": true, "messaggio": "Varco chiuso (il pezzo attaccato resta: se non serve, eliminalo)"}

func _varco(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if not t.is_empty() and t[0] == "piani":
		return _varco_piano(c, t)
	if t.is_empty() or t[0] != "muri":
		return {"ok": false, "messaggio": "Il varco si apre in un MURO o nel bordo di un PIANO RIALZATO: sceglilo"}
	var e: Dictionary = desc["muri"][t[1]]
	if not e.has("controllo"):
		return {"ok": false, "messaggio": "Questo muro non ha punti da tagliare"}
	var metti := str(c.get("metti", ""))
	if metti != "" and not metti in VARCO_PEZZI:
		return {"ok": false, "messaggio": "Nel varco si può mettere: cancelletto, spinner o bersaglio"}
	var v := trova_varco(e, _vec(c.get("pos", Vector2.ZERO)), maxf(float(c.get("larghezza", 40.0)), 4.0))
	if v.is_empty():
		return {"ok": false, "messaggio": "Non trovo il tratto del muro"}
	var cp: PackedVector2Array = e["controllo"]
	var n := cp.size()
	var chiuso: bool = bool(e.get("chiuso", false)) and n >= 3
	var curvi: Array = e.get("curvi", CurveEditor._lista(n, false)).duplicate()
	var fio: Array = e.get("fionda", CurveEditor._lista(n, false)).duplicate()
	while curvi.size() < n:
		curvi.append(false)
	while fio.size() < n:
		fio.append(false)
	var i: int = v["tratto"]
	var j := (i + 1) % n
	var taglia_a := float(v["s1"]) > 0.5               # resta un pezzetto prima del varco
	var taglia_b := float(v["s2"]) < float(v["lung"]) - 0.5
	# parte A: dall'inizio fino al varco · parte B: dal varco alla fine (per il muro chiuso: una parte sola, che gira)
	var pa := PackedVector2Array()
	var ca: Array = []
	var fa: Array = []
	var pb := PackedVector2Array()
	var cb: Array = []
	var fb: Array = []
	if taglia_b:
		pb.append(v["b"])
		cb.append(false)
		fb.append(fio[i])
	# muro aperto: dal punto dopo il varco alla fine; muro chiuso: tutto il giro, dal punto dopo il varco a quello prima
	var quanti := n - j if not chiuso else n
	for k in quanti:
		var kk := (j + k) % n
		pb.append(cp[kk])
		cb.append(curvi[kk])
		fb.append(fio[kk])
	if chiuso:
		if taglia_a:
			pb.append(v["a"])
			cb.append(false)
			fb.append(false)
		fb[fb.size() - 1] = false
	else:
		for k in range(0, i + 1):
			pa.append(cp[k])
			ca.append(curvi[k])
			fa.append(fio[k])
		if taglia_a:
			pa.append(v["a"])
			ca.append(false)
			fa.append(false)
		if not fa.is_empty():
			fa[fa.size() - 1] = false
	_ricorda()
	var muri_fatti: Array = []
	var resto := {}
	for campo in e:
		if not campo in ["controllo", "curvi", "fionda", "punti", "fionde_tratti", "id", "chiuso"]:
			resto[campo] = e[campo]
	var parti: Array = [[pa, ca, fa], [pb, cb, fb]] if not chiuso else [[pb, cb, fb]]
	var primo := true
	var dove: int = t[1]
	for parte in parti:
		var pts: PackedVector2Array = parte[0]
		if pts.size() < 2:
			continue
		var m: Dictionary = e if primo else resto.duplicate(true)
		if not primo:
			m["id"] = nuovo_id("muri")
			desc["muri"].insert(dove + 1, m)
		m["controllo"] = pts
		m["curvi"] = parte[1]
		m["fionda"] = parte[2]
		m["chiuso"] = false
		CurveEditor.rigenera(m)
		muri_fatti.append(m["id"])
		primo = false
	if primo:
		# il varco ha preso tutto il muro (un solo tratto, corto): il muro sparisce
		desc["muri"].remove_at(dove)
	var out := {"ok": true, "muri": muri_fatti}
	var a: Vector2 = v["a"]
	var b: Vector2 = v["b"]
	var largo := a.distance_to(b)
	if metti != "":
		var el: Dictionary = SchedeEditor.scheda(metti)["nuovo"].duplicate(true)
		el["id"] = nuovo_id(metti)
		el["pos"] = ((a + b) * 0.5).snapped(Vector2(0.5, 0.5))
		el["angolo"] = wrapf((b - a).angle(), -PI / 2.0, PI / 2.0)
		if metti == "bersagli":
			el["dim"] = Vector2(snappedf(largo, 0.5), Vector2(el.get("dim", Vector2(24, 8))).y)
		else:
			el["larghezza"] = snappedf(largo, 0.5)
		if e.has("livello"):
			el["livello"] = e["livello"]
		if not desc.get(metti) is Array:
			desc[metti] = []
		desc[metti].append(el)
		out["id"] = el["id"]
	_fatto()
	var nome_p: String = {"": "", "cancelli": " con un CANCELLETTO", "spinner": " con uno SPINNER", "bersagli": " con un BERSAGLIO"}[metti]
	out["messaggio"] = "Varco di %.0f mm aperto nel muro%s%s" % [largo, nome_p, " (il muro è diventato due)" if muri_fatti.size() == 2 else ""]
	return out

## IMMAGINE PROPRIA su un pezzo (v0.6). Campi del comando (tutti facoltativi tranne "id"):
##  "file": percorso di un'immagine (PNG/JPG/WEBP) da mettere sul pezzo (entra nel file del tavolo, max 1024 px)
##  "misura": "pezzo" (grande come il pezzo) | "centro" (solo al centro) · "dim": [larghezza, altezza] mm
##  "pos": spostamento dal centro [x, y] mm · "rot": gradi · "modo": "sopra" | "sostituisce" · "togli": true
func _immagine(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if t.is_empty():
		return {"ok": false, "messaggio": "Non trovo il pezzo " + str(c.get("id", ""))}
	if not t[0] in PittorePezzi.TIPI and not t[0] in ["decorazioni", "rampe"]:
		return {"ok": false, "messaggio": "Questo pezzo non prende immagini (ancora)"}
	var e: Dictionary = desc[t[0]][t[1]]
	if bool(c.get("togli", false)):
		_ricorda()
		e.erase("immagine")
		_pulisci_immagini()
		_fatto()
		return {"ok": true, "messaggio": "Immagine tolta"}
	var nome := ""
	if c.has("file"):
		var dati := PittorePezzi.importa(str(c["file"]))
		if dati == "":
			return {"ok": false, "messaggio": "Non riesco a leggere l'immagine (va bene PNG, JPG o WEBP)"}
		nome = str(c["file"]).get_file().get_basename().validate_filename().replace(" ", "_")
		if not desc.get("immagini") is Dictionary:
			desc["immagini"] = {}
		var base := nome
		var k := 2
		while desc["immagini"].has(nome) and desc["immagini"][nome] != dati:
			nome = "%s_%d" % [base, k]
			k += 1
		_ricorda()
		desc["immagini"][nome] = dati
	elif not PittorePezzi.ha_immagine(e):
		return {"ok": false, "messaggio": "Prima scegli un'immagine"}
	else:
		_ricorda()
	var im: Dictionary = e.get("immagine", {}) if e.get("immagine") is Dictionary else {}
	if nome != "":
		im["nome"] = nome
		if not c.has("misura") and not c.has("dim") and not im.has("dim"):
			c["misura"] = "pezzo"
	var tex := PittorePezzi.texture(desc, str(im["nome"]))
	var prop := Vector2(tex.get_width(), tex.get_height()) if tex else Vector2.ONE
	var mp := PittorePezzi.misura_pezzo(t[0], e)
	match str(c.get("misura", "")):
		"pezzo":
			im["dim"] = _adatta(prop, mp)
			im["pos"] = Vector2.ZERO
		"centro":
			im["dim"] = _adatta(prop, mp * 0.5)
			im["pos"] = Vector2.ZERO
	if c.has("dim"):
		im["dim"] = _vec(c["dim"])
	if c.has("pos"):
		im["pos"] = _vec(c["pos"])
	if c.has("rot"):
		im["rot"] = deg_to_rad(float(c["rot"]))
	if c.has("modo"):
		im["modo"] = "sostituisce" if str(c["modo"]) == "sostituisce" else "sopra"
	im["modo"] = im.get("modo", "sopra")
	if t[0] == "decorazioni":
		# immagine sul piano: la misura è quella del pezzo (si ridimensiona e ruota come tutti i pezzi)
		im["modo"] = "sostituisce"
		if nome != "" or str(c.get("misura", "")) != "":
			e["dim"] = _adatta(prop, Vector2.ONE * maxf(Vector2(e.get("dim", Vector2(100, 100))).x, Vector2(e.get("dim", Vector2(100, 100))).y))
		if c.has("dim"):
			e["dim"] = _vec(c["dim"])
		im["dim"] = e["dim"]
	e["immagine"] = im
	_pulisci_immagini()
	_fatto()
	return {"ok": true, "messaggio": "Immagine «%s» sul pezzo (%.0f × %.0f mm)" % [im["nome"], Vector2(im["dim"]).x, Vector2(im["dim"]).y]}

## L'immagine entra nel riquadro `box` senza deformarsi.
static func _adatta(prop: Vector2, box: Vector2) -> Vector2:
	var f := minf(box.x / maxf(prop.x, 1.0), box.y / maxf(prop.y, 1.0))
	return (prop * f).snapped(Vector2(0.5, 0.5))

## Toglie dal tavolo le immagini che nessun pezzo usa più (il file resta leggero).
func _pulisci_immagini() -> void:
	if not desc.get("immagini") is Dictionary:
		return
	var usate := {str(desc.get("fondo", "")): true}
	for k in PittorePezzi.TIPI + ["decorazioni", "rampe"]:
		for e in desc.get(k, []):
			if PittorePezzi.ha_immagine(e):
				usate[str(e["immagine"]["nome"])] = true
	for n in desc["immagini"].keys():
		if not usate.has(n):
			desc["immagini"].erase(n)

## Sposta: "pos" = nuovo centro, oppure "di" = spostamento.
func _sposta(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if t.is_empty():
		return {"ok": false, "messaggio": "Non trovo il pezzo " + str(c.get("id", ""))}
	var e: Dictionary = desc[t[0]][t[1]]
	var di: Vector2 = _vec(c["di"]) if c.has("di") else _vec(c.get("pos", Vector2.ZERO)) - centro(t[0], e)
	_ricorda()
	trasla(t[0], e, di)
	_fatto()
	return {"ok": true, "messaggio": "Spostato di %s mm" % _vec_testo(di)}

## Trasla un pezzo (senza annulla: lo usa anche il trascinamento col mouse).
static func trasla(chiave: String, e: Dictionary, di: Vector2) -> void:
	var cp := SchedeEditor.campo_pos(chiave)
	if cp != "":
		e[cp] = Vector2(e[cp]) + di
		return
	var k := SchedeEditor.campo_punti(chiave)
	if k == "":
		return
	var pts = e[k]
	for i in pts.size():
		if pts[i] is Vector3:
			pts[i] = pts[i] + Vector3(di.x, di.y, 0)
		else:
			pts[i] = pts[i] + di
	e[k] = pts

func _sposta_punto(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	var k := SchedeEditor.campo_punti(t[0]) if not t.is_empty() else ""
	if k == "":
		return {"ok": false, "messaggio": "Il pezzo non ha punti"}
	var e: Dictionary = desc[t[0]][t[1]]
	var i := int(c.get("indice", -1))
	if i < 0 or i >= e[k].size():
		return {"ok": false, "messaggio": "Punto %d inesistente" % i}
	_ricorda()
	imposta_punto(t[0], e, i, _vec(c.get("pos", Vector2.ZERO)))
	_fatto()
	return {"ok": true, "messaggio": "Punto %d spostato" % i}

## Sposta un punto, tenendo chiusi i muri chiusi (primo punto = ultimo). Senza annulla (trascinamento).
static func imposta_punto(chiave: String, e: Dictionary, i: int, p: Vector2) -> void:
	var k := SchedeEditor.campo_punti(chiave)
	var pts = e[k]
	var chiuso: bool = pts.size() > 3 and Vector2(pts[0].x, pts[0].y).distance_to(Vector2(pts[-1].x, pts[-1].y)) < 0.5
	var indici := [i]
	if chiuso and (i == 0 or i == pts.size() - 1):
		indici = [0, pts.size() - 1]
	for j in indici:
		pts[j] = Vector3(p.x, p.y, pts[j].z) if pts[j] is Vector3 else p
	e[k] = pts

func _aggiungi_punto(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	var k := SchedeEditor.campo_punti(t[0]) if not t.is_empty() else ""
	if k == "" or t[0] == "fionde":
		return {"ok": false, "messaggio": "A questo pezzo non si aggiungono punti"}
	var e: Dictionary = desc[t[0]][t[1]]
	var dopo := clampi(int(c.get("dopo", e[k].size() - 1)), 0, e[k].size() - 1)
	var p := _vec(c.get("pos", Vector2.ZERO))
	_ricorda()
	var pts = e[k]
	if pts[0] is Vector3:
		pts.insert(dopo + 1, Vector3(p.x, p.y, pts[dopo].z))
	else:
		pts.insert(dopo + 1, p)
	e[k] = pts
	for flag in ["curvi", "fionda"]:
		if e.has(flag):
			e[flag].insert(dopo + 1, bool(c.get("curvo", false)) if flag == "curvi" else false)
	for misura in ["larghezze", "altezze"]:
		if e.has(misura) and e[misura].size() > dopo:
			var vicino: float = float(e[misura][dopo])
			if dopo + 1 < e[misura].size():
				vicino = (vicino + float(e[misura][dopo + 1])) * 0.5
			e[misura].insert(dopo + 1, vicino)
	_fatto()
	return {"ok": true, "messaggio": "Punto aggiunto"}

func _togli_punto(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	var k := SchedeEditor.campo_punti(t[0]) if not t.is_empty() else ""
	if k == "" or t[0] == "fionde":
		return {"ok": false, "messaggio": "A questo pezzo non si tolgono punti"}
	var e: Dictionary = desc[t[0]][t[1]]
	if e[k].size() <= (3 if bool(e.get("chiuso", false)) else 2):
		return {"ok": false, "messaggio": "Servono almeno 2 punti (3 per una forma chiusa)"}
	_ricorda()
	var pts = e[k]
	var idx := clampi(int(c.get("indice", 0)), 0, pts.size() - 1)
	pts.remove_at(idx)
	e[k] = pts
	for flag in ["curvi", "fionda", "larghezze", "altezze"]:
		if e.has(flag) and idx < e[flag].size():
			e[flag].remove_at(idx)
	_fatto()
	return {"ok": true, "messaggio": "Punto tolto"}

func _duplica(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if t.is_empty() or SchedeEditor.scheda(t[0]).get("senza_nuovo", false):
		return {"ok": false, "messaggio": "Questo pezzo non si può duplicare (v0.1)"}
	_ricorda()
	var e: Dictionary = desc[t[0]][t[1]].duplicate(true)
	e["id"] = nuovo_id(t[0])
	trasla(t[0], e, _vec(c.get("di", Vector2(30, 30))))
	desc[t[0]].append(e)
	_fatto()
	return {"ok": true, "messaggio": "Duplicato: «%s»" % e["id"], "id": e["id"]}

## COPIA A SPECCHIO: crea il pezzo uguale dall'altra parte del tavolo (asse = in mezzo alle due palette principali).
## Palette: lato e tasto invertiti. Fionde e muri: punti specchiati. Pezzi con angolo: angolo invertito.
func asse_specchio() -> float:
	var xs: Array = []
	for pa in desc.get("palette", []):
		if pa.get("id", "") in ["sx", "dx"]:
			xs.append(float(Vector2(pa["perno"]).x))
	return (xs[0] + xs[1]) * 0.5 if xs.size() == 2 else float(desc.get("campo", 586.0)) * 0.5

static func _x_specchio(v: Vector2, asse: float) -> Vector2:
	return Vector2(2.0 * asse - v.x, v.y)

func _specchia(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if t.is_empty():
		return {"ok": false, "messaggio": "Non trovo il pezzo"}
	var k: String = t[0]
	if SchedeEditor.scheda(k).get("senza_nuovo", false):
		return {"ok": false, "messaggio": "Questo pezzo non si può ancora copiare"}
	var asse := asse_specchio()
	var e: Dictionary = desc[k][t[1]].duplicate(true)
	e["id"] = nuovo_id(k)
	for campo in ["pos", "perno", "molla_verso"]:
		if e.has(campo) and e[campo] is Vector2:
			e[campo] = _x_specchio(e[campo], asse)
	for campo in ["uscita_dir", "dir", "lancio_dir"]:
		if e.has(campo) and e[campo] is Vector2:
			e[campo] = Vector2(-e[campo].x, e[campo].y)
	if e.has("angolo"):
		e["angolo"] = -float(e["angolo"])
	if k == "palette":
		e["verso"] = -float(e.get("verso", 1.0))
		e["comando"] = "paletta_dx" if str(e.get("comando", "")) == "paletta_sx" else "paletta_sx"
	for campo in ["punti", "percorso", "controllo"]:
		if e.has(campo):
			var pts = e[campo]
			for i in pts.size():
				pts[i] = Vector3(2.0 * asse - pts[i].x, pts[i].y, pts[i].z) if pts[i] is Vector3 else _x_specchio(pts[i], asse)
			e[campo] = pts
	_ricorda()
	desc[k].append(e)
	_fatto()
	return {"ok": true, "messaggio": "Copia a specchio: «%s» dall'altra parte del tavolo" % e["id"], "id": e["id"]}

# ================================================================ STRUMENTI SU PIÙ PEZZI (v0.4, come VPX)
## {"ids": [...], "azione": sposta | elimina | duplica | specchia | scala | capovolgi | ruota | allinea | distribuisci |
##  blocca, ...}: una sola voce di annulla per tutto il gruppo. Restituisce anche "ids" (es. le copie create).
func _gruppo(c: Dictionary) -> Dictionary:
	var ids: Array = c.get("ids", [])
	var voci: Array = []          # [lista, dizionario]
	for id in ids:
		var t := trova(str(id))
		if not t.is_empty() and not desc[t[0]][t[1]].has("da_nastro") and not desc[t[0]][t[1]].has("da_captive"):
			voci.append([t[0], desc[t[0]][t[1]]])
	if voci.is_empty():
		return {"ok": false, "messaggio": "Nessun pezzo scelto"}
	var azione := str(c.get("azione", ""))
	var cg := Vector2.ZERO
	for v in voci:
		cg += centro(v[0], v[1])
	cg /= voci.size()
	var nuovi: Array = []
	_ricorda()
	match azione:
		"sposta":
			for v in voci:
				trasla(v[0], v[1], _vec(c.get("di", Vector2.ZERO)))
		"elimina":
			var protetti := 0
			for v in voci:
				if v[0] == "palette" and str(v[1]["id"]) in ["sx", "dx"]:
					protetti += 1
					continue
				desc[v[0]].erase(v[1])
			if protetti == voci.size():
				_annulla.pop_back()
				return {"ok": false, "messaggio": "Le due palette principali non si eliminano"}
		"duplica", "specchia":
			for v in voci:
				if SchedeEditor.scheda(v[0]).get("senza_nuovo", false):
					continue
				var copia: Dictionary = v[1].duplicate(true)
				copia["id"] = nuovo_id(v[0])
				if azione == "duplica":
					trasla(v[0], copia, _vec(c.get("di", Vector2(30, 30))))
				else:
					_capovolgi_pezzo(v[0], copia, "x", asse_specchio())
				desc[v[0]].append(copia)
				nuovi.append(copia["id"])
		"scala":
			var f := clampf(float(c.get("fattore", 1.1)), 0.2, 5.0)
			for v in voci:
				_scala_pezzo(v[0], v[1], f, cg if voci.size() > 1 else centro(v[0], v[1]))
		"capovolgi":
			var asse := str(c.get("asse", "x"))
			for v in voci:
				var cc := cg if voci.size() > 1 else centro(v[0], v[1])
				_capovolgi_pezzo(v[0], v[1], asse, cc.x if asse == "x" else cc.y)
		"ruota":
			var a := deg_to_rad(float(c.get("gradi", 15.0)))
			for v in voci:
				var cv := centro(v[0], v[1])
				var nuovo_c := (cv - cg).rotated(a) + cg if voci.size() > 1 else cv
				_ruota_pezzo(v[0], v[1], a)
				trasla(v[0], v[1], nuovo_c - cv)
		"allinea":
			var su_x := str(c.get("asse", "y")) == "x"      # x = stessa colonna, y = stessa riga
			for v in voci:
				var cv2 := centro(v[0], v[1])
				trasla(v[0], v[1], Vector2(cg.x - cv2.x, 0) if su_x else Vector2(0, cg.y - cv2.y))
		"distribuisci":
			var lungo_x := str(c.get("asse", "x")) == "x"
			voci.sort_custom(func(a, b): return centro(a[0], a[1]).x < centro(b[0], b[1]).x if lungo_x else centro(a[0], a[1]).y < centro(b[0], b[1]).y)
			var primo := centro(voci[0][0], voci[0][1])
			var ultimo := centro(voci[-1][0], voci[-1][1])
			for i in voci.size():
				var dove := primo.lerp(ultimo, float(i) / float(maxi(1, voci.size() - 1)))
				var cv3 := centro(voci[i][0], voci[i][1])
				trasla(voci[i][0], voci[i][1], Vector2(dove.x - cv3.x, 0) if lungo_x else Vector2(0, dove.y - cv3.y))
		"blocca":
			for v in voci:
				v[1]["bloccato"] = bool(c.get("valore", true))
		"aspetto", "colore":
			# v0.5: stesso aspetto (o colore) per tutti i pezzi scelti; "" = come il tavolo
			var val = c.get("valore", "")
			for v in voci:
				if not v[0] in PittorePezzi.TIPI and v[0] != "nastri":
					continue
				if val == null or str(val) == "":
					if v[0] != "nastri":
						v[1].erase(azione)
				else:
					v[1][azione] = _converti(v[0], azione, val) if azione == "colore" else str(val)
		_:
			_annulla.pop_back()
			return {"ok": false, "messaggio": "Azione sconosciuta: " + azione}
	_fatto()
	var nomi := {"sposta": "spostati", "elimina": "eliminati", "duplica": "duplicati", "specchia": "copiati a specchio", "scala": "ridimensionati",
		"capovolgi": "capovolti", "ruota": "ruotati", "allinea": "allineati", "distribuisci": "distribuiti", "blocca": "sbloccati" if azione == "blocca" and not bool(c.get("valore", true)) else "bloccati",
		"aspetto": "con l'aspetto nuovo", "colore": "col colore nuovo"}
	return {"ok": true, "messaggio": "%d pezzi %s" % [voci.size(), nomi.get(azione, azione)] if voci.size() > 1 else "Pezzo %s" % _singolare(str(nomi.get(azione, azione))), "ids": nuovi}

static func _singolare(t: String) -> String:
	return t.trim_suffix("i") + "o" if t.ends_with("i") else t

## Ridimensiona un pezzo di un fattore intorno al punto `c` (misure e punti).
static func _scala_pezzo(k: String, e: Dictionary, f: float, c: Vector2) -> void:
	# v0.21: l'immagine del pezzo cresce con lui (prima restava della stessa grandezza)
	if e.get("immagine") is Dictionary:
		var im: Dictionary = e["immagine"]
		im["dim"] = (Vector2(im.get("dim", Vector2(40, 40))) * f).snapped(Vector2(0.5, 0.5))
		im["pos"] = Vector2(im.get("pos", Vector2.ZERO)) * f
	for campo in ["raggio", "raggio_y", "larghezza", "lunghezza"]:
		if e.has(campo) and (e[campo] is float or e[campo] is int):
			e[campo] = float(e[campo]) * f
	if e.has("dim") and e["dim"] is Vector2:
		e["dim"] = Vector2(e["dim"]) * f
	if e.has("larghezze"):
		e["larghezze"] = e["larghezze"].map(func(x): return float(x) * f)
	var cp := SchedeEditor.campo_pos(k)
	if cp != "" and e.has(cp):
		e[cp] = c + (Vector2(e[cp]) - c) * f
	for chiave in ["controllo", "punti", "percorso"]:
		if e.has(chiave) and (chiave != "punti" or SchedeEditor.campo_punti(k) == "punti"):
			var pts = e[chiave]
			for i in pts.size():
				var q := Vector2(pts[i].x, pts[i].y)
				var nq := c + (q - c) * f
				pts[i] = Vector3(nq.x, nq.y, pts[i].z) if pts[i] is Vector3 else nq
			e[chiave] = pts

## Capovolge un pezzo intorno alla retta x = v (asse "x", sinistra↔destra) o y = v (asse "y", su↔giù).
static func _capovolgi_pezzo(k: String, e: Dictionary, asse: String, v: float) -> void:
	var fx := asse == "x"
	var rifletti := func(q: Vector2) -> Vector2: return Vector2(2.0 * v - q.x, q.y) if fx else Vector2(q.x, 2.0 * v - q.y)
	for campo in ["pos", "perno", "molla_verso", "uscita"]:
		if e.has(campo) and e[campo] is Vector2:
			e[campo] = rifletti.call(e[campo])
	for campo in ["uscita_dir", "dir", "lancio_dir"]:
		if e.has(campo) and e[campo] is Vector2:
			e[campo] = Vector2(-e[campo].x, e[campo].y) if fx else Vector2(e[campo].x, -e[campo].y)
	if e.has("angolo"):
		e["angolo"] = -float(e["angolo"]) if fx else PI - float(e["angolo"])
	if k == "decorazioni":
		e["specchiata"] = not bool(e.get("specchiata", false))
	if k == "palette" and fx:
		e["verso"] = -float(e.get("verso", 1.0))
		e["comando"] = "paletta_dx" if str(e.get("comando", "")) == "paletta_sx" else "paletta_sx"
	for campo in ["punti", "percorso", "controllo"]:
		if e.has(campo):
			var pts = e[campo]
			for i in pts.size():
				var q := rifletti.call(Vector2(pts[i].x, pts[i].y)) as Vector2
				pts[i] = Vector3(q.x, q.y, pts[i].z) if pts[i] is Vector3 else q
			e[campo] = pts

static func _ruota_pezzo(k: String, e: Dictionary, a: float) -> void:
	# v0.21: l'immagine gira con il pezzo (non per la paletta: lì gira già da sola)
	if k != "palette" and e.get("immagine") is Dictionary:
		var im: Dictionary = e["immagine"]
		im["rot"] = float(im.get("rot", 0.0)) + a
		im["pos"] = Vector2(im.get("pos", Vector2.ZERO)).rotated(a)
	if k == "inserti":
		e["angolo_luce"] = float(e.get("angolo_luce", Vector2(e.get("dir", Vector2(0, -1))).angle() + PI / 2)) + a
		return
	if e.has("angolo"):
		e["angolo"] = float(e["angolo"]) + a
		return
	var cc := centro(k, e)
	for campo in ["controllo", "punti", "percorso"]:
		if e.has(campo) and (campo != "punti" or SchedeEditor.campo_punti(k) == "punti"):
			var pts = e[campo]
			for i in pts.size():
				var q := (Vector2(pts[i].x, pts[i].y) - cc).rotated(a) + cc
				pts[i] = Vector3(q.x, q.y, pts[i].z) if pts[i] is Vector3 else q
			e[campo] = pts

## Incolla pezzi copiati (Ctrl+C): nomi nuovi, il gruppo si centra sul punto `pos` (dove sta il mouse).
func _incolla(pezzi: Array, pos: Vector2) -> Dictionary:
	if pezzi.is_empty():
		return {"ok": false, "messaggio": "Niente da incollare (prima Ctrl+C su un pezzo)"}
	var cg := Vector2.ZERO
	for p in pezzi:
		cg += centro(p[0], p[1])
	cg /= pezzi.size()
	_ricorda()
	var nuovi: Array = []
	for p in pezzi:
		var copia: Dictionary = p[1].duplicate(true)
		copia["id"] = nuovo_id(p[0])
		copia.erase("bloccato")
		trasla(p[0], copia, pos - cg)
		if not desc.get(p[0]) is Array:
			desc[p[0]] = []
		desc[p[0]].append(copia)
		nuovi.append(copia["id"])
	_fatto()
	return {"ok": true, "messaggio": "Incollati %d pezzi" % nuovi.size(), "ids": nuovi}

## Pezzi COMPOSTI (un clic, un solo annulla): «corsia» = due guide + sensore + luce; «corsie_3» = 3 corsie in alto.
func _composto(nome: String, pos: Vector2) -> Dictionary:
	var larg := 46.0                          # luce della corsia (pallina 27 mm: passa bene, sopra i 36 mm)
	var lunghe := 70.0
	if nome.begins_with("abbattibili_"):
		return _fila_abbattibili(int(nome.trim_prefix("abbattibili_")), pos)
	if nome == "scoop":
		return _scoop(pos)
	if nome in GRUPPI_PRONTI:
		return _gruppo_pronto(nome, pos)
	var n := 1 if nome == "corsia" else (3 if nome == "corsie_3" else 0)
	if n == 0:
		return {"ok": false, "messaggio": "Pezzo composto sconosciuto: " + nome}
	_ricorda()
	var x0 := pos.x - (larg * n) * 0.5
	var ids: Array = []
	for g in n + 1:
		var x := x0 + larg * g
		var mid := nuovo_id("muri")
		desc["muri"].append({"id": mid, "tipo": "metallo", "altezza": 22.0, "chiuso": false,
			"controllo": PackedVector2Array([Vector2(x, pos.y - lunghe * 0.5), Vector2(x, pos.y + lunghe * 0.5)]),
			"curvi": [false, false], "fionda": [false, false]})
		ids.append(mid)
	# v0.12: le 3 corsie sono un GRUPPO con il CAMBIO CORSIA (le palette spostano le luci; tutte accese = premio)
	var gruppo := ""
	if n > 1:
		var kg := 1
		while _gruppo_usato("corsie_%d" % kg):
			kg += 1
		gruppo = "corsie_%d" % kg
	for k in n:
		var cx := x0 + larg * (k + 0.5)
		var sid := nuovo_id("sensori")
		var sen := {"id": sid, "pos": Vector2(cx, pos.y), "dim": Vector2(larg - 8.0, 8.0), "dir": Vector2(0, 1)}
		if gruppo != "":
			sen["gruppo"] = gruppo
		desc["sensori"].append(sen)
		var lid := nuovo_id("inserti")
		var luce := {"id": lid, "pos": Vector2(cx, pos.y + lunghe * 0.5 + 18.0), "forma": "tondo", "dim": Vector2(14, 14), "colore": Color(1.0, 0.85, 0.4)}
		if gruppo != "":
			luce["luce_modo"] = "corsia"
			luce["luce_rif"] = sid
		desc["inserti"].append(luce)
		ids.append(sid)
	if gruppo != "":
		if not desc.get("cambio_corsie") is Array:
			desc["cambio_corsie"] = []
		desc["cambio_corsie"].append({"gruppo": gruppo, "premio": {"punti": 25000, "bonus_x": 1}})
	_fatto()
	return {"ok": true, "messaggio": ("Corsia aggiunta (guide, sensore e luce)" if n == 1 else "3 corsie aggiunte (guide, sensori e luci)"), "id": ids[0]}

## SCOOP (v0.15): buca che TIENE la pallina con intorno un bordo di metallo a ferro di cavallo, aperto verso il
## basso (verso le palette): la pallina entra dall'apertura, sbatte sul fondo, cade nella buca ed è risputata fuori
## dall'apertura. Ruota e sposta come gli altri pezzi (sono una buca + un muro).
func _scoop(pos: Vector2) -> Dictionary:
	_ricorda()
	var bid := nuovo_id("buche")
	desc["buche"].append({"id": bid, "pos": pos, "raggio": 14.0, "tipo": "tiene", "tempo": 1.0, "uscita_dir": Vector2(0, 1), "uscita_vel": 900.0})
	var mid := nuovo_id("muri")
	var arco := PackedVector2Array()
	var curvi: Array = []
	for k in 7:
		var a := deg_to_rad(lerpf(20.0, 160.0, k / 6.0))
		arco.append(pos + Vector2(cos(a), -sin(a)) * 30.0 + Vector2(0, 6))
		curvi.append(true)
	arco.reverse()
	arco.insert(0, arco[0] + Vector2(0, 24))
	arco.append(arco[arco.size() - 1] + Vector2(0, 24))
	curvi = [false] + curvi + [false]
	desc["muri"].append({"id": mid, "tipo": "metallo", "altezza": 25.0, "chiuso": false, "controllo": arco, "curvi": curvi, "fionda": curvi.map(func(_x): return false)})
	_fatto()
	return {"ok": true, "messaggio": "Scoop aggiunto (buca «%s» + bordo «%s»)" % [bid, mid], "id": bid}

## FILA DI BERSAGLI ABBATTIBILI (v0.7): n bersagli affiancati (passo 27 mm, come i banchi dei flipper veri) con lo
## stesso gruppo e una luce davanti a ognuno. Regola di base: tutti giù = premio, poi si rialzano.
func _fila_abbattibili(n: int, pos: Vector2) -> Dictionary:
	if n < 2 or n > 7:
		return {"ok": false, "messaggio": "Una fila va da 2 a 7 bersagli"}
	_ricorda()
	var k := 1
	while _gruppo_usato("fila_%d" % k):
		k += 1
	var gruppo := "fila_%d" % k
	var passo := 27.0
	var ids: Array = []
	var luci: Array = []
	for i in n:
		var x := pos.x + (i - (n - 1) * 0.5) * passo
		var bid := nuovo_id("bersagli")
		desc["bersagli"].append({"id": bid, "pos": Vector2(x, pos.y), "angolo": 0.0, "dim": Vector2(24, 8), "abbattibile": true,
			"molla": false, "molla_verso": Vector2(317, 300), "gruppo": gruppo})
		ids.append(bid)
		var lid := nuovo_id("inserti")
		desc["inserti"].append({"id": lid, "pos": Vector2(x, pos.y + 24.0), "forma": "tondo", "dim": Vector2(12, 12), "colore": Color(1.0, 0.82, 0.15)})
		luci.append(lid)
	_fatto()
	return {"ok": true, "messaggio": "Fila di %d bersagli abbattibili (gruppo %s) con le luci" % [n, gruppo], "id": ids[0], "ids": ids, "luci": luci}

func _gruppo_usato(g: String) -> bool:
	for k in ["bersagli", "sensori"]:
		for b in desc.get(k, []):
			if str(b.get("gruppo", "")) == g:
				return true
	return false

## Punti (x, y, altezza) di una rampa nuova: parte da terra (0 mm, dove la pallina entra), sale fino ad
## `hmax` a metà e riscende a terra alla fine; con `resta_alta` finisce sospesa a 32 mm (la pallina cade sul piano,
## regola dei nostri flipper). Altezze date a mano: usate così come sono.
static func profilo_rampa(pv: PackedVector2Array, altezze: Array, hmax: float, resta_alta: bool) -> Array:
	var tot := 0.0
	for i in range(1, pv.size()):
		tot += pv[i].distance_to(pv[i - 1])
	var out: Array = []
	var acc := 0.0
	for i in pv.size():
		if i > 0:
			acc += pv[i].distance_to(pv[i - 1])
		var f := acc / maxf(tot, 1.0)
		var z := hmax * sin(PI * f) if not resta_alta else (hmax * sin(PI * 0.5 * minf(f * 1.6, 1.0)) if i < pv.size() - 1 else 32.0)
		if i == 0:
			z = 0.0
		elif i == pv.size() - 1 and not resta_alta:
			z = 0.0
		if i < altezze.size():
			z = float(altezze[i])
		out.append(Vector3(pv[i].x, pv[i].y, snappedf(z, 1.0)))
	return out

## Interruttori di un punto di un muro: {"id", "indice", "curvo": bool?, "fionda": bool?}; "indice": -1 = tutti i punti.
func _punto(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if not t.is_empty() and t[0] == "rampe":
		return _punto_rampa(desc["rampe"][t[1]], c)
	if not t.is_empty() and t[0] == "nastri":
		return _punto_nastro(desc["nastri"][t[1]], c)
	if t.is_empty() or not t[0] in ["muri", "piani"]:
		return {"ok": false, "messaggio": "Curvo/fionda si usano sui muri e sui piani rialzati"}
	if t[0] == "piani" and c.has("fionda"):
		return {"ok": false, "messaggio": "Il bordo di un piano rialzato non fa da fionda"}
	var e: Dictionary = desc[t[0]][t[1]]
	var n: int = e["controllo"].size()
	var i := int(c.get("indice", -1))
	if i >= n:
		return {"ok": false, "messaggio": "Punto %d inesistente" % i}
	_ricorda()
	var indici: Array = range(n) if i < 0 else [i]
	var testo: Array = []
	for flag in [["curvo", "curvi"], ["fionda", "fionda"]]:
		if c.has(flag[0]):
			for j in indici:
				e[flag[1]][j] = bool(c[flag[0]])
			testo.append("%s %s" % [flag[0], "sì" if bool(c[flag[0]]) else "no"])
	_fatto()
	return {"ok": true, "messaggio": ("Tutti i punti: " if i < 0 else "Punto %d: " % i) + ", ".join(testo)}

## Punti di un NASTRO: {"indice" (-1 = tutti, "ingresso", "uscita"), "larghezza"?, "altezza"?, "curvo"?}.
func _punto_nastro(e: Dictionary, c: Dictionary) -> Dictionary:
	var n: int = e["controllo"].size()
	var quale = c.get("indice", -1)
	var indici: Array = []
	if str(quale) == "ingresso":
		indici = [0]
	elif str(quale) == "uscita":
		indici = [n - 1]
	elif int(quale) < 0:
		indici = range(n)
	elif int(quale) < n:
		indici = [int(quale)]
	if indici.is_empty():
		return {"ok": false, "messaggio": "Punto inesistente"}
	_ricorda()
	var testo: Array = []
	if c.has("larghezza"):
		for j in indici:
			e["larghezze"][j] = clampf(float(c["larghezza"]), 20.0, 200.0)
		testo.append("larghezza %.0f mm" % clampf(float(c["larghezza"]), 20.0, 200.0))
	if c.has("altezza"):
		for j in indici:
			e["altezze"][j] = clampf(float(c["altezza"]), 0.0, 120.0)
		testo.append("altezza %.0f mm" % clampf(float(c["altezza"]), 0.0, 120.0))
	if c.has("curvo"):
		for j in indici:
			e["curvi"][j] = bool(c["curvo"])
		testo.append("curvo " + ("sì" if bool(c["curvo"]) else "no"))
	_fatto()
	var dove := "tutti i punti" if indici.size() > 1 else ("ingresso" if indici[0] == 0 else ("uscita" if indici[0] == n - 1 else "punto %d" % (indici[0] + 1)))
	return {"ok": true, "messaggio": "Nastro, %s: %s" % [dove, ", ".join(testo)]}

# ================================================================ GRUPPI CON NOME (v0.16)
## Solo per l'editor (desc["gruppi_editor"] = {nome: [id]}): un clic su un pezzo del gruppo sceglie tutto il gruppo
## (Alt+clic = il pezzo da solo). Non c'entra con il campo «gruppo» dei bersagli e delle corsie (regole del gioco).
func gruppi_editor() -> Dictionary:
	var g = desc.get("gruppi_editor", {})
	if not g is Dictionary:
		return {}
	var out := {}
	for n in g:
		var vivi: Array = (g[n] as Array).filter(func(i): return not trova(str(i)).is_empty())
		if vivi.size() >= 2:
			out[n] = vivi
	return out

func gruppo_di(id: String) -> String:
	var g := gruppi_editor()
	for n in g:
		if id in g[n]:
			return n
	return ""

func _gruppo_nome(c: Dictionary) -> Dictionary:
	var az := str(c.get("azione", "crea"))
	var nome := str(c.get("nome", "")).strip_edges()
	if not desc.get("gruppi_editor") is Dictionary:
		desc["gruppi_editor"] = {}
	var g: Dictionary = desc["gruppi_editor"]
	match az:
		"crea":
			var ids: Array = (c.get("ids", []) as Array).map(func(x): return str(x)).filter(func(i): return not trova(i).is_empty())
			if ids.size() < 2:
				return {"ok": false, "messaggio": "Per un gruppo servono almeno 2 pezzi"}
			if nome == "":
				var k := 1
				while g.has("Gruppo %d" % k):
					k += 1
				nome = "Gruppo %d" % k
			_ricorda()
			for n in g.keys():
				g[n] = (g[n] as Array).filter(func(i): return not i in ids)
				if (g[n] as Array).size() < 2:
					g.erase(n)
			g[nome] = ids
			_fatto()
			return {"ok": true, "messaggio": "Gruppo «%s»: %d pezzi" % [nome, ids.size()], "nome": nome}
		"sciogli":
			if not g.has(nome):
				return {"ok": false, "messaggio": "Non trovo il gruppo " + nome}
			_ricorda()
			g.erase(nome)
			_fatto()
			return {"ok": true, "messaggio": "Gruppo «%s» sciolto (i pezzi restano)" % nome}
		"rinomina":
			var nuovo := str(c.get("nuovo", "")).strip_edges()
			if not g.has(nome) or nuovo == "" or g.has(nuovo):
				return {"ok": false, "messaggio": "Nome non valido o già usato"}
			_ricorda()
			g[nuovo] = g[nome]
			g.erase(nome)
			_fatto()
			return {"ok": true, "messaggio": "Gruppo rinominato: " + nuovo}
	return {"ok": false, "messaggio": "Azione sconosciuta"}

# ================================================================ COLLEZIONE e ZONE (v0.14)
## {"comando": "collezione", "azione": aggiungi|togli|imposta|nome|premio, "indice", "nome", "rarita" (1-3), "punti",
##   "evolve_in" (id di un altro oggetto, "" = nessuna), "evolve_dopo" (catture)}
## {"comando": "zone", "azione": aggiungi|togli|imposta, "indice", "nome", "nome_en"}
func _collezione_zone(c: Dictionary) -> Dictionary:
	var az := str(c.get("azione", "aggiungi"))
	_ricorda()
	if c["comando"] == "collezione":
		if not desc.get("collezione") is Dictionary:
			desc["collezione"] = {"nome": "Collezione", "oggetti": [], "premio_completa": 1000000}
		var col: Dictionary = desc["collezione"]
		var ogg: Array = col["oggetti"]
		var k := int(c.get("indice", ogg.size() - 1))
		match az:
			"nome":
				col["nome"] = str(c.get("nome", "Collezione"))
			"premio":
				col["premio_completa"] = int(c.get("punti", 1000000))
			"aggiungi":
				var n := ogg.size() + 1
				while ogg.any(func(o): return str(o.get("id", "")) == "ogg_%d" % n):
					n += 1
				ogg.append({"id": "ogg_%d" % n, "nome": str(c.get("nome", "Oggetto %d" % n)), "rarita": clampi(int(c.get("rarita", 1)), 1, 3), "punti": int(c.get("punti", 10000))})
			"togli", "imposta":
				if k < 0 or k >= ogg.size():
					_annulla.pop_back()
					return {"ok": false, "messaggio": "Oggetto %d inesistente" % (k + 1)}
				if az == "togli":
					var tolto := str(ogg[k].get("id", ""))
					ogg.remove_at(k)
					for o in ogg:
						if str(o.get("evolve_in", "")) == tolto:
							o.erase("evolve_in")
				else:
					for f in ["nome", "rarita", "punti"]:
						if c.has(f):
							ogg[k][f] = str(c[f]) if f == "nome" else (clampi(int(c[f]), 1, 3) if f == "rarita" else int(c[f]))
					# v0.17.2 evoluzioni: "evolve_in" = id di un altro oggetto ("" = nessuna), "evolve_dopo" = catture
					if c.has("evolve_in"):
						var dest := str(c["evolve_in"])
						if dest == "" or dest == str(ogg[k].get("id", "")):
							ogg[k].erase("evolve_in")
						elif ogg.any(func(o): return str(o.get("id", "")) == dest):
							ogg[k]["evolve_in"] = dest
							ogg[k]["evolve_dopo"] = int(ogg[k].get("evolve_dopo", 3))
					if c.has("evolve_dopo"):
						ogg[k]["evolve_dopo"] = clampi(int(c["evolve_dopo"]), 1, 20)
		_fatto()
		return {"ok": true, "messaggio": "Collezione «%s»: %d oggetti" % [col["nome"], ogg.size()]}
	if not desc.get("zone") is Array:
		desc["zone"] = []
	var zz: Array = desc["zone"]
	var kz := int(c.get("indice", zz.size() - 1))
	match az:
		"aggiungi":
			zz.append({"nome": str(c.get("nome", "Zona %d" % (zz.size() + 1)))})
		"togli", "imposta":
			if kz < 0 or kz >= zz.size():
				_annulla.pop_back()
				return {"ok": false, "messaggio": "Zona %d inesistente" % (kz + 1)}
			if az == "togli":
				zz.remove_at(kz)
			else:
				for f in ["nome", "nome_en"]:
					if c.has(f):
						zz[kz][f] = str(c[f])
	_fatto()
	return {"ok": true, "messaggio": "%d zone: %s" % [zz.size(), ", ".join(zz.map(func(z): return str(z.get("nome", ""))))]}

# ================================================================ MENU DEL GIOCO (v0.14)
## desc["menu"]: titolo, col_a, col_b, col_fondo, col_pannello, col_testo, regole, missioni, crediti, pagine[{titolo, testo}].
## Valore vuoto = come prima (menu di oggi). Le voci del menu comune non si tolgono mai.
const CAMPI_MENU := ["titolo", "col_a", "col_b", "col_fondo", "col_pannello", "col_testo", "regole", "missioni", "crediti", "font", "font_titolo"]

## v0.21: font di menu e tabellone. "sans"/"serif" = quelli dell'editor (liberi, OFL); gli altri si importano
## (TTF/OTF) e restano DENTRO il tavolo (desc["font_file"]), così viaggiano con l'esportazione.
const FONT_PRONTI := {"": "Predefinito", "sans": "Noto Sans (dritto, pulito)", "serif": "Noto Serif (con grazie, da titolo)"}

func _importa_font(c: Dictionary) -> Dictionary:
	var f := str(c.get("file", ""))
	var est := f.get_extension().to_lower()
	if not FileAccess.file_exists(f) or not est in ["ttf", "otf"]:
		return {"ok": false, "messaggio": "Serve un file di font .ttf o .otf"}
	var dati := FileAccess.get_file_as_bytes(f)
	if dati.size() > 3 * 1024 * 1024:
		return {"ok": false, "messaggio": "Font troppo pesante (più di 3 MB)"}
	var prova := FontFile.new()
	prova.data = dati
	if prova.get_string_size("Prova", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= 0.0:
		return {"ok": false, "messaggio": "Non riesco a leggere questo font"}
	var nome := f.get_file().get_basename().validate_filename()
	_ricorda()
	if not desc.get("font_file") is Dictionary:
		desc["font_file"] = {}
	desc["font_file"][nome] = Marshalls.raw_to_base64(dati)
	if not desc.get("menu") is Dictionary:
		desc["menu"] = {}
	var dove := str(c.get("per", "font"))
	if dove in ["font", "font_titolo"]:
		desc["menu"][dove] = nome
	_fatto()
	return {"ok": true, "messaggio": "Font «%s» importato. Ricorda di dichiarare la licenza (📜 Licenze): i font di terzi servono con licenza commerciale scritta." % nome, "nome": nome}

func _imposta_tabellone(c: Dictionary) -> Dictionary:
	_ricorda()
	if not desc.get("tabellone") is Dictionary:
		desc["tabellone"] = {}
	if c.has("altezza"):
		desc["tabellone"]["altezza"] = clampf(float(c.get("altezza", 150.0)), 90.0, 220.0)
	if c.has("scritte"):
		desc["tabellone"]["scritte"] = "centro" if str(c["scritte"]) == "centro" else "alto"
		_fatto()
		return {"ok": true, "messaggio": "Scritte grandi del gioco: " + ("in mezzo al tavolo (come prima)" if desc["tabellone"]["scritte"] == "centro" else "dentro il tabellone (non coprono il tavolo)")}
	_fatto()
	return {"ok": true, "messaggio": "Tabellone alto %d (prima 150): il tavolo si rimpicciolisce o si allarga per starci sotto" % int(desc["tabellone"]["altezza"])}

func _menu_cmd(c: Dictionary) -> Dictionary:
	if not desc.get("menu") is Dictionary:
		desc["menu"] = {}
	var m: Dictionary = desc["menu"]
	if c["comando"] == "imposta_menu":
		var campo := str(c.get("campo", ""))
		if not campo in CAMPI_MENU:
			return {"ok": false, "messaggio": "Campo del menu sconosciuto: " + campo}
		var v = c.get("valore")
		_ricorda()
		if v == null or (v is String and v == ""):
			m.erase(campo)
		elif campo.begins_with("col_"):
			m[campo] = v if v is Color else (Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0) if v is Array else Color(str(v)))
		else:
			m[campo] = str(v)
		_fatto()
		return {"ok": true, "messaggio": "Menu: %s %s" % [campo, "come prima" if not m.has(campo) else "cambiato"]}
	var pagine: Array = m.get("pagine", [])
	var az := str(c.get("azione", "aggiungi"))
	var k := int(c.get("indice", pagine.size() - 1))
	if az != "aggiungi" and (k < 0 or k >= pagine.size()):
		return {"ok": false, "messaggio": "Pagina %d inesistente" % (k + 1)}
	_ricorda()
	match az:
		"aggiungi":
			pagine.append({"titolo": str(c.get("titolo", "Pagina %d" % (pagine.size() + 1))), "testo": str(c.get("testo", ""))})
		"togli":
			pagine.remove_at(k)
		"imposta":
			for f in ["titolo", "testo"]:
				if c.has(f):
					pagine[k][f] = str(c[f])
	m["pagine"] = pagine
	_fatto()
	return {"ok": true, "messaggio": "Menu: %d pagine in più" % pagine.size()}

## Testo della pagina MISSIONI scritto dalle missioni del tavolo (per il menu).
func testo_missioni_menu() -> String:
	var righe: Array = []
	for m in desc.get("missioni", []):
		if bool(m.get("attiva", true)):
			var f: Array = m.get("fasi", [])
			righe.append("%s%s – %s" % [str(m.get("nome", "")).to_upper(), " (MODALITÀ)" if int(m.get("priorita", 0)) > 0 else "", Mattoncini.descrivi_fase(f[0]) if not f.is_empty() else ""])
	return "\n".join(righe)

# ================================================================ MUSICA DEL TAVOLO (v0.12)
## {"ruolo": "main"|"multiball"|"attract"|"missione", "id" (missione), "file": percorso} · {"ruolo", "togli": true}
const RUOLI_MUSICA := {"main": "in gioco", "multiball": "multiball", "attract": "attesa (fuori partita)"}

func _musica_cmd(c: Dictionary) -> Dictionary:
	var ruolo := str(c.get("ruolo", "main"))
	var mi := indice_missione(str(c.get("id", ""))) if ruolo == "missione" else -1
	if ruolo == "missione" and mi < 0:
		return {"ok": false, "messaggio": "Non trovo la missione " + str(c.get("id", ""))}
	if ruolo != "missione" and not RUOLI_MUSICA.has(ruolo):
		return {"ok": false, "messaggio": "Ruolo della musica sconosciuto: " + ruolo}
	var nome := ""
	if not bool(c.get("togli", false)):
		if cartella == "":
			return {"ok": false, "messaggio": "Salva prima il tavolo: la musica va nella sua cartella"}
		var f := str(c.get("file", ""))
		if not FileAccess.file_exists(f) or not f.get_extension().to_lower() in ["ogg", "mp3", "wav"]:
			return {"ok": false, "messaggio": "File musicale non valido (ogg, mp3 o wav): " + f}
		DirAccess.make_dir_recursive_absolute(cartella.path_join("musica"))
		nome = f.get_file()
		if DirAccess.copy_absolute(f, cartella.path_join("musica").path_join(nome)) != OK:
			return {"ok": false, "messaggio": "Non riesco a copiare la canzone"}
	_ricorda()
	if ruolo == "missione":
		desc["missioni"][mi]["musica"] = nome
	else:
		if not desc.get("musica") is Dictionary:
			desc["musica"] = {}
		desc["musica"][ruolo] = nome
	_fatto()
	var dove: String = ("missione «%s»" % desc["missioni"][mi].get("nome", "")) if ruolo == "missione" else RUOLI_MUSICA[ruolo]
	return {"ok": true, "messaggio": ("Musica %s: %s" % [dove, nome]) if nome != "" else "Musica %s tolta" % dove}

# ================================================================ MISSIONI A MATTONCINI (v0.10)
## Le missioni stanno nel file del tavolo (desc["missioni"]); il gioco le fa avanzare con Mattoncini (motore).
## Valgono per i tavoli con le regole di base (tutti quelli nuovi); il tavolo Space d'esempio usa le sue regole.
func missioni_valgono() -> bool:
	return str(desc.get("regole", FileTavolo.REGOLE_BASE)) == FileTavolo.REGOLE_BASE

func indice_missione(id: String) -> int:
	var l: Array = desc.get("missioni", []) if desc.get("missioni") is Array else []
	for i in l.size():
		if str(l[i].get("id", "")) == id:
			return i
	return -1

func _nuovo_id_missione() -> String:
	var n := 1
	while indice_missione("missione_%d" % n) >= 0:
		n += 1
	return "missione_%d" % n

func _missioni_cmd(c: Dictionary) -> Dictionary:
	if not desc.get("missioni") is Array:
		desc["missioni"] = []
	var l: Array = desc["missioni"]
	var cmd := str(c["comando"])
	if cmd == "missione_aggiungi":
		var m: Dictionary = {}
		if c.get("missione") is Dictionary:
			m = c["missione"].duplicate(true)
		elif str(c.get("modello", "")) != "":
			m = ModelliMissioni.crea(str(c["modello"]), desc)
			if m.has("errore"):
				return {"ok": false, "messaggio": "Modello «%s»: %s" % [c["modello"], m["errore"]]}
		else:
			m = {"nome": "Missione nuova", "attiva": true, "ripeti": true, "fasi": [{"quando": {"tipo": "bumper"}, "volte": 5}], "premio": {"punti": 25000}}
		m["id"] = str(c.get("id", _nuovo_id_missione()))
		if indice_missione(m["id"]) >= 0:
			return {"ok": false, "messaggio": "Esiste già una missione " + m["id"]}
		_ricorda()
		l.append(m)
		_fatto()
		return {"ok": true, "messaggio": "Missione «%s» aggiunta" % m.get("nome", m["id"]), "id": m["id"]}
	if cmd == "missione_duplica":
		# v0.18.3: copia di una missione (subito dopo l'originale), con id nuovo e «(copia)» nel nome
		var io := indice_missione(str(c.get("id", "")))
		if io < 0:
			return {"ok": false, "messaggio": "Non trovo la missione " + str(c.get("id", ""))}
		var cp: Dictionary = (l[io] as Dictionary).duplicate(true)
		cp["id"] = _nuovo_id_missione()
		cp["nome"] = str(cp.get("nome", "Missione")) + " (copia)"
		if str(cp.get("nome_en", "")) != "":
			cp["nome_en"] = str(cp["nome_en"]) + " (copy)"
		_ricorda()
		l.insert(io + 1, cp)
		_fatto()
		return {"ok": true, "messaggio": "Missione duplicata: «%s»" % cp["nome"], "id": cp["id"]}
	if cmd == "missioni_pacchetto":
		# tutti i modelli che il tavolo permette, in ordine; la modalità finale chiede tutte le altre (max 6)
		_ricorda()
		var aggiunte: Array = []
		for v in ModelliMissioni.ELENCO:
			if v[0] == "wizard":
				continue
			var m2 := ModelliMissioni.crea(v[0], desc)
			if not m2.has("errore"):
				m2["id"] = _nuovo_id_missione()
				l.append(m2)
				aggiunte.append(m2["nome"])
		var w := ModelliMissioni.crea("wizard", desc)
		w["id"] = _nuovo_id_missione()
		w["sblocco"] = {"completate": mini(6, l.size())}
		l.append(w)
		aggiunte.append(w["nome"])
		_fatto()
		return {"ok": true, "messaggio": "%d missioni aggiunte: %s" % [aggiunte.size(), ", ".join(aggiunte)]}
	if cmd == "missioni_avvio":
		_ricorda()
		desc["missioni_avvio"] = {"tipo": str(c.get("tipo", "subito")), "id": str(c.get("id", "")), "scelta": bool(c.get("scelta", false))}
		_fatto()
		return {"ok": true, "messaggio": "Le missioni partono: " + ("da sole" if str(c.get("tipo", "subito")) == "subito" else "con un tiro in " + (str(c.get("id", "")) if str(c.get("id", "")) != "" else str(c["tipo"])))}
	var i := indice_missione(str(c.get("id", "")))
	if i < 0:
		return {"ok": false, "messaggio": "Non trovo la missione " + str(c.get("id", ""))}
	var mm: Dictionary = l[i]
	match cmd:
		"missione_togli":
			_ricorda()
			l.remove_at(i)
			_fatto()
			return {"ok": true, "messaggio": "Missione «%s» tolta" % mm.get("nome", "")}
		"missione_sposta":
			var j := clampi(i + int(c.get("di", 1)), 0, l.size() - 1)
			if j == i:
				return {"ok": false, "messaggio": "È già in fondo / in cima"}
			_ricorda()
			l.remove_at(i)
			l.insert(j, mm)
			_fatto()
			return {"ok": true, "messaggio": "«%s» ora è la numero %d" % [mm.get("nome", ""), j + 1]}
		"missione_fase":
			var fasi: Array = mm.get("fasi", [])
			_ricorda()
			if str(c.get("azione", "aggiungi")) == "togli":
				var k := int(c.get("indice", fasi.size() - 1))
				if fasi.size() <= 1 or k < 0 or k >= fasi.size():
					_annulla.pop_back()
					return {"ok": false, "messaggio": "Una missione ha almeno una fase"}
				fasi.remove_at(k)
			else:
				fasi.append({"quando": {"tipo": "bumper"}, "volte": 3})
			mm["fasi"] = fasi
			_fatto()
			return {"ok": true, "messaggio": "Missione «%s»: %d fasi" % [mm.get("nome", ""), fasi.size()]}
		"missione_imposta":
			# campo con i punti: "nome", "premio.punti", "fasi.0.quando.tipo", "sblocco.completate"…
			# v0.18.3: "energia.attiva" true/false crea o toglie l'energia della missione
			if str(c.get("campo", "")) == "energia.attiva":
				_ricorda()
				if bool(c.get("valore", false)):
					mm["energia"] = {"luci": 6, "cala": 4.0, "ricarica": {"tipo": "bumper"}}
				else:
					mm.erase("energia")
				_fatto()
				return {"ok": true, "messaggio": "Energia " + ("attiva: 6 luci, una ogni 4 s, si ricarica con i bumper" if mm.has("energia") else "tolta")}
			var parti := str(c.get("campo", "")).split(".")
			if parti.is_empty() or parti[0] == "" or parti[0] == "id":
				return {"ok": false, "messaggio": "Campo non valido"}
			_ricorda()
			var cur = mm
			for k2 in range(parti.size() - 1):
				var p2 := parti[k2]
				var dopo := parti[k2 + 1]
				if cur is Array:
					cur = cur[int(p2)]
				else:
					if not cur.has(p2) or (dopo.is_valid_int() and not cur[p2] is Array) or (not dopo.is_valid_int() and not cur[p2] is Dictionary):
						cur[p2] = [] if dopo.is_valid_int() else {}
					cur = cur[p2]
			var ultimo := parti[parti.size() - 1]
			var v = c.get("valore")
			if cur is Array:
				cur[int(ultimo)] = v
			elif v == null or (v is String and v == "" and ultimo in ["id", "gruppo", "dopo"]):
				cur[ultimo] = ""
			else:
				cur[ultimo] = v
			_fatto()
			return {"ok": true, "messaggio": "%s: %s = %s" % [mm.get("nome", ""), c.get("campo"), str(v)]}
	return {"ok": false, "messaggio": "Comando sconosciuto"}

# ================================================================ LIVELLI CON NOME (v0.9.4, 24/11)
## Livello 0 = il tavolo; 1, 2, … = i piani rialzati (il nome è quello del piano). Nell'editor ogni livello si può
## NASCONDERE (occhio) o BLOCCARE (lucchetto: i suoi pezzi non si scelgono né si spostano). È solo una comodità
## dell'editor (desc["editor_livelli"]): nel gioco non cambia niente.
static func livello_di(k: String, e: Dictionary) -> int:
	return int(e.get("livello", 0)) if e is Dictionary else 0

func stato_livello(n: int) -> Dictionary:
	var ev = desc.get("editor_livelli", {})
	return ev.get(n, {}) if ev is Dictionary and ev.get(n, {}) is Dictionary else {}

func livello_nascosto(n: int) -> bool:
	return bool(stato_livello(n).get("nascosto", false))

func livello_bloccato(n: int) -> bool:
	return bool(stato_livello(n).get("bloccato", false)) or livello_nascosto(n)

## Elenco dei livelli: [{livello, nome, altezza, piano (id o ""), pezzi, nascosto, bloccato}].
func elenco_livelli() -> Array:
	var out: Array = [{"livello": 0, "nome": "Tavolo", "altezza": 0.0, "piano": "", "pezzi": 0}]
	for p in desc.get("piani", []):
		if p is Dictionary and p.has("id"):
			out.append({"livello": int(p.get("livello", 1)), "nome": str(p.get("nome", "Piano")), "altezza": float(p.get("altezza", 40.0)), "piano": p["id"], "pezzi": 0})
	for v in elenco():
		var n := livello_di(v["tipo"], pezzo(v["id"]))
		if v["tipo"] == "piani":
			continue
		if not out.any(func(x): return x["livello"] == n):
			out.append({"livello": n, "nome": "Livello %d (importato)" % n, "altezza": 0.0, "piano": "", "pezzi": 0})
		for l in out:
			if l["livello"] == n:
				l["pezzi"] += 1
	for l in out:
		l["nascosto"] = livello_nascosto(l["livello"])
		l["bloccato"] = bool(stato_livello(l["livello"]).get("bloccato", false))
	return out

## {"livello": n, "nascosto"?: bool, "bloccato"?: bool, "nome"?: testo (solo i piani)}.
func _livello_vista(c: Dictionary) -> Dictionary:
	var n := int(c.get("livello", -1))
	var l: Dictionary = {}
	for x in elenco_livelli():
		if x["livello"] == n:
			l = x
	if l.is_empty():
		return {"ok": false, "messaggio": "Livello %d inesistente" % n}
	if c.has("nome"):
		if l["piano"] == "":
			return {"ok": false, "messaggio": "Il livello 0 è il tavolo: il nome si dà ai piani rialzati"}
		return _imposta({"id": l["piano"], "campo": "nome", "valore": str(c["nome"])})
	if not desc.get("editor_livelli") is Dictionary:
		desc["editor_livelli"] = {}
	var st: Dictionary = desc["editor_livelli"].get(n, {})
	var testo: Array = []
	for k in ["nascosto", "bloccato"]:
		if c.has(k):
			st[k] = bool(c[k])
			testo.append(("nascosto" if st[k] else "visibile") if k == "nascosto" else ("bloccato" if st[k] else "sbloccato"))
	desc["editor_livelli"][n] = st
	modificato = true
	cambiato.emit()
	return {"ok": true, "messaggio": "Livello «%s»: %s" % [l["nome"], ", ".join(testo)]}

## Altezza dei punti di una rampa: {"indice", "altezza"} oppure {"profilo": "sale_scende" | "resta_alta", "altezza_max"}.
func _punto_rampa(e: Dictionary, c: Dictionary) -> Dictionary:
	var pts: Array = e["punti"]
	_ricorda()
	if c.has("profilo"):
		var pv := PackedVector2Array()
		for q in pts:
			pv.append(Vector2(q.x, q.y))
		e["punti"] = profilo_rampa(pv, [], float(c.get("altezza_max", 45.0)), str(c["profilo"]) == "resta_alta")
		_fatto()
		return {"ok": true, "messaggio": "Profilo della rampa: " + ("sale e resta in alto (uscita sospesa)" if str(c["profilo"]) == "resta_alta" else "sale e riscende a terra")}
	if c.has("altezza_tutta"):
		# 24/11 (come «altezza di tutto il nastro»): la rampa tiene la sua forma, cambia solo quanto sale in alto
		var hv := clampf(float(c["altezza_tutta"]), 5.0, 120.0)
		var hmax := 0.0
		for q in pts:
			hmax = maxf(hmax, float(q.z))
		if hmax < 0.5:
			var pv0 := PackedVector2Array()
			for q in pts:
				pv0.append(Vector2(q.x, q.y))
			e["punti"] = profilo_rampa(pv0, [], hv, false)
		else:
			var nuovi: Array = []
			for q in pts:
				nuovi.append(Vector3(q.x, q.y, snappedf(float(q.z) * hv / hmax, 1.0)))
			e["punti"] = nuovi
		_fatto()
		return {"ok": true, "messaggio": "Rampa: punto più alto a %.0f mm (gli altri in proporzione)" % hv}
	if c.has("imbocco"):
		# larghezza dell'imbocco (a terra): il motore la usa davvero ("invito" = mezza larghezza)
		e["invito"] = clampf(float(c["imbocco"]), 38.0, 90.0) * 0.5
		_fatto()
		return {"ok": true, "messaggio": "Rampa: imbocco largo %.0f mm" % (float(e["invito"]) * 2.0)}
	var i := int(c.get("indice", -1))
	if i < 0 or i >= pts.size() or not c.has("altezza"):
		_annulla.pop_back()
		return {"ok": false, "messaggio": "Scegli un punto della rampa"}
	pts[i] = Vector3(pts[i].x, pts[i].y, clampf(float(c["altezza"]), 0.0, 120.0))
	e["punti"] = pts
	_fatto()
	return {"ok": true, "messaggio": "Punto %d della rampa: altezza %.0f mm" % [i + 1, pts[i].z]}

## Ruota di N gradi: cambia "angolo" se il pezzo lo ha, altrimenti ruota i punti intorno al centro.
func _ruota(c: Dictionary) -> Dictionary:
	var t := trova(str(c.get("id", "")))
	if t.is_empty():
		return {"ok": false, "messaggio": "Non trovo il pezzo"}
	var e: Dictionary = desc[t[0]][t[1]]
	var a := deg_to_rad(float(c.get("gradi", 15.0)))
	_ricorda()
	if e.has("angolo"):
		e["angolo"] = float(e["angolo"]) + a
	elif SchedeEditor.campo_punti(t[0]) != "":
		var cc := centro(t[0], e)
		var k := SchedeEditor.campo_punti(t[0])
		var pts = e[k]
		for i in pts.size():
			var q := (Vector2(pts[i].x, pts[i].y) - cc).rotated(a) + cc
			pts[i] = Vector3(q.x, q.y, pts[i].z) if pts[i] is Vector3 else q
		e[k] = pts
	else:
		_annulla.pop_back()
		return {"ok": false, "messaggio": "Questo pezzo non ha una rotazione"}
	_fatto()
	return {"ok": true, "messaggio": "Ruotato di %.0f°" % rad_to_deg(a)}

func _fatto() -> void:
	CurveEditor.prepara_tavolo(desc)
	modificato = true
	cambiato.emit()

## Il trascinamento col mouse modifica il tavolo dal vivo: prima si chiama questo (una sola voce di annulla).
func inizia_trascinamento() -> void:
	_ricorda()

func fine_trascinamento() -> void:
	_fatto()

# ================================================================ conversioni (comandi dell'AI arrivano in JSON)
func _converti(chiave: String, campo: String, v):
	var tipo := ""
	for f in SchedeEditor.campi(chiave):
		if f["k"] == campo:
			tipo = f["tipo"]
	match tipo:
		"vec":
			return _vec(v)
		"num":
			return float(v)
		"int":
			return int(v)
		"bool":
			return bool(v)
		"angolo":
			return float(v)
		"colore":
			if v is Color:
				return v
			if v is Array:
				return Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0)
			return Color(str(v))
	return v

static func _vec(v) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Dictionary:
		return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
	return Vector2.ZERO

static func _vec_testo(v: Vector2) -> String:
	return "%.0f × %.0f" % [v.x, v.y]

func _diario(chi: String, c: Dictionary, r: Dictionary) -> void:
	if cartella == "" or str(c.get("comando", "")) in ["stato", "elenco"]:
		return
	var f := FileAccess.open(cartella.path_join("diario.txt"), FileAccess.READ_WRITE if FileAccess.file_exists(cartella.path_join("diario.txt")) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("%s\t%s\t%s\t%s" % [Time.get_datetime_string_from_system(), chi, JSON.stringify(c), str(r.get("messaggio", ""))])
		f.close()

# ================================================================ SPETTACOLI DI LUCE e ATTESA (v0.17)
## {"comando": "spettacolo", "nome", "azione": "nuovo"|"pronto"|"togli"|"rinomina", "da"?: pronto, "nuovo_nome"?}
## {"comando": "spettacolo_passo", "nome", "azione": "aggiungi"|"togli"|"imposta", "indice"?, "dopo"?, "effetto"?,
##   "colore"?, "dur"?, "verso"?, "grande"?}
## {"comando": "attesa", "spettacolo"?, "pausa"?, "scritta"?}
const CAMPI_PASSO := ["dopo", "effetto", "colore", "dur", "verso", "grande"]

func _spettacoli_cmd(c: Dictionary) -> Dictionary:
	if not desc.get("spettacoli") is Dictionary:
		desc["spettacoli"] = {}
	var sp: Dictionary = desc["spettacoli"]
	var nome := str(c.get("nome", "")).strip_edges()
	match str(c["comando"]):
		"attesa":
			var att: Dictionary = (desc.get("attesa", {}) as Dictionary).duplicate() if desc.get("attesa") is Dictionary else {}
			if c.has("spettacolo"):
				var n := str(c["spettacolo"])
				if n != "" and not sp.has(n) and not RegiaDati.SPETTACOLI_PRONTI.has(n):
					return {"ok": false, "messaggio": "Spettacolo sconosciuto: " + n}
				att["spettacolo"] = n
			if c.has("pausa"):
				att["pausa"] = clampf(float(c["pausa"]), 0.0, 30.0)
			if c.has("scritta"):
				att["scritta"] = str(c["scritta"]).substr(0, 40)
			_ricorda()
			desc["attesa"] = att
			_fatto()
			return {"ok": true, "messaggio": "Attesa in sala: %s, pausa %.1f s%s" % [("spettacolo «%s»" % att["spettacolo"]) if str(att.get("spettacolo", "")) != "" else "luci di base",
				float(att.get("pausa", 1.0)), (", scritta «%s»" % att["scritta"]) if str(att.get("scritta", "")) != "" else ""]}
		"spettacolo":
			var az := str(c.get("azione", "nuovo"))
			if az == "pronto":
				var da := str(c.get("da", ""))
				if not RegiaDati.SPETTACOLI_PRONTI.has(da):
					return {"ok": false, "messaggio": "Spettacolo pronto sconosciuto: " + da}
				if nome == "":
					nome = da
				_ricorda()
				sp[_nome_libero(sp, nome)] = {"passi": (RegiaDati.SPETTACOLI_PRONTI[da] as Array).duplicate(true)}
				_fatto()
				return {"ok": true, "messaggio": "Spettacolo copiato da «%s»" % da}
			if az == "nuovo":
				_ricorda()
				var n2 := _nome_libero(sp, nome if nome != "" else "Spettacolo")
				sp[n2] = {"passi": [{"dopo": 0.0, "effetto": "spazzata", "colore": "caldo", "dur": 0.8, "verso": "su"}]}
				_fatto()
				return {"ok": true, "messaggio": "Spettacolo nuovo: «%s»" % n2, "nome": n2}
			if not sp.has(nome):
				return {"ok": false, "messaggio": "Spettacolo sconosciuto: " + nome}
			if az == "togli":
				_ricorda()
				sp.erase(nome)
				_riferimenti_spettacolo(nome, "")
				_fatto()
				return {"ok": true, "messaggio": "Spettacolo tolto: «%s» (gli eventi che lo usavano tornano come prima)" % nome}
			if az == "rinomina":
				var nn := str(c.get("nuovo_nome", "")).strip_edges()
				if nn == "" or sp.has(nn):
					return {"ok": false, "messaggio": "Nome non valido o già usato: " + nn}
				_ricorda()
				sp[nn] = sp[nome]
				sp.erase(nome)
				_riferimenti_spettacolo(nome, nn)
				_fatto()
				return {"ok": true, "messaggio": "Spettacolo rinominato: «%s»" % nn}
			return {"ok": false, "messaggio": "Azione sconosciuta: " + az}
		"spettacolo_passo":
			if not sp.has(nome):
				return {"ok": false, "messaggio": "Spettacolo sconosciuto: " + nome}
			var passi: Array = sp[nome]["passi"]
			var az := str(c.get("azione", "aggiungi"))
			var i := int(c.get("indice", passi.size() - 1))
			if az == "aggiungi":
				if passi.size() >= 24:
					return {"ok": false, "messaggio": "Al massimo 24 passi per spettacolo (luci leggere per il Raspberry Pi)"}
				_ricorda()
				var dopo := RegiaDati.durata_spettacolo(passi) if not passi.is_empty() else 0.0
				var nuovo := {"dopo": snappedf(dopo, 0.05), "effetto": "onda_grande", "colore": "freddo", "dur": 0.8}
				for k in CAMPI_PASSO:
					if c.has(k):
						nuovo[k] = c[k]
				passi.append(_passo_pulito(nuovo))
				_fatto()
				return {"ok": true, "messaggio": "Passo %d aggiunto a «%s» (dura in tutto %.1f s)" % [passi.size(), nome, RegiaDati.durata_spettacolo(passi)]}
			if i < 0 or i >= passi.size():
				return {"ok": false, "messaggio": "Passo inesistente: %d" % (i + 1)}
			_ricorda()
			if az == "togli":
				passi.remove_at(i)
			elif az == "imposta":
				var p: Dictionary = passi[i]
				for k in CAMPI_PASSO:
					if c.has(k):
						p[k] = c[k]
				passi[i] = _passo_pulito(p)
			else:
				return {"ok": false, "messaggio": "Azione sconosciuta: " + az}
			_fatto()
			return {"ok": true, "messaggio": "«%s»: %d passi, %.1f s" % [nome, passi.size(), RegiaDati.durata_spettacolo(passi)]}
	return {"ok": false, "messaggio": "Comando sconosciuto"}

func _passo_pulito(p: Dictionary) -> Dictionary:
	var e := str(p.get("effetto", "onda"))
	var out := {"dopo": clampf(float(p.get("dopo", 0.0)), 0.0, 30.0),
		"effetto": e if RegiaDati.EFFETTI_PASSO.has(e) else "onda",
		"colore": str(p.get("colore", "caldo")) if RegiaDati.COLORI.has(str(p.get("colore", ""))) else "caldo",
		"dur": clampf(float(p.get("dur", 0.6)), 0.05, 10.0)}
	if out["effetto"] == "spazzata":
		out["verso"] = "giu" if str(p.get("verso", "su")) == "giu" else "su"
	if bool(p.get("grande", false)):
		out["grande"] = true
	return out

func _nome_libero(sp: Dictionary, base: String) -> String:
	if not sp.has(base):
		return base
	var k := 2
	while sp.has("%s %d" % [base, k]):
		k += 1
	return "%s %d" % [base, k]

## Uno spettacolo tolto o rinominato: aggiorna eventi, attesa e azioni delle missioni che lo usavano.
func _riferimenti_spettacolo(vecchio: String, nuovo: String) -> void:
	var le = desc.get("luci_eventi", {})
	if le is Dictionary:
		for ev in le.keys():
			if str(le[ev].get("effetto", "")) == "spettacolo:" + vecchio:
				if nuovo == "":
					le.erase(ev)
				else:
					le[ev]["effetto"] = "spettacolo:" + nuovo
	if desc.get("attesa") is Dictionary and str(desc["attesa"].get("spettacolo", "")) == vecchio:
		desc["attesa"]["spettacolo"] = nuovo
	_rinomina_in(desc.get("missioni", []), vecchio, nuovo)

func _rinomina_in(x, vecchio: String, nuovo: String) -> void:
	if x is Dictionary:
		for k in x.keys():
			if k == "spettacolo" and str(x[k]) == vecchio:
				x[k] = nuovo
			else:
				_rinomina_in(x[k], vecchio, nuovo)
	elif x is Array:
		for v in x:
			_rinomina_in(v, vecchio, nuovo)

# ================================================================ REGISTRO LICENZE (v0.17.2, Fase 4)
## del tavolo (immagini sui pezzi, fondo, immagini sul piano, musiche) ha una FONTE dichiarata in desc["licenze"]
const FONTI := {"": "DA DICHIARARE", "mia": "fatta da me", "ai": "generata con un servizio di intelligenza artificiale (verifica i termini d'uso)",
	"cc0": "CC0 / pubblico dominio (es. Freesound CC0)", "licenza": "di terzi con licenza commerciale scritta (scrivi dove nella nota)",
	"catalogo": "del catalogo dell'editor (fatta da noi)"}
const FILE_REGISTRO := "LICENZE_GRAFICA_E_MUSICA.md"

## Tutti i file usati dal tavolo: [{chiave, tipo, nome, dove: [...]}].
func asset_usati() -> Array:
	var per := {}
	var imm: Dictionary = desc.get("immagini", {}) if desc.get("immagini") is Dictionary else {}
	for n in imm:
		per["immagine:" + str(n)] = {"chiave": "immagine:" + str(n), "tipo": "immagine", "nome": str(n), "dove": []}
	var f := str(desc.get("fondo", ""))
	if f != "" and per.has("immagine:" + f):
		per["immagine:" + f]["dove"].append("fondo del tavolo")
	for k in PittorePezzi.TIPI + ["decorazioni", "rampe"]:
		for e in desc.get(k, []):
			if PittorePezzi.ha_immagine(e) and per.has("immagine:" + str(e["immagine"]["nome"])):
				per["immagine:" + str(e["immagine"]["nome"])]["dove"].append(str(e.get("id", k)))
	if desc.get("font_file") is Dictionary:
		for n in desc["font_file"]:
			per["font:" + str(n)] = {"chiave": "font:" + str(n), "tipo": "font", "nome": str(n), "dove": ["menu e tabellone"]}
	var mus: Array = []
	if desc.get("musica") is Dictionary:
		for ruolo in desc["musica"]:
			if str(desc["musica"][ruolo]) != "":
				mus.append([str(desc["musica"][ruolo]), "musica " + str(RUOLI_MUSICA.get(ruolo, ruolo))])
	for m in desc.get("missioni", []):
		if m is Dictionary and str(m.get("musica", "")) != "":
			mus.append([str(m["musica"]), "missione " + str(m.get("nome", m.get("id", "")))])
	for x in mus:
		var ch: String = "musica:" + str(x[0])
		if not per.has(ch):
			per[ch] = {"chiave": ch, "tipo": "musica", "nome": x[0], "dove": []}
		per[ch]["dove"].append(x[1])
	var out: Array = per.values()
	out.sort_custom(func(a, b): return a["chiave"] < b["chiave"])
	return out

func fonte_di(chiave: String) -> Dictionary:
	var l = desc.get("licenze", {})
	if l is Dictionary and l.has(chiave) and l[chiave] is Dictionary:
		var v: Dictionary = l[chiave]
		return v
	# fonte predefinita delle musiche: dalla configurazione (config/gioco.cfg, [musica] fonte_musica); "" = da dichiarare
	return {"fonte": str(Parametri.valore("musica", "fonte_musica", "")) if chiave.begins_with("musica:") else "", "nota": ""}

func _licenze_cmd(c: Dictionary) -> Dictionary:
	if c["comando"] == "licenza":
		var ch := str(c.get("chiave", ""))
		if not asset_usati().any(func(a): return a["chiave"] == ch):
			return {"ok": false, "messaggio": "File non usato dal tavolo: " + ch}
		var fo := str(c.get("fonte", fonte_di(ch)["fonte"]))
		if not FONTI.has(fo):
			return {"ok": false, "messaggio": "Fonte sconosciuta: " + fo}
		_ricorda()
		if not desc.get("licenze") is Dictionary:
			desc["licenze"] = {}
		var vecchio: Dictionary = desc["licenze"].get(ch, {}) if desc["licenze"].get(ch) is Dictionary else {}
		var voce := {"fonte": fo, "nota": str(c.get("nota", fonte_di(ch).get("nota", ""))).substr(0, 200)}
		# v0.26: dati completi della risorsa (registro per il rilascio libero)
		for campo in ["autore", "url", "licenza", "modifiche", "limitazioni"]:
			var v = c.get(campo, vecchio.get(campo, ""))
			if str(v) != "":
				voce[campo] = str(v).substr(0, 300)
		if voce.has("licenza") and not LicenzeProgetto.LICENZE.has(voce["licenza"]):
			return {"ok": false, "messaggio": "Licenza sconosciuta: %s (usa una di: %s)" % [voce["licenza"], ", ".join(LicenzeProgetto.LICENZE.keys())]}
		desc["licenze"][ch] = voce
		_fatto()
		return {"ok": true, "messaggio": "%s: %s%s" % [ch.get_slice(":", 1), FONTI[fo], (" · " + str(voce["licenza"])) if voce.has("licenza") else ""]}
	# registro_licenze: scrive il file nella cartella del tavolo
	if cartella == "":
		return {"ok": false, "messaggio": "Salva prima il tavolo: il registro va nella sua cartella"}
	var righe := PackedStringArray(["# Registro licenze – %s" % str(desc.get("titolo", desc.get("nome", "tavolo"))).capitalize(), "",
		"*Scritto dal Pinball Editor 2D il %s. Fonte di ogni immagine e musica del tavolo (regola: niente file di terzi senza licenza commerciale scritta).*" % Time.get_date_string_from_system(), "",
		"| File | Tipo | Dove si usa | Fonte | Nota |", "|---|---|---|---|---|"])
	var mancano := 0
	for a in asset_usati():
		var fo := fonte_di(a["chiave"])
		if str(fo["fonte"]) == "":
			mancano += 1
		righe.append("| %s | %s | %s | %s | %s |" % [a["nome"], a["tipo"], ", ".join(a["dove"]) if not a["dove"].is_empty() else "—", FONTI.get(str(fo["fonte"]), "?"), str(fo.get("nota", "")).replace("|", "/")])
	righe.append("")
	righe.append("Suoni degli effetti: generati dal codice dell'editor o del catalogo del gioco (nessun suono di terzi). Caratteri: Noto (SIL Open Font License).")
	var fa := FileAccess.open(cartella.path_join(FILE_REGISTRO), FileAccess.WRITE)
	if fa == null:
		return {"ok": false, "messaggio": "Non riesco a scrivere il registro"}
	fa.store_string("\n".join(righe) + "\n")
	fa.close()
	return {"ok": true, "messaggio": "Registro scritto: %s (%d file%s)" % [FILE_REGISTRO, asset_usati().size(), (", %d DA DICHIARARE" % mancano) if mancano > 0 else ""]}

## Avvisi per CONTROLLA: file senza fonte dichiarata.
func avvisi_licenze() -> Array:
	var out: Array = []
	for a in asset_usati():
		if str(fonte_di(a["chiave"])["fonte"]) == "":
			out.append("Licenza: «%s» (%s) non ha una fonte dichiarata: pannello del tavolo → LICENZE." % [a["nome"], a["tipo"]])
	return out

# ================================================================ TIRI DI RIFERIMENTO (v0.18.1)
## {"comando": "tiro_salva", "nome"} salva l'ultimo tiro singolo (traccia) · {"comando": "tiro_togli", "indice"} ·
## {"comando": "tiri_verifica"} li rifà tutti e confronta.
func _tiri_cmd(c: Dictionary) -> Dictionary:
	if not desc.get("tiri_riferimento") is Array:
		desc["tiri_riferimento"] = []
	var tr: Array = desc["tiri_riferimento"]
	match str(c["comando"]):
		"tiro_salva":
			var u := ultima_traccia
			if not bool(u.get("ok", false)) or u.get("tiri", []).size() != 1 or u.has("calore") or str(u.get("opz", {}).get("paletta", "")) != "":
				return {"ok": false, "messaggio": "Fai prima UN tiro con Traccia tiro (non ventaglio né mappa di calore)"}
			var o: Dictionary = (u.get("opz", {"da": u["da"], "vel": u["vel"]}) as Dictionary).duplicate()
			o["tiri"] = 1
			o["variazione"] = 0.0
			_ricorda()
			var nome := str(c.get("nome", "")).strip_edges()
			if nome == "":
				nome = "Tiro %d" % (tr.size() + 1)
			tr.append({"nome": nome, "opz": o, "atteso": Tracciatore.impronta(u["tiri"][0])})
			_fatto()
			var imp: Dictionary = tr[tr.size() - 1]["atteso"]
			return {"ok": true, "messaggio": "Tiro di riferimento «%s» salvato: colpisce %s" % [nome, ", ".join(imp["colpi"]) if not imp["colpi"].is_empty() else "nessun pezzo obiettivo"]}
		"tiro_togli":
			var i := int(c.get("indice", -1))
			if i < 0 or i >= tr.size():
				return {"ok": false, "messaggio": "Tiro inesistente"}
			_ricorda()
			tr.remove_at(i)
			_fatto()
			return {"ok": true, "messaggio": "Tiro di riferimento tolto"}
	var esiti := Tracciatore.verifica(desc)
	var cambiati := esiti.filter(func(x): return not x["ok"])
	return {"ok": true, "messaggio": "Tiri di riferimento: %d su %d come prima" % [esiti.size() - cambiati.size(), esiti.size()], "esiti": esiti}

# ================================================================ CONFRONTO TRA VERSIONI (v0.18.2, Fase 10)
## Cosa è cambiato tra il tavolo di adesso e un altro (di solito l'ultimo salvataggio): pezzi aggiunti, tolti,
## spostati o cambiati, e le parti del tavolo cambiate (missioni, luci, menu…). I pezzi GENERATI (pareti dei nastri,
## bordi dei piani, canali delle prigioniere…) non contano: cambiano da soli quando cambia il loro pezzo.
const CHIAVI_GENERATE := ["da_nastro", "da_piano", "da_captive", "da_buca", "da_rampa"]
const CAMPI_IGNORATI := ["punti", "livello_auto", "livello_fine_auto", "inizio_auto", "prosegue_auto", "fermo", "bersaglio", "mezze", "solida"]
const SEZIONI := {"missioni": "missioni", "spettacoli": "spettacoli di luce", "attesa": "attesa in sala", "menu": "menu del gioco",
	"collezione": "collezione", "zone": "zone", "musica": "musiche", "suoni": "suoni degli eventi", "luci_eventi": "luci degli eventi",
	"colori": "colori", "forma": "forma del tavolo", "licenze": "licenze", "tiri_riferimento": "tiri di riferimento", "fondo": "fondo dipinto",
	"luce_ambiente": "luce ambientale", "titolo": "nome del tavolo", "cambio_corsie": "cambio corsia", "gruppi_editor": "gruppi"}

static func _generato(e) -> bool:
	if not e is Dictionary:
		return true
	for k in CHIAVI_GENERATE:
		if e.has(k):
			return true
	return false

static func _impronta_pezzo(e: Dictionary) -> String:
	var c := e.duplicate()
	for k in CAMPI_IGNORATI:
		c.erase(k)
	return var_to_str(c)

func confronta(altro: Dictionary) -> Array:
	var out: Array = []
	for k in LISTE:
		var prima := {}
		for e in altro.get(k, []):
			if not _generato(e) and e.has("id"):
				prima[str(e["id"])] = e
		var ora := {}
		for e in desc.get(k, []):
			if not _generato(e) and e.has("id"):
				ora[str(e["id"])] = e
		var nome: String = str(SchedeEditor.scheda(k).get("breve", SchedeEditor.scheda(k).get("nome", k)))
		for id in ora:
			if not prima.has(id):
				out.append("+ aggiunto %s «%s»" % [nome, id])
		for id in prima:
			if not ora.has(id):
				out.append("− tolto %s «%s»" % [nome, id])
		for id in ora:
			if not prima.has(id):
				continue
			var d := centro(k, ora[id]).distance_to(centro(k, prima[id]))
			var cambiati: Array = []
			for f in ora[id]:
				if f in CAMPI_IGNORATI or f in ["pos", "perno", "casa"]:
					continue
				if var_to_str(ora[id].get(f)) != var_to_str(prima[id].get(f)):
					cambiati.append(f)
			for f in prima[id]:
				if not ora[id].has(f) and not f in CAMPI_IGNORATI and not f in cambiati:
					cambiati.append(f)
			if d > 0.5 and not cambiati.has("controllo"):
				out.append("↔ spostato %s «%s» di %.0f mm" % [nome, id, d])
			if not cambiati.is_empty():
				out.append("✎ cambiato %s «%s»: %s" % [nome, id, ", ".join(cambiati)])
	for k in SEZIONI:
		if var_to_str(desc.get(k)) != var_to_str(altro.get(k)):
			out.append("✎ cambiati: %s" % SEZIONI[k])
	return out

## Un'immagine sua diventa un pezzo di gioco: l'immagine resta INTATTA (si vede al posto del disegno dell'editor) e
## sotto c'è una collisione invisibile, separata, da regolare (forma, misura, posizione) con i parametri fisici del
## pezzo. Categoria = tipo di pezzo che dà fisica e gioco. Lato più lungo di partenza per categoria (mm, STIMA).
const CATEGORIE_IMMAGINE := {
	"bumper": ["Bumper (respinge)", 60.0], "bersaglio": ["Bersaglio", 40.0], "buca": ["Buca", 40.0],
	"paletto": ["Paletto di gomma", 24.0], "forma": ["Forma libera (muro o isola: la sagoma la disegni tu)", 120.0],
	"fionda": ["Fionda (triangolo con l'elastico che spara la pallina)", 100.0], "rampa": ["Rampa già disegnata (il percorso lo metti tu)", 260.0],
	"immagine": ["Solo immagine (decorazione, senza fisica)", 120.0]}

func _elemento_da_immagine(c: Dictionary) -> Dictionary:
	var cat := str(c.get("categoria", "bumper"))
	if not CATEGORIE_IMMAGINE.has(cat):
		return {"ok": false, "messaggio": "Categoria sconosciuta: " + cat}
	var f := str(c.get("file", ""))
	var img := Image.load_from_file(f) if FileAccess.file_exists(f) else null
	if img == null or img.is_empty():
		return {"ok": false, "messaggio": "Non riesco a leggere l'immagine (va bene PNG, JPG o WEBP)"}
	var lato := float(c.get("lato", CATEGORIE_IMMAGINE[cat][1]))
	var dimm := Vector2(img.get_width(), img.get_height()) * (lato / float(maxi(img.get_width(), img.get_height())))
	dimm = dimm.snapped(Vector2(0.5, 0.5))
	var pos := _vec(c.get("pos", Vector2(317, 560)))
	var cmd := {"comando": "aggiungi", "pos": pos}
	match cat:
		"bumper":
			cmd.merge({"tipo": "bumper", "valori": {"raggio": snappedf(dimm.x * 0.45, 0.5), "raggio_y": snappedf(dimm.y * 0.45, 0.5)}})
		"bersaglio":
			cmd.merge({"tipo": "bersagli", "valori": {"dim": Vector2(dimm.x, minf(dimm.y, 10.0))}})
		"buca":
			cmd.merge({"tipo": "buche", "valori": {"raggio": snappedf(minf(dimm.x, dimm.y) * 0.4, 0.5)}})
		"paletto":
			cmd.merge({"tipo": "elastici", "valori": {"raggio": snappedf(minf(dimm.x, dimm.y) * 0.45, 0.5)}})
		"forma":
			var h := dimm * 0.45
			cmd.merge({"tipo": "muri", "punti": [pos + Vector2(-h.x, -h.y), pos + Vector2(h.x, -h.y), pos + Vector2(h.x, h.y), pos + Vector2(-h.x, h.y)], "chiuso": true, "valori": {"tipo": "gomma"}})
		"fionda":
			cmd.merge({"tipo": "muri", "preset": "fionda"})
		"rampa":
			# percorso iniziale lungo il lato lungo dell'immagine (dal basso verso l'alto); larghezza = 1/4 del lato corto
			var asse := Vector2(0, dimm.y * 0.42) if dimm.y >= dimm.x else Vector2(dimm.x * 0.42, 0)
			cmd.merge({"tipo": "rampe", "punti": [pos + asse, pos, pos - asse], "valori": {"larghezza": snappedf(clampf(minf(dimm.x, dimm.y) * 0.25, 34.0, 120.0), 1.0)}})
		"immagine":
			cmd.merge({"tipo": "decorazioni", "valori": {"dim": dimm}})
	var ra := esegui(cmd, "editor")
	if not ra.get("ok", false):
		return ra
	var ri := _immagine({"id": ra["id"], "file": f, "dim": dimm, "pos": [0, 0], "modo": "sostituisce"})
	if ri.get("ok", false):
		_annulla.pop_back()                  # un solo «annulla» per tutto l'elemento
	var e: Dictionary = pezzo(ra["id"])
	e["da_immagine"] = cat
	return {"ok": true, "messaggio": "%s da immagine: «%s» (immagine %.0f × %.0f mm; la collisione azzurra si regola a destra)" % [CATEGORIE_IMMAGINE[cat][0].get_slice(" (", 0), ra["id"], dimm.x, dimm.y], "id": ra["id"]}

# ================================================================ I MIEI ELEMENTI (v0.19, libreria)
## Un elemento configurato (pezzo con immagine, collisione e fisica) si salva in un file nella cartella
## «libreria_elementi» (accanto al progetto dell'editor, uguale per tutti i tavoli) e si inserisce in altri tavoli.
## File = var_to_str di {chiave, pezzo (posizione relativa 0,0), immagini: {nome: PNG base64}, data}.
static func cartella_libreria() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join("libreria_elementi").simplify_path()

static func elenco_elementi() -> Array:
	var d := cartella_libreria()
	if not DirAccess.dir_exists_absolute(d):
		return []
	var out: Array = []
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".elemento"):
			out.append(f.get_basename())
	out.sort()
	return out

func _libreria_cmd(c: Dictionary) -> Dictionary:
	var dir := cartella_libreria()
	match str(c["comando"]):
		"elementi_elenco":
			var el := elenco_elementi()
			return {"ok": true, "messaggio": "%d elementi in libreria" % el.size(), "elementi": el}
		"elemento_salva":
			var t := trova(str(c.get("id", "")))
			if t.is_empty():
				return {"ok": false, "messaggio": "Scegli prima un pezzo"}
			var k: String = t[0]
			var e: Dictionary = (desc[k][t[1]] as Dictionary).duplicate(true)
			var nome := str(c.get("nome", "")).strip_edges().validate_filename()
			if nome == "":
				nome = str(e["id"])
			# posizione relativa: il pezzo si salva centrato in 0,0
			var cen := centro(k, e)
			_sposta_dati(k, e, -cen)
			e.erase("id")
			for x in ["livello", "livello_auto", "gruppo"]:
				e.erase(x)
			var imm := {}
			if PittorePezzi.ha_immagine(e) and desc.get("immagini", {}).has(str(e["immagine"]["nome"])):
				imm[str(e["immagine"]["nome"])] = desc["immagini"][str(e["immagine"]["nome"])]
			DirAccess.make_dir_recursive_absolute(dir)
			var fa := FileAccess.open(dir.path_join(nome + ".elemento"), FileAccess.WRITE)
			if fa == null:
				return {"ok": false, "messaggio": "Non riesco a scrivere nella libreria"}
			fa.store_string(var_to_str({"chiave": k, "pezzo": e, "immagini": imm, "data": Time.get_date_string_from_system()}))
			fa.close()
			return {"ok": true, "messaggio": "Elemento «%s» salvato in «I miei elementi»" % nome}
		"elemento_togli":
			var ft := dir.path_join(str(c.get("nome", "")) + ".elemento")
			if not FileAccess.file_exists(ft):
				return {"ok": false, "messaggio": "Elemento sconosciuto"}
			OS.move_to_trash(ft)
			return {"ok": true, "messaggio": "Elemento tolto dalla libreria (è nel Cestino)"}
	# elemento_inserisci
	var fi := dir.path_join(str(c.get("nome", "")) + ".elemento")
	var dati = str_to_var(FileAccess.get_file_as_string(fi)) if FileAccess.file_exists(fi) else null
	if not dati is Dictionary or not dati.has("pezzo"):
		return {"ok": false, "messaggio": "Elemento non leggibile: " + str(c.get("nome", ""))}
	var kk := str(dati["chiave"])
	var nuovo: Dictionary = (dati["pezzo"] as Dictionary).duplicate(true)
	nuovo["id"] = nuovo_id(kk)
	_sposta_dati(kk, nuovo, _vec(c.get("pos", Vector2(317, 560))))
	_ricorda()
	if not desc.get("immagini") is Dictionary:
		desc["immagini"] = {}
	for n in dati.get("immagini", {}):
		var nome_i := str(n)
		var k2 := 2
		while desc["immagini"].has(nome_i) and desc["immagini"][nome_i] != dati["immagini"][n]:
			nome_i = "%s_%d" % [n, k2]
			k2 += 1
		desc["immagini"][nome_i] = dati["immagini"][n]
		if PittorePezzi.ha_immagine(nuovo) and str(nuovo["immagine"]["nome"]) == str(n):
			nuovo["immagine"]["nome"] = nome_i
	if not desc.get(kk) is Array:
		desc[kk] = []
	desc[kk].append(nuovo)
	_fatto()
	return {"ok": true, "messaggio": "Inserito «%s» come «%s»" % [c.get("nome", ""), nuovo["id"]], "id": nuovo["id"]}

## Sposta tutti i dati di posizione di un pezzo di `d` (posizione, punti, controllo).
static func _sposta_dati(k: String, e: Dictionary, d: Vector2) -> void:
	for campo in ["pos", "perno", "casa"]:
		if e.get(campo) is Vector2:
			e[campo] = Vector2(e[campo]) + d
	for campo in ["punti", "controllo"]:
		if e.has(campo):
			var out: Array = []
			for q in e[campo]:
				if q is Vector3:
					out.append(Vector3(q.x + d.x, q.y + d.y, q.z))
				else:
					out.append(Vector2(q) + d)
			e[campo] = PackedVector2Array(out) if e[campo] is PackedVector2Array else out
