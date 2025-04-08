%ifndef CLIENT_REQUEST_INCLUDE
%define CLIENT_REQUEST_INCLUDE
%include '../common/time.asm'
%include '../common/string.asm'
section .data
  REQ_METHOD_OFFSET equ 0
  REQ_METHOD_SIZE equ 1 ; 1 byte in length 
  REQ_PATH_OFFSET equ REQ_METHOD_OFFSET + REQ_METHOD_SIZE
  REQ_PATH_SIZE equ 256 ; 255 bytes in length + null terminator
  ;//REQ_CONTENT_LENGTH_OFFSET equ REQ_PATH_OFFSET + REQ_PATH_SIZE
  ;//REQ_CONTENT_LENGTH_SIZE equ 2 ; 2 bytes in length (potentially can store 65,535 in length)
  ;//REQ_DATA_OFFSET equ REQ_CONTENT_LENGTH_OFFSET + REQ_CONTENT_LENGTH_SIZE
  REQ_DATA_OFFSET equ REQ_PATH_OFFSET + REQ_PATH_SIZE
  REQ_DATA_SIZE equ 4096 ; 4096 bytes in length
  REQ_RESP_CODE_OFFSET equ REQ_DATA_OFFSET + REQ_DATA_SIZE
  REQ_RESP_CODE_SIZE equ 2 ; 2 bytes in length

  REQ_TOTAL_SIZE equ REQ_METHOD_SIZE + REQ_PATH_SIZE + REQ_DATA_SIZE + REQ_RESP_CODE_SIZE

  METHOD_MAX_STR_LEN equ 8
  METHOD_GET equ 0b00
  METHOD_POST equ 0b01
  METHOD_PUT equ 0b10
  METHOD_DELETE equ 0b11

  STR_ERR_UNKNOWN_METHOD db "Unknown method received in packet: ", 0
  STR_ERR_URI_TOO_LONG db "Request URI Too Long (Over 255)", 10, 0

  DATA_START db 0xD, 0xA, 0xD, 0xA

section .text

generateRequestStruct:
  push ebp
  mov ebp, esp
  push edx
  push ebx
  push edi
  push eax
  push ecx

  mov eax, [ebp+8] ; struct pointer
  mov ebx, [ebp+12] ; HTTP message pointer

  push eax
  mov ecx, REQ_TOTAL_SIZE
.cleanStruct:
  mov byte [eax], 0
  inc eax
  loop .cleanStruct
  pop eax

  mov word [eax + REQ_RESP_CODE_OFFSET], 200 ; set 200 OK as default resp code

  sub esp, METHOD_MAX_STR_LEN
  mov edi, esp ; reserve tmp buff for req

  push edi
  push dword 0x00
  push dword METHOD_MAX_STR_LEN
  call memset

  mov eax, [ebp+8] ; struct pointer
  mov ecx, METHOD_MAX_STR_LEN
  push edi ; save value in stack
.methodByteLoop:
  cmp byte [ebx], ' '
  jz .endmethodByteLoop
  
  mov dl, byte [ebx]
  mov byte [edi], dl

  inc ebx
  inc edi
  loop .methodByteLoop
.endmethodByteLoop:
  ; pop edi, push edi
  call getMethodType
  pop edx
  test edx, edx
  jns .validMethod
  mov word [eax + REQ_RESP_CODE_OFFSET], 501 ; set 501 Not Implemented as resp code (can also be 405)
  .validMethod:
  mov byte [eax + REQ_METHOD_OFFSET], dl

  add esp, METHOD_MAX_STR_LEN ; deallocate tmp buff

  mov edi, eax
  add edi, REQ_PATH_OFFSET

  mov ecx, REQ_PATH_SIZE
  dec ecx ; path size includes null terminator
.gotoPathStart:
  cmp byte [ebx], '/'
  jz .pathByteLoop
  inc ebx
  jmp .gotoPathStart

.pathByteLoop:
  cmp byte [ebx], ' '
  jz .endpathByteLoop

  mov dl, byte [ebx]
  mov byte [edi], dl

  inc ebx
  inc edi
  loop .pathByteLoop

  cmp byte [ebx], ' '
  jz .endpathByteLoop
  mov word [eax + REQ_RESP_CODE_OFFSET], 414 ; set 414 Request-URI Too Long as resp code

  push ANSI_RED
  push STR_ERR_URI_TOO_LONG
  call printColored

.endpathByteLoop:
  mov byte [edi], 0 ; null terminate string
  
  mov edx, dword [DATA_START]

  .goto_DataStart:
  inc ebx
  cmp dword [ebx], edx
  jnz .goto_DataStart
  add ebx, 4

  mov edx, REQ_TOTAL_SIZE
  add edx, [ebp+12] ; get end of HTTP req ptr
  mov ecx, REQ_DATA_SIZE
  mov edi, eax
  add edi, REQ_DATA_OFFSET
  .copyData:
  cmp edx, ebx
  jbe .end

  mov dl, byte [ebx]
  mov byte [edi], dl

  inc ebx
  inc edi
  loop .copyData

.end:
  push dword [ebp+12] ; struct
  push dword [ebp+8] ; request content
  call parseHeaders

  pop ecx
  pop eax
  pop edi
  pop ebx
  pop edx
  pop ebp
  ret 8

STR_GET: db "GET", 0
STR_POST: db "POST", 0
STR_PUT: db "PUT", 0
STR_DELETE: db "DELETE", 0
getMethodType:
  push ebp
  mov ebp, esp
  push eax
  push ebx

  mov eax, [ebp+8] ; suspected method

  push eax
  push STR_GET
  call strcmp
  cmp dword [esp], 1
  jz .get

  push eax
  push STR_POST
  call strcmp
  cmp dword [esp], 1
  jz .post
  
  push eax
  push STR_PUT
  call strcmp
  cmp dword [esp], 1
  jz .put
  
  push eax
  push STR_DELETE
  call strcmp
  cmp dword [esp], 1
  jz .delete

  push ANSI_RED
  call setDefaultColor

  push STR_ERR_UNKNOWN_METHOD
  call printMessage
  push eax
  call printMessage
  call printTerminator

  call resetDefaultColor

  mov dword [ebp+8], -1
  add esp, 4*4
  jmp .end

  .get:
  mov dword [ebp+8], METHOD_GET
  add esp, 4
  jmp .end
  .post:
  mov dword [ebp+8], METHOD_POST
  add esp, 4*2
  jmp .end
  .put:
  mov dword [ebp+8], METHOD_PUT
  add esp, 4*3
  jmp .end
  .delete:
  mov dword [ebp+8], METHOD_DELETE
  add esp, 4*4
  jmp .end
.end:
  pop ebx
  pop eax
  pop ebp
  ret

STR_WEBSOCKET_UPGRADE: db "Upgrade: websocket", 0
STR_WEBSOCKET_KEY: db "Sec-WebSocket-Key: ", 0
parseHeaders:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edi

  mov ebx, [ebp+12] ; buffer
.nextHeader:
  mov edx, dword [DATA_START] ; \r\n
  inc ebx
  cmp word [ebx], dx
  jnz .nextHeader
  cmp dword [ebx], edx
  jz .end
  inc ebx
  inc ebx
  ; at this point ebx points to the start of a new line in the message, and already exited if reached start of data

  push ebx
  push STR_WEBSOCKET_KEY
  call startswith
  pop edx
  cmp edx, 1
  jz .secWebsocketKey

  push ebx
  push STR_WEBSOCKET_UPGRADE
  call startswith
  pop edx
  cmp edx, 1
  jz .websocketExists

  ; ... do all other handling of headers

  jmp .nextHeader
.secWebsocketKey:
  push ebx

  mov edx, ebx
  push STR_WEBSOCKET_KEY
  call igetLength
  add edx, [esp]
  add esp, 4

  mov eax, [ebp+8]
  add eax, REQ_DATA_OFFSET
  mov ecx, REQ_DATA_SIZE
  xor ebx, ebx

.copyWebsocketSec:
  mov bl, byte [edx]

  cmp bl, 0Dh
  jz .endCopyWebsocketSec

  mov byte [eax], bl
  inc eax
  inc edx
  loop .copyWebsocketSec
.endCopyWebsocketSec:
  mov byte [eax], 0

  pop ebx
  jmp .nextHeader
.websocketExists:
  mov eax, [ebp+8] ; struct pointer
  mov dword [eax + REQ_RESP_CODE_OFFSET], 101 ; 101 Switching Protocol
  jmp .nextHeader
.end:
  pop edi
  pop ecx
  pop ebx
  pop eax
  pop ebp    
  ret 8

printHeaders:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edi

  mov ebx, [ebp+8] ; buffer
.nextHeader:
  mov edx, dword [DATA_START] ; \r\n
  inc ebx
  cmp word [ebx], dx
  jnz .nextHeader
  cmp dword [ebx], edx
  jz .end
  inc ebx
  inc ebx

  push ANSI_RED
  call setDefaultColor
  push ebx
  push dword ':'
  call printUntil
  push dword ' '
  push dword ':'
  call printChar
  call printChar
  call resetDefaultColor


  sub esp, 2
  mov edi, esp
  mov byte [edi], ':'
  mov byte [edi+1], 0

  push ebx
  push edi
  call strstr
  pop edx
  inc edx
  inc edx

  add esp, 2

  push edx
  push dword 0xD
  call printUntil
  call printTerminator

  jmp .nextHeader

.end:
  pop edi
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 4

strLog: db "Analisys of new packet:", 10, 0
strMethod: db "Method: ", 0
strPath: db "Path: ", 0
strData: db "Data: ", 0
strStatusCode: db "Response status code: ", 0
printStruct:
  push ebp
  mov ebp, esp
  push eax
  push ebx

  mov eax, [ebp+8] ; struct
  push strLog
  call printMessage

  push strMethod
  call printMessage
  xor ebx, ebx
  mov bl, byte [eax + REQ_METHOD_OFFSET]
  push ebx
  call printInt
  call printTerminator

  push strPath
  call printMessage
  mov ebx, eax
  add ebx, REQ_PATH_OFFSET
  push ebx
  call printMessage
  call printTerminator

  push strData
  call printMessage
  mov ebx, eax
  add ebx, REQ_DATA_OFFSET
  push ebx
  call printMessage
  call printTerminator

  push strStatusCode
  call printMessage
  xor ebx, ebx
  mov bx, word [eax + REQ_RESP_CODE_OFFSET]
  push ebx
  call printInt
  call printTerminator

  pop ebx
  pop eax
  pop ebp
  ret 4

printReqFormatted:
  push ebp
  mov ebp, esp
  push eax
  push ebx

  mov eax, [ebp+8] ; req struct
  push '['
  call printChar
  push dword 2 ; UTC+2
  call unixNow
  call timeFormatPrint
  push ' '
  push ']'
  call printChar
  call printChar

  xor ebx, ebx
  mov bl, byte [eax + REQ_METHOD_OFFSET]
  cmp bl, METHOD_GET
  jz .printGET
  cmp bl, METHOD_POST
  jz .printPOST
  cmp bl, METHOD_PUT
  jz .printPUT
  cmp bl, METHOD_DELETE
  jz .printDELETE
.printGET:
  push STR_GET
  call printMessage
  jmp .printPath
.printPOST:
  push STR_POST
  call printMessage
  jmp .printPath
.printPUT:
  push STR_PUT
  call printMessage
  jmp .printPath
.printDELETE:
  push STR_DELETE
  call printMessage
  jmp .printPath
.printPath:
  push ' '
  call printChar

  mov ebx, eax
  add ebx, REQ_PATH_OFFSET
  push ebx
  call printMessage

  push ' '
  push '-'
  push ' '
  call printChar
  call printChar
  call printChar

  xor ebx, ebx
  mov bx, word [eax + REQ_RESP_CODE_OFFSET]
  push ebx
  call printInt
  call printTerminator

  mov ebx, eax
  add ebx, REQ_DATA_OFFSET
  cmp byte [ebx], 0
  jz .end
.printData:
  push ' '
  push '>'
  call printChar
  call printChar
  
  push strData
  call printMessage
  push ebx
  call printMessage
  call printTerminator
.end:
  pop ebx
  pop eax
  pop ebp
  ret 4
%endif