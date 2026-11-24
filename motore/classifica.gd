## stesso titolare). Una classifica per tavolo, salvata in user://classifica_<nome del tavolo>.cfg.
## Si spegne dal tavolo con desc["classifica"] = false (resta solo il record, come prima).
class_name ClassificaTavolo
extends RefCounted

const POSTI := 10
const LETTERE := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
var salva := true                   # i test e le prove automatiche non toccano la classifica vera

var file := ""
var voci: Array = []                # [[iniziali, punti], …] dal primo al decimo

func _init(nome_tavolo: String, salva_file := true) -> void:
	salva = salva_file
	file = "user://classifica_%s.cfg" % (nome_tavolo.validate_filename().replace(" ", "_") if nome_tavolo != "" else "tavolo")
	for i in POSTI:
		voci.append(["---", 0])
	var cfg := ConfigFile.new()
	if salva and cfg.load(file) == OK:
		var v = cfg.get_value("classifica", "voci", null)
		if v is Array and v.size() == POSTI:
			voci = v

## Posto in classifica di questi punti (0 = primo), -1 = fuori dai 10.
func posizione(punti: int) -> int:
	if punti <= 0:
		return -1
	for i in voci.size():
		if punti > int(voci[i][1]):
			return i
	return -1

func inserisci(iniziali: String, punti: int) -> int:
	var i := posizione(punti)
	if i < 0:
		return -1
	voci.insert(i, [iniziali, punti])
	voci.resize(POSTI)
	if salva:
		var cfg := ConfigFile.new()
		cfg.set_value("classifica", "voci", voci)
		cfg.save(file)
	return i

func testo() -> String:
	var righe := PackedStringArray()
	for i in voci.size():
		righe.append("%2d.  %s   %s" % [i + 1, str(voci[i][0]), RegoleBase.formatta(int(voci[i][1])) if int(voci[i][1]) > 0 else "-"])
	return "\n".join(righe)
