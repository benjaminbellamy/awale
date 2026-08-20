# Awalé rules specification

This document is the authoritative rule specification for this project.
The implementation must match it exactly. If anything here is ambiguous,
stop and ask before implementing.

Variant implemented: **Oware Abapa** (the standard adult/competitive ruleset).

## 1. Board and setup

- 12 houses in 2 rows of 6.
- South row: indices `0, 1, 2, 3, 4, 5` (left to right from South's view).
- North row: indices `6, 7, 8, 9, 10, 11`.
- Sowing direction is counterclockwise, meaning index order
  `0 -> 1 -> 2 -> ... -> 11 -> 0 -> ...`.
- Each house starts with 4 seeds. Total seeds on the board: 48.
- Each player has a store, starting at 0.
- South (the human player, by default) moves first. This must be
  configurable, and the computer may open.

**Invariant, must be asserted after every single move:**
`sum(board) + south_store + north_store == 48`

## 2. A move

On their turn, a player chooses one house from **their own row** that
contains **at least one seed**. They lift all seeds from it, leaving it
empty, then sow them one at a time into the following houses in
counterclockwise order.

### 2.1 The skip rule (12 or more seeds)

If the lifted house contained 12 or more seeds, the sowing wraps all the way
around. **The house of origin is skipped and stays empty.** Continue sowing
into the next house instead.

Worked example: a house holding 12 seeds. Seeds 1 to 11 fill each of the 11
other houses once. Seed 12 would land back on the house of origin, so it is
skipped, and seed 12 goes into the house immediately after the origin, which
therefore receives 2 seeds. The house of origin ends empty.

Worked example: a house holding exactly 11 seeds fills every other house
once, and the house of origin ends empty. No skip is triggered.

## 3. Capturing

A capture happens only if **both** conditions hold:

1. The **last** sown seed lands in a house belonging to the **opponent**.
2. That house, **after** receiving the seed, contains exactly **2 or 3**
   seeds.

Those seeds are then removed from the board and added to the mover's store.

### 3.1 Chained capture (walk backwards)

After capturing, examine the **previous** house in the sowing order (the one
sown just before). If that house is **also in the opponent's row** and also
contains exactly 2 or 3 seeds, capture it too. Repeat backwards until either:

- a house contains a number of seeds other than 2 or 3, or
- the walk reaches the mover's own row (never capture from your own row), or
- the walk reaches the start of the sowing.

Worked example: South plays house 4, which holds 3 seeds. They land in
houses 5, 6, 7. House 7 is North's and now holds 2 seeds, so it is captured.
Walk back to house 6, which is North's and now holds 3 seeds, so it is
captured too. Walk back to house 5, which belongs to South, so the chain
stops. Nothing else is captured.

Note that a chained capture cannot skip a house. One non-qualifying house
stops the chain immediately.

## 4. The feeding obligation (starvation)

If the opponent's row is entirely empty at the start of your turn, you
**must** play a move that puts at least one seed into their row. Any move
that does not feed them is illegal and must not be selectable in the UI.

If no legal feeding move exists, the game ends immediately (see 6.3).

## 5. Grand slam

A "grand slam" is a move that would capture **every** seed remaining in the
opponent's row, leaving them with nothing to play.

**Rule used in this project (Abapa):** the move is **legal**, but **no seeds
are captured** by it. The seeds stay on the board and the opponent plays on.

This differs between variants, and some rulesets forbid the move outright.
Therefore this behaviour must be implemented as an explicit, documented,
named policy constant:

```vala
public enum GrandSlamPolicy {
    LEGAL_NO_CAPTURE,  // default, Abapa
    FORBIDDEN          // move cannot be played
}
```

Default is `LEGAL_NO_CAPTURE`. Do not silently hard-code either behaviour.

## 6. End of the game

### 6.1 Victory by seed count

Total seeds is 48, so:

- A player who collects **25 or more** seeds has won, and the game ends
  immediately as soon as that threshold is crossed.
- **24 to 24** is a draw.

### 6.2 Cycles and endless play

Late in a game, a small number of seeds can circulate forever. The game must
terminate. Use both of these guards:

- If the same position (full board state **plus** the side to move) occurs
  for the **third** time, the game ends.
- If **100 consecutive plies** are played without any capture, the game ends.

When either guard fires, **each player collects the seeds remaining in their
own row**, and the result is decided by the resulting totals.

### 6.3 Starvation ending

If the player to move cannot feed a starving opponent (see section 4), the
game ends and **the player to move collects all seeds remaining on the
board**, which are by definition all in their own row.

## 7. Required unit tests

The engine is not done until all of these pass.

**Setup and invariants**
1. Initial position: every house holds 4 seeds, both stores are 0, total is 48.
2. The 48-seed invariant holds after every move in a 1000 move random self play.

**Move generation**
3. A player may never select an empty house.
4. A player may never select a house in the opponent's row.
5. When the opponent's row is empty, only feeding moves are generated.
6. When the opponent's row is empty and no feeding move exists, move
   generation returns empty and the game is flagged terminal.

**Sowing**
7. Sowing 11 seeds leaves the house of origin empty and adds exactly one seed
   to each of the 11 other houses.
8. Sowing 12 seeds leaves the house of origin empty, adds one seed to 10
   houses, and adds two seeds to the house immediately after the origin.
9. Sowing 23 seeds skips the house of origin twice.

**Capturing**
10. Last seed lands in an opponent house bringing it to 2: captured.
11. Last seed lands in an opponent house bringing it to 3: captured.
12. Last seed lands in an opponent house bringing it to 4: nothing captured.
13. Last seed lands in an opponent house bringing it to 1: nothing captured.
14. Last seed lands in the mover's **own** row with 2 seeds: nothing captured.
15. Chained capture across three consecutive qualifying opponent houses.
16. A chain stops at the first non-qualifying house, and does not resume past it.
17. A chain never crosses back into the mover's own row.

**Grand slam**
18. With `LEGAL_NO_CAPTURE`: the move is legal, is playable, and the
    opponent's seed count is unchanged after it.
19. With `FORBIDDEN`: the move is absent from the legal move list.
20. A move that captures all but one of the opponent's seeds is a normal
    capture and is not treated as a grand slam.

**Termination**
21. Reaching 25 seeds ends the game immediately with a win.
22. A 24 to 24 finish is reported as a draw.
23. A threefold repetition ends the game and splits the board by row.
24. 100 plies without capture ends the game and splits the board by row.
25. Starvation with no feeding move gives the remaining board seeds to the
    player to move.

**Search**
26. In a position with an immediate forced capture of 5 seeds and no better
    alternative, all three difficulty levels find it.
27. Hard level search at depth 12 completes inside its time budget.
28. Search never returns an illegal move.
29. Search is deterministic when the random tie-break seed is fixed.
30. Reaching 25 seeds settles the game, so a move that lets the opponent reach
    it is never chosen while a move that prevents it exists.
31. Two games played from the opening position at the same level differ: the
    computer chooses freely among its best openings, or every game is the
    same game.

## 8. Notation for tests and the CLI

Use a compact position string so tests and self play logs are readable:

```
4,4,4,4,4,4 | 4,4,4,4,4,4 | S:0 N:0 | to_move=S
```

Left group is South houses 0 to 5, right group is North houses 6 to 11,
followed by the stores and the side to move. The CLI must be able to load
and print this format.
