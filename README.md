# serez-cobol

A **COBOL → Serez (`.sz`) source-to-source translator** for
[Serez-Code](https://serezcode.org), written in pure `.sz`, plus a **reverse pass** that takes a
documented subset of `.sz` back to COBOL. It turns a COBOL program into an equivalent Serez-Code
program that runs on the `sz` interpreter — and can translate Serez back the other way.

The core's exact `dec` type is what makes COBOL's fixed-point arithmetic (`PIC 9V99`,
`COMPUTE … ROUNDED`) faithful — a banking calculation translates without binary rounding drift:

```cobol
COMPUTE WS-TAX = WS-SUBTOTAL * 0.21 ROUNDED.
```
becomes
```serez
WS_TAX = ((WS_SUBTOTAL * 0.21m) + 0m).setScale(2, "half-up");
```

## Install & use

```powershell
sz install serez-cobol
```

The package exposes a single `convert` command via `sz run` — it decides the direction from the
file extension, there are no sub-commands:

```sh
sz run convert program.cob    # COBOL → Serez: writes program.sz
sz run convert program.sz     # Serez → COBOL: writes program.cob
sz program.sz                 # run the translated program
```

Options carry **no leading dashes** — `sz` itself rejects unknown `--flags` before this package
ever runs:

```sh
sz run convert program.cob clean   # generate .sz without the //@ annotations
sz run convert program.sz sync     # reconcile the //@ annotations with the code, in place
```

Free-format **and** fixed-format sources are auto-detected; `COPY` copybooks resolve next to the
source file.

## COBOL → Serez

This is the direction the translator is built around, and it handles the working set of a real
COBOL program: DATA / PROCEDURE divisions, `PIC` types (numeric-edited included), `OCCURS` tables,
level-88 condition names, arithmetic with `ROUNDED`, `IF` / `EVALUATE` (including `ALSO` decision
tables), every `PERFORM` form (`THRU`, `TIMES`, `UNTIL`, `VARYING … AFTER`), unstructured control
flow (`GO TO`, `GO TO … DEPENDING ON`, `ALTER` — paragraphs run under a program-counter driver so
spaghetti COBOL behaves exactly like COBOL), `CALL` to same-file subprograms, string handling
(`STRING`, `UNSTRING`, `INSPECT`, reference modification) and LINE SEQUENTIAL file I/O.

Main gaps: `REDEFINES` / `COMP-3` byte layouts, `SORT`/`MERGE`, report writer, cross-file `CALL`.

## Serez → COBOL

Two kinds of `.sz` go back to COBOL, and they take different routes.

**A `.sz` that the forward pass produced** round-trips through the `//@` annotations it embeds — a
source map of the IDENTIFICATION / ENVIRONMENT / DATA divisions — while the procedure is genuinely
re-translated. A COBOL → `.sz` → COBOL → `.sz` cycle preserves **behavior** (same output), though
not byte-identical text: `ADD 1 TO X` comes back as `COMPUTE X = X + 1`.

**A `.sz` you wrote yourself** needs no annotations at all. Top-level statements become the main
`PROCEDURE DIVISION`, each `fn name(params)` becomes a COBOL subprogram reached with
`CALL … USING`, and the DATA DIVISION is inferred from the code:

```serez
fn int Sumar(a, b) {
    return a + b;
}

let resultado = Sumar(10, 20);
out resultado;
```
```cobol
IDENTIFICATION DIVISION.
PROGRAM-ID. DEMO.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 RESULTADO PIC S9(9) VALUE 0.
01 SUMAR-A PIC S9(9) VALUE 0.
01 SUMAR-B PIC S9(9) VALUE 0.
01 SUMAR-RESULT PIC S9(9) VALUE 0.
PROCEDURE DIVISION.
           MOVE 10 TO SUMAR-A
           MOVE 20 TO SUMAR-B
           CALL "SUMAR" USING SUMAR-A SUMAR-B SUMAR-RESULT
           MOVE SUMAR-RESULT TO RESULTADO.
           DISPLAY RESULTADO.
           STOP RUN.
END PROGRAM DEMO.
…
```

### What translates

`let` declarations · assignment (`MOVE` / `COMPUTE`) · `out` (`DISPLAY`) · string concatenation
(`STRING`) · `if` / `else if` / `else` · `while` (`PERFORM UNTIL`) · counted `for`
(`PERFORM VARYING`) · `fn` with parameters and a return value (`CALL … USING`) · `return` ·
`exit(0)` (`STOP RUN`).

### Types on parameters

Parameters and return values may be typed, and the declared type drives the `PIC` directly instead
of being guessed from the call sites:

```serez
fn int    Suman(int a, int b)     { return a + b; }        // PIC S9(9)
fn string Saludo(string quien)    { return "hola " + quien; }
fn dec    ConIva(dec monto)       { return monto * 1.21m; }
```

A `dec` result takes **the scale the arithmetic actually produces** — a product adds its operands'
scales, a sum takes the widest — so `monto * 1.21m` with a `V99` argument yields `PIC S9(9)V9999`.
A fixed `V99` there would make COBOL truncate what Serez computed exactly, which is the one thing
this translator exists to get right. A `string` result is sized to the exact width of what it
returns, so `DISPLAY` does not pad with blanks the `.sz` never prints.

The same rule applies to a plain variable holding a computed value — `let iva = precio * 0.21m;`
gets `PIC S9(9)V9999`, not the `PIC S9(9)` its (non-literal) initializer would otherwise suggest.

### What does not, and says so

COBOL has no dynamic arrays, dictionaries, objects, closures, exceptions, booleans or dynamic
typing. Anything in that list is **refused with the line number and the reason, and no `.cob` is
written** — the translator never emits a half-program, and never emits COBOL that would not
compile:

```
$ sz run convert app.sz
ERROR: cannot translate app.sz to COBOL — nothing was written.
  line 1: array literals have no COBOL equivalent
  line 3: dynamic arrays (push/pop) have no COBOL equivalent — a COBOL table has a fixed OCCURS
  line 4: lambdas / arrow functions have no COBOL equivalent
```

The full list of what is refused, and why:

| Serez | Why COBOL cannot take it |
| --- | --- |
| `[1, 2, 3]`, `a.push(x)` | a COBOL table is a fixed `OCCURS`, declared up front |
| `({ k: v })` | no dictionary / map type exists |
| `x => x * 2` | no closures, no first-class functions |
| `class` / `interface` / `enum` | no user-defined types |
| `try` / `throw` / `catch` | no exceptions |
| `import` | no module system — a `CALL` reaches a subprogram in the same file |
| `for (x in coll)` | iteration is a counted `PERFORM VARYING` |
| `t[i] = x` | needs a table declared with `OCCURS`, which inference cannot invent |
| `obj.campo = x` | no object to hold the field |
| `let ok = true;`, `let ok = a > b;` | no boolean data item — use `0`/`1`, or a level-88 name |
| `a % 3` | remainder is a statement (`DIVIDE … REMAINDER`), not an operator |
| `a += 2` | no compound assignment — write `a = a + 2;` |
| `break` / `continue` | no mid-loop exit; the condition has to carry it |
| `do { … } while (c)` | `PERFORM UNTIL` tests **before** the body |
| `match` / `switch` | `EVALUATE` is only produced going the other way; use `if` / `else if` |
| `s.toUpperCase()`, any stdlib call | only functions defined in the same file become a `CALL` |
| `out "n: " + F(x);` | a `CALL` is a statement, not an operand — assign it first |
| `if (c) { out 1; }` on one line | the translator reads one statement per line |

### What inference cannot recover

`PIC` widths come from the literals actually assigned, so a COBOL `PIC X(20) VALUE "world"` that
became `let WS_NAME = "world";` infers back as `PIC X(5)`. Level hierarchies (`05` / `10` inside an
`01`), `OCCURS`, level-88, numeric-edited masks and `FD` / `SELECT` clauses are not in the `.sz` at
all and cannot be inferred — for those, keep the annotations.

## The `//@` annotations

They are ordinary comments: nothing stops them from drifting out of step with the code they
describe. So they are **not trusted blindly** — every conversion cross-checks them against the
actual `let` declarations, keeps what still matches, adds inferred entries for variables that were
never annotated, drops the ones whose variable is gone, and reports it:

```
annotation drift in app.sz:
  dropped: 'WS-NAME' is annotated but no longer declared in the code
  added:   'WS-NOMBRE' is declared in the code but was not annotated (PIC inferred)
  note:    a dropped + added pair is what a rename looks like from here;
           if it was one, the original PIC could not be carried over.
  (pass `sync` to reconcile them in the source .sz)
```

Without `sync` the source `.sz` is **never** modified — the drift is only reported. With `sync`,
the reconciled block is written back into the file. Use `clean` on the forward pass if you are
migrating one way and never coming back, and want a `.sz` with no annotations at all.

## Documentation

- **[serez-cobol reference](https://serezcode.org/docs/serez-cobol)** — supported statements,
  type mapping, round-trip semantics and worked examples, on the Serez-Code site.

## Tests

```sh
sz tests/run_tests.sz         # COBOL → sz: translate + run + diff vs golden   (23)
sz tests/run_roundtrip.sz     # COBOL → sz → COBOL → sz, behavior preserved    (22)
sz tests/run_plain.sz         # hand-written sz → COBOL → sz, plus clean/sync   (9)
```

Every `examples/<name>.cob` is translated, executed, and compared against its
`examples/<name>.expected` golden; the round-trip runner then verifies the full cycle on the same
examples; the plain runner does the same for `examples/plain/*.sz`, which carry no annotations, and
checks that unsupported sources are refused outright.

## Layout

```
index.sz             single entry point (routes by file extension, forwards clean/sync)
cobol.sz             the COBOL→sz engine (lexer + parser + emitter + COPY)
serez.sz             the sz→COBOL engine (annotations, inference, plain mode)
runtime/cobol_rt.sz  PIC-editing + class-test runtime, prepended when needed
examples/            sample COBOL programs, copybooks and golden outputs
examples/plain/      hand-written .sz sources (no annotations)
tests/               end-to-end + round-trip + plain runners (pure .sz)
```
