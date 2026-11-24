## Regole comuni a tutti i tavoli: partita, palline, punteggio, salva-pallina, bonus di fine pallina,
## multiball, tilt, record. Le regole di un tavolo (missioni) estendono questa classe e ridefiniscono
## `_evento_tavolo`, `_inizio_pallina`, `_voci_bonus` e `stato_luci`.
class_name RegoleBase
extends Node

signal punteggio_cambiato(totale: int)
signal messaggio(titolo: String, sotto: String, durata: float)
signal effetto(nome: String, posizione: Vector2)        # per grafica, luci e audio
signal stato_cambiato(stato: int)

enum { ATTESA, GIOCO, FINE_PALLINA, GAME_OVER, PREMIO }   # PREMIO: proposta del video con premio (21/11)

const FILE_RECORD := "user://record.cfg"

var tavolo: TavoloFisico
var stato := ATTESA
var punti := 0
var pallina := 0
var palline_max := 3
var moltiplicatore := 1             # moltiplicatore del bonus di fine pallina
var punti_x := 1                    # moltiplicatore dei punti (modalità speciali)
var multiball := false
var salva_fino := 0.0               # tempo (s) fino a cui la pallina persa viene restituita
var record := 0
var salva_record := true             # i test non toccano il record vero
var contatori := {}                  # contatori della pallina per il bonus
var avvisi_tilt := 0
var _ultima_spinta := -99.0
var t := 0.0                         # tempo di partita (s)
var titolo := "PINBALL"                 # nome del tavolo sul tabellone
# Pallina extra come nei flipper veri (20/11, regola comune a tutti i flipper: REGOLE_FLIPPER.md, sezione 11):
# - si guadagna col punteggio di rigioco (2 livelli per partita) o raccogliendo una pallina extra ACCESA da un obiettivo;
# - non fa avanzare il numero della pallina: a fine pallina, dopo il bonus, TIRA ANCORA lo stesso giocatore;
# - luce TIRA ANCORA (tondo tra le palette) accesa fissa finché c'è una pallina extra da giocare;
# - limiti: al massimo N per pallina in gioco e N per partita; oltre il limite vale punti (come le macchine vere);
# - il TILT fa perdere la pallina in gioco e il suo bonus, non le palline extra già guadagnate.
var extra_palline := 0               # palline extra guadagnate e non ancora giocate
var extra_accese := 0                # palline extra accese, da raccogliere col tiro indicato dalla luce rossa
var extra_partita := 0               # palline extra date in questa partita
var extra_pallina := 0               # palline extra date durante la pallina in gioco
var rigioco_livello := 0             # livelli del punteggio di rigioco già raggiunti
var tira_ancora := false             # la pallina in gioco è una pallina extra

func collega(t_: TavoloFisico) -> void:
	tavolo = t_
	tavolo.evento.connect(registra)
	tavolo.pallina_persa.connect(_pallina_persa)
	var cfg := ConfigFile.new()
	if cfg.load(FILE_RECORD) == OK:
		record = int(cfg.get_value("record", "punti", 0))
	# v0.23: classifica dei 10 migliori con le iniziali (si spegne dal tavolo: desc["classifica"] = false)
	if bool(tavolo.d.get("classifica", true)):
		classifica = ClassificaTavolo.new(str(tavolo.d.get("nome", "")), salva_record and not Parametri.argomenti.has("prova"))

var classifica: ClassificaTavolo
var iniziali := "AAA"
var iniziali_pos := -1               # lettera che si sta scegliendo (0-2); -1 = non si scrivono le iniziali

func scrive_iniziali() -> bool:
	return iniziali_pos >= 0

## Palette: lettera precedente (−1) o successiva (+1).
func iniziali_cambia(verso: int) -> void:
	if iniziali_pos < 0:
		return
	var L := ClassificaTavolo.LETTERE
	var c := (L.find(iniziali[iniziali_pos]) + verso + L.length()) % L.length()
	iniziali = iniziali.substr(0, iniziali_pos) + L[c] + iniziali.substr(iniziali_pos + 1)

## START o lancio: conferma la lettera; dopo la terza il punteggio entra in classifica.
func iniziali_conferma() -> void:
	if iniziali_pos < 0:
		return
	iniziali_pos += 1
	if iniziali_pos >= 3:
		iniziali_pos = -1
		var posto := classifica.inserisci(iniziali, punti) if classifica else -1
		messaggio.emit(Testi.t("CLASSIFICA"), "%d° posto: %s  %s" % [posto + 1, iniziali, RegoleBase.formatta(punti)], 4.0)

func nuova_partita() -> void:
	iniziali_pos = -1
	tavolo.togli_tutte()
	punti = 0
	pallina = 0
	palline_max = int(Parametri.valore("regole", "palline", 3))
	premio_usato = false
	_azzera_extra()
	_azzera_partita()
	punteggio_cambiato.emit(punti)
	_nuova_pallina()

## `extra` = la pallina è una pallina extra (TIRA ANCORA): il numero della pallina non cambia.
func _nuova_pallina(extra := false) -> void:
	if not extra:
		pallina += 1
	tira_ancora = extra
	extra_pallina = 0
	moltiplicatore = 1
	punti_x = 1
	multiball = false
	contatori = {}
	avvisi_tilt = 0
	tavolo.tilt = false
	tavolo.accendi_kickback()
	salva_fino = -1.0
	_imposta_stato(GIOCO)
	_inizio_pallina()
	tavolo.aggiungi_palline(1, false)
	if extra:
		messaggio.emit(Testi.t("TIRA ANCORA"), Testi.t("pallina extra · pallina %d") % pallina, 2.0)
	else:
		messaggio.emit(Testi.t("PALLINA %d") % pallina, "", 1.5)

## Il salva-pallina parte quando la pallina lascia la corsia di lancio (non mentre è ferma nella corsia).
func _avvia_salva() -> void:
	salva_fino = t + float(Parametri.valore("regole", "salva_pallina", 8.0))

func salva_attivo() -> bool:
	return t < salva_fino

func in_gioco() -> bool:
	return stato == GIOCO

func _imposta_stato(s: int) -> void:
	stato = s
	stato_cambiato.emit(s)

func aggiungi_punti(n: int) -> void:
	if stato != GIOCO or tavolo.tilt:
		return
	punti += n * punti_x
	punteggio_cambiato.emit(punti)
	_controlla_rigioco()

# ================================================================ pallina extra
## Livelli del punteggio di rigioco ([regole] punti_rigioco e punti_rigioco_2; 0 = spento).
func livelli_rigioco() -> Array:
	var l: Array = []
	for k in ["punti_rigioco", "punti_rigioco_2"]:
		var v := int(Parametri.valore("regole", k, 0))
		if v > 0 and (l.is_empty() or v > int(l[-1])):
			l.append(v)
	return l

## Prossimo punteggio di rigioco da raggiungere (0 = nessuno).
func prossimo_rigioco() -> int:
	var l := livelli_rigioco()
	return int(l[rigioco_livello]) if rigioco_livello < l.size() else 0

func _controlla_rigioco() -> void:
	var l := livelli_rigioco()
	while rigioco_livello < l.size() and punti >= int(l[rigioco_livello]):
		rigioco_livello += 1
		effetto.emit("rigioco", Vector2.ZERO)
		premia_extra(Vector2.ZERO, Testi.t("RIGIOCO A %s PUNTI") % formatta(int(l[rigioco_livello - 1])))

## Dà una pallina extra (TIRA ANCORA a fine pallina). Oltre i limiti vale punti. Restituisce true se data davvero.
func premia_extra(pos := Vector2.ZERO, motivo := "") -> bool:
	var max_partita := int(Parametri.valore("regole", "extra_max_partita", 4))
	var max_pallina := int(Parametri.valore("regole", "extra_max_pallina", 2))
	if extra_partita >= max_partita or extra_pallina >= max_pallina:
		var v := int(Parametri.valore("regole", "extra_valore", 250000))
		aggiungi_punti(v)
		messaggio.emit(Testi.t("PALLINA EXTRA = PUNTI"), Testi.t("limite raggiunto  +") + formatta(v * punti_x), 2.0)
		effetto.emit("extra_punti", pos)
		return false
	extra_palline += 1
	extra_partita += 1
	extra_pallina += 1
	messaggio.emit(Testi.t("PALLINA EXTRA!"), motivo if motivo != "" else Testi.t("a fine pallina TIRA ANCORA"), 2.5)
	effetto.emit("pallina_extra", pos)
	return true

## Un obiettivo accende la pallina extra: si raccoglie col tiro indicato (luce rossa). Resta accesa tra una pallina e l'altra.
func accendi_extra(dove: String) -> void:
	if extra_accese >= int(Parametri.valore("regole", "extra_max_accese", 2)):
		return
	extra_accese += 1
	messaggio.emit(Testi.t("PALLINA EXTRA ACCESA"), dove, 2.5)
	effetto.emit("extra_accesa", Vector2.ZERO)

## Il tiro della pallina extra: se è accesa la raccoglie. Restituisce true se ce n'era una accesa.
func raccogli_extra(pos: Vector2) -> bool:
	if extra_accese <= 0 or stato != GIOCO or tavolo.tilt:
		return false
	extra_accese -= 1
	premia_extra(pos)
	return true

func _azzera_extra() -> void:
	extra_palline = 0
	extra_accese = 0
	extra_partita = 0
	extra_pallina = 0
	rigioco_livello = 0
	tira_ancora = false

## Luce TIRA ANCORA (tondo tra le palette): lampeggia col salva-pallina, fissa se c'è una pallina extra da giocare.
func luce_tira_ancora() -> int:
	if salva_attivo():
		return 2
	return 1 if extra_palline > 0 else 0

## Palline in campo nei multiball ([regole] multiball_palline, 20/11: 5 invece di 3).
func palline_multiball() -> int:
	return maxi(2, int(Parametri.valore("regole", "multiball_palline", 5)))

## Multiball fino ad avere `palline_multiball()` palline in tutto (quelle già in gioco contano).
func avvia_multiball_pieno() -> void:
	avvia_multiball(maxi(1, palline_multiball() - tavolo.palline_totali()))

func conta(chiave: String, n := 1) -> void:
	contatori[chiave] = int(contatori.get(chiave, 0)) + n

func registra(tipo: String, id: String, pos: Vector2) -> void:
	if stato != GIOCO:
		return
	if tipo == "lancio" and salva_fino < 0.0:
		_avvia_salva()
	_evento_tavolo(tipo, id, pos)

func avvia_multiball(palline_extra: int) -> void:
	multiball = true
	tavolo.aggiungi_palline(palline_extra, true)
	salva_fino = t + 10.0
	effetto.emit("multiball", Vector2.ZERO)

func _pallina_persa(_p: Pallina, rimaste: int) -> void:
	if stato != GIOCO:
		return
	if salva_attivo() and not tavolo.tilt:
		# una sola pallina restituita (fuori dal multiball): poi il salva-pallina si spegne fino alla prossima pallina
		if not multiball:
			salva_fino = 0.0
		tavolo.aggiungi_palline(1, true)
		messaggio.emit(Testi.t("SALVA PALLINA"), "", 1.5)
		effetto.emit("salva_pallina", Vector2.ZERO)
		return
	if multiball:
		if rimaste <= 1:
			multiball = false
			_fine_multiball()
		if rimaste >= 1:
			return
	if rimaste > 0:
		return
	_fine_pallina()

func _fine_pallina() -> void:
	_imposta_stato(FINE_PALLINA)
	var voci := _voci_bonus()
	var totale := 0
	for v in voci:
		totale += int(v[1])
	totale *= moltiplicatore
	if tavolo.tilt:
		totale = 0
	punti += totale
	punteggio_cambiato.emit(punti)
	messaggio.emit(Testi.t("BONUS %s") % formatta(totale), "x%d" % moltiplicatore, 2.0)
	_controlla_rigioco()                 # anche il bonus conta per il rigioco (come nei flipper veri)
	effetto.emit("bonus", Vector2.ZERO)
	await get_tree().create_timer(2.2, false).timeout
	if stato != FINE_PALLINA:
		return
	if extra_palline > 0:
		extra_palline -= 1
		_nuova_pallina(true)
	elif pallina >= palline_max:
		_fine_o_premio()
	else:
		_nuova_pallina()

func _fine_partita() -> void:
	_imposta_stato(GAME_OVER)
	extra_palline = 0
	extra_accese = 0
	tira_ancora = false
	tavolo.togli_tutte()
	var nuovo := punti > record
	if nuovo:
		record = punti
		if salva_record:
			var cfg := ConfigFile.new()
			cfg.set_value("record", "punti", record)
			cfg.save(FILE_RECORD)
	messaggio.emit(Testi.t("GAME OVER"), Testi.t("NUOVO RECORD!") if nuovo else Testi.t("premi START"), 6.0)
	if classifica and classifica.posizione(punti) >= 0 and not tavolo.autoplay:
		iniziali = "AAA"
		iniziali_pos = 0
	effetto.emit("game_over", Vector2.ZERO)

## Persa l'ultima pallina (solo APK con pubblicità, video pronto, una volta per partita): il menu propone «guarda un
## È una pallina, non una «vita» né una partita nuova: punteggio, missioni e numero di pallina restano.
var premio_usato := false
var offri_premio: Callable          # impostata da Main solo nell'APK con pubblicità: true se il video è pronto
var _premio_n := 0

func _fine_o_premio() -> void:
	if not premio_usato and offri_premio.is_valid() and bool(offri_premio.call()):
		premio_usato = true
		_premio_n += 1
		var n := _premio_n
		_imposta_stato(PREMIO)
		# sicurezza: se la scelta o il video non rispondono mai, dopo 3 minuti game over (il gioco non resta fermo)
		get_tree().create_timer(180.0).timeout.connect(func():
			if n == _premio_n:
				premio_rifiutato())
		return
	_fine_partita()

## Video visto fino in fondo: una pallina in più (fuori dai limiti delle palline extra: è un premio a parte).
func premio_ricevuto() -> void:
	if stato != PREMIO:
		return
	_nuova_pallina(true)
	tira_ancora = false
	messaggio.emit(Testi.t("PALLINA IN PIÙ!"), Testi.t("grazie per aver guardato il video"), 2.5)

## Rifiutato, video chiuso prima della fine o non disponibile: game over.
func premio_rifiutato(video_interrotto := false) -> void:
	if stato != PREMIO:
		return
	_fine_partita()
	if video_interrotto:
		messaggio.emit(Testi.t("VIDEO NON COMPLETATO"), Testi.t("nessuna pallina in più"), 3.0)

## Nudge: due spinte troppo vicine = avviso; troppi avvisi = TILT (palette spente fino alla pallina dopo).
func spinta(dir: Vector2) -> void:
	if stato != GIOCO or tavolo.tilt:
		return
	tavolo.spingi(dir)
	if t - _ultima_spinta < Parametri.f("tilt_finestra", 1.2):
		avvisi_tilt += 1
		if avvisi_tilt >= int(Parametri.f("tilt_avvisi", 3)):
			tavolo.tilt = true
			messaggio.emit(Testi.t("TILT"), "", 3.0)
			effetto.emit("tilt", Vector2.ZERO)
		else:
			messaggio.emit(Testi.t("ATTENZIONE"), "", 1.0)
			effetto.emit("avviso", Vector2.ZERO)
	_ultima_spinta = t

func _physics_process(delta: float) -> void:
	t += delta

static func formatta(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

# ---------------------------------------------------------------- da ridefinire nel tavolo
func _azzera_partita() -> void:
	pass

func _inizio_pallina() -> void:
	pass

func _evento_tavolo(_tipo: String, _id: String, _pos: Vector2) -> void:
	pass

func _fine_multiball() -> void:
	pass

## Voci del bonus: [[nome, punti], ...] (prima del moltiplicatore).
func _voci_bonus() -> Array:
	return []

## Stato delle luci del piano: id inserto -> 0 spento, 1 acceso, 2 lampeggia.
func stato_luci() -> Dictionary:
	return {}
