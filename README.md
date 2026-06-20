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
WS_TAX = (WS_SUBTOTAL * 0.21m).setScale(2, "half-up");
```

## Usage

```sh
sz cobol.sz examples/invoice.cob      # writes examples/invoice.sz
sz examples/invoice.sz                # run the translated program
```

`cobol.sz` needs the `File` and `Env` permissions (declared in `serez.json` /
via `use permissions { File, Env }`).

## What v0.1 supports

| COBOL | Serez (`.sz`) |
|---|---|
| `IDENTIFICATION` / `DATA` / `PROCEDURE` divisions | parsed (free-format) |
| `PIC 9(n)` | `int` |
| `PIC 9(n)V9(m)`, `S9(n)V9(m)` | `dec` (exact), scale = fractional digits |
| `PIC X(n)` | `string` |
| `VALUE` clause / `ZERO` / `SPACE` | initializer |
| `DISPLAY a b c` | `out a + b + c;` |
| `MOVE x TO y` | `y = x;` (dec → `setScale`) |
| `COMPUTE z = expr [ROUNDED]` | `z = (expr).setScale(s, "half-up"/"down");` |
| `ADD x TO y` / `SUBTRACT x FROM y` | `y = y + x;` / `y = y - x;` |
| `IF … [ELSE …] END-IF` | `if (…) { … } else { … }` |
| `PERFORM para` | `para_();` |
| paragraphs | `fn para_() { … }`, called in order (PERFORM targets stay subroutines) |
| `STOP RUN` | end of flow |

`=` becomes `==` in conditions; `AND`/`OR`/`NOT` map to `&&`/`||`/`!`. COBOL
identifiers (`WS-TOTAL`) become valid `.sz` names (`WS_TOTAL`).

### Worked example

`examples/invoice.cob` → translated → run:

```
Item:     Widget
Subtotal: 59.97
Tax:      12.59
Total:    72.56
Status:   premium
```

Every amount is computed with exact `dec` arithmetic, so `19.99 * 3` and
`* 0.21 ROUNDED` give the same results a COBOL runtime would.

## Not in v0.1 (planned)

- `PERFORM … UNTIL / VARYING / N TIMES`, `GO TO`, `EVALUATE`, nested `MOVE`
  PICTURE truncation/padding, `OCCURS` tables, group items / `REDEFINES`.
- `COMP-3` / packed-decimal / `COMP` binary fields and EBCDIC.
- Fixed-column (cols 1-6 / 7 / 8-72) layout — v0.1 expects free-format with `*`
  comment lines.
- `sz → COBOL` (reverse direction).

These are tracked for later versions. `STOP RUN` mid-flow is treated as
end-of-program for the common "MAIN does PERFORMs then STOP RUN" pattern.

## Tests

```sh
pwsh -File tests/run_tests.ps1            # translate + run + diff vs golden
pwsh -File tests/run_tests.ps1 -generate  # regenerate golden .expected files
```

Each `examples/<name>.cob` is translated, the generated `.sz` is executed, and
its output is compared against `examples/<name>.expected`.

## Layout

```
cobol.sz             the translator (lexer + parser + emitter + CLI driver)
examples/*.cob       sample COBOL programs
examples/*.expected  golden output of the translated programs
tests/run_tests.ps1  end-to-end test runner
```

## Architecture

`cobol.sz` is a single file (to sidestep import-ordering quirks):

1. **Tokenizer** — line-oriented; `"T:value"` tokens (`W`ord/`S`tring/`N`um/`D`ecimal/`O`perator), `*` comment lines, `-` kept inside identifiers.
2. **DATA pass** — `collectVars` reads `WORKING-STORAGE`, parses `PIC` masks into `kind|scale`, records initializers.
3. **PROCEDURE pass** — `emitProcedure` splits the body into paragraphs (→ `fn`), translating each statement; `emitStmt` handles one statement and returns the next cursor position.
4. **Emitter** — globals for working-storage, one `fn` per paragraph, a main section that calls the non-PERFORMed paragraphs in order.
