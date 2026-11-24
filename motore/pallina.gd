## Pallina d'acciaio: corpo rigido 2D con collisione continua (CCD). Le spinte esterne (bumper, fionde, nudge)
## si applicano nel passo fisico; sui binari la pallina segue il percorso con una fisica a una dimensione.
class_name Pallina
extends RigidBody2D

signal binario_finito(pallina: Pallina, binario: Binario, completato: bool)

var _spinte: Array = []
var _aggiunte := Vector2.ZERO
var _teletrasporto = null
var tenuta := false
var punto_tenuta := Vector2.ZERO
var ferma_da := 0.0
## anti ping-pong: punto di riferimento e da quanto la pallina gli resta vicina (anche rimbalzando)
var ancora := Vector2(-999, -999)
var ancora_t := 0.0
## colpi di fionda di fila (per rompere il ping-pong tra le due fionde) e quando è arrivato l'ultimo
var fionde_fila := 0
var ultima_fionda := -99.0
## colpi di barile di fila nel Molo (per non restare intrappolata a rimbalzare)
var barili_fila := 0
var ultimo_barile := -99.0
var ignora_buche := 0.0
var dal_lancio := 99.0
var altezza := 0.0                     # metri grafici (0 = sul piano)
var nascosta := false                  # sotto il tavolo (passaggi segreti, cassa): non si disegna, non collide
## livello di gioco: 0 = piano principale, 1, 2… = piani rialzati (mini-playfield). La pallina tocca solo gli oggetti
## del suo livello (strato di collisione 1 << livello); "quota" = altezza grafica di quel piano in mm.
var livello := 0
var quota := 0.0
var catena: Array = []                 # rampe concatenate già percorse (si contano solo a percorso finito)
var vel_uscita_binario := 0.0          # velocità lungo il binario quando lo ha lasciato (per i binari concatenati)

# binario
var binario: Binario = null
var _s := 0.0
var _v := 0.0

static func bit(l: int) -> int:
	return 1 << l

func imposta_livello(l: int, q := 0.0) -> void:
	livello = l
	quota = q
	collision_layer = bit(l)
	collision_mask = bit(l)

func _ready() -> void:
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 4

func respingi(direzione: Vector2, velocita_min: float) -> void:
	_spinte.append([direzione, velocita_min])

func aggiungi_vel(v: Vector2) -> void:
	_aggiunte += v

func metti(posizione: Vector2, velocita: Vector2) -> void:
	_teletrasporto = [posizione, velocita]

func tieni(p: Vector2) -> void:
	tenuta = true
	punto_tenuta = p

func rilascia(velocita: Vector2) -> void:
	tenuta = false
	ignora_buche = 0.6
	metti(punto_tenuta, velocita)

## laterale = distanza dal centro della rampa all'entrata (si annulla nei primi CENTRO_RAMPA mm, come una pallina
## che le sponde accompagnano al centro); da = quanto è già dentro l'imbocco. Così la pallina non «salta» sul binario.
const CENTRO_RAMPA := 60.0
var _caduta := 0.0                   # mm sopra il piano mentre cade dalla fine sospesa di una rampa (solo grafica)
var _vel_caduta := 0.0
var _laterale := 0.0
var _lat_frazione := 0.0              # v0.17.1: posizione laterale sul nastro largo (-1..1 dello spazio libero)

## allora la velocità è negativa e la rampa è «completata» quando arriva all'imbocco.
var _inverso := false

func sali_su(b: Binario, velocita: float, laterale := 0.0, da := 0.0, inverso := false) -> void:
	binario = b
	_inverso = inverso
	_s = clampf(da, b.lunghezza * 0.5, b.lunghezza) if inverso else clampf(da, 0.0, b.lunghezza * 0.5)
	_laterale = clampf(laterale, -12.0, 12.0)
	# v0.17.1: sul nastro largo la pallina resta dov'è entrata, poi le pareti che si stringono la portano al centro
	_lat_frazione = 0.0
	if b.larga():
		var libero := maxf(b.mezza(_s) - 14.0, 1.0)
		_lat_frazione = clampf(laterale / libero, -1.0, 1.0)
	_v = velocita
	_teletrasporto = null
	tenuta = false
	collision_layer = 0
	collision_mask = 0
	# spinte rimaste da un colpo nello stesso istante (bumper, fionda): non devono partire all'uscita della rampa,
	_spinte.clear()
	_aggiunte = Vector2.ZERO

## La pallina sparisce (entra in una buca o nella cassa): ferma, invisibile, senza collisioni.
func nascondi(p: Vector2) -> void:
	binario = null
	altezza = 0.0
	nascosta = true
	collision_layer = 0
	collision_mask = 0
	tieni(p)

## Riappare da un cannone con la velocità data.
func riappari(p: Vector2, velocita: Vector2, liv := 0, q := 0.0) -> void:
	nascosta = false
	imposta_livello(liv, q)
	tenuta = false
	ignora_buche = 0.5
	metti(p, velocita)

## Distanza percorsa sul binario attuale (per la scia di luce sotto le rampe).
func posizione_binario() -> float:
	return _s

## true se la pallina sta per essere spostata (la sua posizione attuale non è ancora quella nuova).
func in_spostamento() -> bool:
	return _teletrasporto != null

func sul_binario() -> bool:
	return binario != null

func _scendi(posizione: Vector2, velocita: Vector2, completato: bool) -> void:
	var b := binario
	binario = null
	if completato:
		imposta_livello(b.livello_fine, b.quota_fine)
	else:
		imposta_livello(b.livello, b.quota_inizio)
	altezza = quota
	# uscita sospesa (filo che finisce sopra la corsia, 21/11): la pallina cade dall'altezza della fine della rampa
	if completato:
		_caduta = maxf(b.altezze[b.altezze.size() - 1] - quota, 0.0)
		_vel_caduta = 0.0
	vel_uscita_binario = absf(_v)
	ignora_buche = 0.3
	if b.cattura and completato:
		tieni(b.punti[b.punti.size() - 1])
	else:
		# fine di una rampa: la gomma e il filo della corsia frenano la pallina (troppo veloce rimbalzava sulla paletta)
		if completato:
			velocita = velocita.limit_length(Parametri.f("rampa_vel_uscita_max", 1100.0))
		metti(posizione, velocita)
	binario_finito.emit(self, b, completato)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var dt := state.step
	if binario != null:
		var b := binario
		#  - la gravità, con la pendenza della rampa E quella del tavolo (Binario.accelerazione);
		#  - l'attrito di rotolamento, che frena e basta: non può mai invertire il moto, e a velocità quasi zero
		#    si annulla (una sfera d'acciaio su plastica o filo non resta incollata su un pendio).
		# Tolte le due forze finte di prima: la velocità minima di 280 mm/s imposta appena passata la cima (la
		# pallina che arrivava strisciando veniva tirata su) e la spinta all'indietro dopo 0,25 s quasi ferma.
		# Se la pallina non ha energia per la cima, rallenta, si ferma e torna giù da sola.
		# Passo «a energia esatta»: si sposta la pallina, poi la velocità viene dal bilancio dell'energia
		# (v² nuova = v² vecchia - 2 × differenza di energia potenziale). Così non può nascere energia dal nulla
		# nemmeno per arrotondamento, a nessuna velocità. Dove la pallina si ferma (v² < 0) inverte il moto.
		var frena := Parametri.f("rampa_attrito", 140.0) * clampf(absf(_v) / 30.0, 0.0, 1.0) * dt
		var a := b.accelerazione(_s)
		var s_nuovo := _s + (_v + 0.5 * a * dt) * dt
		if absf(_v) > 60.0 and s_nuovo > 0.0 and s_nuovo < b.lunghezza:
			var v2 := _v * _v - 2.0 * (b.potenziale_in(s_nuovo) - b.potenziale_in(_s))
			_v = signf(_v) * sqrt(v2) if v2 > 0.0 else -signf(_v) * 1.0
		else:
			_v += a * dt
		_v = signf(_v) * maxf(absf(_v) - frena, 0.0)
		# binario che torna indietro dentro quello da cui arriva (Lungomare → Rampa del Castello, discesa → Via Etnea):
		# la pallina ripercorre la rampa all'indietro invece di cadere dal tetto
		if _s + _v * dt <= 0.0 and _v < 0.0 and b.precedente != null:
			binario = b.precedente
			_s = binario.lunghezza + _s
			b = binario
		_s += _v * dt
		altezza = b.altezza(clampf(_s, 0.0, b.lunghezza))
		var sc := clampf(_s, 0.0, b.lunghezza)
		var lat := _laterale * clampf(1.0 - (b.lunghezza - sc if _inverso else sc) / CENTRO_RAMPA, 0.0, 1.0)
		if b.larga():
			lat = _lat_frazione * maxf(b.mezza(sc) - 14.0, 0.0)
		state.transform = Transform2D(0, b.posizione(sc) + b.direzione(sc).orthogonal() * lat)
		state.linear_velocity = Vector2.ZERO
		_v_prima = Vector2.ZERO
		if _s >= b.lunghezza:
			var fine := b.punti[b.punti.size() - 1]
			if _inverso:
				fine += b.direzione(b.lunghezza - 1.0) * 6.0
			_scendi(fine, b.direzione(b.lunghezza - 1.0) * _v, not _inverso)
		elif _s <= 0.0 and _v <= 0.0:
			_scendi(b.punti[0] - b.direzione(0.0) * 6.0, -b.direzione(0.0) * maxf(-_v, 0.0), _inverso)
		return
	if _caduta > 0.0:
		_vel_caduta += 9810.0 * dt
		_caduta = maxf(_caduta - _vel_caduta * dt, 0.0)
	altezza = quota + _caduta
	if _teletrasporto != null:
		state.transform = Transform2D(0, _teletrasporto[0])
		state.linear_velocity = _teletrasporto[1]
		state.angular_velocity = 0
		_v_prima = _teletrasporto[1]
		_teletrasporto = null
	if tenuta:
		state.transform = Transform2D(0, punto_tenuta)
		state.linear_velocity = Vector2.ZERO
		_v_prima = Vector2.ZERO
		_spinte.clear()
		_aggiunte = Vector2.ZERO
		return
	var v := state.linear_velocity + _aggiunte
	_aggiunte = Vector2.ZERO
	v = _calo_rimbalzo(state, v)
	for sp in _spinte:
		var dir: Vector2 = sp[0]
		var vn := v.dot(dir)
		if vn < sp[1]:
			v += dir * (sp[1] - vn)
	_spinte.clear()
	var vmax := Parametri.f("velocita_max", 2600.0)
	if v.length() > vmax:
		v = v.normalized() * vmax
	state.linear_velocity = v
	_v_prima = v

## CALO DEL RIMBALZO («falloff» di VPX, Pinball Editor 2D 24/11). Misura prima della modifica (tools/misura_rimbalzi):
## la gomma restituiva sempre il 75% della velocità, anche a 3 m/s; in VPX (gomma 0,80, calo 0,30) a 3 m/s il 42%.
## Qui, appena la pallina è rimbalzata su un materiale col «calo», la parte perpendicolare della velocità d'uscita
## si riduce di 1 / (1 + calo × (velocità d'arrivo − 300 mm/s) / 1000): sotto 300 mm/s non cambia niente.
var _v_prima := Vector2.ZERO

func _calo_rimbalzo(state: PhysicsDirectBodyState2D, v: Vector2) -> Vector2:
	for i in state.get_contact_count():
		var o = state.get_contact_collider_object(i)
		if not o is PhysicsBody2D or not "physics_material_override" in o or o.physics_material_override == null:
			continue
		var calo := float(o.physics_material_override.get_meta("calo", 0.0))
		if calo <= 0.0:
			continue
		var n := state.get_contact_local_normal(i)
		if _v_prima.dot(n) > 0.0:
			n = -n
		var arrivo := -_v_prima.dot(n)
		var uscita := v.dot(n)
		if arrivo > 300.0 and uscita > 0.0:
			var k := 1.0 / (1.0 + calo * (arrivo - 300.0) / 1000.0)
			v -= n * uscita * (1.0 - k)
			break
	return v
