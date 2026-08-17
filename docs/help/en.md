# How to play Awalé

Awalé is a sowing game of the mancala family, played across West Africa and the
Caribbean. It is also known as oware, awélé and wari. This program plays the
Oware Abapa ruleset, the one used in competition.

Two players, forty eight seeds, twelve houses. No dice, no hidden information:
everything is on the board.

## The board

You sit at the bottom row. The computer sits at the top. Each of you owns the
six houses on your own side, and a store at the end of your row where captured
seeds are kept.

```
                    computer
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                      you
```

The game begins with four seeds in every house. Seeds travel **anticlockwise**:
along your row from your house 1 to your house 6, then up into the computer's row
and back along it, and round again.

## Your turn

Choose one of **your own** houses that is not empty. Lift every seed out of it and
drop them one at a time into the houses that follow, going anticlockwise.

You play your house 3, which holds four seeds:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                      ^ you play here
```

The four seeds go into your houses 4, 5 and 6, and then into the computer's house 1:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    5
  [ 0 ]                                   [ 0 ]
           4    4    0    5    5    5
          (1)  (2)  (3)  (4)  (5)  (6)
```

Your house 3 is now empty, and the seed that left your row landed in the
computer's house 1.

If a house holds twelve seeds or more, the sowing goes all the way round the
board. When that happens the house you started from is **skipped** and stays
empty.

## Capturing

You capture when **both** of these are true:

- your **last** seed lands in one of the **computer's** houses, and
- that house then holds **exactly two or three** seeds.

Those seeds come off the board and go into your store.

Then look at the house just before it, the one you sowed into a moment earlier. If
it is also the computer's and also holds two or three seeds, take it too. Keep
walking backwards like that until a house does not qualify, or until you reach
your own row. **One house that does not qualify stops the chain.**

Your last seed lands in the computer's house 2, bringing it to 2. The house before
it holds 3. Both are captured, five seeds:

```
   before                            after
   ... 3    2    1                   ... 3    0    0
       ^    ^    ^                       ^
       |    |    last seed               chain stops here
       |    captured (2)
       captured (3)
```

A capture that would take **every** seed the computer has left is allowed, but
it captures nothing: the seeds stay where they are and the computer plays on.

## Keeping the other side fed

If the computer has no seeds at all when your turn begins, you **must** play a
move that puts at least one seed into its row. Moves that do not are not
allowed, and the program will not let you make them.

The same applies to the computer. If neither of you can feed the other, the
game ends and whoever cannot move keeps the seeds left on the board.

## How the game ends

- Someone reaches **25 seeds** and has won: more than half of forty eight.
- **24 each** is a draw.
- If the same position comes up three times, or a hundred moves go by with no
  capture at all, the game stops and each player takes the seeds still sitting
  in their own row.

In this program the winner is announced as soon as they reach 25, but you can
keep playing the round out if you want to.

## Tips

- **Count before you sow.** Follow your seeds with your finger. Knowing where
  the last one lands is most of the game.
- **Houses holding one or two seeds are the targets.** They are the ones a single
  seed can bring to two or three. Watch yours as closely as the computer's.
- **A big house is a weapon and a liability.** Twelve or more seeds sweeps the
  whole board, but it also refills the computer's row.
- **Starving the other side rarely works.** You are obliged to feed them, and a
  player with nothing to lose is dangerous.
- **Late in the game, count the seeds.** Once 25 is out of reach for one side,
  the only thing that matters is the final total.
- **Turn on learning mode.** It marks the strongest move and tells you why. It
  never forces your hand.

## Reading the hints

With learning mode on, a star marks the house the computer would play. If
several moves are just as good, they all get a star.

The star comes from playing each move out and looking twelve moves ahead, always
at the computer's strongest setting, whatever level you have chosen.

It is the computer's opinion, not the truth, and it never stops you playing
whatever you like.

## Playing with the keyboard

| Key | What it does |
| --- | --- |
| `1` to `6` | Play that house of your row, left to right |
| `Tab` | Move between houses, including the computer's |
| `Ctrl+Z` | Take back your last move |
| `Ctrl+N` | Start a new game |
| `L` | Turn learning mode on or off |
| `S` | Show or hide the seed counts |
| `Esc` | Step out of the board |

Every house announces its number and how many seeds it holds, so the whole board
can be read out loud without using a mouse.

## Learn more

[Oware on Wikipedia](https://en.wikipedia.org/wiki/Oware)
