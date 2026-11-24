# PINBALL EDITOR 2D – Manuale
**Versione 0.26.1** (manuale completo in italiano; in inglese: docs/USER_GUIDE.md) · Created by Carmelo Vadalà · Open Source Community Project

## 1. Avviare l'editor
- Serve **Godot 4.7.2** (gratis, https://godotengine.org).
- Dalla cartella del progetto: `godot --path . res://editor/editor.tscn` oppure `./avvia_editor.sh`.
- I tavoli si salvano nella cartella `progetti/` accanto al progetto (si crea da sola).

## 2. Com'è fatta la finestra
```
┌ Nuovo Apri Salva «Salva con nome» │ Annulla Ripristina │ Modalità │ Griglia ─────── ▶ GIOCA  ✔ CONTROLLA ┐
│ STRUMENTI e PEZZI   │              IL TAVOLO (dall'alto, in mm veri)              │ PROPRIETÀ del pezzo │
│ a icone (sinistra)  │                                                            │ o FORMA del tavolo  │
│                     ├────────────────────────────────────────────────────────────┤                     │
│                     │ Problemi │ Pezzi │ Diario   (in basso)                     │                     │
└ riga dei messaggi: ti dice sempre cosa è appena successo o cosa fare ────────── mouse: x × y mm ───────┘
```
- **Riga dei messaggi** (in fondo a sinistra): leggila sempre, ti guida passo per passo.
- **mouse: x × y mm** (in fondo a destra): dove si trova il mouse sul tavolo, in millimetri.

## 3. Muoversi sul tavolo
| Cosa vuoi fare | Come |
|---|---|
| Ingrandire / rimpicciolire | **rotella** del mouse (ingrandisce dove punti) |
| Spostare la vista | tieni premuto il **tasto destro** (o la rotella) e trascina |
| Griglia | interruttore **«Griglia e aggancio 5 mm»**: i pezzi si posizionano a scatti di 5 mm. Spegnilo per muoverli liberamente |

## 4. Creare un tavolo nuovo
1. Premi **Nuovo**: si apre una finestra con due file di disegni.
     Arco (mezzo cerchio in alto), Squadrata, Larga (700 mm), Stretta (580 mm). Clicca quella che vuoi.
   - **2. Il TAVOLO PRONTO**: «Solo zona bassa» (vuoto, lo riempi tu), **Arena** (4 bumper e pozzo di gravità),
     **Classico** (3 bumper, corsie in alto, bersagli, spinner, buca), **Largo** (5 bumper, bersagli a molla, magnete),
2. Premi **Crea il tavolo**. Puoi combinare: per esempio forma «Arco» + tavolo «Classico».
3. Premi **Salva con nome**, scrivi il nome (es. `Vulcano`) e premi **Salva** (o Invio). Il tavolo va nella cartella
   `progetti` come `Vulcano.pinproj`. Se il nome esiste già, l'editor te lo dice e non sovrascrive.
4. Da quel momento **Salva** (o **Ctrl+S**) salva sempre lì.

I tavoli pronti sono stati provati: nessun varco pericoloso e nessuna pallina incastrata.

## 4b. Cambiare la FORMA del tavolo (la parte esterna)
1. Clicca su un punto **vuoto** del tavolo (o premi **Esc** e poi clic sul vuoto): a destra compare **TAVOLO**.
2. In **FORMA DEL TAVOLO** clicca uno dei 6 disegni: la sponda cambia subito.
3. Per regolarla tu, trascina le tre barre:
   - **Larghezza** (560-720 mm);
   - **Curva dell'angolo sinistro** e **dell'angolo destro** (più grande = curva più ampia).
4. **Rendi simmetrico**: i due angoli in alto diventano uguali.
5. **Sponda a mano**: sceglie la sponda e puoi spostarne i punti uno per uno (quadratini gialli), per forme libere.
6. La **zona bassa** (palette, fionde, corsie, lancio) si adatta da sola; gli altri pezzi restano e, se cambia la
   larghezza, si allargano o si stringono in proporzione. Tutto si annulla con **Ctrl+Z**.
7. Dopo un cambio di forma premi **CONTROLLA**.

## 5. Aggiungere i pezzi
A sinistra ci sono le **icone**: in cima **Seleziona** (la freccia), sotto i **pezzi**.
1. Clicca l'icona del pezzo, es. **Bumper** (resta accesa).
2. Clicca sul tavolo dove lo vuoi: il bumper compare ed è **già scelto** (cerchio giallo).
3. Puoi continuare a cliccare per metterne altri uguali.
4. Per tornare a scegliere e spostare: icona **Seleziona** (o tasto **Esc**).

Pezzi in **SEMPLICE**: Bumper, **Fionda**, **Paletta**, Spinner, **Sensore**, **Corsia**, **3 corsie**, Bersaglio, Buca,
Luce, Muro, **Gomma**, **Isola**, **Rampa**.

**Sensore** = linea invisibile che conta la pallina che passa (punti, missioni): non la ferma e non la spinge. Va messo
in mezzo a una corsia. **Corsia** = due guide + sensore + luce già pronti con un clic; **3 corsie** = le tre corsie in
alto (come nel tavolo Classico).
In **PRO** in più: Paletto di gomma, Kickback, Pozzo di gravità / magnete.

**Esempio:** 3 bumper a triangolo in alto: icona Bumper → clic a 250 × 330, clic a 380 × 330, clic a 315 × 430
(guarda i numeri «mouse» in basso a destra), poi Seleziona.

## 6. Scegliere, spostare, cambiare un pezzo
| Cosa | Come |
|---|---|
| Scegliere un pezzo | clic sopra (diventa giallo). Oppure scheda **Pezzi** in basso → clic sul nome |
| Spostarlo | trascinalo col mouse, oppure **frecce** della tastiera (1 mm; con **Maiusc** 10 mm) |
| Cambiare misure e opzioni | a destra, nelle **Proprietà**: scrivi il numero o usa le freccette |
| Ruotarlo | pulsante **Ruota 15°**, oppure tasto **R** (Maiusc+R al contrario). Per un angolo preciso: campo «Rotazione» |
| Copiarlo | **Duplica** (o **Ctrl+D**): la copia compare spostata di 3 cm |
| Copiarlo dall'altra parte | **⇋ Copia a specchio** (o **Ctrl+M**): stesso pezzo, simmetrico rispetto al centro tra le palette. Per le palette inverte anche il lato e il tasto |
| Toglierlo | **Elimina** (o tasto **Canc**) |
| Annullare un errore | **Annulla** (Ctrl+Z) — fino a 200 passi indietro. **Ripristina** (Ctrl+Y) |
| Dargli un nome | in **PRO**: campo **Nome (id)** in alto nelle proprietà, poi Invio (servirà per missioni e luci) |

**Modalità SEMPLICE / PRO** (pulsante in alto): in SEMPLICE vedi meno pezzi e solo le proprietà principali; in PRO
tutto (pezzi tecnici, nome/id dei pezzi, direzione d'uscita delle buche, forza del pozzo, senso unico dei muri). Non si
perde niente cambiando.

## Come si FINISCE un muro, una rampa o un nastro (importante)
Mentre disegni compare in alto sul tavolo una barra gialla con tre pulsanti:
- **✔ FINE**: il pezzo è fatto (oppure **clic destro**, **Invio** o **doppio clic**);
- **✖ Annulla**: butta via il disegno (oppure **Esc**);
- **↶ Togli l'ultimo punto**: se hai cliccato nel posto sbagliato.
Se premi GIOCA, CONTROLLA, Salva o scegli un altro strumento, il disegno si chiude da solo (non resta appeso).

## 7. Disegnare muri, curve, fionde e gomme (forme a punti, come in Visual Pinball)
Ogni muro è fatto di **punti**. Ogni punto può essere **ad angolo** (quadratino) o **curvo** (cerchietto): con i punti
curvi la linea passa morbida, così un'orbita o un arco si fanno con 3-4 punti.
1. Icona **Muro**, poi clic sul tavolo punto dopo punto:
   - **clic** = punto ad angolo; **Maiusc+clic** = punto **curvo**;
   - **Invio** o **doppio clic** per finire, **Esc** per annullare.
   - (0.9.3) Mentre disegni la linea gialla mostra **già la curva**; se tieni premuto **Maiusc** vedi subito come
     verrà il punto curvo prima di cliccare. Punto curvo = **cerchietto**, ad angolo = **quadratino**.
2. Per correggerlo: sceglilo (clic sulla linea) e compaiono i punti gialli:
   - **trascina** un punto per spostarlo;
   - **clic** su un punto per sceglierlo (cerchio bianco): a destra, in **PUNTI**, spunta **Curvo** o
     **Fionda** (il tratto da quel punto al successivo diventa una **fionda** che spinge la pallina, più forte al
     centro, come nelle macchine vere);
   - **Tutti curvi** / **Tutti ad angolo** per tutta la forma;
   - **doppio clic** sulla linea per aggiungere un punto, **clic destro** su un punto per toglierlo.
3. Nelle proprietà: **Materiale** (metallo, legno, gomma) e **Forma chiusa** (spunta = blocco/isola chiusa;
   senza = guida aperta). In PRO anche la **forza dei tratti-fionda**.

**Forme pronte** (un clic sul tavolo, poi le modifichi punto per punto):
- **Fionda**: triangolo di gomma con il lato lungo che spinge. In gioco la **gomma si tende** quando la pallina la
  colpisce. Per quella dall'altra parte: **Copia a specchio**. Puoi spostarne i punti e darle la forma che vuoi.
- **Gomma**: anello di gomma ovale e curvo, da allungare intorno a paletti o tra due guide.
- **Isola**: blocco chiuso con i bordi curvi.

Anche i **muri già esistenti** (zona bassa, sponde) si modificano così.

## 7c. Rampe e binari a fili
1. Icona **Rampa**, poi clic sull'**IMBOCCO** (dove la pallina entra: il punto a terra, rivolto verso le palette), poi
   i punti del percorso; **Invio** o **doppio clic** per finire. Il motore fa passare la rampa morbida tra i punti.
2. L'editor dà da solo le **altezze**: parte da 0 mm, sale fino a ~45 mm a metà e riscende a terra alla fine. Ogni
   punto mostra la sua altezza («43 mm»).
3. Per cambiarle: scegli la rampa, **clicca un punto** e a destra scrivi l'**altezza** (0-120 mm). Oppure i
   pulsanti **Sale e riscende** o **Uscita sospesa** (finisce in alto a 32 mm e la pallina cade sul piano, per
   esempio sopra una corsia di ritorno).
4. Nelle proprietà, **Tipo**: **rampa di plastica** oppure **binario a fili** (in gioco si vede diverso).
   (0.9.3) Opzioni prese dal nastro:
   - **Colore** della rampa (pulsante «Colore del tavolo» per tornare a quello normale) e **Frecce sul fondo**;
   - **TUTTA LA RAMPA → Altezza del punto più alto**: alzi o abbassi tutta la rampa, gli altri punti in proporzione;
   - **Larghezza dell'imbocco** (38-90 mm): l'entrata a terra si allarga a imbuto e si stringe in 3 cm. È vera anche
     nel gioco: più larga = più facile da prendere.
   - La rampa è **sempre morbida** (il motore la fa passare curva tra i punti): non serve Maiusc. Per una corsia larga
     con larghezza punto per punto e pareti, usa il **Nastro** alzato (diventa una rampa).
5. Rampe e binari passano **sopra** gli altri pezzi: sotto la pallina continua a giocare sul piano.
6. In gioco: se il tiro è debole la pallina **torna indietro** (come nei flipper veri).

## 7d. Il NASTRO (corsia o rampa larga)
1. Icona **Nastro**, poi clic sull'**INGRESSO** e sui punti del percorso (Maiusc+clic = curvo); Invio per finire.
2. A destra, in **INGRESSO, USCITA E CORSIA**:
   - **Larghezza dell'ingresso** e **dell'uscita** (es. ingresso largo 80 che si stringe a 50);
   - **Larghezza di tutta la corsia**;
   - **Altezza di tutto il nastro**: 0 = **corsia a terra** con due pareti vere; più alto = diventa una **rampa**.
3. Clicca un punto: **larghezza** e **altezza** solo lì (per esempio che sale piano e finisce sospeso).
4. Proprietà: **Colore**, **Aspetto** (**effetto 3D** con ombra, spessore e pareti in luce, oppure **piatto**),
   **parete a sinistra / a destra** (si possono togliere), **altezza delle pareti**, **frecce** sul fondo (facoltative).
5. Si sposta, si copia a specchio, si ridimensiona come tutti gli altri pezzi.

**(0.17.1) Nastro alzato e rampe sono SOLIDI dove sono bassi** (meno di 3 cm sopra il tavolo): la pallina che corre
sul tavolo ci sbatte contro le pareti, come su una rampa vera; dove sono alti ci passa sotto. Sul nastro le pareti sono
larghe come il nastro disegnato e la bocca è larga come l'ingresso (la pallina sale anche entrando di lato).
Per una rampa che vuoi «trasparente» spegni **Solida dove è bassa** nel suo pannello.
**Attenzione:** non mettere la bocca di una rampa o di un nastro **attaccata** a una guida o sopra una corsia: la
pallina può incastrarsi tra la bocca e la guida. CONTROLLA lo segnala in rosso col cerchio.

## 7f. ASPETTO: effetto 3D o piatto, e i colori (novità 0.5)
**Come si vede ora.** In **effetto 3D** il tavolo si guarda un po' inclinato, come nella tua tavola spaziale: ogni pezzo
ha la **base** dove tocca la pallina e la **cima più in alto**; in mezzo si vedono i **fianchi**, con luce da sinistra e
ombre morbide in basso a destra. I **bumper** sono alti, con la gonna a strisce e la cupola lucida (in gioco la cupola si
accende con le luci); **bersagli** in piedi; **paletti** di gomma; **buche** con la parete dentro; **fionde** a blocco
con la gomma a tubo e i paletti cromati; **palette** spesse; **muri** di legno a blocco e guide di metallo a tubo;
il **nastro** sollevato si vede più in alto, con lo spessore, i **sostegni** fino al piano e l'ombra sotto. Nell'editor
il nastro sollevato ha anche una **linea tratteggiata** sul piano: è la sua «pianta», dove stanno i punti da trascinare.

**Tutto il tavolo** (nessun pezzo scelto, pannello a destra → **ASPETTO DEL TAVOLO**):
1. Scegli **effetto 3D** oppure **piatto**: vale per tutti i pezzi che sono «come il tavolo».
2. **Uguale per tutti i pezzi**: anche quelli a cui avevi dato un aspetto proprio tornano come il tavolo.
3. **Colore 1** (palette, paletti, fionde, strisce dei bumper), **Colore 2** (bumper, gomme), **Colore del piano**:
   clic sul colore, scegli, chiudi la tavolozza.

**Un pezzo solo** (scegli il pezzo → sezione **ASPETTO**): **Aspetto** = come il tavolo / effetto 3D / piatto;
**Colore** proprio (il pulsante **Colore del tavolo** lo toglie); per i bumper anche **Colore delle strisce**, per le
fionde **Colore della plastica dentro**.

**Più pezzi insieme** (Maiusc+clic o rettangolo): in fondo al pannello **ASPETTO DEI PEZZI SCELTI** e **Colore dei
pezzi scelti**: si cambiano tutti con un solo passo (un Ctrl+Z li rimette come prima).

**Altezza nel disegno 3D** (0.6): nella sezione ASPETTO di ogni pezzo (bumper 34 mm, bersagli 18, fionde 20…). Più
alta = il pezzo si vede più alto, con fianchi e ombra più lunghi. Non cambia la fisica, solo il disegno. Per i muri
c'è «Altezza» in modalità PRO.

## 7g. IMMAGINI TUE sui pezzi (novità 0.6)
1. Scegli il pezzo (bumper, bersaglio, fionda, paletta, spinner, buca, paletto, muro, kickback).
2. A destra, sezione **IMMAGINE TUA** → **Scegli immagine…** → un file **PNG, JPG o WEBP** (meglio PNG con lo sfondo
   trasparente). L'immagine **entra nel file del tavolo** (ridotta a massimo 1024 px): viaggia con lui, non si perde.
3. **Come il pezzo** = copre tutto il pezzo (es. tutto il bumper); **Al centro** = piccola al centro (es. sulla cupola).
4. **Mostra**: *sopra il disegno del pezzo* (il bumper 3D resta, l'immagine è in cima) oppure *al posto del disegno*
   (si vede solo la tua immagine, con l'ombra sotto se il tavolo è in 3D).
5. **Col mouse** (0.7.1): sul pezzo scelto compaiono due maniglie azzurre: il **rombo** al centro dell'immagine la
   **sposta**, il **quadratino** nell'angolo la **ingrandisce o rimpicciolisce** (proporzioni mantenute). Ctrl+Z annulla.
   Oppure coi numeri: **Larghezza e altezza** (con «Mantieni le proporzioni»), **Spostamento dal centro**, **Rotazione**.
6. **Togli immagine**: il pezzo torna col suo disegno. Tutto si annulla con Ctrl+Z.
- Sulla **paletta** l'immagine gira insieme alla paletta.
- La stessa immagine usata su più pezzi è salvata una volta sola.

## 7i. FONDO DIPINTO e IMMAGINI SUL PIANO (novità 0.6)
**Fondo dipinto** (come la tua tavola spaziale): nessun pezzo scelto → pannello a destra → **FONDO DIPINTO** →
**Scegli immagine…**. Copre tutto il tavolo dentro la sponda (meglio un'immagine verticale, come il tavolo; viene
ridotta a massimo 2048 px). **Togli fondo** per tornare al piano colorato.

**Immagine sul piano** (pianeti, scritte, loghi, frecce dipinte): icona **Immagine** (in fondo agli strumenti) → clic
sul tavolo dove la vuoi → a destra **Scegli immagine…**. Poi si usa come gli altri pezzi:
- si **trascina col mouse**; **Ingrandisci / Rimpicciolisci** (tasti + e −), **Ruota 15°**, **Capovolgi**, **Duplica**;
- a destra: **Larghezza e altezza**, **Rotazione**, **Trasparenza** (1 = piena), **A specchio**;
  **Proporzioni dell'immagine** rimette le proporzioni giuste; in PRO **Sopra i pezzi** (altrimenti è dipinta sul piano,
  sotto bumper e palline).
- La pallina ci passa sopra: le immagini non cambiano la fisica.

## 7h. 🖼 RENDERIZZA: il disegno finito in immagini (novità 0.6)
Pulsante **🖼 RENDERIZZA** in alto (il tavolo deve essere salvato):
- **Tutto il tavolo e ogni pezzo**: nella cartella del progetto, sottocartella **renderizzati**, un PNG per ogni pezzo
  (sfondo trasparente, 6 pixel per mm) e **tavolo_intero.png** (si apre per un attimo una finestra del gioco che si
  chiude da sola).
- **Solo il pezzo scelto**: solo quel PNG.
Servono per vedere il risultato, ritoccare un pezzo con un programma di disegno e rimetterlo come **immagine tua**.
*Nel gioco* le parti fisse sono già trasformate in immagini all'avvio (per restare fluido); l'esportazione per telefono
e Raspberry userà queste immagini pronte (Fase «Esportazione»).

## 7e. Lavorare su più pezzi insieme
- **Scegliere più pezzi**: **Maiusc+clic** su ognuno, oppure trascina un **rettangolo** partendo da un punto vuoto.
  **Ctrl+A** li sceglie tutti.
- Trascinane uno: si spostano **tutti**.
- A destra: **Duplica**, **Copia a specchio**, **Ingrandisci / Rimpicciolisci** (tasti + e −), **Capovolgi ↔ / ↕**
  sul posto, **Ruota 15°**, **In riga**, **In colonna**, **Distanze uguali**, **Blocca** (non si sposta più per sbaglio;
  si sblocca con doppio clic nella scheda **Pezzi**), **Elimina**.
- **Ctrl+C** copia, **Ctrl+V** incolla **dove punta il mouse**.
- Gli stessi pulsanti ci sono anche per un pezzo solo.

## 7j. Cancelletto e fila di abbattibili (novità 0.7)
**Cancelletto** (icona **Cancello**): una lamina tra due staffe; la pallina passa **solo nel verso della freccia verde**
(che si vede nell'editor) e dall'altra parte trova un muro. Quando passa, in gioco la lamina si alza. Per cambiare
verso: **Ruota 15°** o «Rotazione» a destra (180° = verso opposto). Si regola la **Larghezza**. Tipico all'uscita
delle orbite: la pallina entra dall'alto e non torna indietro.

**Fila di abbattibili** (icone **3 abbattibili** e **5 abbattibili**, vicino a Bersaglio): un clic mette 3 o 5 bersagli
affiancati con una luce davanti a ognuno, tutti nello stesso gruppo. In gioco: ogni bersaglio colpito cade; **tutti
giù = 5.000 punti**, poi dopo un secondo si rialzano. Ogni bersaglio poi si sposta e si cambia da solo.

## 7l. PIANI RIALZATI (novità 0.9)
Un **piano rialzato** è un mini-tavolo più in alto del tavolo, con i suoi pezzi (bumper, bersagli, mini palette…).
1. Icona **Piano** (gruppo Rampe) → **doppio clic** sul tavolo = piano pronto (rettangolo con gli angoli curvi);
   oppure clic per i punti della forma (Maiusc+clic = curvo) e Invio. Poi trascini i quadratini gialli.
   (0.9.3) Scegli il piano e clicca un quadratino: a destra, in **PUNTI**, spunta **Curvo**; oppure **Tutti curvi**
   per un piano tutto arrotondato.
2. A destra: **Nome**, **Altezza dal tavolo**, **Bordo aperto** (spento = muro tutto intorno, la pallina resta sopra;
   acceso = la pallina può cadere giù dal bordo), **Colore**, **Bordo / luce** (anche neon) e un'**immagine tua**.
3. **Pezzi sul piano:** mettili dentro la forma: salgono sul piano da soli. Spostati fuori, tornano sul tavolo.
4. **Salire con una RAMPA:** disegna una rampa che **finisce dentro** il piano: la pallina arriva sul piano.
   (Una rampa che **parte** dal piano la fa scendere.)
5. **Salire con una BUCA:** metti una buca sul tavolo → «Cosa fa» = **la manda in un altro punto** → «Dove riappare la
   pallina» = un punto **dentro** il piano. La pallina entra nella buca e riappare sopra.
6. **Scendere:** una buca **sul piano** che manda la pallina in un punto del tavolo; oppure il **bordo aperto**.
7. **(0.17) Il piano è STACCATO dal tavolo:** la pallina che corre sul tavolo **ci sbatte contro** come contro un
   blocco; lassù si arriva **solo** con una rampa, un binario o una buca. Se invece vuoi un piano «sui pilastri»
Nell'editor i viaggi «sotto il tavolo» delle buche si vedono come linee tratteggiate viola.
**Col mouse (0.9.1):** scegli la buca: la **freccia verde** è la direzione in cui la pallina esce (trascinala); il
**mirino viola** è il punto dove la pallina riappare (trascinalo, anche dentro un piano rialzato).
Prova pronta: **Apri → Prova_piano_rialzato**.

## 7m. Rampe collegate e deviatore (novità 0.9.2)
- Disegna una rampa che **finisce in alto** (in PRO: «uscita sospesa», oppure finisce su un piano rialzato) e poi una
  seconda rampa che **comincia nello stesso punto** (entro 3 cm): l'editor le collega da solo, la pallina passa
  dalla prima alla seconda senza toccare il tavolo.
- Se dallo stesso punto partono **due** rampe nasce un **deviatore**: manda la pallina **una volta per strada**.
- Una rampa che **finisce dentro una buca** ci lascia la pallina.
- Sposti via una rampa: il collegamento si toglie da solo.

## 7ak. NOVITÀ 0.26.1 – WINDOWS, LINUX E PIÙ PIATTAFORME PER I GIOCHI
- **L'editor si scarica già pronto** per **Windows** e **Linux** (pacchetti ZIP con dentro Godot ufficiale e tutto
  l'editor): si scompatta e si fa doppio clic su `Pinball Editor 2D.bat` (Windows) o `Pinball Editor 2D.sh` (Linux).
  Non serve installare niente.
- **I giochi** si esportano per **PC Linux, PC Windows, Raspberry Pi 4 e Android**. Android chiede sempre conferma.
  Mac e iPhone non ci sono: chi vorrà potrà aggiungerli (istruzioni in `docs/PIATTAFORME.md` della copia pubblica).
- **📦 ESPORTA → «Installa i modelli di esportazione»**: la prima volta scarica dal sito ufficiale di Godot i file che
  servono per esportare e controlla che siano integri.
- Come provarla: Apri → un tavolo → 📦 ESPORTA, scegli la piattaforma.

## 7aj. NOVITÀ 0.26 – RILASCIO UFFICIALE E LICENZE LIBERE
- **📦 ESPORTA → 🚀 RILASCIO UFFICIALE**: il pinball si distribuisce insieme al suo **codice sorgente pubblico**.
  Sono 7 passi:
  1. informazioni (nome, autore, descrizione, versione);
  2. verifica delle risorse;
  3. licenze;
  4. repository pubblico su GitHub, con il tuo consenso esplicito;
  5. crediti e novità della versione;
  6. esportazione;
  7. verifica finale.
- **Cosa fa l'editor nel passo 6:** pubblica il sorgente, controlla che chiunque lo possa scaricare, **compila il
  gioco da quel sorgente esatto** e prepara il pacchetto in `rilasci/NOME-VERSIONE/`:
  - il gioco e il sorgente (anche in ZIP);
  - immagini, musica e font;
  - le licenze, i crediti e le istruzioni per le AI;
  - il manifest delle licenze, le istruzioni per ricompilare;
  - l'indirizzo, il commit e il codice di controllo (hash) del rilascio.
- Se la pubblicazione non riesce, il rilascio **non** è ufficiale. Le build di ESPORTA (PC, Pi, APK) restano
  **build di prova**.
- **📜 LICENZE** ora chiede, per ogni immagine, musica e font: licenza, autore, indirizzo della fonte, modifiche e
  limitazioni. Per un rilascio libero servono licenze che permettono uso commerciale e modifiche.
- **Il menu del gioco:** se un tavolo non ha testi propri, le pagine REGOLE, MISSIONI e CREDITI mostrano testi
  generici e le missioni del tavolo. Un gioco rilasciato mostra anche la licenza e l'indirizzo del suo sorgente.

## 7ai. NOVITÀ 0.25 – PER CHI NON SA PROGRAMMARE
- **🪄 Primo flipper** (barra in alto). Procedura guidata in 5 passi:
  1. la forma;
  2. il tema;
  3. i pezzi da mettere (corsie, triangolo di bumper, abbattibili, buca con bersagli, spinner, scoop);
  4. missioni, segreti e classifica;
  5. il nome.
  L'editor mette i pezzi al posto giusto, aggiunge le missioni pronte, controlla da solo gli spazi pericolosi e alla
  fine chiede «▶ Gioca adesso». Poi ricordati **Salva con nome**.
- **🎨 Aspetto → TEMI PRONTI**: Spazio, Lava, Mare, Giungla, Notte neon, Classico. Un clic cambia i colori del tavolo
  e del menu, la luce ambientale e i font.
- **Gruppi di pezzi pronti** (colonna dei pezzi):
  - **3 bumper** (triangolo già alla distanza giusta), accanto al Bumper;
  - **Buca con 3 bersagli** ad arco dietro, accanto alla Buca;
  - **Spinner in una corsia** con due guide, accanto allo Spinner.
  Un solo «annulla» li toglie tutti.
- **🔧 Sistema tu** (accanto a CONTROLLA): allarga da solo gli spazi pericolosi tra i pezzi (quelli tra 20 e 36 mm,
  dove la pallina si incastra), spostando il pezzo più piccolo. Non tocca la sponda, le palette e i pezzi bloccati. Un
  solo «annulla» rimette tutto.
- **📱 Telefono**: mostra sul tavolo lo schermo del telefono (di oggi 20:9, oppure vecchio 16:9) con il tabellone,
  come nel gioco. Quello che è fuori dal riquadro si scurisce.
- **📦 ESPORTA → 🎬 Video promozionale**: il gioco gioca da solo 30 secondi e la finestra viene registrata **in tempo
  reale**. Il video MP4 finisce nella cartella `video` del tavolo, **senza audio** (la musica si aggiunge al montaggio).
  Durante la registrazione non coprire la finestra del gioco. Per i video dei giochi sul telefono resta la regola:
  si registrano dal telefono.

## 7ah. NOVITÀ 0.24 – PARETE INTERA E SCRITTE NEL TABELLONE
- La **parete esterna** (la parte marrone) ora si vede **intera** nel gioco, con la curva in alto. Prima la sua cima
  restava fuori dalla «foto» del tavolo che il gioco prepara all'avvio.
- Le **scritte grandi** (nome del tavolo, «premi START», missioni, segreti) compaiono **dentro il tabellone in
  alto**, al posto delle righe piccole, e non coprono più il tavolo.
- Per rimetterle in mezzo al tavolo: 🎨 Aspetto → «Scritte grandi» → «In mezzo al tavolo».

## 7ag. NOVITÀ 0.23
mancavano. La fisica non è cambiata.
- **🔒 SEGRETI** (scheda Missioni, in fondo). Obiettivi che **non si vedono sul tabellone**: il giocatore li scopre
  giocando; ognuno vale **una volta per partita** e dà punti con la scritta «SEGRETO SCOPERTO!».
  - Modelli pronti, fatti con i pezzi del tuo tavolo: Raffica di bumper (6 colpi in 2 s), Vortice (30 giri dello
    spinner in 5 s), Doppia rampa, Giro completo (rampa → buca → rampa), Salvati e vola (rampa entro 5 s dal kickback),
    Esploratore (tutti i sensori in una pallina).
  - Per ognuno cambi nome, colpi, secondi e punti.
  - Girano **insieme** alle missioni senza disturbarle. Si provano anche nel Simulatore.
- **🏆 CLASSIFICA dei 10 migliori** (scheda Missioni, in fondo: accesa di serie). A fine partita, se il punteggio entra
  nei 10, il giocatore scrive le **iniziali**:
  - sul PC: palette = lettera, START o lancio = conferma;
  - sul telefono: tocco a sinistra o a destra = lettera, tocco in alto = conferma.
  - Nel menu del gioco c'è la pagina **CLASSIFICA**.
  - Se la spegni, resta solo il record come prima.
- **⏱ Misura la velocità vera** (proprietà del tavolo, sotto il peso stimato). Il gioco gioca da solo circa
  30 secondi (normale e multiball) e misura fotogrammi al secondo, fotogrammi peggiori, tempo della fisica, memoria e
  temperatura. Poi dà un giudizio: **OK 60**, **SOLO 30** o **INSUFFICIENTE**. Il rapporto si salva anche nella
  cartella del tavolo (`misura_velocita.txt`).
- **Non portati, e perché:**
  - i personaggi 3D animati e i riflessi del piano: si disegnano a ogni fotogramma, contro la regola della grafica
    prerenderizzata, e sono troppo pesanti per il Raspberry Pi;
  - i comandi del cabinato: sono già uguali nei due motori.

## 7af. NOVITÀ 0.22 – PROGETTO GODOT e IMPORTA FLIPPER
- Prima salva il tavolo, poi scegli questa voce: nella cartella del tavolo nasce `esportati/progetto_godot/NOME/`.
- Quella cartella è un **progetto Godot 4.7 completo e indipendente**: motore, grafica, menu, tabellone e il tuo
  tavolo.
- Alla fine l'editor chiede: «**Apri in Godot**» (si apre l'editor di Godot su quel progetto) oppure «Mostra la
  cartella».
- In Godot premi **F5** e giochi il tuo tavolo.
- Dentro c'è `LEGGIMI_GODOT.md`, che spiega dove sta ogni cosa:
  - il tavolo è `gioco/tavolo.tavolo`, un file di testo con le misure in mm;
  - le immagini sono `gioco/immagini/*.png`: ridipingile o sostituiscile con lo stesso nome e il gioco usa le nuove;
  - le musiche sono in `gioco/musica/`;
  - la fisica, le regole, il disegno, il menu e il tabellone sono nelle cartelle `motore/`, `grafica/` e
    `interfaccia/`.
- Da Godot si esporta il gioco come sempre (Progetto → Esporta). Chiavi e pubblicità non ci sono e non vanno messe.

**📥 Importa flipper** (in alto). Apre come tavolo nuovo un tuo flipper 2D già fatto.
- Si importano forma, pezzi, rampe, livelli (il Palco) e colori.
- **Non** si importano le regole scritte a mano di quel gioco (missioni e punti: qui si rifanno a mattoncini) né le sue
  immagini.
- È una **copia**: il gioco originale non cambia.
- Ricorda di fare **Salva con nome**.
  schermata.


**Parete 3D:** l'inquadratura del gioco comprende tutta la parete esterna alzata.

**Elementi da immagine: immagine e funzione sono UNA cosa sola.**
- Si sceglie cliccando **ovunque dentro l'immagine** (prima solo sulla collisione).
- **Trascinalo** (o trascina il rombo azzurro): si spostano insieme immagine e collisione. La fionda, il bumper o la
  buca vanno dove va l'immagine.
- **Quadratino nell'angolo**: ingrandisce o rimpicciolisce **tutto insieme**. Lo fanno anche i tasti **+ / −**;
  **R** ruota l'immagine insieme al pezzo.
- Solo per ritoccare: **Alt + trascina** il rombo o il quadratino = muovi o ridimensiona **solo l'immagine**.
- «Fionda» ora si chiama «Fionda (triangolo con l'elastico che spara la pallina)», per non confonderla con la molla del
  lancio.

**🎨 Aspetto** (pulsante in alto). Raccoglie colori e **font** del menu, **altezza del tabellone** e pagine del menu.
- **Font:** «Predefinito», Noto Sans, Noto Serif, oppure **Importa un font (.ttf / .otf)**. Il font entra nel tavolo
  e va dichiarato in 📜 Licenze: un font di terzi serve con licenza commerciale.
- **Tabellone:** Piccolo, Normale o Grande. Il tavolo si mette sempre **sotto** il tabellone.

**Tabellone che copriva il tavolo.** La finestra di ▶ GIOCA ora prende l'altezza del tuo schermo: prima era fissa a
800 px e su uno schermo più basso usciva. Il tabellone resta sempre **centrato**, anche se allarghi la finestra.

**Livelli (scheda in basso).**
- Una spiegazione in cima.
- «**Solo questo**» mostra solo quel livello e nasconde gli altri; «**Mostra tutti i livelli**» li rimette.
- Sotto ogni livello ci sono i suoi pezzi: un clic e il pezzo è scelto.

**Missioni e Simulatore.** In cima a tutte e due c'è un riquadro azzurro con i passi da seguire (si chiude con ✕).
Nel Simulatore, dopo «▶ Nuova partita», **clicchi i pezzi direttamente sul tavolo**: ogni clic è un colpo della
pallina.

**Barra in alto:** se lo schermo è stretto va a capo, invece di tagliare i pulsanti a destra.

## 7ad. NOVITÀ 0.20 – 📦 ESPORTA
1. **Salva** il tavolo (si esporta quello salvato, con le sue musiche).
2. In alto **📦 ESPORTA** → scegli:
   - **Gioco per PC (Linux)**: un file unico che si avvia con un doppio clic;
   - **Gioco per Raspberry Pi 4 (Linux ARM64)**: da copiare sul Pi (quando ci sarà);
   - **APK Android di PROVA (senza pubblicità)**: l'editor ti chiede conferma (regola: l'APK solo con il tuo ok).
     Installarlo sul telefono è un passaggio a parte.
3. Dopo qualche decina di secondi si apre la cartella **esportati/…** del tavolo con il gioco e, accanto:
   `LICENSE`, `EULA.md`, `COPYRIGHT.md` (closed source, col **nome del tuo tavolo**; sono adattati da quelli di
   `LEGGIMI_ESPORTAZIONE.md`.
4. Nel gioco esportato ci sono il tavolo, le missioni, le luci, le musiche e i giocattoli; NON ci sono pubblicità,
   chiavi o ID (per la versione con pubblicità serve un passaggio insieme).

1. A sinistra, sopra i pezzi: **🖼 Da immagine…** → scegli la tua immagine (PNG, JPG, WEBP) → scegli **che cos'è**:
   Bumper · Bersaglio · Buca · Paletto di gomma · Forma libera (muro o isola) · Fionda · **Rampa già disegnata** ·
   Solo immagine.
2. Il pezzo nasce al centro della vista con la **tua immagine intatta al posto del disegno** dell'editor (il
   programma non la ridisegna) e con una **collisione invisibile** grande più o meno come l'immagine.
3. La collisione si vede **in azzurro solo nell'editor** (mai nel gioco). In alto, **Collisioni** la mostra anche per
   tutti gli altri pezzi.
4. Regoli la collisione a destra, senza toccare l'immagine:
   - **Bumper**: raggio e «raggio in altezza» (cerchio od ovale, es. una zucca larga), **Forza con cui respinge**,
     Rimbalzo (PRO), rotazione dell'ovale (PRO);
   - **Bersaglio**: larghezza e spessore, rimbalzo (PRO);
   - **Forma libera e Fionda**: la sagoma si disegna trascinando i quadratini gialli, come i muri (anche curvi);
   - **Rampa già disegnata**: il percorso sono i punti della rampa (trascinali sull'immagine), l'altezza come tutte le
     rampe, la **Larghezza delle pareti**, l'imbocco largo. Nell'editor vedi il percorso tratteggiato sopra
     l'immagine; nel gioco solo la tua immagine.
   L'immagine (misura, posizione, rotazione) si regola a parte, nella sezione IMMAGINE del pannello.
5. **⭐ I miei elementi**: scegli un pezzo, scrivi un nome e premi **⭐ Salva in I miei elementi** (in fondo al
   pannello). Lo ritrovi in OGNI tavolo con il pulsante **⭐ I miei elementi** → **Inserisci** (con immagine, collisione
   e fisica). I file stanno nella cartella `libreria_elementi` accanto al progetto dell'editor.

## 7ab. NOVITÀ 0.18.3 – MISSIONI
- **COME si conta → «tieni vivo per N secondi»**: il primo colpo accende, poi serve un colpo almeno ogni «X secondi»
  per tutta la durata; se aspetti troppo si spegne (SPENTO!) e si ricomincia. Sul tabellone: «12/20 s».
- **ENERGIA** (in alto nel pannello della missione, casella «Con ENERGIA»): N luci che si spengono una ogni tot
  secondi; il tiro scelto («Si ricarica colpendo») ne riaccende una; a zero la missione è persa. Sul tabellone «⚡4/6».
  Le **luci del piano** possono mostrarla: modo «energia: accesa se restano almeno N luci».
- **Missioni pronte nuove**: «Tieni acceso» e «Corsa all'energia».
- **⧉ Duplica la missione** (in fondo al pannello della missione): una copia da cambiare.
- **🗺 Schema** (scheda Missioni): chi sblocca chi, in colonne con le frecce. Oro = modalità, grigio = spenta,
  rosso = in un cerchio impossibile.
- **CONTROLLA** avvisa anche: missioni in cerchio (A aspetta B e B aspetta A: non parte nessuna), missione che aspetta
  una missione spenta, energia troppo corta.

## 7aa. NOVITÀ 0.18.2
- **❓ Guida** (in alto a destra, o tasto **F1**): questo manuale dentro l'editor, con l'indice dei capitoli a
  sinistra e la ricerca in alto (es. scrivi «rampa»).
- **Peso stimato** (pannello del tavolo, in verde/arancio/rosso): quanta memoria userà il tavolo nel gioco
  (immagini tue, disegno del tavolo, musiche). È una STIMA: fino a 150 MB va bene anche per il Raspberry Pi da 1 GB e
  i telefoni; oltre, CONTROLLA avvisa e consiglia di rimpicciolire le immagini (e segnala quelle oltre 2048 pixel).
- **⇄ Cosa è cambiato dall'ultimo salvataggio** (pannello del tavolo): elenco nel **Diario** dei pezzi aggiunti, tolti,
  spostati o cambiati e delle parti cambiate (missioni, luci, menu…). Utile prima di salvare sopra una versione buona.

## 7z. NOVITÀ 0.18.1
- **Tiri di riferimento** (strumento **Traccia tiro**, a destra): fai un tiro che funziona (es. dalla paletta destra
  alla rampa), scrivi un nome e premi **Salva l'ultimo tiro**: l'editor ricorda cosa ha colpito. Dopo le modifiche,
  **Rifai e confronta** (o **CONTROLLA**, che lo fa da solo) ti dice per ogni tiro «come prima» oppure «NON colpisce
  più la rampa…». Contano i pezzi «obiettivo» (rampe, bersagli, buche, sensori, spinner, prigioniera…): i rimbalzi
  su bumper e fionde cambiano troppo facilmente per contare.
- **Giocattoli**: scegli un'**Immagine sul piano** (con la sua immagine) e in fondo al pannello:
  **movimento continuo** (gira piano, ondeggia, pulsa) e/o **si muove quando…** (bumper, rampa, missione completata,
  multiball, cattura…) con **come si muove** (gira, salta, trema, pulsa, lampeggia). In PRO puoi farla reagire a un
  solo pezzo (scrivi il suo nome). Si vede con **▶ GIOCA**. È un'immagine pronta che si sposta: leggera anche per il
  Raspberry Pi.

## 7y. NOVITÀ 0.18
- **Pallina prigioniera** (icona «Prigioniera», gruppo Speciali): clic sul tavolo. A destra: **Verso del canale** (0° =
  verso l'alto) e **Lunghezza del canale**. L'editor costruisce da solo il canale, le «labbra» all'imbocco (la pallina
  di gioco non entra ma colpisce la prigioniera che sporge) e il bersaglio in fondo. Colpita bene, la prigioniera corre
  in fondo: evento «Pallina prigioniera» (punti, suono e luce nella scheda Suoni e luci, usabile nelle missioni).
- **CONTROLLA** ora segnala anche:
  - **superfici piatte in alto** (fila di bersagli dritta, cancelletto dritto, lato alto piatto di un piano): la
    pallina può restarci in equilibrio sopra. Basta inclinarle di 5-10°. (Il **piano pronto** nasce già a punta.)
  - **incroci delle rampe**: due rampe che si incrociano con meno di 32 mm di differenza d'altezza, o una rampa che
    passa dentro o troppo bassa sopra un piano rialzato;
  - le **pareti delle rampe** vicino alle guide (un solo avviso per coppia, con lo spazio più stretto);
  - le immagini **senza licenza dichiarata**.
- **Evoluzioni** (pannello COLLEZIONE): per ogni oggetto «si evolve in» un altro «dopo N» catture. L'oggetto di arrivo
  non esce mai a caso: si ottiene solo facendo evolvere (messaggio EVOLUZIONE!, punti doppi, effetto «Evoluzione»).
  scritta…) e una nota. **Scrivi il registro** crea `LICENZE_GRAFICA_E_MUSICA.md` nella cartella del tavolo, da
- **Tavoli di prova sistemati**: Prova_piano_rialzato (bocca della Salita spostata, piano a punta) e
  Prova_della_notte (bocca del nastro più larga, fila di bersagli e cancelletto inclinati).

## 7x. SPETTACOLI DI LUCE e ATTESA IN SALA (novità 0.17)
Scheda **Suoni e luci** (sotto il tavolo), in alto:
- **ATTESA IN SALA** (quando nessuno gioca, prima di START): scegli lo **spettacolo** che si ripete, la **pausa** tra
  una ripetizione e l'altra e una **scritta** che sul tabellone si alterna a «premi START» (es. «INSERT COIN»).
  «luci di base» = come prima.
- **SPETTACOLI DI LUCE**: uno spettacolo è una **sequenza di effetti a tempo**. **+ Nuovo spettacolo** oppure
  **Copia il pronto** (Arcobaleno, Festa, Allarme, Respiro: fatti da noi). Ogni **passo** ha: **dopo** quanti secondi
  parte, **effetto** (onda, onda su tutto il tavolo, lampo, spazzata su o giù, lampeggio lento o veloce, girandola),
  **colore**, **quanto dura**, e **grande** (abbassa per un attimo le altre luci, come nei jackpot). **+ passo**
  aggiunge un passo dopo la fine degli altri, **✕** lo toglie; il nome si cambia scrivendolo e premendo Invio.
- **Dove si usano:** per ogni **evento** (nell'elenco EVENTI, la tendina della luce ha anche «spettacolo: …»), in una
  **missione** (all'inizio o nel premio: «Spettacolo di luce») e nell'**attesa in sala**.
Per vederli: **▶ GIOCA** (l'attesa si vede subito, prima di premere START).

## 7w. STRUMENTI PER PROGETTARE E CONTROLLARE (novità 0.16)
- **Righello** (STRUMENTI): clic e trascina sul tavolo: distanza in mm, orizzontale/verticale e angolo; tacche ogni
  10 mm. La misura resta finché non ne fai un'altra.
- **Gruppi con nome**: scegli più pezzi (Maiusc+clic o rettangolo) → a destra **Fai gruppo** con un nome. Poi un clic
  su un pezzo del gruppo **sceglie tutto il gruppo** (per spostarlo insieme); **Alt+clic** = un pezzo solo. Elenco dei
  gruppi nella scheda **Livelli** (Scegli); rinomina e scioglie dal pannello del gruppo. Non cambia niente nel gioco.
- **Simulatore** (scheda sotto il tavolo): **Nuova partita**, poi **clicca un pezzo** dell'elenco = la pallina lo
  colpisce. Vedi punti, missione e conteggio, messaggi del tabellone e luci (● accesa, ◐ lampeggia, ○ spenta).
  **+5 secondi** fa passare il tempo (missioni a tempo, hurry-up), **◀ Paletta / Paletta ▶** per la scelta della
  missione e il cambio corsia. Usa le regole vere del gioco: si prova una missione in pochi secondi.
- **Ventaglio dalla paletta** (pannello di **Traccia tiro**): scegli la paletta e quanti tiri: la pallina ferma in
  quei punti della paletta (dalla base alla punta) e la paletta scatta. Vedi dove va ogni tiro e cosa colpisce:
  serve a sapere se una rampa o un bersaglio **si prendono davvero** dalla paletta.
- **Mappa di calore** (stesso pannello): il tavolo gioca da solo per i secondi scelti; i quadretti **rossi** sono dove
  la pallina passa di più, i **blu** dove passa poco; dove non c'è colore la pallina non arriva mai.

## 7v. SCOOP, DEVIATORE e PORTA (novità 0.15)
- **Scoop** (accanto a Buca): una buca con intorno un bordo di metallo a ferro di cavallo, aperto verso le palette.
  La pallina entra dall'apertura, viene trattenuta e risputata fuori. Sono una buca e un muro: si spostano e si
  modificano come gli altri pezzi (tempo e velocità d'uscita nella buca).
- **Deviatore** (lama sul piano): ruota sul suo **perno** (pallino arancio) tra la **posizione A** (linea piena) e la
  **posizione B** (tratteggiata). Nelle proprietà: lunghezza, i due versi, la posizione all'inizio e **quando cambia
  lato**: «a ogni colpo della pallina» (manda la pallina una volta a destra e una a sinistra) oppure «solo con le
  missioni». Non si muove mai addosso alla pallina.
- **Porta**: una barra che chiude un passaggio. «Aperta all'inizio» nelle proprietà.
- **Nelle missioni** (pannello della missione, «All'inizio» e «Premio finale»): **Apri la porta**, **Chiudi la
  porta**, **Muovi il deviatore** (all'altro lato, in A o in B). Esempio: all'inizio della missione si apre la porta
  della buca segreta, a missione finita si richiude. C'è anche il QUANDO «un deviatore sul piano».
- **Ricerca della pallina bloccata**: c'era già. Se la pallina resta ferma, il motore la spinge da solo.

## 7u. MENU DEL GIOCO, COLLEZIONE e ZONE (novità 0.14)
- **Menu del gioco** (quello che si apre con ☰ nel gioco): pannello del **tavolo** → **☰ MENU DEL GIOCO**. Puoi
  cambiare il **titolo**, i **5 colori** (principale, secondario, testo, fondo, pannello), i testi delle pagine
  **REGOLE**, **MISSIONI** (c'è il pulsante che la scrive dalle tue missioni) e **CREDITI**, e aggiungere **pagine
  in più** (es. «Storia», «Come si gioca»: un pulsante ciascuna sotto INFORMAZIONI). **Vuoto = come oggi**: senza
- **Collezione** (scheda Missioni → **Collezione e zone…**): gli oggetti da catturare (es. creature), ognuno con
  **rarità** (comune, raro, leggendario: i rari escono meno) e punti, più il **premio per la collezione completa**.
  Nel premio di una missione spunta **«Cattura un oggetto della collezione»** (o usa il modello **Cattura**). Una
  missione si può sbloccare **dopo N oggetti catturati**.
- **Zone (viaggi)**: elenco di zone (es. Terra, Luna, Marte). Il premio **«Passa alla zona successiva»** (o il
  modello **Viaggio**) cambia zona; in ogni missione scegli **in quali zone si gioca** (nessuna spunta = in tutte).
  Il tabellone mostra la zona.
- Nuove regole di luce: **oggetto già catturato**, **zona numero N**. Nuovi eventi per suoni e luci: cattura,
  collezione completa, cambio di zona.

## 7t. MODALITÀ, INGLESE e CONTROLLA più preciso (novità 0.13)
- **Modalità:** nel pannello di una missione, **MODALITÀ → Tipo**: «missione normale» (in fila con le altre) oppure
  **«MODALITÀ»**: parte **da sola** appena è sbloccata (dopo N missioni normali completate, in «Quando si sblocca»),
  anche se un'altra missione è in corso; quella va **IN PAUSA** e **riprende da dov'era** quando la modalità finisce
  (il tempo della pausa non conta). Poi la modalità si sblocca di nuovo dopo altre N missioni. «Modalità forte»
  interrompe anche le altre modalità. La **Modalità finale** dei modelli è già una modalità.
- **Inglese:** pannello del **tavolo** → **Lingua del tabellone**: italiano o inglese. In inglese il gioco mostra i
  testi in inglese; nelle missioni compaiono i campi **Nome in inglese** e **Testo in inglese** (vuoti = automatici).
- **CONTROLLA:** prima gioca da solo per qualche secondo (lancio e palette automatiche) e segna dove la pallina
  arriva davvero; poi cerca gli incastri **solo lì**. Niente più allarmi rossi nelle zone dove la pallina non può

## 7s. PALETTE NELLE REGOLE e MUSICA TUA (novità 0.12)
- **Cambio corsia:** le corsie con lo **stesso Gruppo** (campo «Gruppo» del sensore) formano una fila: passandoci la
  pallina **accende** la corsia, le **palette spostano** le luci accese a destra e a sinistra, **tutte accese** =
  premio (punti e moltiplicatore del bonus) e si spengono. Il pezzo **3 corsie** è già pronto così (gruppo, luci e
  premio). Nella scheda **Missioni** lo accendi/spegni e scegli i punti del premio. Esiste anche il QUANDO «tutte le
  corsie accese» per le missioni, e la regola di luce «corsia accesa».
- **Scelta della missione:** se le missioni partono **con un tiro**, spunta **«la scegli con le palette»**: quando una
  missione è pronta, le palette cambiano quella proposta (il nome appare sul tabellone), il tiro la fa partire.
- **Musica:** scheda **Missioni**, riga **Musica**: scegli le tue canzoni (ogg, mp3, wav) per **in gioco**,
  **multiball** e **attesa**; in ogni missione, **Musica durante la missione**. Le canzoni vengono **copiate nella
  cartella del tavolo** (serve averlo salvato). ✖ = togli. Senza scelte il gioco resta com'era.

## 7r. REGIA: LUCI CHE SEGUONO IL GIOCO e SUONI (novità 0.11)
**Luci del piano.** Scegli una **Luce** e a destra, in **COSA FA LA LUCE IN GIOCO**, decidi cosa segue:
- **Guida al tiro**: lampeggia quando la missione chiede **quel** pezzo (mettila davanti al tiro: rampa, buca…);
- **Barra**: più luci in fila che si accendono man mano che la missione avanza (es. luce 1 di 3, 2 di 3, 3 di 3);
- **Missione in corso** / **missione completata** / **missione pronta**;
- **Pezzo già colpito in questa pallina** (le corsie in alto come nei flipper veri) · **Bersaglio abbattuto**;
- **Multiball**, **salva-pallina attivo**, **pallina extra da giocare**, **sempre accesa**, **lampeggia sempre**.
**Suoni e luci degli eventi.** Sotto il tavolo, scheda **Suoni e luci**: per ogni evento (bumper, fionda, rampa,
missione iniziata/completata/fallita, multiball, pallina extra, tilt…) scegli il **suono** (lo senti subito) e
l'**effetto di luce** (onda, lampo, spazzata, lampeggio veloce, girandola) con il **colore**. «come prima» = quello
di base. I suoni sono **solo quelli del nostro catalogo** (niente suoni di altri flipper).

## 7q. MISSIONI A MATTONCINI (novità 0.10)
Sotto il tavolo, scheda **Missioni**.
1. **Aggiungere:** scegli un **modello** dall'elenco e premi **Aggiungi**, oppure **Tutte le pronte** (tutte quelle
   che il tuo tavolo permette, più la **modalità finale**). I modelli grigi dicono cosa manca (es. «non c'è uno
   spinner»). **Vuota** = una missione da costruire da zero.
2. **I 12 modelli:** Pioggia di colpi (bumper ×25) · Giro delle rampe (3 rampe) · Corsie accese (6 corsie) · Abbatti
   la fila (2 volte) · Tiro a segno (tutti i bersagli) · Elica (spinner ×30) · Caccia alla buca (2 volte) · Combo (3
   tiri di fila entro 4 s) · Corsa contro il tempo (15 colpi in 30 s) · Hurry-up (il premio cala ogni secondo) ·
   Multiball jackpot (3 jackpot) · Modalità finale (dopo 6 missioni: multiball, punti doppi, gran premio).
   Punti e tempi sono **di partenza**: si regolano provando.
3. **Ordine:** le missioni si giocano **una dopo l'altra** nell'ordine dell'elenco (frecce ↑ ↓). La spunta a sinistra
   le accende o le spegne. **Le missioni partono:** «da sole» oppure «con un tiro in» una buca o una rampa che scegli.
4. **Modifica** apre a destra i **mattoncini** della missione:
   - **Nome**, **Attiva**, **Si ripete**, **Tempo massimo** (se scade la missione è fallita e riparte più avanti);
   - **Quando si sblocca:** dopo un'altra missione, o dopo N missioni completate;
   - **All'inizio:** salva-pallina, multiball, punti moltiplicati;
   - **FASI** (una dopo l'altra): **QUANDO** = cosa colpire (tipo di pezzo, e se vuoi quale pezzo); **COME si conta** =
     *N volte* · *tutti i pezzi almeno una volta* · *in ordine* (sequenza) · *combo* (di fila, in fretta) · *hurry-up*
     (premio che cala); **premio della fase**, **tempo della fase**, **testo** sul tabellone; **+ Aggiungi una fase**;
   - **PREMIO FINALE:** punti, pallina extra, moltiplicatore del bonus, salva-pallina, multiball.
5. In **GIOCA** il tabellone mostra la missione, il conteggio e il tempo che resta.
6. **CONTROLLA** avvisa se una missione cita un pezzo che hai cancellato o non si può mai sbloccare.

## 7p. TRACCIA TIRO (novità 0.9.5)
Serve a capire **dove va la pallina** senza giocare: per provare un'idea, mirare una rampa, trovare un tiro che si perde.
1. In **STRUMENTI** premi **Traccia tiro** (sotto Seleziona).
2. **Clic** sul tavolo dove parte la pallina, **tieni premuto e trascina** verso dove deve andare: più lunga è la
   freccia, più forte è il tiro (da 100 a 3200 mm/s, il numero si vede accanto alla freccia). **Rilascia**: il tiro si
   fa sul **motore vero** in un attimo.
3. Sul tavolo compare il percorso: **blu = lenta, rosso = veloce**, linea spessa = sopra una rampa, **pallini** = cosa
   ha colpito (col nome), **croce** = dove è finita (rossa se si è fermata o è uscita).
4. A destra: **quanti tiri** (es. 5) e la **variazione d'angolo** tra un tiro e l'altro (es. ±3°) per vedere se un
   tiro è «sicuro» o se basta poco per sbagliarlo; **secondi** da seguire; **livello** di partenza (per i piani
   rialzati). **Ripeti l'ultimo tiro** dopo aver spostato un pezzo; **Cancella** per togliere il percorso.
5. Il riassunto dice per ogni tiro quanto è durato, come è finito (scarico, buca, ancora in gioco, ferma) e i colpi.
Le palette restano ferme in basso durante la traccia.

## 7n. LIVELLI con nome (novità 0.9.4)
Sotto il tavolo, scheda **Livelli**: una riga per il **Tavolo** (livello 0) e una per ogni **piano rialzato**, col suo
nome, l'altezza e quanti pezzi ha.
- **👁 Visibile**: togli la spunta e quel livello sparisce dall'editor (comodo per lavorare sotto un piano). Nel gioco
  si vede sempre tutto.
- **🔒 Bloccato**: i pezzi di quel livello si vedono ma non si scelgono né si spostano per sbaglio.
- **Rinomina / scegli**: sceglie il piano; il nome lo cambi a destra in «Nome».

## 7o. Gomme più vere (novità 0.9.4, motore)
Prima la gomma restituiva sempre il 75% della velocità, anche nei colpi fortissimi. Ora fa come Visual Pinball:
colpi lenti quasi uguali a prima, colpi forti rimbalzano meno (a 3 m/s circa il 41%). Vale per muri di gomma, gomme e
paletti di gomma. Palette, bumper, fionde, metallo e legno **non cambiano**.

## 7k. Bordi, neon e luce ambientale (novità 0.8)
**Bordo di un pezzo** (scegli il pezzo → sezione ASPETTO → **Bordo / luce**):
- **nessuno**;
- **semplice (linea)**: un contorno pieno, nero o del colore che scegli;
- **rilievo 3D**: contorno con luce in alto a sinistra e ombra in basso a destra;
- **neon luminoso**: una striscia che brilla, con l'alone che illumina il piano intorno.
Quando c'è un bordo compaiono **Colore del bordo** e **Intensità** (1 = normale, fino a 3 = fortissimo).
*Esempio – striscia neon lungo la parete laterale:* clicca la **sponda** di legno (o «Sponda a mano» nel pannello del
tavolo) → Bordo / luce = **neon luminoso** → scegli il colore (es. azzurro) e l'intensità.
Funziona su bumper, paletti, bersagli, buche, spinner, cancelletti, muri e guide, fionde, palette e kickback; con più
pezzi scelti lo imposti pezzo per pezzo.

**Luce ambientale** (nessun pezzo scelto → **LUCE AMBIENTALE**): spenta / dall'alto / dal basso / dai lati / su tutto
il piano, con **colore** e **intensità** (cursore). È una luce colorata che bagna il piano dentro la sponda e colora i
riflessi dei muri e delle guide.

**Luci del piano** (icona **Luce**): ora l'editor mostra la **forma vera**; forme: **tondo, freccia, rettangolo, rombo,
triangolo, stella, esagono**. «Verso (dove punta)» le gira (anche con Ruota 15°).

**Corretto:** cambiando un colore (tavolozza) il programma si chiudeva: ora non succede più, su nessun pezzo.

## 7b. Palette e fionde in più
- **Fionda**: vedi la sezione 7 (forma libera con il tratto che spinge).
- **Paletta**: icona Paletta → clic dove vuoi il **perno**. A destra scegli il **Lato** (sinistra/destra), la
  **Lunghezza** (palette piccole: 40-60 mm) e con quale **tasto** si muove. Per la gemella: **Copia a specchio**.
- Le due palette principali in basso si spostano ma non si eliminano; quelle aggiunte sì.
- Le fionde disegnate con l'icona **Fionda** hanno già la **gomma che si muove** in gioco (prima versione: la
  grafica rifinita arriva dopo).

## 8. Provare il tavolo: ▶ GIOCA
1. Premi **▶ GIOCA**: si apre la finestra del gioco con il **motore vero**, con il tavolo così com'è adesso
   (anche se non hai salvato: la prova non cambia il progetto).
2. Comandi: **Invio** = start · **Z** / **M** (o frecce ← →) = palette · **Spazio** (tieni premuto e lascia) =
   lancio · **B** = scossa · **Esc** = menu.
3. Chiudi la finestra del gioco per tornare all'editor. Correggi, poi GIOCA di nuovo.

In questa versione i tavoli nuovi hanno **regole semplici**: 3 palline, punti per ogni pezzo colpito, bonus, salva-
pallina, tilt. Missioni e luci personalizzate arrivano con i mattoncini.

## 9. Far controllare il tavolo: ✔ CONTROLLA
1. Premi **✔ CONTROLLA**. Ci vogliono circa **15-20 secondi** (in PRO circa un minuto: più palline).
2. L'editor fa due controlli:
   - **Varchi** (arancio ○): spazi tra due pezzi **tra 20 e 36 mm**, dove la pallina (27 mm) può incastrarsi.
     Regola dei nostri flipper: meglio **sotto 20** (non ci entra) o **sopra 36** (ci passa bene).
   - **Incastri** (rosso ●): lancia **100 palline a caso** sul tavolo con il motore vero e segna dove si **fermano**
     o dove il motore ha dovuto **spingerle** per sbloccarle.
3. I problemi compaiono **sul tavolo** (cerchi colorati) e nella scheda **Problemi** in basso: **clicca una riga** e
   la vista va su quel punto, con la spiegazione nella riga dei messaggi.
4. Non tutti i segni arancio sono errori: guardali e decidi (una corsia stretta voluta, per esempio, va bene).

**Limite noto (v0.1):** le palline di prova vengono messe anche in **zone chiuse** dove in gioco la pallina non arriva
versione dei controlli.

## 10. Salvare e riaprire
- **Salva** (Ctrl+S): salva il progetto. Il titolo della finestra mostra **\*** se ci sono modifiche non salvate.
- **Apri**: compare l'elenco dei tavoli salvati; **doppio clic** sul nome (o sceglilo e premi **Apri**).
- Ogni salvataggio tiene una **copia di quello precedente** (`tavolo.tavolo.prima`) e scrive tutto nel **diario**
  (`diario.txt`): chi ha fatto cosa (tu o l'AI) e quando.
  tavolo pronto usa **Nuovo** (sezione 4).

## 11. Tasti rapidi
| Tasto | Cosa fa |
|---|---|
| Ctrl+S | salva |
| Ctrl+Z / Ctrl+Y | annulla / ripristina |
| Ctrl+D | duplica il pezzo scelto |
| Ctrl+M | copia a specchio il pezzo scelto |
| Ctrl+C / Ctrl+V | copia / incolla dove punta il mouse |
| Ctrl+A | sceglie tutti i pezzi |
| + / − | ingrandisce / rimpicciolisce |
| Maiusc+clic | aggiunge o toglie un pezzo dalla scelta |
| Canc | elimina il pezzo scelto |
| R / Maiusc+R | ruota di 15° / di −15° |
| Frecce (+ Maiusc) | sposta di 1 mm (10 mm) |
| Invio | finisce il muro che stai disegnando |
| Esc | torna a Seleziona |

