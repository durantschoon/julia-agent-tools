module JuliaAgentTools

using InteractiveUtils
using Test

export audit_allocations, is_type_stable, run_ast_grep, run_ast_lint, generate_tags, install_directives

const PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const CTAGS_OPT = normpath(joinpath(PACKAGE_ROOT, "ctags.d", "julia.ctags"))
const RULES_DIR = normpath(joinpath(PACKAGE_ROOT, "rules"))
const SG_CONFIG = normpath(joinpath(PACKAGE_ROOT, "sgconfig.yml"))

"""
    audit_allocations(f, args...) -> Int

Measure the heap memory allocated by executing `f(args...)` with zero REPL/global scope capture.
Runs a warmup execution first to ensure JIT compilation overhead is excluded.
Returns the total bytes allocated.
"""
function audit_allocations(f::F, args...) where {F}
    # JIT warm-up execution
    f(args...)

    # Local function barrier to prevent dynamic boxing
    @noinline function _measure_allocs(fn::F, xs...) where {F}
        return @allocated fn(xs...)
    end

    return _measure_allocs(f, args...)
end

"""
    is_type_stable(f, argtypes::Tuple) -> Bool

Check whether `f` invoked with argument types `argtypes` has a concrete, fully inferred return type.
"""
function is_type_stable(f, argtypes::Tuple)
    ir = code_typed(f, argtypes)
    if isempty(ir)
        return false
    end
    ret_type = ir[1].second
    return isconcretetype(ret_type)
end

"""
    run_ast_grep(; pattern=nothing, kind=nothing, path=".")

Execute `ast-grep` against Julia source code using the configured Tree-sitter grammar.
"""
function run_ast_grep(; pattern::Union{Nothing, String}=nothing, kind::Union{Nothing, String}=nothing, path::String=".")
    sg = Sys.which("ast-grep")
    if sg === nothing
        sg = Sys.which("sg")
    end
    if sg === nothing
        error("ast-grep (or sg) not found on PATH. Install via `brew install ast-grep` or `cargo install ast-grep`.")
    end

    cmd_args = String[sg, "run", "-c", SG_CONFIG]
    if kind !== nothing
        push!(cmd_args, "-k", kind)
    end
    if pattern !== nothing
        push!(cmd_args, "-p", pattern)
    end
    push!(cmd_args, path)

    run(Cmd(cmd_args))
end

"""
    run_ast_lint(path=".")

Scan the target path using `ast-grep` and the pre-configured Julia AST lint rules.
"""
function run_ast_lint(path::String=".")
    sg = Sys.which("ast-grep")
    if sg === nothing
        sg = Sys.which("sg")
    end
    if sg === nothing
        error("ast-grep (or sg) not found on PATH.")
    end

    run(`$sg scan -c $SG_CONFIG $path`)
end

"""
    generate_tags(dir="."; output="tags")

Generate a `tags` file for the given directory using Universal Ctags with Julia optlib extensions.
"""
function generate_tags(dir::String="."; output::String="tags")
    ctags_bin = Sys.which("ctags")
    if ctags_bin === nothing
        error("Universal Ctags not found on PATH. Install via `brew install universal-ctags`.")
    end

    cmd = `$ctags_bin --options=$CTAGS_OPT -f $output -R $dir`
    run(cmd)
    return output
end

"""
    install_directives(target_dir::String; agent::Symbol=:all, overwrite::Bool=false)

Install agent directives (CLAUDE.md, AGENTS.md, .cursorrules, .agents/) and tooling configs into `target_dir`.
Supported `agent` values: `:claude`, `:codex`, `:antigravity`, `:cursor`, `:all`.
"""
function install_directives(target_dir::String; agent::Symbol=:all, overwrite::Bool=false)
    isdir(target_dir) || error("Target directory does not exist: $target_dir")

    function copy_file_safe(src, dst)
        if !isfile(dst) || overwrite
            mkpath(dirname(dst))
            cp(src, dst; force=overwrite)
            println("Installed: $(relpath(dst, target_dir))")
        else
            println("Skipping existing: $(relpath(dst, target_dir)) (use overwrite=true to replace)")
        end
    end

    if agent in (:claude, :all)
        src = joinpath(PACKAGE_ROOT, "directives", "claude", "CLAUDE.md")
        dst = joinpath(target_dir, "CLAUDE.md")
        copy_file_safe(src, dst)
    end

    if agent in (:codex, :all)
        src = joinpath(PACKAGE_ROOT, "directives", "codex", "AGENTS.md")
        dst = joinpath(target_dir, "AGENTS.md")
        copy_file_safe(src, dst)
    end

    if agent in (:cursor, :all)
        src = joinpath(PACKAGE_ROOT, "directives", "cursor", ".cursorrules")
        dst = joinpath(target_dir, ".cursorrules")
        copy_file_safe(src, dst)
    end

    if agent in (:antigravity, :all)
        src_rule = joinpath(PACKAGE_ROOT, "directives", "antigravity", ".agents", "rules", "julia.md")
        dst_rule = joinpath(target_dir, ".agents", "rules", "julia.md")
        copy_file_safe(src_rule, dst_rule)

        src_wf1 = joinpath(PACKAGE_ROOT, "directives", "antigravity", ".agents", "workflows", "benchmarking.md")
        dst_wf1 = joinpath(target_dir, ".agents", "workflows", "benchmarking.md")
        copy_file_safe(src_wf1, dst_wf1)

        src_wf2 = joinpath(PACKAGE_ROOT, "directives", "antigravity", ".agents", "workflows", "type-stability.md")
        dst_wf2 = joinpath(target_dir, ".agents", "workflows", "type-stability.md")
        copy_file_safe(src_wf2, dst_wf2)
    end

    # Install ctags optlib
    dst_ctags = joinpath(target_dir, "ctags.d", "julia.ctags")
    copy_file_safe(CTAGS_OPT, dst_ctags)

    println("Agent directives installation complete.")
end

end # module JuliaAgentTools
