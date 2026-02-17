# asm [![CC BY 4.0][cc-by-shield]][cc-by]

## Table of contents

- [The stdlib](#the-stdlib)
- [Projects made using it](#projects-made-using-it)
  - [A discord clone](#a-discord-clone)
  - [Voxel Space Game](#voxel-space-game)
- [Compiling](#compiling)
- [Documentation](#documentation)

---

a whole working standard library (non production ready use) built from the ground up in x86 assesmbly, and some projects using it

## The stdlib

the stdlib includes:
- common string operations (c-like strings)
- debuggning functions (print, colored print)
- file handling
- multiprocessing wrappers (fork, shmget, shmat, mmap)
- socket creating and handling
- time formatting
- shared data store managers (used for "databases")
- **simple HTTP library (client && server side)**
- **websockets from scratch**
- **SHA1 hashing**
- **BASE64 encoding and decoding**

> NOTE: the `misc` folder is not related to the stdlib but includes some other 8086 projects, most notably snake

all of the code is x86 assembly. the project can only run under a linux kernel since it relies on its internal syscalls

_[stdlib docs](https://NoamRothschild.github.io/asm/docs.html)_

## Projects made using it

### A discord clone

![image](https://github.com/user-attachments/assets/0fe0669e-3157-4e75-a6a7-f573bbfc1d34)

- clients can register or login to an existing account
- credential verification + hashing of the important + cookie session creating, storing, and loading
- talk on 4 different chats, each with their own history of messages and stream
- clients are connected to the channels using websockets to receive messages in a full-duplex communication manner
- routing of static files, custom paths, and websocket creation endpoints
- profile picture uploading

> NOTES: if you want to test it out yourself, open `localhost:8000` (or use nginx to expose). make sure you are opening it using a chromium based browser since firefox has an unresolved issue with the login mechanism

### Voxel Space Game

![image](https://i.postimg.cc/k5ZskNxM/image.png)

_[link to an old demo](https://www.youtube.com/watch?v=4efJBanv8nc)_

_The demo video perscribed is from an older with python as the renderer, that demonstrated the rendering, but all works visually the same when using the browser_

How does it work?

- The clients enters the browser, a canvas is created and a websocket is established
- keystrokes of the user are sent through the websocket, to which the server (assembly) simulates, generates the next frame and sends back using the websocket the new buffer

For a great explanation about the rendering algorithm used, [check out this amazing github page](https://github.com/s-macke/VoxelSpace) about Voxel Space.

> NOTE FOR RUNNING:
> 
> revert the repo to commit `6877abe` and run from game_prototypes. the stdlib has changed since and the renderer didnt update acordingly.

## Compiling

Firstly install required packages:
```bash
apt-get install nasm
apt-get install binutils
```
And then compile using the build script:
```bash
./asm.sh %FILENAME%
```
or alternatively,
```bash
nasm -f elf "$1.asm"
ld -m elf_i386 "$1.o" -o "$1"
```

## Documentation

_[documentation deployed here](https://NoamRothschild.github.io/asm/docs.html)_

Or, in the json file `docs/docs.json`.

calling conventions && understanding the docs

- Arguments are provided through the stack by pushing them before calling (from bottom to top)
- Retreive values from functions by poping them into a 32 bit register after call
- All values passed back and fourth must be in chunks of 32 bits and no less (the size of a normal register)
- [&] - Pass by reference (pointer to a specified memory region)
- [#] - Pass by value (a 32 bit value)

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg
This work is licensed under a [Creative Commons Attribution 4.0 International License][cc-by].
