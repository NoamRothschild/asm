%include '../common/general.asm'
%include '../common/debug.asm'
%include 'sha1_utils.asm'
section .data
    msg db 01100001b, 01100010b, 01100011b, 01100100b, 01100101b ; example msg from RFC
    msg_length_bytes dd 5
    msg2 db "hello world!", 0
    msg2_length_bytes dd 12

section .bss
    output: resb SHA1_OUTPUT_SIZE_BYTES

section .text

global _start

str: db "sha1-digest: ", 0
_start:

    push str
    call printMessage

    push dword msg2
    push dword [msg2_length_bytes]
    call makeChunk
    push output
    call digest

    push dword SHA1_OUTPUT_SIZE_BYTES
    push output
    call printHex

    call printTerminator

    call exit