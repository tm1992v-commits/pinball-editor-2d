## File del tavolo (Pinball Editor 2D, 23/11/2026): il tavolo descritto a numeri (mm) salvato e riletto SENZA perdite.
## Formato: testo leggibile di Godot (`var_to_str`, lo stesso dei file .tres): simile al JSON, ma vettori, colori, interi e
## liste di punti restano del loro tipo (il JSON puro trasforma tutti i numeri in decimali e i vettori in liste).
## È lo stesso dizionario che oggi restituisce `layout_*.gd → descrizione()`: il motore non cambia.
class_name FileTavolo

const VERSIONE_FORMATO := 1
const REGOLE_BASE := "res://tavoli/base/regole_tavolo.gd"
const LUCI_BASE := "res://tavoli/base/luci_tavolo.gd"

static func salva(desc: Dictionary, percorso: String) -> Error:
	var dati := {"formato": VERSIONE_FORMATO, "tavolo": desc}
	# salvataggio sicuro: prima un file temporaneo, poi si sostituisce l'originale (mai un file a metà)
	var tmp := percorso + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(var_to_str(dati))
	f.close()
	if leggi(tmp).is_empty():
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(percorso):
		var dir := DirAccess.open(percorso.get_base_dir())
		dir.copy(percorso, percorso + ".prima")
	return DirAccess.rename_absolute(tmp, percorso)

static func leggi(percorso: String) -> Dictionary:
	if not FileAccess.file_exists(percorso):
		return {}
	var testo := FileAccess.get_file_as_string(percorso)
	var dati = str_to_var(testo)
	if not dati is Dictionary or not dati.has("tavolo") or not dati["tavolo"] is Dictionary:
		return {}
	return dati["tavolo"]
