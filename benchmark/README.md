# EctoTrail Performance Benchmarks

This directory contains tools to measure the performance of EctoTrail operations and compare different branches.

## Benchmark Script

The `ecto_trail_benchmark.exs` script tests various EctoTrail operations:

1. Simple insert (small changeset)
2. Complex insert (large changeset with embeds and associations)
3. Simple update (small changeset)
4. Complex update (large changeset)
5. Delete operation
6. Bulk operations (multiple items)
7. Insert with redacted fields
8. Tests with different actor_id data types (string, atom, integer)

Each operation is benchmarked for execution time and memory usage.

## Running Benchmarks

### Option 1: Run on current branch only

```bash
mix run benchmark/ecto_trail_benchmark.exs
```

This will run the benchmark on your current branch and output results to the console and an HTML file.

### Option 2: Compare two branches

Use the comparison script to automatically benchmark both the main branch and your optimized branch:

```bash
./benchmark/compare_branches.sh your-branch-name
```

For example:

```bash
./benchmark/compare_branches.sh acrogenesis/updates-n-warnings
```

This will:
1. Run benchmarks on the main branch
2. Run benchmarks on your optimized branch
3. Save console output to text files
4. Save HTML reports for detailed analysis
5. Return to your original branch

## Interpreting Results

The benchmark results include:

- **Average time**: Average execution time per operation
- **ips**: Iterations per second (higher is better)
- **Comparison**: Relative performance between scenarios
- **Memory usage**: Memory consumption per operation

Look for improvements in both execution time (speed) and memory usage between branches.

## Tips for Fair Comparison

- Run benchmarks when your system is not under heavy load
- Close other applications that might consume system resources
- Run multiple times to account for variance
- Focus on the relative differences rather than absolute values