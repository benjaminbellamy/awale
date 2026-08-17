// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale.Notation {

    /**
     * Reads the compact position string of RULES.md 8, for example
     * {{{4,4,4,4,4,4 | 4,4,4,4,4,4 | S:0 N:0 | to_move=S}}}.
     *
     * These strings are written by hand in tests and by the CLI, so every
     * deviation is reported rather than repaired.
     */
    public Board parse (string text) throws NotationError {
        string[] fields = text.split ("|");
        if (fields.length != 4) {
            throw new NotationError.MALFORMED (
                "expected 4 fields separated by '|', got %d in \"%s\"",
                fields.length, text);
        }

        Board board = Board ();
        parse_row (fields[0], Player.SOUTH.row_start (), ref board);
        parse_row (fields[1], Player.NORTH.row_start (), ref board);

        string[] stores = split_on_spaces (fields[2]);
        if (stores.length != 2) {
            throw new NotationError.MALFORMED (
                "expected \"S:<n> N:<n>\", got \"%s\"", fields[2].strip ());
        }
        board.south_store = parse_store (stores[0], "S");
        board.north_store = parse_store (stores[1], "N");

        board.to_move = parse_side (fields[3]);

        if (!board.invariant_holds ()) {
            throw new NotationError.BAD_TOTAL (
                "position holds %d seeds, expected %d",
                board.seeds_on_board () + board.south_store + board.north_store,
                TOTAL_SEEDS);
        }
        return board;
    }

    /** Writes the position string of RULES.md 8. */
    public string format (Board board) {
        var builder = new StringBuilder ();
        append_row (builder, board, Player.SOUTH.row_start ());
        builder.append (" | ");
        append_row (builder, board, Player.NORTH.row_start ());
        builder.append_printf (" | S:%d N:%d | to_move=%s",
                               board.south_store,
                               board.north_store,
                               board.to_move.to_letter ());
        return builder.str;
    }

    private void append_row (StringBuilder builder, Board board, int start) {
        for (int i = 0; i < ROW_SIZE; i++) {
            if (i > 0) {
                builder.append_c (',');
            }
            builder.append_printf ("%d", board.houses[start + i]);
        }
    }

    private void parse_row (string field, int start, ref Board board) throws NotationError {
        string[] counts = field.split (",");
        if (counts.length != ROW_SIZE) {
            throw new NotationError.MALFORMED (
                "expected %d house counts, got %d in \"%s\"",
                ROW_SIZE, counts.length, field.strip ());
        }
        for (int i = 0; i < ROW_SIZE; i++) {
            board.houses[start + i] = parse_count (counts[i]);
        }
    }

    private int parse_store (string token, string label) throws NotationError {
        string prefix = label + ":";
        if (!token.has_prefix (prefix)) {
            throw new NotationError.MALFORMED (
                "expected a \"%s\" store, got \"%s\"", prefix, token);
        }
        return parse_count (token.substring (prefix.length));
    }

    private Player parse_side (string field) throws NotationError {
        const string PREFIX = "to_move=";
        string token = field.strip ();
        if (!token.has_prefix (PREFIX)) {
            throw new NotationError.MALFORMED (
                "expected \"%s<S|N>\", got \"%s\"", PREFIX, token);
        }
        string side = token.substring (PREFIX.length).strip ();
        switch (side) {
            case "S":
                return Player.SOUTH;
            case "N":
                return Player.NORTH;
            default:
                throw new NotationError.MALFORMED (
                    "side to move must be \"S\" or \"N\", got \"%s\"", side);
        }
    }

    private int parse_count (string token) throws NotationError {
        string trimmed = token.strip ();
        int64 value = 0;
        if (trimmed == "" || !int64.try_parse (trimmed, out value)) {
            throw new NotationError.MALFORMED ("\"%s\" is not a number", token);
        }
        if (value < 0 || value > TOTAL_SEEDS) {
            throw new NotationError.OUT_OF_RANGE (
                "%s seeds is outside 0 to %d", trimmed, TOTAL_SEEDS);
        }
        return (int) value;
    }

    private string[] split_on_spaces (string field) {
        string[] tokens = {};
        foreach (string token in field.split (" ")) {
            string trimmed = token.strip ();
            if (trimmed != "") {
                tokens += trimmed;
            }
        }
        return tokens;
    }
}
