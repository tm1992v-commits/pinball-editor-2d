## Schede dei pezzi del Pinball Editor 2D (v0.1, 23/11/2026): per ogni tipo di pezzo del motore dice in quale lista
## nasce un pezzo nuovo. L'editor costruisce libreria e pannello delle proprietà SOLO da qui: un pezzo nuovo del motore
## si aggiunge con una scheda, senza toccare l'editor.
class_name SchedeEditor

## Tipi di campo: "num" (decimale), "int", "bool", "testo", "scelta" (opzioni), "vec" (x, y in mm), "angolo" (gradi a
## video, radianti nel file), "colore".
const TIPI := {
	"bumper": {"nome": "Bumper", "categoria": "Base", "colore": Color(1.0, 0.45, 0.35),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "raggio", "nome": "Raggio", "tipo": "num", "unita": "mm", "min": 8.0, "max": 80.0},
			# v0.19: collisione ovale e fisica per pezzo (elementi da immagine: zucca, astronave…)
			{"k": "raggio_y", "nome": "Collisione ovale: raggio in altezza (= raggio per un cerchio)", "tipo": "num", "unita": "mm", "min": 8.0, "max": 80.0, "pred_da": "raggio"},
			{"k": "angolo_coll", "nome": "Collisione ovale: rotazione", "tipo": "angolo", "unita": "°", "pro": true, "pred": 0.0},
			{"k": "forza", "nome": "Forza con cui respinge", "tipo": "num", "unita": "mm/s", "min": 200.0, "max": 1600.0, "pred": 760.0},
			{"k": "rimbalzo", "nome": "Rimbalzo (0-1)", "tipo": "num", "min": 0.0, "max": 1.0, "pro": true, "pred": 0.85},
			{"k": "zona", "nome": "Zona (per le regole)", "tipo": "testo", "pro": true},
		],
		"nuovo": {"raggio": 26.0, "zona": "bumper"}},
	"bersagli": {"nome": "Bersaglio", "categoria": "Bersagli", "colore": Color(1.0, 0.85, 0.3),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "angolo", "nome": "Rotazione", "tipo": "angolo", "unita": "°"},
			{"k": "dim", "nome": "Larghezza e spessore", "tipo": "vec", "unita": "mm"},
			{"k": "abbattibile", "nome": "Si abbatte (cade quando colpito)", "tipo": "bool"},
			{"k": "rimbalzo", "nome": "Rimbalzo (0-1)", "tipo": "num", "min": 0.0, "max": 1.0, "pro": true, "pred": 0.5},
			{"k": "molla", "nome": "A molla (rilancia la pallina)", "tipo": "bool"},
			{"k": "molla_verso", "nome": "Molla: punto verso cui rilancia", "tipo": "vec", "unita": "mm", "pro": true},
			{"k": "gruppo", "nome": "Gruppo", "tipo": "testo"},
		],
		"nuovo": {"angolo": 0.0, "dim": Vector2(24, 8), "abbattibile": false, "molla": false, "molla_verso": Vector2(317, 300), "gruppo": "gruppo_1"}},
	"buche": {"nome": "Buca", "categoria": "Buche", "colore": Color(0.5, 0.5, 0.6),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "raggio", "nome": "Raggio", "tipo": "num", "unita": "mm", "min": 10.0, "max": 25.0},
			{"k": "tipo", "nome": "Cosa fa", "tipo": "scelta", "opzioni": ["la tiene e la rimanda fuori", "la manda in un altro punto (anche su un piano rialzato)"], "valori": ["tiene", "passaggio"], "ricostruisci": true},
			{"k": "uscita", "nome": "Dove riappare la pallina", "tipo": "vec", "unita": "mm", "solo_se_valore": ["tipo", "passaggio"]},
			{"k": "tempo", "nome": "Tempo di attesa", "tipo": "num", "unita": "s", "min": 0.2, "max": 5.0},
			{"k": "uscita_dir", "nome": "Direzione d'uscita", "tipo": "vec", "pro": true},
			{"k": "uscita_vel", "nome": "Velocità d'uscita", "tipo": "num", "unita": "mm/s", "min": 200.0, "max": 2000.0},
		],
		"nuovo": {"raggio": 14.0, "tipo": "tiene", "tempo": 1.0, "uscita_dir": Vector2(0, 1), "uscita_vel": 650.0, "uscita": Vector2(317, 300)}},
	"spinner": {"nome": "Spinner", "categoria": "Base", "colore": Color(0.6, 0.9, 1.0),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "angolo", "nome": "Rotazione", "tipo": "angolo", "unita": "°"},
			{"k": "larghezza", "nome": "Larghezza", "tipo": "num", "unita": "mm", "min": 20.0, "max": 60.0},
		],
		"nuovo": {"angolo": 0.0, "larghezza": 38.0}},
	# v0.7: cancelletto a senso unico (la freccia nell'editor dice il verso in cui la pallina passa)
	"cancelli": {"nome": "Cancelletto (la pallina passa in un verso solo)", "breve": "Cancello", "categoria": "Base", "colore": Color(0.85, 0.85, 0.95),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "angolo", "nome": "Rotazione (la freccia = verso in cui passa)", "tipo": "angolo", "unita": "°"},
			{"k": "larghezza", "nome": "Larghezza", "tipo": "num", "unita": "mm", "min": 30.0, "max": 90.0},
		],
		"nuovo": {"angolo": 0.0, "larghezza": 46.0}},
	"sensori": {"nome": "Sensore (conta la pallina che passa)", "breve": "Sensore", "categoria": "Base", "colore": Color(0.4, 1.0, 0.5),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "dim", "nome": "Larghezza e spessore", "tipo": "vec", "unita": "mm"},
			{"k": "dir", "nome": "Verso che conta", "tipo": "vec", "pro": true},
			{"k": "gruppo", "nome": "Gruppo (corsie dello stesso gruppo = cambio corsia)", "tipo": "testo"},
		],
		"nuovo": {"dim": Vector2(36, 8), "dir": Vector2(0, 1), "gruppo": ""}},
	"elastici": {"nome": "Paletto di gomma", "breve": "Paletto", "categoria": "Base", "colore": Color(0.85, 0.85, 0.85),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "raggio", "nome": "Raggio", "tipo": "num", "unita": "mm", "min": 3.0, "max": 20.0},
		],
		"nuovo": {"raggio": 6.0}},
	"kickback": {"nome": "Kickback", "categoria": "Speciali", "colore": Color(1.0, 0.5, 0.2),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "dim", "nome": "Larghezza e spessore", "tipo": "vec", "unita": "mm"},
		],
		"nuovo": {"dim": Vector2(40, 12)}},
	"campi": {"nome": "Pozzo / magnete", "breve": "Pozzo", "categoria": "Speciali", "colore": Color(0.75, 0.4, 1.0),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "tipo", "nome": "Tipo", "tipo": "scelta", "opzioni": ["pozzo", "magnete"]},
			{"k": "raggio", "nome": "Raggio d'azione", "tipo": "num", "unita": "mm", "min": 20.0, "max": 150.0},
			{"k": "forza", "nome": "Forza", "tipo": "num", "min": 500.0, "max": 8000.0, "pro": true},
			{"k": "acceso", "nome": "Acceso dall'inizio", "tipo": "bool"},
		],
		"nuovo": {"tipo": "pozzo", "raggio": 60.0, "forza": 2400.0, "acceso": true}},
	"inserti": {"nome": "Luce sul piano", "breve": "Luce", "categoria": "Luci", "colore": Color(1.0, 1.0, 0.6),
		"campi": [
			{"k": "pos", "nome": "Posizione", "tipo": "vec", "unita": "mm"},
			{"k": "forma", "nome": "Forma", "tipo": "scelta", "opzioni": ["tondo", "freccia", "rettangolo", "rombo", "triangolo", "stella", "esagono"]},
			{"k": "dim", "nome": "Larghezza e lunghezza", "tipo": "vec", "unita": "mm"},
			{"k": "angolo_luce", "nome": "Verso (dove punta)", "tipo": "angolo", "unita": "°"},
			{"k": "colore", "nome": "Colore", "tipo": "colore"},
		],
		"nuovo": {"forma": "tondo", "dim": Vector2(20, 20), "angolo_luce": 0.0, "colore": Color(1.0, 0.8, 0.3)}},
	# pezzi fatti di punti (si spostano interi o punto per punto con le maniglie)
	"muri": {"nome": "Muro / guida", "breve": "Muro", "categoria": "Muri", "colore": Color(0.8, 0.82, 0.88), "punti": "controllo",
		"campi": [
			{"k": "tipo", "nome": "Materiale", "tipo": "scelta", "opzioni": ["metallo", "legno", "gomma"]},
			{"k": "chiuso", "nome": "Forma chiusa (blocco, isola, fionda)", "tipo": "bool"},
			{"k": "forza_fionda", "nome": "Forza dei tratti-fionda", "tipo": "num", "unita": "mm/s", "min": 200.0, "max": 1500.0, "pro": true},
			{"k": "altezza", "nome": "Altezza (disegno)", "tipo": "num", "unita": "mm", "min": 5.0, "max": 60.0, "pro": true},
			{"k": "senso_unico", "nome": "Senso unico", "tipo": "bool", "pro": true},
		],
		"nuovo": {"tipo": "metallo", "altezza": 25.0, "senso_unico": false, "chiuso": false, "forza_fionda": 680.0}},
	"fionde": {"nome": "Fionda (molla)", "breve": "Fionda", "categoria": "Base", "colore": Color(1.0, 0.6, 0.8), "punti": "punti",
		"campi": [],
		# triangolo come la fionda sinistra di Space, intorno al punto cliccato (lato attivo = dal 1° al 3° punto)
		"nuovo": {"punti_rel": [Vector2(-16, -78), Vector2(-21, 23), Vector2(36, 55)]}},
	"palette": {"nome": "Paletta", "breve": "Paletta", "categoria": "Base", "colore": Color(1.0, 1.0, 1.0), "punto": "perno",
		"campi": [
			{"k": "perno", "nome": "Perno", "tipo": "vec", "unita": "mm"},
			{"k": "lunghezza", "nome": "Lunghezza", "tipo": "num", "unita": "mm", "min": 40.0, "max": 100.0},
			{"k": "verso", "nome": "Lato", "tipo": "scelta", "opzioni": ["sinistra (punta a destra)", "destra (punta a sinistra)"], "valori": [1.0, -1.0]},
			{"k": "comando", "nome": "Si muove col tasto", "tipo": "scelta", "opzioni": ["paletta sinistra", "paletta destra"], "valori": ["paletta_sx", "paletta_dx"]},
		],
		"nuovo": {"verso": 1.0, "lunghezza": 60.0, "comando": "paletta_sx"}},
	"porte": {"nome": "Porta (si apre e si chiude con le missioni)", "breve": "Porta", "categoria": "Speciali", "colore": Color(0.9, 0.5, 0.5), "punti": "punti",
		"campi": [
			{"k": "aperta", "nome": "Aperta all'inizio", "tipo": "bool"},
		],
		"nuovo": {"punti_rel": [Vector2(-25, 0), Vector2(25, 0)], "aperta": false}},
	# v0.17.2: PALLINA PRIGIONIERA (captive): canale, fermo e bersaglio in fondo li costruisce l'editor
	"captive": {"nome": "Pallina prigioniera (captive): la colpisci e lei colpisce il bersaglio in fondo al canale", "breve": "Prigioniera", "categoria": "Speciali", "colore": Color(0.85, 0.72, 0.4), "punto": "casa",
		"campi": [
			{"k": "casa", "nome": "Posizione della pallina", "tipo": "vec", "unita": "mm"},
			{"k": "angolo", "nome": "Verso del canale", "tipo": "angolo", "unita": "°"},
			{"k": "corsa", "nome": "Lunghezza del canale", "tipo": "num", "unita": "mm", "min": 40.0, "max": 200.0},
			{"k": "nome", "nome": "Nome", "tipo": "testo"},
		],
		"nuovo": {"angolo": 0.0, "corsa": 90.0, "nome": ""}},
	# v0.15: DEVIATORE SUL PIANO (lama che ruota sul perno tra due posizioni)
	"lame": {"nome": "Deviatore sul piano (lama)", "breve": "Deviatore", "categoria": "Speciali", "colore": Color(0.8, 0.82, 0.9), "punto": "perno",
		"campi": [
			{"k": "perno", "nome": "Perno", "tipo": "vec", "unita": "mm"},
			{"k": "lunghezza", "nome": "Lunghezza", "tipo": "num", "unita": "mm", "min": 25.0, "max": 120.0},
			{"k": "angolo_a", "nome": "Posizione A (verso)", "tipo": "angolo", "unita": "°"},
			{"k": "angolo_b", "nome": "Posizione B (verso)", "tipo": "angolo", "unita": "°"},
			{"k": "posizione", "nome": "All'inizio è in", "tipo": "scelta", "opzioni": ["posizione A", "posizione B"], "valori": ["a", "b"]},
			{"k": "cambia", "nome": "Cambia lato", "tipo": "scelta", "opzioni": ["a ogni colpo della pallina", "solo con le missioni"], "valori": ["colpo", "missioni"]},
		],
		"nuovo": {"lunghezza": 55.0, "angolo_a": 1.0472, "angolo_b": 2.0944, "posizione": "a", "cambia": "colpo"}},
	"nastri": {"nome": "Nastro (corsia o rampa larga, personalizzabile)", "breve": "Nastro", "categoria": "Rampe", "colore": Color(0.25, 0.55, 1.0), "punti": "controllo",
		"campi": [
			{"k": "nome", "nome": "Nome", "tipo": "testo"},
			{"k": "colore", "nome": "Colore", "tipo": "colore"},
			{"k": "aspetto", "nome": "Aspetto", "tipo": "scelta", "opzioni": ["effetto 3D (ombre e fianchi)", "piatto"], "valori": ["3d", "piatto"]},
			{"k": "pareti_sx", "nome": "Parete a sinistra", "tipo": "bool"},
			{"k": "pareti_dx", "nome": "Parete a destra", "tipo": "bool"},
			{"k": "altezza_pareti", "nome": "Altezza delle pareti (disegno)", "tipo": "num", "unita": "mm", "min": 5.0, "max": 60.0},
			{"k": "frecce", "nome": "Frecce sul fondo", "tipo": "bool"},
			{"k": "materiale", "nome": "Materiale delle pareti", "tipo": "scelta", "opzioni": ["metallo", "gomma", "legno"], "pro": true},
			{"k": "stile", "nome": "Se sollevato: tipo", "tipo": "scelta", "opzioni": ["rampa di plastica", "binario a fili"], "valori": ["", "filo"], "pro": true},
		],
		"nuovo": {"nome": "Nastro", "colore": Color(0.1, 0.45, 1.0), "aspetto": "3d", "pareti_sx": true, "pareti_dx": true, "altezza_pareti": 25.0, "frecce": false, "materiale": "metallo", "stile": ""}},
	# v0.6: immagine libera sul piano (pianeti, scritte, loghi, frecce dipinte…): si sposta, ruota e ridimensiona come
	# gli altri pezzi; la pallina ci passa sopra (non tocca la fisica)
	"decorazioni": {"nome": "Immagine sul piano", "breve": "Immagine", "categoria": "Grafica", "colore": Color(0.6, 0.9, 0.6),
		"campi": [
			{"k": "pos", "nome": "Posizione (centro)", "tipo": "vec", "unita": "mm"},
			{"k": "dim", "nome": "Larghezza e altezza", "tipo": "vec", "unita": "mm"},
			{"k": "angolo", "nome": "Rotazione", "tipo": "angolo", "unita": "°"},
			{"k": "opacita", "nome": "Trasparenza (1 = piena)", "tipo": "num", "min": 0.05, "max": 1.0},
			{"k": "specchiata", "nome": "A specchio", "tipo": "bool"},
			{"k": "sopra", "nome": "Sopra i pezzi (altrimenti dipinta sul piano)", "tipo": "bool", "pro": true},
			# v0.18.1: GIOCATTOLO (immagine che si muove nel gioco)
			{"k": "sempre", "nome": "Giocattolo: movimento continuo", "tipo": "scelta", "opzioni": ["ferma", "gira piano", "ondeggia", "pulsa"], "valori": ["", "gira", "ondeggia", "pulsa"]},
			{"k": "reagisce", "nome": "Giocattolo: si muove quando…", "tipo": "scelta",
				"opzioni": ["(mai)", "bumper colpito", "fionda", "bersaglio", "imbocco della rampa", "rampa completata", "spinner", "buca", "pallina prigioniera", "corsia (sensore)", "missione: inizio", "missione completata", "multiball", "cattura (collezione)", "evoluzione", "pallina extra"],
				"valori": ["", "bumper", "fionda", "bersaglio", "rampa_entrata", "rampa", "spinner", "buca", "captive", "sensore", "missione_inizio", "missione_completa", "multiball", "cattura", "evoluzione", "pallina_extra"]},
			{"k": "reagisce_id", "nome": "…solo per il pezzo (nome; vuoto = tutti)", "tipo": "testo", "pro": true},
			{"k": "anim", "nome": "Giocattolo: come si muove", "tipo": "scelta", "opzioni": ["gira", "salta", "trema", "pulsa", "lampeggia"], "valori": ["gira", "salta", "trema", "pulsa", "lampeggia"]},
		],
		"nuovo": {"dim": Vector2(100, 100), "angolo": 0.0, "opacita": 1.0, "specchiata": false, "sopra": false, "sempre": "", "reagisce": "", "anim": "salta"}},
	# v0.9: PIANO RIALZATO (mini-tavolo sopra il tavolo): si disegna la forma come un muro chiuso (o un clic = forma
	# pronta). I pezzi messi dentro vanno sul piano; rampe che finiscono dentro e buche che «mandano la pallina» dentro
	# lo raggiungono.
	"piani": {"nome": "Piano rialzato", "breve": "Piano", "categoria": "Rampe", "colore": Color(0.55, 0.35, 0.85), "punti": "controllo",
		"campi": [
			{"k": "nome", "nome": "Nome", "tipo": "testo"},
			{"k": "altezza", "nome": "Altezza dal tavolo", "tipo": "num", "unita": "mm", "min": 15.0, "max": 90.0},
			{"k": "bordo_aperto", "nome": "Bordo aperto (la pallina può cadere giù dal bordo)", "tipo": "bool"},
			{"k": "passa_sotto", "nome": "Sui pilastri (la pallina del tavolo ci passa sotto; di solito NO: ci sbatte contro)", "tipo": "bool"},
		],
		"nuovo": {"nome": "Piano", "altezza": 40.0, "bordo_aperto": false, "colore": Color(0.42, 0.22, 0.62), "chiuso": true}},
	"rampe": {"nome": "Rampa o binario (con altezza)", "breve": "Rampa", "categoria": "Rampe", "colore": Color(0.5, 0.7, 1.0), "punti": "punti",
		"campi": [
			{"k": "nome", "nome": "Nome", "tipo": "testo"},
			{"k": "stile", "nome": "Tipo", "tipo": "scelta", "opzioni": ["rampa di plastica", "binario a fili"], "valori": ["", "filo"]},
			{"k": "larghezza", "nome": "Larghezza delle pareti (mm; rampa da immagine: come il disegno)", "tipo": "num", "unita": "mm", "min": 34.0, "max": 160.0, "pred": 38.0},
			{"k": "solida", "nome": "Solida dove è bassa (la pallina del tavolo ci sbatte; spenta = ci passa sotto)", "tipo": "bool"},
			{"k": "colore", "nome": "Colore", "tipo": "colore", "sempre": true, "togli": true},
			{"k": "frecce", "nome": "Frecce sul fondo", "tipo": "bool"},
			{"k": "due_sensi", "nome": "Si prende anche dall'uscita (a terra)", "tipo": "bool", "pro": true},
		],
		"nuovo": {"nome": "Rampa", "stile": "", "frecce": false}},
}

## (aggiunto sotto in TIPI con `TIPI_NASTRO`)
## Ordine della libreria (i tipi «senza_nuovo» si modificano ma non si aggiungono ancora: v0.1).
const ORDINE := ["bumper", "fionde", "palette", "spinner", "cancelli", "sensori", "elastici", "bersagli", "buche", "kickback", "campi", "inserti", "muri", "rampe", "nastri", "piani", "lame", "porte", "captive", "decorazioni"]

static func scheda(chiave: String) -> Dictionary:
	return TIPI.get(chiave, {})

## v0.5 (24/11): campi dell'ASPETTO comuni a tutti i pezzi che il PittorePezzi disegna: piatto / effetto 3D / come il
## tavolo, e colore proprio. «sempre» = si mostrano anche se il pezzo non li ha ancora (valore: quello del tavolo).
const CAMPI_ASPETTO := [
	{"k": "aspetto", "nome": "Aspetto", "tipo": "scelta", "opzioni": ["come il tavolo", "effetto 3D (ombre e fianchi)", "piatto"], "valori": ["", "3d", "piatto"], "sempre": true},
	{"k": "colore", "nome": "Colore", "tipo": "colore", "sempre": true, "togli": true},
	{"k": "altezza_3d", "nome": "Altezza nel disegno 3D", "tipo": "num", "unita": "mm", "min": 2.0, "max": 120.0, "sempre": true, "non_muri": true},
	# v0.8: bordo / illuminazione del pezzo (colore e intensità compaiono solo se c'è un bordo)
	{"k": "bordo", "nome": "Bordo / luce", "tipo": "scelta", "opzioni": ["nessuno", "semplice (linea)", "rilievo 3D", "neon luminoso"], "valori": ["", "semplice", "rilievo", "neon"], "sempre": true, "ricostruisci": true},
	{"k": "colore_bordo", "nome": "Colore del bordo", "tipo": "colore", "sempre": true, "togli": true, "solo_se": "bordo"},
	{"k": "intensita_bordo", "nome": "Intensità del bordo (1 = normale)", "tipo": "num", "min": 0.2, "max": 3.0, "sempre": true, "solo_se": "bordo"},
]
const CAMPO_INTERNO := {"k": "colore_2", "nome": "Colore della plastica dentro", "tipo": "colore", "sempre": true, "togli": true}

## Tutti i campi del pezzo (quelli della scheda + aspetto e colore).
static func campi(chiave: String) -> Array:
	var c: Array = scheda(chiave).get("campi", []).duplicate()
	if chiave in PittorePezzi.TIPI:
		for f in CAMPI_ASPETTO:
			if not (chiave in ["muri", "piani"] and f.get("non_muri", false)):
				c.append(f)
		if chiave == "fionde":
			c.append(CAMPO_INTERNO)
		elif chiave == "bumper":
			var cs: Dictionary = CAMPO_INTERNO.duplicate()
			cs["nome"] = "Colore delle strisce"
			c.append(cs)
	return c

## Nome del campo «posizione» del pezzo ("" = pezzo fatto di punti).
static func campo_pos(chiave: String) -> String:
	var s := scheda(chiave)
	if s.has("punti"):
		return ""
	return str(s.get("punto", "pos"))

static func campo_punti(chiave: String) -> String:
	return str(scheda(chiave).get("punti", ""))
