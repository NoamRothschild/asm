%include '../common/general.asm'
%include '../common/debug.asm'
%include '../common/threading.asm'
%include '../game_prototypes/cubes.asm'
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
  ; call init_files

  push dword PLAYERS_BUFFER_SIZE
  call createSharedMemory
  pop edx
  cmp edx, -1 ; shmid or -1
  jz .end
  push edx
  call attachSharedMemory
  pop edx
  cmp edx, -1 ; shmid or -1
  jz .end
  mov [playersRegionPtr], edx ; shmaddr

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
  call registerPlayer
  push esi
  call setNonBlocking

  ; making any error on ws force disconnect player.
  mov ecx, .ws_disconnect
  mov ebx, 11 ; seg fault
  mov eax, 0x30 ; SYS_SIGNAL
  int 0x80
.websocket:
  push esi
  call hasData
  pop ecx
  cmp ecx, -1 ; close socket and free player slot if socket closed by client
  jz .ws_disconnect
  cmp ecx, 1 ; only parse if data was found
  jnz .ws_send
.ws_parse:
  push dword _return
  push esi
  call parseRequest
  add esp, 4
.ws_send:
  call voxelSpaceResponse
  push ecx
  push esi
  push wsRespBuff
  call writeSocket
  jmp .websocket
.ws_disconnect:
  call removePlayer
.closeSocket:
  push esi
  call closeSocket
.end:
  call exit