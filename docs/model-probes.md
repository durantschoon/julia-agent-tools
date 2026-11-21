# Does your model need the struct-field rules?

The directives and lint rules in this repo exist because coding agents were
seen making specific Julia mistakes. Models differ, and they change. This
page is a small probe you can run on any model and harness to see whether one
of those mistakes still happens for you: leaving struct fields untyped or
abstractly typed.

It is most useful on smaller, cheaper or older models. If you find one that
slips, please add a row to the table below.

## Why this page exists

After the [announcement](https://discourse.julialang.org/t/julia-agent-tools-agent-directives-ast-grep-rules-and-a-ctags-optlib-for-julia/142735),
a reply said the untyped-field problem had not shown up for them with
DeepSeek V4.1. We checked on 2026-11-04 and got the same answer: asked for a
small particle module, DeepSeek V4.1 Flash (through OpenCode) gave every
field a concrete type, both inside this repository and in an empty directory.

So for that model, on that task, the rule has nothing to catch. One case
does not settle which models, harnesses or prompts do produce the mistake,
which is what the probe is for.

## What is here

Everything is in [`probes/struct-fields/`](probes/struct-fields/).

| File | Role |
|---|---|
| `tasks.txt` | Five small tasks, one per line, written to invite an untyped or abstract field without naming the mistake. |
| `check.sh` | Scores Julia files with the two rules, `lint-untyped-struct-field` and `lint-abstract-struct-field`. |
| `field_checks_demo.jl` | The flagged control. Two of its four structs are wrong on purpose; it also prints what each declaration costs at run time. |
| `particles_2d.jl` | The clean reference, kept from the 2026-11-04 follow-up. Every field is concretely typed. |

Only task 1 (the particle module) has been tried on a model so far. Tasks 2
to 5 are untested suggestions.

## Running the probe

You need `ast-grep` and the Julia grammar (`make dylib`); see the README.

1. Check the checker:

   ```bash
   make test-probes
   ```

   It must report two hits for the control and none for the clean reference.

2. For each line of `tasks.txt`, start your agent in an **empty directory**
   with no directives installed, give it the task as the whole prompt, and
   keep the Julia file it writes. One fresh session per task.

3. Score what it wrote:

   ```bash
   docs/probes/struct-fields/check.sh /path/to/the/outputs
   ```

   `PASS` means no field was flagged. `FLAGGED` lists each hit with its rule.
   The exit status is 1 when anything is flagged. A scan that cannot run
   finds nothing, which would look like a pass, so the checker first confirms
   that the flagged control still gets its two hits and stops with status 2
   if it does not.

4. Optional: install the directives into a second empty directory
   (`./bin/julia-agent-tools install-directives <dir>`), repeat, and compare.

The rules read syntax only. They catch a field with no annotation and a
field annotated `Any`, `Number`, `Real`, `Integer`, `Function` or
`Abstract...`. They do not catch an abstract type nested inside another type,
such as `Vector{Real}`, so read the output as well as the score.

## Results

"Tasks flagged" counts the tasks, out of those run, where at least one field
was flagged.

| Date | Model | Harness | Directives | Tasks run | Tasks flagged | Notes |
|---|---|---|---|---|---|---|
| 2026-11-04 | DeepSeek V4.1 Flash (1017), via OpenRouter | OpenCode | none | task 1, twice (in this repository and in an empty directory) | 0 | Concrete field types both times. |

To add a row, open a pull request or an issue with the model, the harness,
which tasks you ran and what `check.sh` reported. Runs where the model slips
are the interesting ones, and so are clean runs on small models.
