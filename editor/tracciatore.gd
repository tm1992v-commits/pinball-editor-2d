## TRACCIATORE (Pinball Editor 2D v0.9.5): lancia tools/tracciatore.tscn senza finestra sul tavolo di prova e legge il
## risultato. Lo usano il mouse (strumento «Traccia») e l'AI (comando "traccia"): stessi tiri, stesso motore.
class_name Tracciatore

## opz: da (Vector2), vel (Vector2 mm/s), tiri, variazione (gradi), secondi, livello. Bloccante (≈0,5 s a tiro).
static func esegui(desc: Dictionary, opz: Dictionary) -> Dictionary:
	var dir := ProjectSettings.globalize_path("user://prove")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := dir.path_join("traccia.tavolo")
	var u := dir.path_join("traccia.json")
	if FileTavolo.salva(desc, f) != OK:
		return {"ok": false, "errore": "non riesco a preparare il tavolo"}
	if FileAccess.file_exists(u):
		DirAccess.remove_absolute(u)
	var da: Vector2 = opz.get("da", Vector2(317, 600))
	var vel: Vector2 = opz.get("vel", Vector2(0, -1500))
	var args := ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "res://tools/tracciatore.tscn", "--",
		"--tavolo_file=" + f, "--da=%f,%f" % [da.x, da.y], "--vel=%f,%f" % [vel.x, vel.y],
		"--tiri=%d" % int(opz.get("tiri", 1)), "--variazione=%f" % float(opz.get("variazione", 0.0)),
		"--secondi=%f" % float(opz.get("secondi", 4.0)), "--livello=%d" % int(opz.get("livello", 0)), "--uscita=" + u]
	if str(opz.get("paletta", "")) != "":
		args.append_array(["--paletta=" + str(opz["paletta"]), "--colpi=%d" % int(opz.get("colpi", 5))])
	if float(opz.get("calore", 0.0)) > 0.0:
		args.append("--calore=%f" % float(opz["calore"]))
	OS.execute(OS.get_executable_path(), args, [], true)
	var r = JSON.parse_string(FileAccess.get_file_as_string(u)) if FileAccess.file_exists(u) else null
	if not r is Dictionary:
		return {"ok": false, "errore": "il motore non ha risposto"}
	r["da"] = da
	r["vel"] = vel
	r["opz"] = opz.duplicate()        # v0.18.1: per salvare il tiro come riferimento
	return r

# ================================================================ TIRI DI RIFERIMENTO (v0.18.1, Fase 3)
## Un tiro che funziona (es. «dalla paletta destra prendo la rampa») si salva con ciò che colpisce; dopo ogni
## modifica si rifà e si confronta: se ora colpisce altro o finisce diversamente, l'editor lo dice (prova di
## «non regressione»). I fionda/bumper colpiti cambiano facilmente per piccoli rimbalzi: contano i pezzi «obiettivo».
const OBIETTIVI := ["rampa", "rampa_entrata", "bersaglio", "buca", "captive", "sensore", "spinner", "cancello", "kickback", "lama", "prigione", "scoop"]

## Cosa ha colpito un tiro (pezzi obiettivo, senza ripetizioni, in ordine) e come è finito.
static func impronta(t: Dictionary) -> Dictionary:
	var colpi: Array = []
	for e in t.get("eventi", []):
		var k := "%s %s" % [e[1], e[2]]
		if str(e[1]) in OBIETTIVI and not k in colpi:
			colpi.append(k)
	return {"colpi": colpi, "fine": str(t.get("fine", ""))}

## Rifà i tiri salvati. Ritorna [{nome, ok, prima, ora, testo}].
static func verifica(desc: Dictionary) -> Array:
	var out: Array = []
	for rif in desc.get("tiri_riferimento", []):
		if not rif is Dictionary:
			continue
		var o: Dictionary = (rif.get("opz", {}) as Dictionary).duplicate()
		o["tiri"] = 1
		o["variazione"] = 0.0
		var r := esegui(desc, o)
		var ora := impronta(r["tiri"][0]) if bool(r.get("ok", false)) and not r.get("tiri", []).is_empty() else {"colpi": [], "fine": "errore"}
		var prima: Dictionary = rif.get("atteso", {})
		var persi: Array = (prima.get("colpi", []) as Array).filter(func(x): return not x in ora["colpi"])
		var nuovi: Array = (ora["colpi"] as Array).filter(func(x): return not x in prima.get("colpi", []))
		var ok := persi.is_empty() and str(prima.get("fine", "")) == str(ora["fine"])
		var testo := "«%s»: %s" % [rif.get("nome", "tiro"), "come prima" if ok and nuovi.is_empty() else ""]
		if not persi.is_empty():
			testo += "NON colpisce più %s. " % ", ".join(persi)
		if not nuovi.is_empty():
			testo += "ora colpisce anche %s. " % ", ".join(nuovi)
		if str(prima.get("fine", "")) != str(ora["fine"]):
			testo += "finiva «%s», ora «%s»." % [prima.get("fine", ""), ora["fine"]]
		out.append({"nome": rif.get("nome", "tiro"), "ok": ok, "prima": prima, "ora": ora, "testo": testo.strip_edges()})
	return out

## Riassunto in parole semplici: cosa ha colpito e come è finita.
static func riassunto(r: Dictionary) -> String:
	if not bool(r.get("ok", false)):
		return "Traccia non riuscita: " + str(r.get("errore", "?"))
	if r.has("calore"):
		return "Mappa di calore: %.0f s di gioco automatico, %d palline, %d quadretti toccati" % [float(r.get("secondi", 0)), int(r.get("palline", 0)), (r["calore"] as Dictionary).size()]
	var fini := {"scarico": "persa nello scarico", "buca": "entrata in una buca", "ferma": "FERMA (si incastra?)", "fuori": "USCITA dal tavolo", "tempo": "ancora in gioco"}
	var righe: Array = []
	for t in r.get("tiri", []):
		var colpi := {}
		for e in t.get("eventi", []):
			var k := "%s %s" % [e[1], e[2]]
			colpi[k] = int(colpi.get(k, 0)) + 1
		var elenco: Array = []
		for k in colpi:
			elenco.append(k + (" ×%d" % colpi[k] if colpi[k] > 1 else ""))
		righe.append("%s%.1f s, %s; colpi: %s" % [(("dal %d%% della paletta: " % int(float(t["frazione"]) * 100.0)) if t.has("frazione") else ("tiro %+.1f°: " % float(t["angolo"]))) if r["tiri"].size() > 1 else "", float(t["durata"]), fini.get(str(t["fine"]), str(t["fine"])), ", ".join(elenco) if not elenco.is_empty() else "nessuno"])
	return "\n".join(righe)
