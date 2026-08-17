# Comment jouer à l’awalé

L’awalé est un jeu de semailles de la famille des mancalas, pratiqué en Afrique
de l’Ouest et dans les Caraïbes. On l’appelle aussi awélé, oware ou wari. Ce
programme applique les règles Oware Abapa, celles des compétitions.

Deux joueurs, quarante-huit graines, douze cases. Ni dés, ni information
cachée : tout est sur le plateau.

## Le plateau

Vous occupez la rangée du bas, l’ordinateur celle du haut. Chacun possède les
six cases de son côté, plus un grenier au bout de sa rangée où s’entassent les
graines capturées.

```
                   ordinateur
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                      vous
```

La partie commence avec quatre graines par case. Les graines circulent dans le
**sens antihoraire** : le long de votre rangée de votre case 1 à votre case 6,
puis dans la rangée de l’ordinateur, et ainsi de suite.

## Votre tour

Choisissez une de **vos** cases, non vide. Prenez-en toutes les graines et
déposez-les une par une dans les cases suivantes, dans le sens antihoraire.

Vous jouez votre case 3, qui contient quatre graines :

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                      ^ vous jouez ici
```

Les quatre graines vont dans vos cases 4, 5 et 6, puis dans la case 1 de
l’ordinateur :

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    5
  [ 0 ]                                   [ 0 ]
           4    4    0    5    5    5
          (1)  (2)  (3)  (4)  (5)  (6)
```

Votre case 3 est vide, et la graine sortie de votre rangée a atterri dans la
case 1 de l’ordinateur.

Si une case contient douze graines ou plus, la semaille fait le tour complet du
plateau. Dans ce cas la case de départ est **sautée** et reste vide.

## Capturer

Vous capturez lorsque **ces deux conditions** sont réunies :

- votre **dernière** graine tombe dans une case de **l’ordinateur**, et
- cette case contient alors **exactement deux ou trois** graines.

Ces graines quittent le plateau et rejoignent votre grenier.

Regardez ensuite la case précédente, celle que vous veniez de semer. Si elle
appartient aussi à l’ordinateur et contient elle aussi deux ou trois graines,
prenez-la également. Continuez ainsi à reculons jusqu’à une case qui ne remplit
pas la condition, ou jusqu’à votre propre rangée. **Une seule case non
conforme arrête la chaîne.**

Votre dernière graine tombe dans la case 2 de l’ordinateur, qui passe à 2. La
case précédente en contient 3. Les deux sont capturées, cinq graines :

```
   avant                             après
   ... 3    2    1                   ... 3    0    0
       ^    ^    ^                       ^
       |    |    dernière graine         la chaîne s’arrête ici
       |    capturée (2)
       capturée (3)
```

Un coup qui capturerait **toutes** les graines restantes de l’ordinateur est
autorisé, mais il ne capture rien : les graines restent en place et
l’ordinateur continue de jouer.

## Nourrir l’adversaire

Si l’ordinateur n’a plus aucune graine au début de votre tour, vous **devez**
jouer un coup qui en dépose au moins une dans sa rangée. Les autres coups sont
interdits, et le programme vous en empêche.

La règle vaut dans les deux sens. Si aucun des deux ne peut nourrir l’autre, la
partie s’arrête et celui qui ne peut pas jouer garde les graines restantes.

## Fin de la partie

- Un joueur atteint **25 graines** et l’emporte : plus de la moitié des
  quarante-huit.
- **24 partout** est un match nul.
- Si la même position revient trois fois, ou si cent coups s’enchaînent sans la
  moindre capture, la partie s’arrête et chacun récupère les graines de sa
  propre rangée.

Dans ce programme le vainqueur est annoncé dès qu’il atteint 25, mais vous
pouvez terminer la manche si vous le souhaitez.

## Conseils

- **Comptez avant de semer.** Suivez vos graines du doigt. Savoir où tombe la
  dernière, c’est l’essentiel du jeu.
- **Les cases à une ou deux graines sont les cibles.** Ce sont celles qu’une
  seule graine amène à deux ou trois. Surveillez les vôtres autant que celles
  de l’ordinateur.
- **Une grosse case est une arme et un risque.** Douze graines ou plus balaient
  tout le plateau, mais elles regarnissent aussi la rangée adverse.
- **Affamer l’adversaire fonctionne rarement.** Vous êtes obligé de le nourrir,
  et un joueur qui n’a plus rien à perdre est dangereux.
- **En fin de partie, comptez.** Dès que 25 devient inatteignable pour un camp,
  seul le total final compte.
- **Activez le mode apprentissage.** Il signale le meilleur coup et explique
  pourquoi. Il ne vous force jamais la main.

## Lire les indications

Avec le mode apprentissage, une étoile marque la case que l'ordinateur jouerait.
Si plusieurs coups se valent, ils reçoivent tous une étoile.

L'étoile vient de jouer chaque coup puis de regarder douze coups plus loin,
toujours au réglage le plus fort de l'ordinateur, quel que soit le niveau
choisi.

C'est l'avis de l'ordinateur, pas la vérité, et il ne vous empêche jamais de
jouer ce que vous voulez.

Les flèches, elles, ne sont pas un avis. Une flèche part de chaque case qui
rapporterait des graines, dans les deux rangées, et suit le chemin des graines
jusqu'à celle où tombe la dernière ; le nombre à son départ est ce qu'elle
rapporterait. Les flèches de la rangée de l'ordinateur montrent ce qu'il
pourrait vous prendre ensuite, que ce soit son tour ou non.

## Jouer au clavier

| Touche | Effet |
| --- | --- |
| `1` à `6` | Jouer cette case de votre rangée, de gauche à droite |
| `Tab` | Passer d’une case à l’autre, y compris celles de l’ordinateur |
| `Ctrl+Z` | Annuler votre dernier coup |
| `Ctrl+N` | Nouvelle partie |
| `L` | Activer ou désactiver le mode apprentissage |
| `S` | Afficher ou masquer le nombre de graines |
| `Échap` | Sortir du plateau |

Chaque case annonce son numéro et son nombre de graines : le plateau entier
peut être lu à voix haute sans souris.

## Pour aller plus loin

[L’awalé sur Wikipédia](https://fr.wikipedia.org/wiki/Awal%C3%A9)
