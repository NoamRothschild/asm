%include 'general.asm'
%include 'lib.asm'

section .data
    msg db 'encode me!', 0
    msg_len db 10

section .bss
    ; output buffer must be equal or above the (original length)*4/3
    output: resb 14

section .text

global _start

_start:

    push dword [msg_len]
    push output
    push msg
    call b64_encode
    
    push output
    call printMessage

    call exit