%include '../common/general.asm'
%include '../common/string.asm'
%include '../common/debug.asm'
%include '../common/threading.asm'
%include '../common/fileManager.asm'
%include 'sockets.asm'
%include 'http.asm'
section .data
    response db 'HTTP/1.1 200 OK', 0Dh, 0Ah, 'Content-Type: text/html', 0Dh, 0Ah, 'Content-Length: 14', 0Dh, 0Ah, 0Dh, 0Ah, 'Hello World!', 0Dh, 0Ah, 0h

section .bss
    buffer: resb 4096
    request_struct: resb REQ_TOTAL_SIZE

section .text
global _start

started_str: db "Server binded up successfully to http://localhost:8000", 10, 0
client_connect_str: db "A new client has connected!, data:", 10, 0

_start:
    xor eax, eax
	xor ebx, ebx
	xor edi, edi
	xor esi, esi

    call createSocket
    mov edi, [esp]
    call bindSocket
    push edi
    call listenSocket
    
    push started_str
    call printMessage

    .parent:
    push edi
    call acceptSocket ; waits here for a message to be sent
    pop esi

    call close_terminated
    call fork
    pop eax
    cmp eax, 0 ; when resulting in 0, executor is child process, else parent.
	jz .child
	jmp .parent

    .child:
    push client_connect_str
    call printMessage

    push dword 4096
    push esi ; connected socket identifying descriptor
	push buffer
	call readSocket
    
    push buffer
    push request_struct
    call requestStruct

    push request_struct
    call printStruct

    push response
    call igetLength
    push esi
    push response
    call writeSocket

    push esi
    call closeSocket

    call exit
