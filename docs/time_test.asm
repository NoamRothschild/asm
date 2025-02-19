%include '../common/general.asm'
%include '../common/debug.asm'
%include '../common/time.asm'

section .data
    msg1 db "127.0.0.1 - [", 0
    msg2 db '] "GET /favicon.ico HTTP/1.1" - 404', 10, 0

section .text

global _start

_start:
    push msg1
    call printMessage

    push 2 ; UTC+2
    call unixNow
    call timeFormatPrint

    push msg2
    call printMessage

    call exit