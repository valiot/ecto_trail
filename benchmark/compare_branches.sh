#!/bin/bash
# Script to compare EctoTrail performance between branches

# Check if branch name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <optimized_branch_name>"
  echo "Example: $0 acrogenesis/updates-n-warnings"
  exit 1
fi

OPTIMIZED_BRANCH=$1
MAIN_BRANCH="main"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Create results directory
mkdir -p benchmark_results

echo "========================================================"
echo "Running performance comparison between branches:"
echo "Main branch: $MAIN_BRANCH"
echo "Optimized branch: $OPTIMIZED_BRANCH"
echo "========================================================"

# Function to run benchmark on a branch
run_benchmark() {
  BRANCH=$1
  RESULT_FILE=$2

  echo "Switching to $BRANCH branch..."
  git checkout $BRANCH

  echo "Getting dependencies..."
  mix deps.get

  echo "Compiling..."
  mix compile

  echo "Running benchmark..."
  mix run benchmark/ecto_trail_benchmark.exs >$RESULT_FILE

  # Extract the HTML result and copy it
  cp benchmark_results.html $RESULT_FILE.html
}

# Run benchmarks on main branch
echo "========================================================"
echo "Running benchmark on $MAIN_BRANCH branch..."
echo "========================================================"
run_benchmark $MAIN_BRANCH "benchmark_results/main_results.txt"

# Run benchmarks on optimized branch
echo "========================================================"
echo "Running benchmark on $OPTIMIZED_BRANCH branch..."
echo "========================================================"
run_benchmark $OPTIMIZED_BRANCH "benchmark_results/optimized_results.txt"

# Return to original branch
echo "Returning to original branch: $CURRENT_BRANCH"
git checkout $CURRENT_BRANCH

echo "========================================================"
echo "Benchmark results saved to:"
echo "Main branch: benchmark_results/main_results.txt"
echo "Main branch HTML: benchmark_results/main_results.txt.html"
echo "Optimized branch: benchmark_results/optimized_results.txt"
echo "Optimized branch HTML: benchmark_results/optimized_results.txt.html"
echo "========================================================"
echo "You can open the HTML files to see detailed comparisons."
