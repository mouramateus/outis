#!/bin/bash
# Roda todos os testes do CLI (sempre no bash 3.2 do macOS).
cd "$(dirname "$0")"
. ./lib.sh
for f in test_*.sh; do
  printf '%s\n' "$f"
  . "./$f"
done
printf '%s passou, %s falhou\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
