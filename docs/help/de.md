# Awalé spielen

Awalé ist ein Streuspiel aus der Mancala-Familie, das in Westafrika und der
Karibik gespielt wird. Es ist auch als Oware, Awélé und Wari bekannt. Dieses
Programm folgt den Oware-Abapa-Regeln, die im Wettkampf verwendet werden.

Zwei Spieler, achtundvierzig Bohnen, zwölf Mulden. Keine Würfel, keine
verborgenen Informationen: alles liegt auf dem Brett.

## Das Brett

Du sitzt an der unteren Reihe, der Computer an der oberen. Jedem gehören die
sechs Mulden auf der eigenen Seite und ein Speicher am Ende der Reihe, in dem
die eroberten Bohnen liegen.

```
                     Computer
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                        du
```

Zu Beginn liegen vier Bohnen in jeder Mulde. Die Bohnen wandern **gegen den
Uhrzeigersinn**: an deiner Reihe entlang von deiner Mulde 1 zur Mulde 6, dann
in die Reihe des Computers und wieder herum.

## Dein Zug

Wähle eine **deiner** Mulden, die nicht leer ist. Nimm alle Bohnen heraus und
lege sie einzeln in die folgenden Mulden, gegen den Uhrzeigersinn.

Du spielst deine Mulde 3, in der vier Bohnen liegen:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                      ^ hier spielst du
```

Die vier Bohnen gehen in deine Mulden 4, 5 und 6 und dann in Mulde 1 des
Computers:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    5
  [ 0 ]                                   [ 0 ]
           4    4    0    5    5    5
          (1)  (2)  (3)  (4)  (5)  (6)
```

Deine Mulde 3 ist jetzt leer, und die Bohne, die deine Reihe verlassen hat,
liegt in Mulde 1 des Computers.

Liegen in einer Mulde zwölf Bohnen oder mehr, läuft die Aussaat einmal ganz um
das Brett. Dann wird die Ausgangsmulde **übersprungen** und bleibt leer.

## Erobern

Du eroberst, wenn **beides** zutrifft:

- deine **letzte** Bohne landet in einer Mulde des **Computers**, und
- diese Mulde enthält danach **genau zwei oder drei** Bohnen.

Diese Bohnen kommen vom Brett in deinen Speicher.

Sieh dann die Mulde davor an, die du kurz zuvor besät hast. Gehört sie
ebenfalls dem Computer und enthält sie ebenfalls zwei oder drei Bohnen, nimm
sie auch. Gehe so rückwärts weiter, bis eine Mulde nicht passt oder bis du
deine eigene Reihe erreichst. **Eine einzige unpassende Mulde beendet die
Kette.**

Deine letzte Bohne landet in Mulde 2 des Computers und bringt sie auf 2. Die
Mulde davor enthält 3. Beide werden erobert, fünf Bohnen:

```
   vorher                            nachher
   ... 3    2    1                   ... 3    0    0
       ^    ^    ^                       ^
       |    |    letzte Bohne            hier endet die Kette
       |    erobert (2)
       erobert (3)
```

Ein Zug, der **alle** verbliebenen Bohnen des Computers erobern würde, ist
erlaubt, erobert aber nichts: die Bohnen bleiben liegen und der Computer spielt
weiter.

## Die andere Seite versorgen

Hat der Computer zu Beginn deines Zuges gar keine Bohnen, **musst** du einen
Zug spielen, der mindestens eine in seine Reihe legt. Andere Züge sind nicht
erlaubt, und das Programm lässt sie nicht zu.

Dasselbe gilt für den Computer. Kann keiner den anderen versorgen, endet die
Partie und wer nicht ziehen kann, behält die Bohnen, die noch auf dem Brett
liegen.

## Wie die Partie endet

- Jemand erreicht **25 Bohnen** und hat gewonnen: mehr als die Hälfte von
  achtundvierzig.
- **24 zu 24** ist unentschieden.
- Kommt dieselbe Stellung dreimal vor, oder vergehen hundert Züge ganz ohne
  Eroberung, wird abgebrochen und jeder nimmt die Bohnen aus der eigenen Reihe.

In diesem Programm wird der Sieger angesagt, sobald er 25 erreicht, aber du
kannst die Runde zu Ende spielen, wenn du möchtest.

## Tipps

- **Zähle, bevor du säst.** Verfolge deine Bohnen mit dem Finger. Zu wissen, wo
  die letzte landet, ist fast das ganze Spiel.
- **Mulden mit einer oder zwei Bohnen sind die Ziele.** Eine einzige Bohne
  bringt sie auf zwei oder drei. Beobachte deine ebenso genau wie die des
  Computers.
- **Eine volle Mulde ist Waffe und Risiko zugleich.** Zwölf Bohnen oder mehr
  fegen über das ganze Brett, füllen aber auch die gegnerische Reihe wieder auf.
- **Aushungern gelingt selten.** Du bist verpflichtet zu versorgen, und wer
  nichts mehr zu verlieren hat, ist gefährlich.
- **Zähle gegen Ende.** Sobald 25 für eine Seite unerreichbar ist, zählt nur
  noch das Endergebnis.
- **Schalte den Lernmodus ein.** Er zeigt den besten Zug und erklärt ihn. Er
  zwingt dich zu nichts.

## Die Hinweise lesen

Ist der Lernmodus an, zeigt ein Stern die Mulde, die der Computer spielen würde.
Sind mehrere Züge gleich gut, bekommen sie alle einen Stern.

Der Stern entsteht daraus, jeden Zug zu spielen und dann zwölf Züge weit
vorauszuschauen, immer in der stärksten Einstellung des Computers, welchen Grad
du auch gewählt hast.

Es ist die Meinung des Computers, nicht die Wahrheit, und sie hält dich nie
davon ab, zu spielen was du willst.

## Mit der Tastatur spielen

| Taste | Wirkung |
| --- | --- |
| `1` bis `6` | Diese Mulde deiner Reihe spielen, von links nach rechts |
| `Tab` | Zwischen den Mulden wechseln, auch denen des Computers |
| `Strg+Z` | Deinen letzten Zug zurücknehmen |
| `Strg+N` | Neue Partie beginnen |
| `L` | Lernmodus ein- oder ausschalten |
| `S` | Samenanzahl ein- oder ausblenden |
| `Esc` | Das Brett verlassen |

Jede Mulde nennt ihre Nummer und ihren Inhalt, das ganze Brett lässt sich also
ohne Maus vorlesen.

## Mehr erfahren

[Oware in der Wikipedia](https://de.wikipedia.org/wiki/Oware)
