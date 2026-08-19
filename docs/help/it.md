# Come giocare all’awalé

L’awalé è un gioco di semina della famiglia mancala, praticato in Africa
occidentale e nei Caraibi. È noto anche come oware, awélé e wari. Questo
programma applica le regole Oware Abapa, quelle usate in competizione.

Due giocatori, quarantotto semi, dodici buche. Niente dadi, niente informazioni
nascoste: tutto è sul tavoliere.

## Il tavoliere

Tu occupi la fila in basso, il computer quella in alto. Ciascuno possiede le sei
buche del proprio lato e un granaio in fondo alla fila dove finiscono i semi
catturati.

```
                     computer
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                        tu
```

Si comincia con quattro semi in ogni buca. I semi girano in **senso
antiorario**: lungo la tua fila dalla buca 1 alla 6, poi nella fila del
computer, e così via.

## Il tuo turno

Scegli una delle **tue** buche che non sia vuota. Prendine tutti i semi e
lasciali cadere uno alla volta nelle buche seguenti, in senso antiorario.

Giochi la tua buca 3, che contiene quattro semi:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                      ^ giochi qui
```

I quattro semi vanno nelle tue buche 4, 5 e 6, poi nella buca 1 del computer:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    5
  [ 0 ]                                   [ 0 ]
           4    4    0    5    5    5
          (1)  (2)  (3)  (4)  (5)  (6)
```

La tua buca 3 è vuota e il seme uscito dalla tua fila è finito nella buca 1 del
computer.

Se una buca contiene dodici semi o più, la semina fa il giro completo del
tavoliere. In quel caso la buca di partenza viene **saltata** e resta vuota.

## Catturare

Catturi quando valgono **entrambe** queste condizioni:

- il tuo **ultimo** seme cade in una buca del **computer**, e
- quella buca arriva ad avere **esattamente due o tre** semi.

Quei semi lasciano il tavoliere e finiscono nel tuo granaio.

Poi guarda la buca precedente, quella che avevi appena seminato. Se è anch’essa
del computer e contiene anch’essa due o tre semi, prendi anche quella. Prosegui
così all’indietro finché una buca non soddisfa la condizione, o finché non
arrivi alla tua fila. **Una sola buca non idonea ferma la catena.**

Il tuo ultimo seme cade nella buca 2 del computer portandola a 2. La buca
precedente ne ha 3. Entrambe vengono catturate, cinque semi:

```
   prima                             dopo
   ... 3    2    1                   ... 3    0    0
       ^    ^    ^                       ^
       |    |    ultimo seme             la catena si ferma qui
       |    catturata (2)
       catturata (3)
```

Una mossa che catturerebbe **tutti** i semi rimasti al computer è consentita ma
non cattura nulla: i semi restano dove sono e il computer continua a giocare.

## Nutrire l’avversario

Se all’inizio del tuo turno il computer non ha più semi, **devi** giocare una
mossa che ne porti almeno uno nella sua fila. Le altre non sono consentite e il
programma non te le lascia fare.

Lo stesso vale per il computer. Se nessuno dei due può nutrire l’altro, la
partita finisce e chi non può muovere tiene i semi rimasti sul tavoliere.

## Come finisce la partita

- Qualcuno arriva a **25 semi** e ha vinto: più della metà di quarantotto.
- **24 pari** è patta.
- Se la stessa posizione si ripete tre volte, o passano cento mosse senza
  nessuna cattura, la partita si ferma e ognuno raccoglie i semi della propria
  fila.

In questo programma il vincitore viene annunciato appena raggiunge 25, ma se
vuoi puoi giocare la mano fino in fondo.

## Consigli

- **Conta prima di seminare.** Segui i semi con il dito. Sapere dove cade
  l’ultimo è quasi tutto il gioco.
- **Le buche con uno o due semi sono i bersagli.** Sono quelle che un solo seme
  porta a due o tre. Sorveglia le tue quanto quelle del computer.
- **Una buca piena è un’arma e un rischio.** Dodici semi o più spazzano tutto
  il tavoliere, ma riempiono anche la fila avversaria.
- **Affamare l’avversario funziona di rado.** Sei obbligato a nutrirlo, e chi
  non ha più nulla da perdere è pericoloso.
- **Verso la fine, conta.** Quando 25 diventa irraggiungibile per una parte,
  conta solo il totale finale.
- **Attiva la modalità apprendimento.** Segnala la mossa migliore e spiega
  perché. Non ti obbliga mai.

## Leggere i suggerimenti

Con la modalità apprendimento attiva, una stella indica la buca che giocherebbe
il computer. Se più mosse valgono altrettanto, ricevono tutte una stella.

La stella nasce dal giocare ogni mossa e guardare dodici mosse più avanti,
sempre all'impostazione più forte del computer, qualunque livello tu abbia
scelto.

È l'opinione del computer, non la verità, e non ti impedisce mai di giocare
quello che vuoi.

Le frecce, invece, non sono un'opinione. Una freccia parte da ogni buca che
farebbe guadagnare semi, in entrambe le file, e segue il percorso dei semi fino
a quella in cui cade l'ultimo; il numero alla sua origine è quanto renderebbe la
mossa. Le frecce sulla fila del computer mostrano ciò che potrebbe prenderti
dopo, che sia il suo turno o no.

## Giocare con la tastiera

| Tasto | Effetto |
| --- | --- |
| `1` a `6` | Gioca quella buca della tua fila, da sinistra a destra |
| `Tab` | Spostarsi tra le buche, comprese quelle del computer |
| `Ctrl+Z` | Annulla la tua ultima mossa |
| `Ctrl+Maiusc+Z` | Rigiocare la tua ultima mossa |
| `Ctrl+N` | Inizia una nuova partita |
| `L` | Attivare o disattivare la modalità apprendimento |
| `S` | Mostrare o nascondere il numero di semi |
| `Esc` | Uscire dal tavoliere |

Ogni buca annuncia il proprio numero e quanti semi contiene, così l’intero
tavoliere si può leggere ad alta voce senza mouse.

## Per saperne di più

[Wari su Wikipedia](https://it.wikipedia.org/wiki/Wari)
