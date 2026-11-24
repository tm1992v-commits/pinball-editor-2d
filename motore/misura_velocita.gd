## stesso titolare). Partita automatica in 2 fasi: «gioco normale» e «multiball». Per ogni fase: FPS medi, 1% dei
## fotogrammi peggiori, tempo di calcolo della logica e della FISICA, fotogrammi lenti, e un giudizio
## (OK 60 / SOLO 30 / INSUFFICIENTE). Alla fine: memoria, oggetti, disegni, temperatura del processore (se c'è).
## Uso: -- --tavolo_file=F --velocita=SECONDI_PER_FASE [--rapporto=FILE]. Il rapporto va anche nell'uscita del programma.
class_name MisuraVelocita
extends Node

const FASI := ["gioco normale", "multiball"]
var main: Node
var durata := 10.0
var rapporto_file := ""
var _fase := -1
var _t := 0.0
var _riscaldamento := 2.0
var _tempi: PackedFloat32Array = []
var _cpu: PackedFloat32Array = []
var _fis: PackedFloat32Array = []
var _righe := PackedStringArray()
var _giudizi: Array = []

func avvia(m: Node, secondi: float, file := "") -> void:
	main = m
	durata = clampf(secondi, 3.0, 120.0)
	rapporto_file = file
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main.tavolo.autoplay = true
	main.regole.salva_record = false
	main.regole.nuova_partita()
	_righe.append("MISURA DELLA VELOCITÀ – %s" % str(main.desc.get("titolo", "tavolo")))
	_righe.append("Data: %s" % Time.get_datetime_string_from_system())
	_righe.append("Sistema: %s %s | processore: %s (%d core)" % [OS.get_name(), Engine.get_architecture_name(), OS.get_processor_name(), OS.get_processor_count()])
	_righe.append("Scheda video: %s | finestra %s | sincronia verticale spenta (margine vero) | %d s per fase" % [RenderingServer.get_video_adapter_name(), str(DisplayServer.window_get_size()), int(durata)])
	_righe.append("Temperatura all'inizio: %s" % _temperatura())
	_righe.append("")

func _process(delta: float) -> void:
	if _fase < 0:
		_riscaldamento -= delta
		if _riscaldamento <= 0.0:
			_inizia(0)
		return
	_tempi.append(delta)
	_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_fis.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_t += delta
	if main.regole.stato == RegoleBase.GAME_OVER or main.regole.stato == RegoleBase.ATTESA:
		main.regole.nuova_partita()          # la misura continua anche se la partita finisce
	if _t >= durata:
		_chiudi()
		if _fase + 1 < FASI.size():
			_inizia(_fase + 1)
		else:
			_fine()

func _inizia(i: int) -> void:
	_fase = i
	_t = 0.0
	_tempi.clear()
	_cpu.clear()
	_fis.clear()
	if i == 1 and not main.regole.multiball:
		main.regole.avvia_multiball(2)

static func _media(a) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)

func _chiudi() -> void:
	var ord := Array(_tempi)
	ord.sort()
	var n := ord.size()
	var medio := _media(ord)
	var p99: float = ord[int(n * 0.99)] if n > 0 else 0.0
	var lenti := 0
	for v in ord:
		if v > 1.0 / 50.0:
			lenti += 1
	var giudizio := "OK 60" if p99 <= 1.0 / 58.0 else ("SOLO 30" if p99 <= 1.0 / 30.0 else "INSUFFICIENTE")
	_giudizi.append(giudizio)
	_righe.append("%-14s FPS medi %4d | 1%% peggiore %4d | logica %.2f ms | fisica %.2f ms | fotogrammi lenti %d | palline %d | %s" % [
		FASI[_fase], int(1.0 / maxf(medio, 0.0001)), int(1.0 / maxf(p99, 0.0001)), _media(_cpu), _media(_fis), lenti,
		main.tavolo.palline.size(), giudizio])

func _fine() -> void:
	_righe.append("")
	_righe.append("Memoria: %.1f MB | oggetti: %d | disegni nell'ultimo fotogramma: %d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	_righe.append("Temperatura alla fine: %s" % _temperatura())
	var peggiore := "OK 60"
	for g in _giudizi:
		if g == "INSUFFICIENTE" or (g == "SOLO 30" and peggiore == "OK 60"):
			peggiore = g
	_righe.append("GIUDIZIO: %s  (OK 60 = anche i fotogrammi peggiori restano sopra ~58 al secondo, su QUESTO computer)" % peggiore)
	var testo := "\n".join(_righe)
	print("VELOCITA_INIZIO\n" + testo + "\nVELOCITA_FINE")
	if rapporto_file != "":
		var f := FileAccess.open(rapporto_file, FileAccess.WRITE)
		if f:
			f.store_string(testo + "\n")
			f.close()
	get_tree().quit()

static func _temperatura() -> String:
	var f := FileAccess.open("/sys/class/thermal/thermal_zone0/temp", FileAccess.READ)
	if f == null:
		return "non disponibile"
	return "%.1f °C" % (float(f.get_line().strip_edges()) / 1000.0)
