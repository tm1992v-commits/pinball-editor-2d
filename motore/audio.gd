## Audio Manager centralizzato (autoload "Audio").
## - 4 canali con volume indipendente: Musica, Effetti, Voci, Ambiente.
## - Ogni effetto ha priorità, numero massimo di copie contemporanee e intervallo minimo: niente valanghe di suoni.
## - File veri: res://audio/<cartella>/<nome>.(ogg|wav|mp3). Se un file manca si usa un SEGNAPOSTO generato
##   dal codice (dichiarato in docs/AUDIO.md). Per sostituirlo basta mettere il file con lo stesso nome.
extends Node

const CANALI := {"Musica": "music", "Effetti": "effects", "Voci": "voices", "Ambiente": "ambience"}
const RATE := 22050
const VOCI_MAX := 18

## nome: [canale, priorità 1-5, copie max, intervallo minimo s, volume dB]
const SUONI := {
	"bumper": ["Effetti", 2, 2, 0.04, -3.0], "fionda": ["Effetti", 2, 2, 0.05, -5.0],
	"paletta": ["Effetti", 3, 2, 0.03, -8.0], "bersaglio": ["Effetti", 2, 2, 0.04, -4.0],
	"ciurma": ["Effetti", 3, 2, 0.05, -3.0], "campana": ["Effetti", 3, 2, 0.08, -6.0],
	"moneta": ["Effetti", 2, 3, 0.04, -6.0], "monete": ["Effetti", 3, 1, 0.3, -3.0],
	"forziere": ["Effetti", 3, 1, 0.2, -2.0], "cannone": ["Effetti", 4, 2, 0.15, -1.0],
	"lancio": ["Effetti", 3, 1, 0.1, -4.0], "spinner": ["Effetti", 1, 2, 0.025, -10.0],
	"rampa": ["Effetti", 3, 2, 0.1, -4.0], "rampa_fine": ["Effetti", 3, 2, 0.1, -5.0],
	"jackpot": ["Effetti", 5, 1, 0.2, 0.0], "super_jackpot": ["Effetti", 5, 1, 0.5, 0.0],
	"multiball": ["Effetti", 5, 1, 1.0, -1.0], "missione_inizio": ["Effetti", 5, 1, 0.5, -2.0],
	"missione_completa": ["Effetti", 5, 1, 0.5, -1.0], "missione_fallita": ["Effetti", 4, 1, 0.5, -3.0],
	"tuono": ["Ambiente", 4, 1, 0.8, -2.0], "tilt": ["Effetti", 5, 1, 0.5, -3.0],
	"avviso": ["Effetti", 4, 1, 0.3, -4.0], "scarico": ["Effetti", 4, 1, 0.3, -3.0],
	"segreto": ["Effetti", 5, 1, 0.5, -2.0], "lock": ["Effetti", 4, 1, 0.3, -2.0],
	"passaggio": ["Effetti", 4, 1, 0.5, -2.0], "skill": ["Effetti", 4, 1, 0.3, -2.0],
	"combo": ["Effetti", 3, 1, 0.1, -4.0], "pallina_extra": ["Effetti", 5, 1, 0.5, -2.0],
	"risata": ["Voci", 3, 1, 1.5, -2.0], "voce_capitano": ["Voci", 4, 1, 1.2, -1.0],
	"colpo_capitano": ["Voci", 4, 1, 0.3, -2.0], "menu": ["Effetti", 2, 1, 0.05, -8.0], "accensione": ["Effetti", 5, 1, 2.0, -1.0],
	# suoni SPAZIALI del tavolo v2 (23/11): generati dal codice (nostri, nessuna licenza di terzi), provvisori
	"jackpot_spazio": ["Effetti", 5, 1, 0.2, -1.0], "multiball_spazio": ["Effetti", 5, 1, 1.0, -1.0],
	"corsia_spazio": ["Effetti", 3, 2, 0.08, -8.0], "portale": ["Effetti", 4, 1, 0.3, -3.0],
	"portale_uscita": ["Effetti", 4, 1, 0.3, -4.0], "pozzo": ["Effetti", 4, 1, 0.5, -3.0],
	"magnete": ["Effetti", 4, 1, 0.3, -3.0],
}
const MUSICHE := ["main", "main_instrumental", "multiball", "jackpot", "attract"]
const AMBIENTI := ["mare", "tempesta"]

var _suoni := {}                    # nome -> AudioStream
var _segnaposto := {}               # nome -> true se generato dal codice
var _voci: Array[AudioStreamPlayer] = []
var _info := {}                     # player -> [nome, priorità]
var _ultimo := {}                   # nome -> tempo
var _musica: AudioStreamPlayer
var _musica_b: AudioStreamPlayer
var _ambiente: AudioStreamPlayer
var _brano := ""
var _tw_musica: Tween                # dissolvenza in corso tra due brani
var _tw_stacco: Tween                # abbassamento breve (jackpot)
var _tono := 1.0
var _pronti := false
var _mutex := Mutex.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in CANALI:
		if AudioServer.get_bus_index(c) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, c)
			AudioServer.set_bus_send(i, "Master")
		_applica_volume(c)
	for i in VOCI_MAX:
		var g := AudioStreamPlayer.new()
		add_child(g)
		_voci.append(g)
	_musica = AudioStreamPlayer.new()
	_musica.bus = "Musica"
	add_child(_musica)
	_musica_b = AudioStreamPlayer.new()
	_musica_b.bus = "Musica"
	add_child(_musica_b)
	_ambiente = AudioStreamPlayer.new()
	_ambiente.bus = "Ambiente"
	add_child(_ambiente)
	Parametri.cambiati.connect(func():
		for c in CANALI:
			_applica_volume(c))
	# file veri subito; segnaposto generati in un thread per non rallentare l'avvio
	for nome in SUONI:
		var s := _carica_file(CANALI[SUONI[nome][0]], nome)
		if s:
			_suoni[nome] = s
	if DisplayServer.get_name() == "headless":
		_genera_segnaposto()
	else:
		WorkerThreadPool.add_task(_genera_segnaposto)

func _applica_volume(canale: String) -> void:
	var i := AudioServer.get_bus_index(canale)
	var v := float(Parametri.valore("audio", canale, 0.8))
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)

## v0.12 (Pinball Editor 2D): musica presa da un file del progetto ("file:" + percorso completo), es. le canzoni di
var _file_cache := {}

func _carica_esterno(percorso: String) -> AudioStream:
	if _file_cache.has(percorso):
		return _file_cache[percorso]
	if not FileAccess.file_exists(percorso):
		return null
	var s: AudioStream = null
	match percorso.get_extension().to_lower():
		"ogg":
			s = AudioStreamOggVorbis.load_from_file(percorso)
		"mp3":
			var m := AudioStreamMP3.new()
			m.data = FileAccess.get_file_as_bytes(percorso)
			s = m
		"wav":
			s = AudioStreamWAV.load_from_file(percorso)
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.loop = true
	_file_cache[percorso] = s
	return s

func _carica_file(cartella: String, nome: String) -> AudioStream:
	if nome.begins_with("file:"):
		return _carica_esterno(nome.trim_prefix("file:"))
	for est in ["ogg", "wav", "mp3"]:
		var p := "res://audio/%s/%s.%s" % [cartella, nome, est]
		if ResourceLoader.exists(p):
			var s: AudioStream = load(p)
			# musica e ambiente si ripetono: si imposta SUBITO, al caricamento, mai mentre il brano suona
			# (i colpi singoli nella cartella ambience, come il tuono, NON si ripetono)
			# (18/11: cambiarlo durante la riproduzione faceva chiudere il gioco su Android, nel thread audio)
			if (cartella == "music" or nome in AMBIENTI) and (s is AudioStreamMP3 or s is AudioStreamOggVorbis):
				if not s.loop:
					s.loop = true
			return s
	return null

func e_segnaposto(nome: String) -> bool:
	return _segnaposto.has(nome)

func pronto() -> bool:
	return _pronti

# ================================================================ effetti
func suona(nome: String, volume_extra := 0.0, tono := 1.0) -> void:
	if Parametri.senza("audio"):
		return
	_mutex.lock()
	var s: AudioStream = _suoni.get(nome)
	_mutex.unlock()
	if s == null or not SUONI.has(nome):
		return
	var d: Array = SUONI[nome]
	var ora := Time.get_ticks_msec() / 1000.0
	if ora - float(_ultimo.get(nome, -10.0)) < d[3]:
		return
	var copie := 0
	for g in _voci:
		if g.playing and _info.get(g, ["", 0])[0] == nome:
			copie += 1
	if copie >= d[2]:
		return
	var scelto: AudioStreamPlayer = null
	for g in _voci:
		if not g.playing:
			scelto = g
			break
	if scelto == null:   # tutte occupate: ruba la voce con priorità più bassa
		var minima := 99
		for g in _voci:
			var pr: int = _info.get(g, ["", 0])[1]
			if pr < minima:
				minima = pr
				scelto = g
		if minima > d[1]:
			return
	_ultimo[nome] = ora
	_info[scelto] = [nome, d[1]]
	scelto.bus = d[0]
	scelto.stream = s
	scelto.volume_db = d[4] + volume_extra
	scelto.pitch_scale = tono
	scelto.play()

# ================================================================ musica e ambiente
## Canzoni tra cui scegliere (22/11): [[file, titolo], ...] da config/gioco.cfg [musica] brani. Senza la sezione:
## solo "main" (gli altri flipper restano come prima).
func brani() -> Array:
	var b = Parametri.valore("musica", "brani", [])
	var out: Array = []
	for x in b:
		if _carica_file("music", str(x[0])) != null:
			out.append(x)
	return out

var _casuale := ""                   # canzone estratta per questa partita (modalità «casuale»)

## File della canzone del gioco adesso: quella scelta nel menu, oppure quella estratta per la partita.
func brano_scelto() -> String:
	var lista := brani()
	if lista.is_empty():
		return "main"
	var scelta := str(Parametri.valore("musica", "scelta", "casuale"))
	if scelta != "casuale":
		for x in lista:
			if str(x[0]) == scelta:
				return scelta
		return str(lista[0][0])
	if _casuale == "":
		_estrai()
	return _casuale

## Modalità casuale: una canzone a caso, diversa dall'ultima (se ce n'è più di una).
func _estrai() -> void:
	var lista := brani()
	if lista.is_empty():
		return
	var scelte: Array = []
	for x in lista:
		if str(x[0]) != _casuale or lista.size() == 1:
			scelte.append(str(x[0]))
	_casuale = scelte[randi() % scelte.size()]

## Chiamata dal menu quando si cambia la scelta: la musica cambia subito (con dissolvenza).
func applica_scelta() -> void:
	if str(Parametri.valore("musica", "scelta", "casuale")) == "casuale":
		_estrai()
	var nome := _brano
	_brano = ""
	if nome != "":
		musica(nome)

func musica(nome: String, dissolvenza := 1.2) -> void:
	if Parametri.senza("audio"):
		return
	if nome == _brano:
		return
	# nuova partita (dall'attesa alla partita): in modalità casuale si estrae un'altra canzone
	if nome == "main" and _brano == "attract" and str(Parametri.valore("musica", "scelta", "casuale")) == "casuale":
		_estrai()
	_brano = nome
	var s := _carica_file("music", brano_scelto() if nome == "main" else nome)
	var tono := 1.0
	if s == null:
		# mancano le versioni dedicate: si usa la canzone del gioco, più veloce per il multiball
		s = _carica_file("music", brano_scelto())
		if nome == "multiball":
			tono = 1.08
		elif nome == "attract":
			tono = 0.94
	if s == null:
		_musica.stop()
		_musica.stream = null          # nessun brano: il controllo di sicurezza non deve farlo ripartire
		return
	# Stesso file già in riproduzione (es. il multiball usa il brano principale più veloce): niente secondo
	# lettore con lo stesso file. Si cambia solo la velocità di quello che suona. (18/11: due lettori sullo stesso
	# file durante la dissolvenza facevano chiudere il gioco su Android.)
	if s == _musica.stream and _musica.playing:
		if _tw_musica and _tw_musica.is_valid():
			_tw_musica.kill()
		_tono = tono
		_tw_musica = create_tween()
		_tw_musica.tween_property(_musica, "pitch_scale", tono, 0.6)
		_musica.volume_db = 0.0
		_musica_b.stop()
		return
	# Una dissolvenza ancora in corso va fermata: altrimenti, a fine corsa, spegnerebbe il lettore che nel
	# frattempo è tornato a suonare il brano nuovo (la musica si fermava e non ripartiva più).
	if _tw_musica and _tw_musica.is_valid():
		_tw_musica.kill()
	if _tw_stacco and _tw_stacco.is_valid():
		_tw_stacco.kill()
	var vecchio := _musica
	_musica = _musica_b
	_musica_b = vecchio
	_musica.stream = s
	_musica.pitch_scale = tono
	_tono = tono
	_musica.volume_db = -40.0
	_musica.play()
	_tw_musica = create_tween().set_parallel()
	_tw_musica.tween_property(_musica, "volume_db", 0.0, dissolvenza)
	_tw_musica.tween_property(vecchio, "volume_db", -40.0, dissolvenza)
	_tw_musica.chain().tween_callback(func():
		if vecchio != _musica:
			vecchio.stop())

## Breve stacco musicale (jackpot): abbassa la musica e suona l'effetto.
func stacco(nome: String) -> void:
	if _tw_stacco and _tw_stacco.is_valid():
		_tw_stacco.kill()
	_tw_stacco = create_tween()
	_tw_stacco.tween_property(_musica, "volume_db", -12.0, 0.1)
	_tw_stacco.tween_interval(1.4)
	_tw_stacco.tween_property(_musica, "volume_db", 0.0, 0.6)
	suona(nome)

## Controllo di sicurezza: se il brano richiesto non sta suonando (per qualsiasi motivo), riparte.
var _t_controllo := 0.0
func _process(delta: float) -> void:
	_t_controllo += delta
	if _t_controllo < 1.0:
		return
	_t_controllo = 0.0
	if _brano != "" and _musica.stream != null and not _musica.playing and not (_tw_musica and _tw_musica.is_running()):
		_musica.volume_db = 0.0
		_musica.pitch_scale = _tono
		_musica.play()

func ambiente(nome: String) -> void:
	var s: AudioStream = _carica_file("ambience", nome)
	if s == null:
		_mutex.lock()
		s = _suoni.get("amb_" + nome)
		_mutex.unlock()
	if s == null:
		_ambiente.stop()
		return
	if _ambiente.stream == s and _ambiente.playing:
		return
	_ambiente.stream = s
	_ambiente.volume_db = -10.0
	_ambiente.play()

func stato_musica() -> String:
	return _brano

# ================================================================ segnaposto generati dal codice
## Suono generato dal codice. In coda c'è un pezzetto di silenzio (CODA_SICUREZZA campioni): il motore audio,
## quella lettura faceva chiudere il gioco all'Assalto dei Fantasmi (18/11, registro del crash: thread AudioTrack).
const CODA_SICUREZZA := 256

func _wav(durata: float, f: Callable, ciclo := false) -> AudioStreamWAV:
	var n := int(durata * RATE)
	var dati := PackedByteArray()
	dati.resize((n + CODA_SICUREZZA) * 2)
	dati.fill(0)
	for i in n:
		var t := float(i) / RATE
		dati.encode_s16(i * 2, int(clampf(f.call(t), -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = dati
	if ciclo:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
	return s

func _note(note: Array, dn: float, timbro := 1.0, coda := 0.3) -> AudioStreamWAV:
	return _wav(dn * note.size() + coda, func(t: float) -> float:
		var k := mini(int(t / dn), note.size() - 1)
		var tl := t - k * dn
		var fr: float = note[k]
		return (sin(TAU * fr * tl) * 0.55 + sin(TAU * fr * 2.0 * tl) * 0.22 * timbro + sin(TAU * fr * 3.0 * tl) * 0.08 * timbro) * exp(-tl * 5.0) * 0.8)

func _rumore() -> float:
	return randf() * 2.0 - 1.0

func _genera_segnaposto() -> void:
	var g := {}
	g["jackpot_spazio"] = _wav(1.4, func(t):
		var k := int(t / 0.09)
		var f := 520.0 * pow(1.26, float(k % 8))
		return sin(TAU * f * t) * 0.35 * exp(-fmod(t, 0.09) * 18.0) + sin(TAU * (900.0 + 600.0 * sin(t * 7.0)) * t) * 0.12 * exp(-t * 1.5))
	g["multiball_spazio"] = _wav(2.2, func(t): return (sin(TAU * (60.0 + 180.0 * t) * t) * 0.45 + sin(TAU * (240.0 + 520.0 * t) * t) * 0.2) * (0.6 + 0.4 * sin(TAU * 8.0 * t)) * minf(t * 4.0, 1.0) * minf((2.2 - t) * 3.0, 1.0))
	g["corsia_spazio"] = _wav(0.14, func(t): return sin(TAU * (1200.0 + 2400.0 * t) * t) * 0.4 * exp(-t * 22.0))
	g["portale"] = _wav(0.7, func(t): return (_rumore() * 0.25 + sin(TAU * (900.0 - 1100.0 * t) * t) * 0.35) * sin(PI * t / 0.7))
	g["portale_uscita"] = _wav(0.5, func(t): return (_rumore() * 0.2 + sin(TAU * (200.0 + 1500.0 * t) * t) * 0.35) * sin(PI * t / 0.5))
	g["pozzo"] = _wav(1.0, func(t): return sin(TAU * (140.0 - 60.0 * t) * t) * 0.5 * (0.7 + 0.3 * sin(TAU * 12.0 * t)) * exp(-t * 2.0))
	g["magnete"] = _wav(0.45, func(t): return signf(sin(TAU * 120.0 * t)) * 0.22 * (0.6 + 0.4 * sin(TAU * 30.0 * t)) * exp(-t * 3.0))
	g["bumper"] = _wav(0.22, func(t): return (sin(TAU * (170.0 - t * 300.0) * t) * 0.8 + _rumore() * exp(-t * 70.0) * 0.6) * exp(-t * 15.0))
	g["fionda"] = _wav(0.09, func(t): return (_rumore() * 0.6 + sin(TAU * 820.0 * t) * 0.4) * exp(-t * 55.0))
	g["paletta"] = _wav(0.07, func(t): return (_rumore() * 0.5 + sin(TAU * 140.0 * t) * 0.6) * exp(-t * 70.0))
	g["bersaglio"] = _wav(0.12, func(t): return (sin(TAU * 600.0 * t) * 0.5 + _rumore() * 0.3) * exp(-t * 40.0))
	g["ciurma"] = _wav(0.25, func(t): return (sin(TAU * (300.0 - t * 600.0) * t) * 0.6 + _rumore() * exp(-t * 50.0) * 0.5) * exp(-t * 12.0))
	g["campana"] = _wav(0.8, func(t): return (sin(TAU * 1320.0 * t) * 0.5 + sin(TAU * 1980.0 * t) * 0.25 + sin(TAU * 2640.0 * t) * 0.1) * exp(-t * 5.0))
	g["moneta"] = _note([988.0, 1319.0], 0.07, 0.3, 0.2)
	g["monete"] = _wav(1.0, func(t): return sin(TAU * (1200.0 + 600.0 * sin(t * 60.0)) * t) * (0.5 + 0.5 * signf(sin(t * 90.0))) * exp(-t * 2.5) * 0.4)
	g["forziere"] = _wav(0.6, func(t): return (sin(TAU * 70.0 * t) * 0.8 * exp(-t * 8.0) + sin(TAU * (220.0 + 40.0 * sin(t * 30.0)) * t) * 0.25 * exp(-t * 3.0)))
	g["cannone"] = _wav(1.1, func(t): return (_rumore() * 0.9 * exp(-t * 4.5) + sin(TAU * 48.0 * t) * 0.7 * exp(-t * 3.0)))
	g["lancio"] = _wav(0.3, func(t): return (sin(TAU * (260.0 + t * 1000.0) * t) * 0.4 + _rumore() * 0.3) * exp(-t * 10.0))
	g["spinner"] = _wav(0.03, func(t): return sin(TAU * 2300.0 * t) * exp(-t * 150.0))
	g["rampa"] = _wav(0.7, func(t): return _rumore() * sin(PI * t / 0.7) * 0.35 * (0.6 + 0.4 * sin(TAU * (10.0 + t * 40.0) * t)))
	g["rampa_fine"] = _wav(0.35, func(t): return (sin(TAU * 900.0 * t) * 0.3 + _rumore() * 0.3) * absf(sin(t * 80.0)) * exp(-t * 6.0))
	g["jackpot"] = _note([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.1)
	g["super_jackpot"] = _note([392.0, 523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0], 0.11, 1.0, 0.6)
	g["multiball"] = _wav(2.0, func(t): return (sin(TAU * (380.0 + 260.0 * sin(TAU * 2.0 * t)) * t) * 0.35 + sin(TAU * 880.0 * t) * 0.15 * absf(sin(t * 12.0))) * minf(t * 5.0, 1.0) * minf((2.0 - t) * 4.0, 1.0))
	g["missione_inizio"] = _wav(1.2, func(t): return (sin(TAU * 147.0 * t) + 0.5 * sin(TAU * 294.0 * t) + 0.3 * sin(TAU * 441.0 * t)) * 0.35 * minf(t * 6.0, 1.0) * exp(-t * 1.5))
	g["missione_completa"] = _note([523.0, 523.0, 784.0, 1047.0], 0.13, 1.0, 0.6)
	g["missione_fallita"] = _note([440.0, 392.0, 330.0, 262.0], 0.16, 0.6, 0.5)
	g["tuono"] = _wav(2.2, func(t): return _rumore() * (exp(-t * 2.0) * 0.8 + 0.3 * exp(-absf(t - 0.4) * 8.0)) * (0.5 + 0.5 * sin(TAU * 30.0 * t)))
	g["tilt"] = _wav(0.6, func(t): return signf(sin(TAU * 110.0 * t)) * 0.3 * exp(-t * 2.5))
	g["avviso"] = _wav(0.3, func(t): return signf(sin(TAU * 220.0 * t)) * 0.25 * exp(-t * 6.0))
	g["scarico"] = _wav(0.6, func(t): return sin(TAU * (120.0 - t * 80.0) * t) * 0.7 * exp(-t * 5.0))
	g["segreto"] = _wav(1.2, func(t): return sin(TAU * (800.0 + 1200.0 * t) * t) * 0.25 * sin(PI * t / 1.2) + sin(TAU * 2000.0 * t) * 0.1 * absf(sin(t * 40.0)) * exp(-t * 2.0))
	g["lock"] = _wav(0.5, func(t): return (sin(TAU * 520.0 * t) * 0.3 + _rumore() * 0.3) * absf(sin(t * 50.0)) * exp(-t * 5.0))
	g["passaggio"] = _wav(1.4, func(t): return sin(TAU * (90.0 + 20.0 * sin(t * 9.0)) * t) * 0.4 * exp(-t * 1.5) + _rumore() * 0.15 * sin(PI * t / 1.4))
	g["skill"] = _note([784.0, 988.0, 1175.0, 1568.0], 0.07)
	g["combo"] = _note([659.0, 880.0], 0.06)
	g["pallina_extra"] = _note([523.0, 659.0, 784.0, 659.0, 784.0, 1047.0], 0.09)
	g["accensione"] = _note([392.0, 523.0, 659.0, 784.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0], 0.14, 1.0, 0.8)
	g["menu"] = _wav(0.05, func(t): return sin(TAU * 1500.0 * t) * exp(-t * 80.0) * 0.5)
	# voci: risata del fantasma (ha-ha-ha con vibrato) e borbottio del capitano (sintetici)
	g["risata"] = _wav(1.4, func(t): return sin(TAU * (330.0 + 40.0 * sin(TAU * 6.0 * t) - t * 80.0) * t) * maxf(sin(TAU * 4.5 * t), 0.0) * 0.45 * exp(-t * 0.8))
	g["voce_capitano"] = _wav(1.0, func(t): return (fmod(t * 95.0, 1.0) * 2.0 - 1.0) * (0.5 + 0.5 * sin(TAU * 5.0 * t)) * 0.3 * minf(t * 8.0, 1.0) * exp(-t * 1.8))
	g["colpo_capitano"] = _wav(0.4, func(t): return (fmod(t * 70.0, 1.0) * 2.0 - 1.0) * 0.4 * exp(-t * 7.0))
	# ambienti in loop
	g["amb_mare"] = _wav(6.0, func(t): return _rumore() * (0.12 + 0.1 * (0.5 + 0.5 * sin(TAU * t / 6.0))), true)
	g["amb_tempesta"] = _wav(4.0, func(t): return _rumore() * (0.22 + 0.08 * sin(TAU * t / 4.0)), true)
	_mutex.lock()
	for nome in g:
		if not _suoni.has(nome):
			_suoni[nome] = g[nome]
			_segnaposto[nome] = true
	_pronti = true
	_mutex.unlock()
