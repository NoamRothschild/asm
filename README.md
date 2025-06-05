# asm [![CC BY 4.0][cc-by-shield]][cc-by]

all of my assembler scripts

Scripts are written in x86 assembly for linux using NASM. Scripts will compile and work on every x86 / x86_64 linux machine.

| Status | Working |
|----------|-------|
| WSL | ✅ |
| Ubuntu | ✅ |
| Hyprland | ✅ |

### Documentation

Documentation for all functions is provided inside docs/docs.json

To run the docs on the browser simply execute from the root folder

```bash
python3 -m http.server PORT
```

And visit `http://127.0.0.1:PORT/docs.html` (default port is 8000)

- Documentation is seperated by folders and files, each function can be clicked to expand and see inputs / outputs
- Arguments are provided through the stack by pushing them before calling (from bottom to top)
- Retreive values from functions by poping them into a 32 bit register after call
- All values passed back and fourth must be in chunks of 32 bits and no less (the size of a normal register)
- [&] - Pass by reference (pointer to a specified memory region)
- [#] - Pass by value (a 32 bit value)

### Compiling

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

# Exposing a running socket to the LAN (WSL)

```bash
$ ip addr | grep inet
# Look for a line with an IPv4 ip starting with 172.x.x.x
# save that IP addr of later.
```
Then, we expose the WSL port to Windows:

on an administrator powershell instance:
```powershell
netsh interface portproxy add v4tov4 listenport=$PORT listenaddress=0.0.0.0 connectport=$PORT connectaddress=$WSL_ADDR
# replace $WSL_ADDR with the ip found before (172.x.x.x)
# replace $PORT with the port of the socket (default 8000)
```

next, inside the Windows Defender Firewall select 'Advanced Settings' on the side and create an inbound rule for a port, with that port being $PORT from before.

Now other users on the network can access the socket with the Windows IPv4 Address (find using `ipconfig` inside powershell) and using the $PORT.

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg
This work is licensed under a [Creative Commons Attribution 4.0 International License][cc-by].
