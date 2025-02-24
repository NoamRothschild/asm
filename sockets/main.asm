%include '../common/general.asm'
%include '../common/string.asm'
%include '../common/debug.asm'
%include '../common/threading.asm'
%include '../common/fileManager.asm'
%include '../common/time.asm'
%include '../sha1/sha1.asm'
%include '../b64/b64.asm'
%include 'sockets.asm'
%include 'http/websocket.asm'
%include 'http/client_request.asm'
%include 'http/server_response.asm'
section .data
    response db 'HTTP/1.1 200 OK', 0Dh, 0Ah, 'Content-Type: text/html', 0Dh, 0Ah, 'Content-Length: 14', 0Dh, 0Ah, 0Dh, 0Ah, 'Hello World!', 0Dh, 0Ah, 0h

section .bss
    buffer: resb 4096
    _tmp: resb 1 ; here only for easier printing since I rely on null terminators
    request_struct: resb REQ_TOTAL_SIZE
    _tmp2: resb 1 ; here only for easier printing since I rely on null terminators

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

    push ANSI_YELLOW
    push buffer
    call printColored
    
    push buffer
    push request_struct
    call requestStruct

    push request_struct
    call printReqFormatted

    push request_struct
    call respond_http
    pop edx

    push edx ; length of full response in bytes
    push esi
    push response_buffer
    call writeSocket

    cmp word [request_struct + REQ_RESP_CODE_OFFSET], 101
    jnz .closeSocket
.websocket:
    
    push esi
    call parseRequest
    push esi
    push ws_resp_buff
    call writeSocket
    jmp .websocket

.closeSocket:
    push esi
    call closeSocket

    call exit
