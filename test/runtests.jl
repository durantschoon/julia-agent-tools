using Test
using JuliaAgentTools

@testset "JuliaAgentTools.jl Suite" begin
    @testset "Allocation Audit" begin
        # Non-allocating arithmetic operation
        zero_alloc_fn(x, y) = x * y + x
        @test audit_allocations(zero_alloc_fn, 3.14, 2.71) == 0

        # Allocating heap array
        alloc_fn(n) = Vector{Float64}(undef, n)
        @test audit_allocations(alloc_fn, 100) > 0
    end

    @testset "Type Stability Checker" begin
        stable_fn(x::Float64) = x * 2.0
        @test is_type_stable(stable_fn, (Float64,)) == true

        unstable_fn(b::Bool) = b ? 1 : 2.5
        @test is_type_stable(unstable_fn, (Bool,)) == false
    end

    @testset "Ctags Generation" begin
        mktempdir() do tmpdir
            sample_file = joinpath(tmpdir, "sample.jl")
            write(sample_file, "struct TestStruct; x::Int; end\n")
            tag_file = joinpath(tmpdir, "tags")
            
            JuliaAgentTools.generate_tags(tmpdir; output=tag_file)
            @test isfile(tag_file)
            content = read(tag_file, String)
            @test occursin("TestStruct", content)
        end
    end

    @testset "Install Directives" begin
        mktempdir() do target_dir
            JuliaAgentTools.install_directives(target_dir; agent=:all)
            @test isfile(joinpath(target_dir, "CLAUDE.md"))
            @test isfile(joinpath(target_dir, "AGENTS.md"))
            @test isfile(joinpath(target_dir, ".cursorrules"))
            @test isfile(joinpath(target_dir, ".agents", "rules", "julia.md"))
            @test isfile(joinpath(target_dir, ".agents", "workflows", "benchmarking.md"))
            @test isfile(joinpath(target_dir, ".agents", "workflows", "type-stability.md"))
            @test isfile(joinpath(target_dir, "ctags.d", "julia.ctags"))
        end
    end
end
