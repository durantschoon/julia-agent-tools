---
description: Workflow for running Julia benchmarks and verifying zero-allocation hot paths
---

# Julia Benchmarking Workflow

1. **Ensure BenchmarkTools is Available**:
   Verify that `BenchmarkTools` is configured in `benchmark/Project.toml` or `test/Project.toml`.

2. **Warm Up Before Measuring**:
   Julia uses JIT compilation; always execute the target function once before timing:
   ```julia
   using BenchmarkTools
   # Warm-up run
   target_fn(sample_args...)
   # Benchmark
   @btime target_fn($sample_args...)
   ```

3. **Check Allocations in Compiled Frame**:
   ```julia
   function check_allocs(args...)
       return @allocated target_fn(args...)
   end
   @assert check_allocs(sample_args...) == 0 "Allocation detected on hot path!"
   ```

4. **Document Latency & Throughput**:
   Record timing percentiles (min, median, max) and memory allocations in benchmarks report.
