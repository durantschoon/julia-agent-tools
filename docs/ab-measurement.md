# Does installing the directives change what an agent writes?

A small A/B, run 2026-10-07. Same ten editing tasks, done by a headless
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
| Tasks that introduced at least one lint hit | **3 of 10** | **1 of 10** |
| Lint hits introduced, total | 3 | 1 |
| Test suites failing after the change | 0 (one flaky segfault, passed on rerun) | 0 |

Every bare-side hit was the same rule, `lint-allocated-outside-function`:
the agent put `@allocated` at top level in a test, which measures
compilation along with the call. The package's existing tests do exactly
that in 31 places, and the bare agent copied the house style; the tooled
agent wrote each probe inside a small function, as the directive says. So
the fair reading is narrow: **the directives overrode a bad local
convention.** They did not make the agent generally careful.

The one tooled-side hit was `lint-unchecked-type-parameter`: a
`Polynomial{T}` with no inner constructor guarding `T`, on the Horner task.
The rule caught it, which is the other half of the point.

Per task (hits introduced / test suite), from [`ab/scores.tsv`](ab/scores.tsv):

| task | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| bare | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 0 |
| tooled | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |

## Caveats, in honesty

- **Single runs vary.** An earlier run of the same tasks, discarded for
  a harness bug (the agent could see the remaining tasks and sometimes did
  them all at once), showed the same direction more strongly: 20 bare
  hits in 6 of 10 tasks against 0 tooled. Treat the numbers above as one
  sample of a noisy process, not a measurement to two digits.
- **The rules see only what they encode.** Five lint rules, one package.
  A task the rules have nothing to say about (threading, task 8) scores
  0 on both sides by construction.
- **A real failure the rules missed.** In the discarded run the bare
  agent, asked for `scale(x, k)` with a float method and a `Number`
  fallback, wrote overlapping `::Real` and `where {T <: Real}` methods and
  precompilation refused the package. `lint-overlapping-supertype-method`
  did not flag it: it handles one-argument methods only. Known gap.
- **Environment.** Julia 1.13.1 and ast-grep 0.42 in a Linux container;
  `Pkg.test()` segfaulted once in each run and passed on rerun, which is
  the container, not the agent.

## Reproduce it on your own package

```sh
make dylib                                        # once, in this repo
docs/ab/ab.sh /path/to/your/julia/project         # ~90 min for ten tasks
```

The script clones the project twice, installs the directives on one copy,
runs each task on both with `claude -p` (permissions limited to edits and
`julia`/`make`), scores with `ast-grep scan --filter '^lint-'` minus the
project's baseline, runs the test suite, and writes `scores.tsv`. It uses
`guix shell` for ast-grep; replace that with your own install if you don't
use Guix. Edit `tasks.txt` to suit your package; keep the prompts free of
hints about the rules.
