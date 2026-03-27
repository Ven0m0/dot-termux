#!/bin/bash

ITERATIONS=10000
test_path="/path/to/some/deep/directory/structure/file.sh"

echo "Running benchmark with $ITERATIONS iterations..."

# Benchmark basename
start_time=$(date +%s%N)
for ((i=0; i<ITERATIONS; i++)); do
    name=$(basename "$test_path")
done
end_time=$(date +%s%N)
basename_time=$(( (end_time - start_time) / 1000000 ))
echo "basename: ${basename_time}ms"

# Benchmark parameter expansion
start_time=$(date +%s%N)
for ((i=0; i<ITERATIONS; i++)); do
    name="${test_path##*/}"
done
end_time=$(date +%s%N)
expansion_time=$(( (end_time - start_time) / 1000000 ))
echo "parameter expansion: ${expansion_time}ms"

if [[ "$expansion_time" -lt "$basename_time" ]]; then
    improvement=$(awk "BEGIN {print ($basename_time - $expansion_time) / $basename_time * 100}")
    echo "Improvement: ${improvement}%"
else
    echo "No improvement measured (might be due to low iterations or system noise)"
fi
