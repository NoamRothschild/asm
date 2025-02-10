%include '../common/general.asm'
%include '../common/debug.asm'
%include 'sha1.asm'
section .data
    msg db 01100001b, 01100010b, 01100011b, 01100100b, 01100101b ; example msg from RFC
    msg_length_bytes dd 5
    msg2 db "hello world!", 0
    msg2_length_bytes dd 12
    msg3 db "dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11", 0
    msg3_length_bytes dd 60
    msg4 db "Lorem ipsum, dolor sit amet consectetur adipisicing elit. Aut magni aliquam beatae esse quos dolorem, quis nostrum inventore ad sed. Omnis eum distinctio fuga ratione veniam cumque culpa error itaque.", 0
    msg4_length_bytes dd 200
    msg5 db "", 0
    msg5_length_bytes dd 0

section .bss
    output: resb SHA1_OUTPUT_SIZE_BYTES

section .text

global _start

str: db "sha1-digest: ", 0
_start:

    push output
    push dword msg
    push dword [msg_length_bytes]
    call sha1
    push str
    call printMessage
    push dword SHA1_OUTPUT_SIZE_BYTES
    push output
    call printHex
    call printTerminator

    push output
    push dword msg2
    push dword [msg2_length_bytes]
    call sha1
    push str
    call printMessage
    push dword SHA1_OUTPUT_SIZE_BYTES
    push output
    call printHex
    call printTerminator

    push output
    push dword msg3
    push dword [msg3_length_bytes]
    call sha1
    push str
    call printMessage
    push dword SHA1_OUTPUT_SIZE_BYTES
    push output
    call printHex
    call printTerminator

    push output
    push dword msg4
    push dword [msg4_length_bytes]
    call sha1
    push str
    call printMessage
    push dword SHA1_OUTPUT_SIZE_BYTES
    push output
    call printHex
    call printTerminator

push output
    push dword msg5
    push dword [msg5_length_bytes]
    call sha1
    push str
    call printMessage
    push dword SHA1_OUTPUT_SIZE_BYTES
    push output
    call printHex
    call printTerminator

    call exit