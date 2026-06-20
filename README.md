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

```sh
# direct engine:
sz cobol.sz examples/invoice.cob      # writes examples/invoice.sz
sz examples/invoice.sz                # run the translated program

# or via the unified CLI:
sz serezTransform.sz toSerez examples/invoice.cob   # COBOL → .sz  (delegates to cobol.sz)
sz serezTransform.sz toCobol examples/invoice.sz    # .sz → COBOL  (planned, future)
```

`cobol.sz` needs the `File` and `Env` permissions (in `serez.json` / via
`use permissions { File, Env }`). It auto-detects free- or fixed-format source.
`serezTransform.sz` is the front-end dispatcher (`toSerez` works today; `toCobol`,
the reverse direction, is reserved for a future release).

## Supported (v1.0)

**Divisions & layout**
- IDENTIFICATION / ENVIRONMENT (FILE-CONTROL) / DATA / PROCEDURE.
- Free-format **and** fixed-format (cols 1-6 sequence, col 7 indicator, >72 ignored).
- `COPY` copybooks (resolved next to the source; `REPLACING` ignored).
- `*` / `*>` comments.

**Data (WORKING-STORAGE, FILE SECTION, LINKAGE)**
- `PIC 9(n)` → `int` · `9(n)V9(m)` / `S9..V..` → exact `dec` · `X(n)`/`A(n)` → `string`.
- Numeric-edited PICs (`Z`, `,`, `.`, `$`, `*`) → formatted on assignment.
- `VALUE`, `ZERO`/`SPACE`; level **88** condition names; group items (organizational);
  `OCCURS n TIMES` tables with subscripts `T(i)`.

**Procedure**
- `DISPLAY`, `MOVE`, `ACCEPT`, `INITIALIZE`, `CONTINUE`, `STOP RUN` (→ real exit).
- `COMPUTE [ROUNDED]`; `ADD`/`SUBTRACT`/`MULTIPLY`/`DIVIDE` with `TO/FROM/BY/INTO/GIVING [ROUNDED]`.
- `IF / ELSE / END-IF`; `EVALUATE … WHEN … WHEN OTHER … END-EVALUATE`
  (subject value, or `EVALUATE TRUE`).
- `PERFORM <para> [THRU <para2>]`, `… N TIMES | UNTIL c | VARYING v FROM a BY b UNTIL c`,
  and inline `PERFORM … END-PERFORM`; paragraphs → functions.
- `GO TO <para>` (forward skip and backward loops) — paragraphs run under a
  program-counter driver, so `GO TO`, fall-through and `STOP RUN` all behave like
  COBOL. (`GO TO … DEPENDING ON` and `GO TO` inside a PERFORMed paragraph: not yet.)
- Strings: reference modification `X(p:len)`, `STRING`, `UNSTRING`, `INSPECT TALLYING`/`REPLACING`.
- Files (LINE SEQUENTIAL): `SELECT…ASSIGN`, `FD`, `OPEN`, `READ … AT END / NOT AT END … END-READ`,
  `WRITE [FROM]`, `CLOSE`.

**Conditions** — `= > < >= <=`, `GREATER`/`LESS`/`EQUAL [THAN/TO]`, `AND`/`OR`, 88-names.
`=` → `==`; COBOL names (`WS-TOTAL`) → valid `.sz` names (`WS_TOTAL`).

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

- `CALL` / nested programs (emitted as a comment — external subprograms can't be
  auto-linked); `GO TO … DEPENDING ON`; `ALTER`.
- `REDEFINES` / byte-overlay, `COMP-3` / `COMP` packed/binary, EBCDIC.
- `SORT`/`MERGE`, report writer, screen section; `ARITH(EXTEND)` 31-digit math
  (`dec` covers 28–29 digits; larger is detected, not supported).
- Group-level `MOVE`/`DISPLAY` (use elementary items); numeric interpretation of
  raw record fields on `READ` (records arrive as strings).
- **`toCobol`** — the reverse direction (Serez `.sz` → COBOL). Reserved as the
  next major objective; `serezTransform.sz` already exposes the command.

## Tests

```sh
sz tests/run_tests.sz            # translate + run + diff vs golden
sz tests/run_tests.sz generate   # regenerate golden .expected files
```

The runner is pure `.sz` (uses `OS.exec` to drive `sz` on each example).

Each `examples/<name>.cob` is translated, the generated `.sz` is executed, and
its output compared against `examples/<name>.expected` (11 end-to-end cases).

## Layout

```
serezTransform.sz    unified CLI dispatcher (toSerez / toCobol)
cobol.sz             the COBOL→sz engine (lexer + parser + emitter + COPY + CLI)
runtime/cobol_rt.sz  PIC-editing runtime, prepended when edited fields are used
examples/*.cob       sample COBOL programs        (*.cpy copybooks)
examples/*.expected  golden output of translated programs
tests/run_tests.sz   end-to-end test runner (pure .sz)
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
