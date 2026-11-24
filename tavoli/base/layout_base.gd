## Tavolo MODELLO «Base» del Pinball Editor 2D: solo la forma (sponda, corsia di lancio) e la ZONA BASSA COLLAUDATA
## (tavoli/base/zona_bassa.tavolo) (palette, fionde, grembiuli, corsie di ritorno, perno). È il punto di partenza di «Nuovo».
## La forma si sceglie tra quelle di FormaTavolo (classica, simmetrica, arco, …) o con numeri propri.
class_name LayoutBase

static func descrizione(forma = "classica") -> Dictionary:
	var f: Dictionary = FormaTavolo.FORME.get(forma, FormaTavolo.FORME["classica"]) if forma is String else forma
	var s: Dictionary = FormaTavolo.zona_bassa()
	var d := FormaTavolo.genera(f, s)
	d["raggio_pallina"] = s["raggio_pallina"]
	d["paletta_angoli"] = s["paletta_angoli"]
	d["bocca_rampa"] = s["bocca_rampa"]
	d["nome"] = "nuovo"
	d["titolo"] = "NUOVO TAVOLO"
	d["luci"] = "res://tavoli/base/luci_tavolo.gd"
	d["regole"] = "res://tavoli/base/regole_tavolo.gd"
	d["cartella_grafica"] = "res://grafica/_editor/"
	d["colori"] = {"primario": Color(1.0, 0.7, 0.3), "secondario": Color(0.4, 0.75, 1.0), "piano": Color(0.12, 0.13, 0.16),
		"piano_2": Color(0.16, 0.17, 0.2), "livello": Color(0.25, 0.2, 0.3), "palette": Color(0.97, 0.96, 0.94), "rampe": {}}
	d["livelli"] = {}
	d["rampe_solide"] = false
	for k in ["bumper", "bersagli", "buche", "passaggi", "rampe", "deviatori", "spinner", "captive", "elastici",
			"kickback", "campi", "inserti"]:
		d[k] = []
	return d
