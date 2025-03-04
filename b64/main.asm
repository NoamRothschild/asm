%include '../common/general.asm'
%include '../common/debug.asm'
%include 'b64.asm'

section .data
    msg db 'encode me!', 0
    msgLen db 10

section .bss
    ; output buffer must be equal or above the (original length)*4/3
    output: resb 14

section .text

global _start

_start:

    push dword [msgLen]
    push output
    push msg
    call b64Encode
    
    push output
    call printMessage

    call exit