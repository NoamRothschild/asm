%include '../common/general.asm'
%include '../common/debug.asm'
%include 'sha1_utils.asm'
section .data
    msg db 01100001b, 01100010b, 01100011b, 01100100b, 01100101b
    length_bytes dd 5
    lengh_bits   dd 5 * 8

section .text

global _start

test_function_f:
    push eax
    push edi

    push dword 81 ; example invalid value for t
    push dword 0  ; example value for b
    push dword 0  ; example value for c
    push dword 0  ; example value for d
    call function_f
    pop eax
    
    sub esp, 4
    mov edi, esp

    bswap eax ; reverse little-endian for the printHex function (reads left to right)
    mov dword [edi], eax
    push dword 4
    push edi
    call printHex ; printing result to stdin

    add esp, 4
    pop edi
    pop eax
    ret

_start:

    push dword msg
    push dword [length_bytes]
    call makeChunk

    push dword SHA1_CHUNK_SIZE_BYTES
    push chunk
    call printHex
    ;call printTerminator
    ;push dword SHA1_CHUNK_SIZE_BYTES
    ;push chunk
    ;call printBin

    call exit