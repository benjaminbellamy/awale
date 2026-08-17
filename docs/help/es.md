# Cómo jugar al awalé

El awalé es un juego de siembra de la familia del mancala, practicado en África
Occidental y el Caribe. También se le conoce como oware, awélé o wari. Este
programa aplica las reglas Oware Abapa, las que se usan en competición.

Dos jugadores, cuarenta y ocho semillas, doce hoyos. Ni dados ni información
oculta: todo está sobre el tablero.

## El tablero

Tú ocupas la fila de abajo y el ordenador la de arriba. Cada uno posee los seis
hoyos de su lado y un granero al final de su fila donde se guardan las semillas
capturadas.

```
                    ordenador
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                       tú
```

La partida empieza con cuatro semillas en cada hoyo. Las semillas viajan en
**sentido antihorario**: a lo largo de tu fila, de tu hoyo 1 al 6, y luego a la
fila del ordenador, y así sucesivamente.

## Tu turno

Elige uno de **tus** hoyos que no esté vacío. Saca todas sus semillas y déjalas
una a una en los hoyos siguientes, en sentido antihorario.

Juegas tu hoyo 3, que contiene cuatro semillas:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                      ^ juegas aquí
```

Las cuatro semillas van a tus hoyos 4, 5 y 6, y después al hoyo 1 del
ordenador:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    5
  [ 0 ]                                   [ 0 ]
           4    4    0    5    5    5
          (1)  (2)  (3)  (4)  (5)  (6)
```

Tu hoyo 3 queda vacío y la semilla que salió de tu fila cayó en el hoyo 1 del
ordenador.

Si un hoyo tiene doce semillas o más, la siembra da la vuelta completa al
tablero. Cuando eso ocurre, el hoyo de partida se **salta** y queda vacío.

## Capturar

Capturas cuando se cumplen **ambas** condiciones:

- tu **última** semilla cae en un hoyo del **ordenador**, y
- ese hoyo pasa a tener **exactamente dos o tres** semillas.

Esas semillas salen del tablero y van a tu granero.

Después mira el hoyo anterior, el que acabas de sembrar. Si también es del
ordenador y también tiene dos o tres semillas, tómalo igualmente. Sigue así
hacia atrás hasta que un hoyo no cumpla la condición, o hasta llegar a tu
propia fila. **Un solo hoyo que no cumpla detiene la cadena.**

Tu última semilla cae en el hoyo 2 del ordenador y lo deja en 2. El hoyo
anterior tiene 3. Ambos se capturan, cinco semillas:

```
   antes                             después
   ... 3    2    1                   ... 3    0    0
       ^    ^    ^                       ^
       |    |    última semilla          la cadena se detiene aquí
       |    capturado (2)
       capturado (3)
```

Una jugada que capturaría **todas** las semillas que le quedan al ordenador
está permitida, pero no captura nada: las semillas se quedan donde están y el
ordenador sigue jugando.

## Alimentar al contrario

Si el ordenador no tiene ninguna semilla al empezar tu turno, **debes** jugar
una jugada que ponga al menos una en su fila. Las demás no están permitidas y
el programa no te dejará hacerlas.

Lo mismo vale para el ordenador. Si ninguno puede alimentar al otro, la partida
termina y quien no puede mover se queda con las semillas que quedan.

## Final de la partida

- Alguien llega a **25 semillas** y gana: más de la mitad de cuarenta y ocho.
- **24 a 24** es empate.
- Si la misma posición aparece tres veces, o pasan cien jugadas sin una sola
  captura, la partida se detiene y cada jugador recoge las semillas de su
  propia fila.

En este programa el ganador se anuncia en cuanto llega a 25, pero puedes
terminar la ronda si quieres.

## Consejos

- **Cuenta antes de sembrar.** Sigue tus semillas con el dedo. Saber dónde cae
  la última es casi todo el juego.
- **Los hoyos con una o dos semillas son el objetivo.** Son los que una sola
  semilla lleva a dos o tres. Vigila los tuyos tanto como los del ordenador.
- **Un hoyo grande es un arma y un riesgo.** Doce semillas o más barren todo el
  tablero, pero también rellenan la fila del contrario.
- **Matar de hambre al contrario rara vez funciona.** Estás obligado a
  alimentarlo, y un jugador sin nada que perder es peligroso.
- **Al final, cuenta.** Cuando 25 queda fuera del alcance de un bando, lo único
  que importa es el total final.
- **Activa el modo de aprendizaje.** Señala la mejor jugada y explica por qué.
  Nunca te obliga.

## Leer las indicaciones

Con el modo de aprendizaje activado, una estrella señala la casa que jugaría el
ordenador. Si varias jugadas son igual de buenas, todas llevan estrella.

La estrella sale de jugar cada jugada y mirar doce jugadas más adelante, siempre
con el ajuste más fuerte del ordenador, sea cual sea el nivel que hayas elegido.

Es la opinión del ordenador, no la verdad, y nunca te impide jugar lo que
quieras.

## Jugar con el teclado

| Tecla | Qué hace |
| --- | --- |
| `1` a `6` | Jugar ese hoyo de tu fila, de izquierda a derecha |
| `Tab` | Moverse entre hoyos, incluidos los del ordenador |
| `Ctrl+Z` | Deshacer tu última jugada |
| `Ctrl+N` | Empezar una partida nueva |
| `L` | Activar o desactivar el modo de aprendizaje |
| `S` | Mostrar u ocultar el número de semillas |
| `Esc` | Salir del tablero |

Cada hoyo anuncia su número y cuántas semillas tiene, así que el tablero entero
se puede leer en voz alta sin ratón.

## Saber más

[Oware en Wikipedia](https://es.wikipedia.org/wiki/Oware)
