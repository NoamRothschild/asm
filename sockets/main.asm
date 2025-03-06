%include '../common/general.asm'
%include '../common/debug.asm'
%include '../common/threading.asm'
%include '../game_prototypes/voxel_space.asm'
%include 'sockets.asm'
%include 'http/http.asm'
%include 'http/websocket.asm'
section .data
    response db 'HTTP/1.1 200 OK', 0Dh, 0Ah, 'Content-Type: text/html', 0Dh, 0Ah, 'Content-Length: 14', 0Dh, 0Ah, 0Dh, 0Ah, 'Hello World!', 0Dh, 0Ah, 0h

section .bss
    buffer: resb 4096
    _tmp: resb 1 ; here only for easier printing since I rely on null terminators
    requestStruct: resb REQ_TOTAL_SIZE
    _tmp2: resb 1 ; here only for easier printing since I rely on null terminators

section .text
global _start

startedStr: db "Server binded up successfully to http://localhost:8000", 10, 0
clientConnectStr: db "A new client has connected!, data:", 10, 0

_start:
    xor eax, eax
	xor ebx, ebx
	xor edi, edi
	xor esi, esi

    ; loading heightmap & colormap into memory for game
    call init_files

    call createSocket
    mov edi, [esp]
    call bindSocket
    push edi
    call listenSocket
    
    push startedStr
    call printMessage

    .parent:
    push edi
    call acceptSocket ; waits here for a message to be sent
    pop esi

    call fork
    pop eax
    cmp eax, 0 ; when resulting in 0, executor is child process, else parent.
	jz .child
	jmp .parent

    .child:
    push clientConnectStr
    call printMessage

    push dword 4096
    push esi ; connected socket identifying descriptor
	push buffer
	call readSocket

    push ANSI_YELLOW
    push buffer
    call printColored
    
    push buffer
    push requestStruct
    call generateRequestStruct

    push requestStruct
    call printReqFormatted

    push requestStruct
    call respondHttp
    pop edx

    push edx ; length of full response in bytes
    push esi
    push responseBuffer
    call writeSocket

    cmp word [requestStruct + REQ_RESP_CODE_OFFSET], 101
    jnz .closeSocket
.websocket:
    push dword voxelSpaceResponse
    push esi
    call parseRequest
    push esi
    push wsRespBuff
    call writeSocket
    
    jmp .websocket

.closeSocket:
    push esi
    call closeSocket

    call exit
