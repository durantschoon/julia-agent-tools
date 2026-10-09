# Does installing the directives change what an agent writes?

A small A/B, three runs on 2026-10-07 and 2026-10-08. Same ten editing tasks, done by a headless
coding agent (`claude -p`, one fresh session per task) on two copies of a
private Julia package of mine (about 250 lines of source, with a test
suite): one **bare**, one **tooled** with `install_directives` run on it.
Nothing else differed. Each task started from a clean checkout and was
scored by this repo's `lint-*` rules (`ast-grep scan`) and by the package's
own `Pkg.test()`. The ten tasks are in [`ab/tasks.txt`](ab/tasks.txt); they
were written to invite the mistakes the rules exist for, without naming
them.

## Result

| | bare | tooled |
|---|---|---|
| Tasks that introduced at least one lint hit, per run | **3, 2, 1 of 10** | **1, 0, 0 of 10** |
| Lint hits introduced, total over three runs | 6 | 1 |
| Test suites failing after the change, over three runs | 1 real (plus one container segfault that passed on rerun) | 0 |

Run 1 was in a Linux container (Julia 1.13.1), runs 2 and 3 on a Mac
(Julia 1.12.7), same model and prompts throughout. Per-task scores for
each run are in [`ab/`](ab/).

Every one of the six bare-side hits was the same rule, `lint-allocated-outside-function`:
the agent put `@allocated` at top level in a test, which measures
compilation along with the call. The package's existing tests do exactly
that in 31 places, and the bare agent copied the house style; the tooled
agent wrote each probe inside a small function, as the directive says. So
the fair reading is narrow: **the directives overrode a bad local
convention.** They did not make the agent generally careful.

The one tooled-side hit, in run 1, was `lint-unchecked-type-parameter`: a
`Polynomial{T}` with no inner constructor guarding `T`, on the Horner task.
The rule caught it, which is the other half of the point.

The one real test failure was bare, run 2, on the allocation task: the
agent asserted that an existing function allocates nothing, and it does
not hold; the tooled agent on the same task wrote a probe that passed.

Hits introduced per task (F marks a failed test suite):

| task | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| run 1 bare | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 0 |
| run 1 tooled | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| run 2 bare | 0 | 1 | 0 | 0 | 0F | 0 | 1 | 0 | 0 | 0 |
| run 2 tooled | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| run 3 bare | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| run 3 tooled | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

Task 2 (a sum-of-squares with a no-allocation test) caught the bare agent
all three times.

## Caveats, in honesty

- **Runs vary.** Three valid runs gave 3, 2 and 1 bare slips. Three
  further runs were discarded for harness bugs (an agent that could read
  the remaining tasks from stdin; two runs whose commits failed to sign
  and piled up); where they said anything they pointed the same way,
  more strongly. Treat the numbers as a direction with a range, not a
  measurement to two digits.
- **The rules see only what they encode.** Five lint rules, one package.
  A task the rules have nothing to say about (threading, task 8) scores
  0 on both sides by construction.
- **A real failure the rules missed.** In the discarded run the bare
  agent, asked for `scale(x, k)` with a float method and a `Number`
  fallback, wrote overlapping `::Real` and `where {T <: Real}` methods and
  precompilation refused the package. `lint-overlapping-supertype-method`
  did not flag it: it handles one-argument methods only. Known gap.
- **Environment.** Run 1: Julia 1.13.1 and ast-grep 0.42 in an x86_64
  Linux container emulated on an ARM Mac, where `Pkg.test()` segfaulted
  once and passed on rerun. Runs 2 and 3: Julia 1.12.7 and ast-grep 0.45
  natively on the Mac, no flakes.

## Reproduce it on your own package

```sh
make dylib                                   # once, in this repo
docs/ab/ab.sh --check                       # tool versions and a scanner self-check
docs/ab/ab.sh /path/to/your/julia/project    # ~90 min; results in ~/ab-runs/<timestamp>/
                                             # (or `git config ab.runsDir DIR` to choose the base dir)
```

The script clones the project twice, installs the directives on one copy,
runs each task on both with `claude -p` (permissions limited to edits and
`julia`/`make`), scores with `ast-grep scan --filter '^lint-'` minus the
project's baseline, runs the test suite, and writes `scores.tsv`. It uses
`guix shell` for ast-grep; replace that with your own install if you don't
use Guix. Edit `tasks.txt` to suit your package; keep the prompts free of
hints about the rules.
