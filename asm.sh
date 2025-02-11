#!/bin/bash

if [ -z "$1" ]; then
  echo "Error: No file inputted."
  exit 1
fi

if [[ "$1" == *.asm ]]; then
  echo "Please enter a file name without its extension (.asm)"
  exit 1
fi

if [ ! -d "bin" ]; then
  echo "Created bin directory for program"
  mkdir bin
fi

if [ -f "bin/$1.o" ]; then
  rm "bin/$1.o"
fi

if [ -f "bin/$1" ]; then
  rm "bin/$1"
fi

trap 'kill -9 $pid $(pgrep -P $pid)' SIGINT

# Compile with the C libraries
# req dependencies: "apt install gcc-multilib"
# 
#   nasm -f elf32 "$1.asm" -o "$1.o"
#   ld -m elf_i386 "$1.o" -lc -dynamic-linker /lib/ld-linux.so.2 -o "$1"

nasm -f elf "$1.asm"
ld -m elf_i386 "$1.o" -o "$1"

./"$1" "${@:2}" &
pid=$!

wait $pid

mv "$1" "bin"
mv "$1.o" "bin"
