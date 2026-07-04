# serez-cobol

A **COBOL → Serez (`.sz`) source-to-source translator**, written in pure `.sz`.
It reads a COBOL program and emits an equivalent Serez-Code program that runs on
the `sz` interpreter.

It depends only on the **serez-code core** — no core changes. The exact `dec`
type added to the core is what makes COBOL's fixed-point (`PIC 9V99`, `COMPUTE …
ROUNDED`) arithmetic faithful: a banking calculation translates without binary
rounding drift.

```cobol
COMPUTE WS-TAX = WS-SUBTOTAL * 0.21 ROUNDED.
```
becomes
```serez
WS_TAX = ((WS_SUBTOTAL * 0.21m) + 0m).setScale(2, "half-up");
```

## Usage

Once installed (`sz install serez-cobol`), the package exposes a single
`convert` command via `sz run`. It decides the direction from the input file
extension — there are no sub-commands:

```sh
sz run convert program.cob    # .cob/.cbl → COBOL → Serez (.sz)     [cobol.sz]
sz run convert program.sz     # .sz       → Serez → COBOL (.cob)     [serez.sz]
sz run convert notes.txt      # anything else → a clear error
```

`sz run convert` forwards the file to the entry point (`index.sz`), which
locates its engines next to itself. Running the entry directly also works —
handy inside the repo:

```sh
sz index.sz program.cob       # same routing, run from the repo
```

You can also run the engines directly:

```sh
sz cobol.sz examples/invoice.cob      # writes examples/invoice.sz
sz examples/invoice.sz                # run the translated program
sz serez.sz program.sz                # writes program.cob
```

`cobol.sz` auto-detects free- or fixed-format source and needs `File`/`Env`
permissions (`serez.json`). Both directions are pure `.sz`.

### Reverse direction (.sz → COBOL)

Because the `.sz` cannot represent COBOL-only structure (the exact PICTURE, level
numbers, sections), `cobol.sz` embeds the IDENTIFICATION / ENVIRONMENT / DATA
divisions as `//@` comment annotations in the generated `.sz` — a source map.
They are ignored when the `.sz` runs (and don't affect any golden). `serez.sz`
reconstructs those divisions from the annotations and genuinely translates the
PROCEDURE back (DISPLAY/MOVE/COMPUTE, IF/EVALUATE→nested IF, PERFORM forms,
GO TO, conditions incl. class tests, subscripts).

A COBOL→.sz→COBOL→.sz round-trip therefore preserves **behavior** (same output),
though not byte-identical text (e.g. `ADD 1 TO X` comes back as `COMPUTE X = X + 1`;
an `EVALUATE` comes back as nested `IF`s). `tests/run_roundtrip.sz` checks this on
all 15 examples (including `STRING`/`UNSTRING`/`INSPECT`/reference-modification
and full file I/O) — **15/15 preserve behavior**.

## Supported (v2.0)

**Divisions & layout**
- IDENTIFICATION / ENVIRONMENT (FILE-CONTROL) / DATA / PROCEDURE.
- Free-format **and** fixed-format (cols 1-6 sequence, col 7 indicator, >72 ignored).
- `COPY` copybooks (resolved next to the source; `REPLACING` ignored).
- `*` / `*>` comments.

**Data (WORKING-STORAGE, FILE SECTION, LINKAGE)**
- `PIC 9(n)` → `int` · `9(n)V9(m)` / `S9..V..` → exact `dec` · `X(n)`/`A(n)` → `string`.
- Numeric-edited PICs (`Z`, `,`, `.`, `$`, `*`) → formatted on assignment.
- `VALUE`, `ZERO`/`SPACE`; level **77** items and level **88** condition names;
  group items (organizational); `OCCURS n TIMES` tables with subscripts `T(i)`.

**Procedure**
- `DISPLAY` (incl. `WITH NO ADVANCING`, parsed), `MOVE`, `ACCEPT`, `INITIALIZE`,
  `SET` (`88 TO TRUE`, index `TO`/`UP BY`/`DOWN BY`), `CONTINUE`,
  `STOP RUN` / `GOBACK` / `EXIT PROGRAM` (→ real exit).
- `COMPUTE [ROUNDED]` (incl. `**` and several receivers `COMPUTE a b = …`);
  `ADD`/`SUBTRACT`/`MULTIPLY`/`DIVIDE` with `TO/FROM/BY/INTO/GIVING [ROUNDED]`,
  `DIVIDE … REMAINDER`, and **multiple receivers** (`ADD 1 TO a b c`).
- `IF / ELSE / END-IF`; `EVALUATE … WHEN [v | v THRU w | a WHEN b] … WHEN OTHER …`
  (subject value, or `EVALUATE TRUE`); multi-subject decision tables
  `EVALUATE a ALSO b … WHEN v1 ALSO v2 … WHEN … ALSO ANY …`.
- `PERFORM <para> [THRU <para2>]`, `… <n|var> TIMES | UNTIL c | VARYING v FROM a BY b
  UNTIL c [AFTER w FROM … UNTIL …]`, and inline `PERFORM … END-PERFORM`.
- `GO TO <para>` (forward skip and backward loops), `GO TO p1 p2 … DEPENDING ON i`
  (computed), and `ALTER <para> TO PROCEED TO <target>` (runtime-mutable GO TO) —
  paragraphs run under a program-counter driver, so all of these plus fall-through
  and `STOP RUN` behave like COBOL. (`GO TO` inside a PERFORMed paragraph: not yet.)
- `CALL "SUB" [USING a b c]` to a subprogram defined in the same file (separate
  compilation units / `END PROGRAM`): the subprogram becomes a function, USING
  args are passed and written back (COBOL BY REFERENCE) via a returned tuple.
- Strings: reference modification `X(p:len)`, `STRING`, `UNSTRING`, `INSPECT TALLYING`/`REPLACING`.
- Files (LINE SEQUENTIAL): `SELECT…ASSIGN`, `FD`, `OPEN`, `READ … AT END / NOT AT END … END-READ`,
  `WRITE [FROM]`, `CLOSE`.

**Conditions** — `= > < >= <=`, `GREATER`/`LESS`/`EQUAL [THAN/TO]`, `AND`/`OR`,
`NOT` (negated operator, group, or relation), abbreviated/implied subject
(`IF X = 1 OR 2 OR 3`), class tests (`IS [NOT] NUMERIC` / `ALPHABETIC[-UPPER|-LOWER]`),
and 88-names. `=` → `==`; COBOL names (`WS-TOTAL`) → valid `.sz` names (`WS_TOTAL`).

### Worked example

`examples/payroll_batch.cob` (tables + dec + PERFORM VARYING + EVALUATE + PIC editing):

```
Emp 1: gross 4,000.00 net $3,280.00 (MID)
Emp 2: gross 3,200.00 net $2,624.00 (MID)
Emp 3: gross 2,635.00 net $2,160.70 (MID)
----------------------------
Total net: $8,064.70
```

All amounts use exact `dec` arithmetic, so results match a COBOL runtime.

## Not yet supported (roadmap)

- `CALL` to a subprogram in *another file* (only same-file units are linked) and
  external system calls. Recursion / persisted subprogram state across calls.
- **Round-trip** (`serez.sz`) of multi-program files: the forward direction
  translates `CALL` + subprograms and runs correctly, but the reverse engine
  rebuilds a single program (subprograms aren't re-emitted yet), so `call.cob` is
  in the forward suite, not the round-trip suite.
- `DISPLAY … WITH NO ADVANCING` is parsed but still prints a trailing newline
  (the core has no no-newline print without a Terminal permission).
- `REDEFINES` / byte-overlay, `COMP-3` / `COMP` packed/binary, EBCDIC.
- `SORT`/`MERGE`, report writer, screen section; `ARITH(EXTEND)` 31-digit math
  (`dec` covers 28–29 digits; larger is detected, not supported).
- Group-level `MOVE`/`DISPLAY` (use elementary items). (Note: a `MOVE` of an
  alphanumeric field into a numeric one *is* converted, via `parseInt`/`Dec.parse`.)
- Reverse direction (`serez.sz`): the round-trip is **behavioral**, not byte-for-
  byte (idioms differ: `ADD`↔`COMPUTE`, `EVALUATE`↔nested `IF`, spacing).

## Tests

```sh
sz tests/run_tests.sz            # translate + run + diff vs golden
sz tests/run_tests.sz generate   # regenerate golden .expected files
sz tests/run_roundtrip.sz        # COBOL→sz→COBOL→sz, check behavior preserved
```

The runners are pure `.sz` (they use `OS.exec` to drive `sz` on each example).

Each `examples/<name>.cob` is translated, the generated `.sz` is executed, and
its output compared against `examples/<name>.expected` (17 end-to-end cases).
Highlights: `features.cob` (v2.0 control-flow/condition showcase), `batch.cob`
(file write→read→total→format), and two whole-program integration tests —
`inventory.cob` (tables + dec + file I/O + STRING + EVALUATE ranges + 2-D PERFORM
VARYING…AFTER + class test + PIC editing) and `parser.cob` (UNSTRING + numeric
conversion + DIVIDE REMAINDER + `**` + INSPECT + ref-mod + GO TO + implied
subject + SET); plus two algorithmic ones — `stats.cob` (bubble sort + linear
search + min/max/decimal average) and `decision.cob` (string reversal with a
negative-step `PERFORM VARYING` + an `EVALUATE … ALSO` decision table).
`run_roundtrip.sz` verifies all 19 survive a full COBOL→sz→COBOL→sz cycle with
identical behavior.

## Layout

```
index.sz             single entry point (routes by file extension)
cobol.sz             the COBOL→sz engine (lexer + parser + emitter + COPY)
serez.sz             the sz→COBOL engine (reverse; reads //@ annotations)
runtime/cobol_rt.sz  PIC-editing + class-test runtime, prepended when needed
examples/*.cob       sample COBOL programs        (*.cpy copybooks)
examples/*.expected  golden output of translated programs
tests/run_tests.sz       end-to-end test runner (pure .sz)
tests/run_roundtrip.sz   COBOL→sz→COBOL behavior round-trip test (pure .sz)
```

## Architecture

`cobol.sz` is a single file (to sidestep import-ordering quirks):

1. **COPY preprocess** — splice copybooks (driver, before tokenizing).
2. **Tokenizer** — fixed/free normalization; typed `"T:value"` tokens
   (`W`ord/`S`tring/`N`um/`D`ec/`O`p/`M`ask); `-` kept in identifiers; PIC masks
   read whole.
3. **DATA pass** — `collectVars` (PIC → kind/scale, 88, OCCURS, group, edited),
   `collectFiles` (SELECT/FD/OPEN).
4. **PROCEDURE pass** — `emitProcedure` splits paragraphs (→ `fn`) and drives a
   block stack for IF/EVALUATE/PERFORM/READ; `emitStmt` translates one statement;
   `emitRef`/`emitLhs` handle subscripts and reference modification.
5. **Emitter** — working-storage globals, one `fn` per paragraph, a main section
   calling the non-PERFORMed paragraphs in order.

> Note on the source: braces the translator emits into generated code use
> raw-string literals (`r"{"`, `r"}"`) to avoid serez string interpolation;
> helper variables avoid the reserved names `out`/`dec`.
