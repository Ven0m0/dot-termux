#!/bin/bash

export SCRIPTS="script1.sh script2.sh script3.sh script4.sh script5.sh script6.sh script7.sh script8.sh script9.sh script10.sh"

echo "Benchmarking $(basename) ..."
time for i in {1..1000}; do
  for script in $SCRIPTS; do
    name=$(basename "$script")
  done
done

echo "Benchmarking parameter expansion \${script##*/} ..."
time for i in {1..1000}; do
  for script in $SCRIPTS; do
    name="${script##*/}"
  done
done
