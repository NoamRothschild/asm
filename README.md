# asm [![CC BY 4.0][cc-by-shield]][cc-by]

all of my assembler scripts

Scripts are built for x86-64 architecture and can be ran natively on Ubuntu or WSL.

To compile:

Firstly install required packages:
```bash
apt-get install nasm
apt-get install binutils
```
And then compile using the script:
```bash
./asm.sh %FILENAME%
```
or alternatively,
```bash
nasm -f elf "$1.asm"
ld -m elf_i386 "$1.o" -o "$1"
```

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg
This work is licensed under a [Creative Commons Attribution 4.0 International License][cc-by].
