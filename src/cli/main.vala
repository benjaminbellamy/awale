// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * Headless driver for the engine. Its output is meant for developers, so its
 * strings are not translated.
 */
namespace Awale.Cli {

    private const string USAGE = """Usage:
  awale-cli show [POSITION]
  awale-cli moves [POSITION]
  awale-cli play HOUSE [POSITION]
  awale-cli perft DEPTH [POSITION]
  awale-cli search LEVEL [POSITION]
  awale-cli selfplay [--seed=N] [--max-plies=N] [--level=LEVEL] [--quiet]

POSITION follows docs/RULES.md section 8, for example
  "4,4,4,4,4,4 | 4,4,4,4,4,4 | S:0 N:0 | to_move=S"
and defaults to the opening position.

LEVEL is easy, medium or hard.

Options:
  --forbid-grand-slam   use GrandSlamPolicy.FORBIDDEN instead of the default
  --seed=N              seed of the self play generator (default 1)
  --max-plies=N         plies to play before stopping self play (default 1000)
  --level=LEVEL         self play with the engine at LEVEL instead of at random
  --quiet               print only the self play summary
""";

    public static int main (string[] args) {
        string[] positional = {};
        var policy = GrandSlamPolicy.LEGAL_NO_CAPTURE;
        uint32 seed = 1;
        int max_plies = 1000;
        bool quiet = false;
        Difficulty? level = null;

        try {
            for (int i = 1; i < args.length; i++) {
                string arg = args[i];
                if (arg == "--forbid-grand-slam") {
                    policy = GrandSlamPolicy.FORBIDDEN;
                } else if (arg == "--quiet") {
                    quiet = true;
                } else if (arg.has_prefix ("--seed=")) {
                    seed = (uint32) parse_number (arg, "--seed=");
                } else if (arg.has_prefix ("--max-plies=")) {
                    max_plies = parse_number (arg, "--max-plies=");
                } else if (arg.has_prefix ("--level=")) {
                    level = parse_difficulty (arg.substring ("--level=".length));
                } else if (arg.has_prefix ("-")) {
                    throw new NotationError.MALFORMED ("unknown option \"%s\"", arg);
                } else {
                    positional += arg;
                }
            }

            if (positional.length == 0) {
                stdout.puts (USAGE);
                return 1;
            }

            switch (positional[0]) {
                case "show":
                    return run_show (positional, policy);
                case "moves":
                    return run_moves (positional, policy);
                case "play":
                    return run_play (positional, policy);
                case "perft":
                    return run_perft (positional, policy);
                case "search":
                    return run_search (positional, policy);
                case "selfplay":
                    return run_selfplay (policy, seed, max_plies, level, quiet);
                default:
                    throw new NotationError.MALFORMED (
                        "unknown command \"%s\"", positional[0]);
            }
        } catch (NotationError e) {
            stderr.printf ("awale-cli: %s\n", e.message);
            return 1;
        }
    }

    private static int run_show (string[] positional, GrandSlamPolicy policy) throws NotationError {
        Board board = position_at (positional, 1);
        print_board (board, policy);
        return 0;
    }

    private static int run_moves (string[] positional, GrandSlamPolicy policy) throws NotationError {
        Board board = position_at (positional, 1);
        stdout.printf ("%s\n", format_moves (board.legal_moves (policy)));
        return 0;
    }

    private static int run_play (string[] positional, GrandSlamPolicy policy) throws NotationError {
        if (positional.length < 2) {
            throw new NotationError.MALFORMED ("play needs a house index");
        }
        int house = parse_number (positional[1], "");
        Board board = position_at (positional, 2);
        if (!board.is_legal (house, policy)) {
            throw new NotationError.MALFORMED (
                "house %d is not a legal move for %s",
                house, board.to_move.to_letter ());
        }

        MoveResult result = board.apply_move (house, policy);
        stdout.printf ("%s\n", Notation.format (board));
        stdout.printf ("captured: %d\n", result.captured);
        stdout.printf ("last house: %d\n", result.last_house);
        if (result.grand_slam_suppressed) {
            stdout.puts ("grand slam: captured nothing\n");
        }
        return 0;
    }

    private static int run_perft (string[] positional, GrandSlamPolicy policy) throws NotationError {
        if (positional.length < 2) {
            throw new NotationError.MALFORMED ("perft needs a depth");
        }
        int depth = parse_number (positional[1], "");
        Board board = position_at (positional, 2);

        // Counts move sequences only. The repetition and no capture guards of
        // RULES.md 6.2 live in Game and are deliberately not applied here.
        for (int d = 1; d <= depth; d++) {
            stdout.printf ("perft(%d) = %s\n", d, perft (board, d, policy).to_string ());
        }
        return 0;
    }

    private static int64 perft (Board board, int depth, GrandSlamPolicy policy) {
        if (depth == 0) {
            return 1;
        }
        int[] moves = board.legal_moves (policy);
        if (moves.length == 0) {
            return 1;
        }
        int64 total = 0;
        foreach (int house in moves) {
            Board next = board.copy ();
            next.apply_move (house, policy);
            total += perft (next, depth - 1, policy);
        }
        return total;
    }

    private static int run_search (string[] positional, GrandSlamPolicy policy) throws NotationError {
        if (positional.length < 2) {
            throw new NotationError.MALFORMED ("search needs a level");
        }
        Difficulty level = parse_difficulty (positional[1]);
        Board board = position_at (positional, 2);

        var engine = new Search ();
        engine.grand_slam_policy = policy;
        engine.use_transposition_table = level.uses_transposition_table ();
        SearchResult result = engine.search (board, level.max_depth (), level.time_budget_ms ());

        stdout.printf ("%s\n", Notation.format (board));
        stdout.printf ("level:     %s (%d plies, %s ms)\n",
                       level.to_keyword (), level.max_depth (),
                       level.time_budget_ms ().to_string ());
        stdout.printf ("best move: %d\n", result.best_move);
        stdout.printf ("score:     %d\n", result.score);
        stdout.printf ("depth:     %d\n", result.depth_reached);
        stdout.printf ("nodes:     %s in %s ms\n",
                       result.nodes.to_string (), result.elapsed_ms.to_string ());
        foreach (MoveScore move in result.moves) {
            stdout.printf ("  house %d  %d\n", move.house, move.score);
        }
        return 0;
    }

    private static int run_selfplay (GrandSlamPolicy policy, uint32 seed, int max_plies,
                                     Difficulty? level, bool quiet) {
        var random = new Rand.with_seed (seed);
        var game = new Game (Player.SOUTH, policy);
        Opponent? engine = null;
        if (level != null) {
            engine = new Opponent (level, seed);
            engine.grand_slam_policy = policy;
        }

        int plies = 0;
        int games = 1;
        while (plies < max_plies) {
            if (game.outcome != Outcome.IN_PROGRESS) {
                if (!quiet) {
                    stdout.printf ("game %d: %s (%s)\n",
                                   games,
                                   game.outcome.to_string (),
                                   game.end_reason.to_string ());
                }
                games++;
                game.reset ();
                if (engine != null) {
                    engine.reset ();
                }
                continue;
            }

            int house;
            if (engine != null) {
                house = engine.choose_move (game.board, game.ply_count);
            } else {
                int[] moves = game.legal_moves ();
                house = moves[random.int_range (0, moves.length)];
            }
            game.play (house);
            plies++;

            if (!game.board.invariant_holds ()) {
                stderr.printf ("invariant broken after ply %d: %s\n",
                               plies, Notation.format (game.board));
                return 1;
            }
            if (!quiet) {
                stdout.printf ("%3d %s plays %d -> %s\n",
                               plies,
                               house < ROW_SIZE ? "S" : "N",
                               house,
                               Notation.format (game.board));
            }
        }

        stdout.printf ("%d plies over %d game(s), invariant held\n", plies, games);
        return 0;
    }

    private static void print_board (Board board, GrandSlamPolicy policy) {
        stdout.printf ("%s\n", Notation.format (board));
        stdout.printf ("north row: %s\n", row_line (board, Player.NORTH, true));
        stdout.printf ("south row: %s\n", row_line (board, Player.SOUTH, false));
        stdout.printf ("stores:    S %d  N %d\n", board.south_store, board.north_store);
        stdout.printf ("to move:   %s\n", board.to_move.to_letter ());
        stdout.printf ("moves:     %s\n", format_moves (board.legal_moves (policy)));
    }

    /** North is printed right to left so the board reads as it is laid out. */
    private static string row_line (Board board, Player player, bool reversed) {
        var builder = new StringBuilder ();
        int start = player.row_start ();
        for (int i = 0; i < ROW_SIZE; i++) {
            int house = reversed ? start + ROW_SIZE - 1 - i : start + i;
            builder.append_printf ("%3d", board.houses[house]);
        }
        return builder.str;
    }

    private static string format_moves (int[] moves) {
        if (moves.length == 0) {
            return "none";
        }
        var builder = new StringBuilder ();
        foreach (int house in moves) {
            if (builder.len > 0) {
                builder.append_c (' ');
            }
            builder.append_printf ("%d", house);
        }
        return builder.str;
    }

    private static Board position_at (string[] positional, int index) throws NotationError {
        if (positional.length <= index) {
            return Board.initial ();
        }
        return Notation.parse (positional[index]);
    }

    private static Difficulty parse_difficulty (string name) throws NotationError {
        Difficulty level;
        if (!Difficulty.from_keyword (name, out level)) {
            throw new NotationError.MALFORMED (
                "level must be easy, medium or hard, got \"%s\"", name);
        }
        return level;
    }

    private static int parse_number (string arg, string prefix) throws NotationError {
        string text = arg.substring (prefix.length);
        int64 value = 0;
        if (text == "" || !int64.try_parse (text, out value)) {
            throw new NotationError.MALFORMED ("\"%s\" is not a number", arg);
        }
        return (int) value;
    }
}
