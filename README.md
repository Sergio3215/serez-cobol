# serez-cobol

A **bidirectional COBOL ⇄ Serez (`.sz`) source-to-source translator** for
[Serez-Code](https://serezcode.org), written in pure `.sz`. It turns a COBOL program into an
equivalent Serez-Code program that runs on the `sz` interpreter — and can translate the generated
`.sz` back to COBOL.

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

Free-format **and** fixed-format sources are auto-detected; `COPY` copybooks resolve next to the
source file.

## What it covers

The forward direction handles the working set of a real COBOL program: DATA / PROCEDURE
divisions, `PIC` types (numeric-edited included), `OCCURS` tables, level-88 condition names,
arithmetic with `ROUNDED`, `IF` / `EVALUATE` (including `ALSO` decision tables), every `PERFORM`
form (`THRU`, `TIMES`, `UNTIL`, `VARYING … AFTER`), unstructured control flow (`GO TO`,
`GO TO … DEPENDING ON`, `ALTER` — paragraphs run under a program-counter driver so spaghetti
COBOL behaves exactly like COBOL), `CALL` to same-file subprograms, string handling (`STRING`,
`UNSTRING`, `INSPECT`, reference modification) and LINE SEQUENTIAL file I/O.

The reverse direction reads `//@` annotations that the forward pass embeds in the generated `.sz`
(a source map of the IDENTIFICATION / ENVIRONMENT / DATA divisions) and genuinely re-translates
the procedure. A COBOL → `.sz` → COBOL → `.sz` round-trip preserves **behavior** (same output),
though not byte-identical text — `ADD 1 TO X` comes back as `COMPUTE X = X + 1`.

Main gaps: `REDEFINES` / `COMP-3` byte layouts, `SORT`/`MERGE`, report writer, cross-file `CALL`.

## Documentation

- **[serez-cobol reference](https://serezcode.org/docs/serez-cobol)** — supported statements,
  type mapping, round-trip semantics and worked examples, on the Serez-Code site.

## Tests

```sh
sz tests/run_tests.sz         # translate + run + diff vs golden (end-to-end)
sz tests/run_roundtrip.sz     # COBOL→sz→COBOL→sz, verifies behavior is preserved
```

Every `examples/<name>.cob` is translated, executed, and compared against its
`examples/<name>.expected` golden; the round-trip runner then verifies the full cycle on the same
examples.

## Layout

```
index.sz             single entry point (routes by file extension)
cobol.sz             the COBOL→sz engine (lexer + parser + emitter + COPY)
serez.sz             the sz→COBOL engine (reverse; reads //@ annotations)
runtime/cobol_rt.sz  PIC-editing + class-test runtime, prepended when needed
examples/            sample COBOL programs, copybooks and golden outputs
tests/               end-to-end + round-trip runners (pure .sz)
```
