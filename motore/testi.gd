## TESTI DEL TABELLONE in italiano o inglese (Pinball Editor 2D v0.13, 24/11/2026). La lingua si sceglie per tavolo
## nell'editor (desc["lingua"] = "it" | "en"); main.gd la imposta all'avvio. Il testo italiano è la chiave: se manca
## la traduzione resta in italiano (così niente si rompe). I tavoli finiti (Space…) restano in italiano.
class_name Testi

static var lingua := "it"

const EN := {
	"PALLINA %d": "BALL %d", "TIRA ANCORA": "SHOOT AGAIN", "pallina extra · pallina %d": "extra ball · ball %d",
	"RIGIOCO A %s PUNTI": "REPLAY AT %s POINTS", "PALLINA EXTRA = PUNTI": "EXTRA BALL = POINTS",
	"limite raggiunto  +": "limit reached  +", "PALLINA EXTRA!": "EXTRA BALL!", "a fine pallina TIRA ANCORA": "SHOOT AGAIN after this ball",
	"PALLINA EXTRA ACCESA": "EXTRA BALL LIT", "SALVA PALLINA": "BALL SAVED", "BONUS %s": "BONUS %s", "GAME OVER": "GAME OVER",
	"NUOVO RECORD!": "NEW HIGH SCORE!", "premi START": "press START", "TILT": "TILT", "ATTENZIONE": "DANGER",
	"PALLINA IN PIÙ!": "BONUS BALL!", "grazie per aver guardato il video": "thanks for watching the video",
	"VIDEO NON COMPLETATO": "VIDEO NOT COMPLETED", "nessuna pallina in più": "no bonus ball",
	"RECORD  %s": "HIGH SCORE  %s", "PALLINA %d / %d      BONUS x%d": "BALL %d / %d      BONUS x%d",
	# missioni
	"MISSIONE PRONTA": "MISSION READY", "SCEGLI": "CHOOSE", "COMPLETATA": "COMPLETE", "FALLITA": "FAILED",
	"FASE %d": "STAGE %d", "COMBO ×%d": "COMBO ×%d", "IN PAUSA": "ON HOLD", "RIPRENDE": "RESUME",
	"PRONTA": "READY", "MISSIONI": "MISSIONS", "fase": "stage", "tempo scaduto": "time is up",
	"tempo della fase scaduto": "stage time is up", "tira in ": "shoot ", " per iniziare": " to start",
	"CORSIE COMPLETE": "LANES COMPLETE", "MISSIONE": "MISSION", "CATTURATO": "CAPTURED", "COLLEZIONE COMPLETA!": "COLLECTION COMPLETE!", "EVOLUZIONE!": "EVOLUTION!", "TIENI!": "HOLD IT!", "per %d s": "for %d s", "SPENTO!": "LOST IT!", "ricomincia": "start again", "energia finita": "out of energy", "tieni vivo %s per %d s (un colpo ogni %d s)": "keep %s alive for %d s (a hit every %d s)",
	"ZONA": "ZONE", "comune": "common", "raro": "rare", "leggendario": "legendary",
	"un bumper": "a bumper", "un bersaglio": "a target", "una fila di bersagli tutta giù": "a full bank of drop targets",
	"tutte le corsie accese (cambio corsia)": "all lanes lit", "una rampa (fino in fondo)": "a ramp",
	"l'imbocco di una rampa": "a ramp entrance", "lo spinner": "the spinner", "una corsia (sensore)": "a lane",
	"una buca": "a hole", "una fionda": "a slingshot", "un paletto di gomma": "a rubber post", "il kickback": "the kickback",
	"un cancelletto": "a gate", "un portale": "a portal", "il lock": "the lock", "la captive ball": "the captive ball",
	"il bersaglio mobile": "the moving target", "un passaggio": "a passage", "qualsiasi pezzo": "anything",
	"colpisci tutti: ": "hit all: ", "in ordine: ": "in order: ", "HURRY-UP: presto, ": "HURRY-UP: quick, ",
	"colpisci %s": "hit %s", "gruppo ": "group ", "combo ×%d su %s (entro %.0f s l'uno dall'altro)": "combo ×%d on %s (within %.0f s)",
}

static func t(testo: String) -> String:
	if lingua == "en":
		return str(EN.get(testo, testo))
	return testo
