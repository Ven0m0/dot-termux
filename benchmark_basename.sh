#!/bin/bash
export LC_ALL=C; IFS=$'\n\t'
JOBS=10000

echo "Benchmarking \$(basename \"\$0\"):"
time for i in $(seq 1 $JOBS); do
  b=$(basename "$0")
done

echo
echo "Benchmarking \${0##*/}:"
time for i in $(seq 1 $JOBS); do
  b="${0##*/}"
done
