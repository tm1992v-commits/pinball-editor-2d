## Binario: percorso sopraelevato (rampa, rotaia, passaggio segreto). La pallina lo percorre senza collisioni
## con il piano: la velocità cala in salita e cresce in discesa secondo la pendenza (fisica a una dimensione).
class_name Binario
extends RefCounted

var nome := ""
var punti := PackedVector2Array()
var altezze := PackedFloat32Array()      # metri grafici
var lunghezze := PackedFloat32Array()    # distanza cumulata in unità del tavolo
var lunghezza := 0.0
var cima := 1                            # indice del punto con l'energia potenziale più alta (la vera cima)
var cattura := false                     # true = alla fine la pallina resta ferma (buca)
var livello := 0                         # livello di gioco dell'imbocco
var livello_fine := 0                    # livello su cui la pallina scende alla fine
var quota_fine := 0.0                    # altezza grafica di quel livello
var quota_inizio := 0.0
var potenziale := PackedFloat32Array()   # energia potenziale di ogni punto (vedi _potenziale)
var precedente: Binario = null          # binario che porta in questo (la pallina che torna indietro ci risale)
## mezza larghezza variabile, come frazioni della lunghezza [0..1] -> mezza larghezza (mm). Vuoto = rampa normale.
var mezze_f := PackedFloat32Array()
var mezze_v := PackedFloat32Array()

func imposta_mezze(coppie: Array) -> void:
	mezze_f.clear()
	mezze_v.clear()
	for c in coppie:
		mezze_f.append(float(c[0]))
		mezze_v.append(float(c[1]))

func larga() -> bool:
	return mezze_f.size() >= 2

## Mezza larghezza nel punto s (solo per le rampe larghe).
func mezza(s: float) -> float:
	var f := clampf(s / maxf(lunghezza, 0.001), 0.0, 1.0)
	for i in range(1, mezze_f.size()):
		if f <= mezze_f[i]:
			var t := (f - mezze_f[i - 1]) / maxf(mezze_f[i] - mezze_f[i - 1], 0.0001)
			return lerpf(mezze_v[i - 1], mezze_v[i], t)
	return mezze_v[mezze_v.size() - 1]

const METRI_PER_UNITA := 1.0          # tavolo in millimetri: altezze in mm

const PASSO := 10.0                      # distanza tra i punti della curva levigata (unità del tavolo)

func _init(n: String, dati_grezzi: Array, fine_in_buca := false) -> void:
	nome = n
	cattura = fine_in_buca
	var dati := levigato(dati_grezzi)
	var acc := 0.0
	for i in dati.size():
		var v: Vector3 = dati[i]
		punti.append(Vector2(v.x, v.y))
		altezze.append(v.z)
		if i > 0:
			acc += punti[i].distance_to(punti[i - 1])
		lunghezze.append(acc)
	lunghezza = acc
	# potenziale più alta: sul binario la pallina sente due pendenze, quella della rampa (altezza) e quella del tavolo
	# inclinato (verso il giocatore = in discesa). Esempio: dal tetto del Castello il Lungomare sale ancora un po' e va
	# verso il fondo del tavolo, quindi la vera cima è più avanti. Da qui la pallina rotola solo per gravità.
	for i in punti.size():
		potenziale.append(_potenziale(punti[i], altezze[i]))
	var umax := -INF
	for i in potenziale.size():
		if potenziale[i] > umax + 0.001:
			umax = potenziale[i]
			cima = i

## Energia potenziale (per unità di massa, mm²/s²) di un punto del binario. Stesse regole di VPX/VPE: la gravità
## ha una parte lungo il piano inclinato (gravita, verso +y) e una perpendicolare (rampa_gravita, verso il basso).
## Valori in config/gioco.cfg: gravita = accelerazione della pallina che rotola sul piano, rampa_gravita = la stessa
## per la salita in altezza (5/7 di g per una sfera che rotola, come in VPX).
static func _potenziale(p: Vector2, h: float) -> float:
	return Parametri.f("rampa_gravita", 6500.0) * h - Parametri.f("gravita", 950.0) * p.y

## Accelerazione lungo il binario (mm/s², positiva = in avanti) data dalla sola gravità nel punto s.
func accelerazione(s: float) -> float:
	var i := _segmento(s)
	var dl := maxf(lunghezze[i + 1] - lunghezze[i], 0.001)
	return -(potenziale[i + 1] - potenziale[i]) / dl

## Energia potenziale nel punto s (per le prove: energia cinetica + potenziale non deve mai crescere).
func potenziale_in(s: float) -> float:
	var i := _segmento(s)
	var t := inverse_lerp(lunghezze[i], lunghezze[i + 1], clampf(s, 0.0, lunghezza))
	return lerpf(potenziale[i], potenziale[i + 1], t)

func _segmento(s: float) -> int:
	for i in range(1, lunghezze.size()):
		if s <= lunghezze[i]:
			return i - 1
	return lunghezze.size() - 2

func posizione(s: float) -> Vector2:
	var i := _segmento(s)
	var t := inverse_lerp(lunghezze[i], lunghezze[i + 1], clampf(s, 0.0, lunghezza))
	return punti[i].lerp(punti[i + 1], t)

func altezza(s: float) -> float:
	var i := _segmento(s)
	var t := inverse_lerp(lunghezze[i], lunghezze[i + 1], clampf(s, 0.0, lunghezza))
	return lerpf(altezze[i], altezze[i + 1], t)

func direzione(s: float) -> Vector2:
	var i := _segmento(s)
	return (punti[i + 1] - punti[i]).normalized()

## Pendenza (salita positiva) nel punto s.
func pendenza(s: float) -> float:
	var i := _segmento(s)
	var dl := maxf((lunghezze[i + 1] - lunghezze[i]) * METRI_PER_UNITA, 0.001)
	return (altezze[i + 1] - altezze[i]) / dl

## Distanza lungo il percorso del punto più vicino a p (in pianta).
func s_vicino(p: Vector2) -> float:
	var migliore := 0
	for i in punti.size():
		if punti[i].distance_to(p) < punti[migliore].distance_to(p):
			migliore = i
	return lunghezze[migliore]

func in_salita(s: float) -> bool:
	return s < lunghezze[cima]

## Curva morbida (Catmull-Rom) che passa per tutti i punti del disegno: niente spigoli, né per la pallina né
## per la grafica. Primo e ultimo punto restano identici (imbocchi e uscite non cambiano).
static func levigato(dati: Array) -> Array:
	if dati.size() < 3:
		return dati
	var out: Array = [dati[0]]
	for i in range(dati.size() - 1):
		var p0: Vector3 = dati[maxi(i - 1, 0)]
		var p1: Vector3 = dati[i]
		var p2: Vector3 = dati[i + 1]
		var p3: Vector3 = dati[mini(i + 2, dati.size() - 1)]
		var n := maxi(2, int(ceil(Vector2(p1.x, p1.y).distance_to(Vector2(p2.x, p2.y)) / PASSO)))
		for k in range(1, n + 1):
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			var v := 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)
			# l'altezza segue la stessa curva ma senza superare i valori dei due punti vicini
			v.z = clampf(v.z, minf(p1.z, p2.z), maxf(p1.z, p2.z))
			out.append(v)
	out[out.size() - 1] = dati[dati.size() - 1]
	return out
