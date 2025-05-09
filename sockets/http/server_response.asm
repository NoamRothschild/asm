%ifndef SERVER_RESPONSE_INCLUDE
%define SERVER_RESPONSE_INCLUDE
%include '../common/string.asm'
%include '../common/fileManager.asm'
section .data
  MAX_READ_BYTES_DISK_FILE equ 65536
  RESP_BUFFER_SIZE equ MAX_READ_BYTES_DISK_FILE + 4096
  FILE_LENGTH_STR_SIZE equ 6 ; potentially hold up to '99999' (ends with a NULL terminator)

  ; RESP_TEMPLATE does not include a % for data!!! (to support binary data)
  RESP_TEMPLATE db 'HTTP/1.1 %', 0Dh, 0Ah, 'Content-Type: %', 0Dh, 0Ah, 'Connection: close', 0Dh, 0Ah, 'Content-Length: %', 0Dh, 0Ah, 0Dh, 0Ah, 0
  WS_TEMPLATE db 'HTTP/1.1 101 Switching Protocols', 0Dh, 0Ah, 'Upgrade: websocket', 0Dh, 0Ah, 'Connection: Upgrade', 0Dh, 0Ah, 'Sec-WebSocket-Accept: %', 0Dh, 0Ah, 0Dh, 0Ah, 0

  ; response codes

  STR_CODE_200 db "200 OK", 0
  STR_CODE_404 db "404 Not Found", 0
  STR_CODE_501 db "501 Not Implemented", 0
  STR_CODE_414 db "414 URI Too Long", 0
  STR_CODE_101 db "101 Switching Protocols", 0
  STR_CODE_301 db "301 Moved Permanently", 0
  STR_CODE_400 db "400 Bad Request", 0

  ; file extensions

  HTML_EXT db 'html', 0
  CSS_EXT db 'css', 0
  JSON_EXT db 'json', 0
  JS_EXT db 'js', 0
  ICO_EXT db 'ico', 0
  PNG_EXT db 'png', 0
  BIN_EXT db 'bin', 0
  SVG_EXT db 'svg', 0

  ; mime types

  HTML_TYPE db 'text/html', 0
  CSS_TYPE db 'text/css', 0
  JSON_TYPE db 'application/json', 0
  JS_TYPE db 'application/javascript', 0
  ICO_TYPE db 'image/x-icon', 0
  PNG_TYPE db 'image/png', 0
  BINARY_TYPE db 'application/octet-stream', 0
  SVG_TYPE db 'image/svg+xml', 0
section .bss
  responseBuffer: resb RESP_BUFFER_SIZE ; this buffer would hold the request sent to the client
  filedataBuffer: resb MAX_READ_BYTES_DISK_FILE

section .text

; takes a client request struct and creates a responseBuffer
respondHttp:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx
  push edi

  mov ebx, [ebp+8] ; request struct
  cmp word [ebx + REQ_RESP_CODE_OFFSET], 101
  jnz .httpReq
.websocket:

  push ebx
  add dword [esp], REQ_DATA_OFFSET
  call wsSecAccept
  push WS_TEMPLATE
  push responseBuffer
  call sprintf
  pop edi
  add esp, 2*4
  sub edi, responseBuffer

  mov [ebp+12], edi

  jmp .end

.httpReq:

  sub esp, FILE_LENGTH_STR_SIZE
  mov edi, esp

  mov edx, ebx
  add edx, REQ_PATH_OFFSET
  inc edx

  push edx ; file path
  call iLengthFile
  pop ecx ; file length

  test ecx, ecx
  jns .readFile

.handle404:
  ; handle file not found here (404)
  mov word [ebx + REQ_RESP_CODE_OFFSET], 404

  mov edx, [ebp + 12] ; traceback file name 
  push edx
  call iLengthFile
  pop ecx ; file length

.readFile:

  push edx
  call getExtension
  call getMime
  pop eax ; mime type

  push edx
  call openFile
  pop edx ; get the file descriptor of the given file

  ;//sub esp, MAX_READ_BYTES_DISK_FILE
  ;//mov esi, esp

  push edx ; file descriptor
  push filedataBuffer ; file contents buffer
  push dword MAX_READ_BYTES_DISK_FILE ; amm of bytes to read
  call readFile

  push edi ; file length buffer
  push ecx ; file length
  call toString

  push edi ; first argument for sprintf
  push eax ; second argument for sprintf
  xor eax, eax
  mov ax, word [ebx + REQ_RESP_CODE_OFFSET]
  push eax
  call getResonseCodeStr

  push RESP_TEMPLATE
  push responseBuffer
  call sprintf
  pop edi ; the pointer to the end of the buffer 
  add esp, 4*4 ; remove 4 out of 5 pushed args from stack

  push edi ; start of data pointer
  push filedataBuffer ; file contents buffer
  push ecx ; ammount of bytes to copy (file length)
  call memcpy
  pop edi

  mov bh, 0xA
  mov bl, 0xD ; /r/n
  mov word [edi], bx
  add edi, 2

  sub edi, responseBuffer ; return only the length of the response buffer

  mov [ebp+12], edi

  ;//add esp, MAX_READ_BYTES_DISK_FILE
  add esp, FILE_LENGTH_STR_SIZE
.end:

  pop edi
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 4

; given a status code (number), return its string representation pointer
getResonseCodeStr:
  cmp dword [esp+4], 101
  jz .101
  cmp dword [esp+4], 200
  jz .200
  cmp dword [esp+4], 404
  jz .404
  cmp dword [esp+4], 414
  jz .414
  cmp dword [esp+4], 501
  jz .501
  cmp dword [esp+4], 301
  jz .301
  cmp dword [esp+4], 400
  jz .400
  jmp .200
.101:
  mov dword [esp+4], STR_CODE_101
  ret
.200:
  mov dword [esp+4], STR_CODE_200
  ret
.404:
  mov dword [esp+4], STR_CODE_404
  ret
.414:
  mov dword [esp+4], STR_CODE_414
  ret
.501:
  mov dword [esp+4], STR_CODE_501
  ret
.301:
  mov dword [esp+4], STR_CODE_301
  ret
.400:
  mov dword [esp+4], STR_CODE_400
  ret

; getMime(fnameExtension*) -> content-type
getMime:
  push ebp
  mov ebp, esp
  push eax
  push edx

  mov eax, [ebp+8] ; fname extension ptr

  push eax
  push HTML_EXT
  call strcmp
  pop edx
  cmp edx, 1
  jz .html

  push eax
  push CSS_EXT
  call strcmp
  pop edx
  cmp edx, 1
  jz .css

  push eax
  push JS_EXT
  call strcmp
  pop edx
  cmp edx, 1
  jz .js

  push eax
  push JSON_EXT
  call strcmp
  pop edx
  cmp edx, 1
  jz .json

  push eax
  push ICO_EXT
  call strcmp
  pop edx
  cmp edx, 1
  jz .ico

  push eax
  push PNG_EXT
  call strcmp
  pop edx
  cmp edx, 1
  jz .png

  push eax
  push BIN_EXT
  call strcmp
  pop edx
  cmp edx, 1
  jz .bin

  push eax
  push SVG_EXT
  call strcmp
  pop edx
  cmp edx, 1
  jz .svg
  ; assumes html if type not found
.html:
  mov dword [ebp+8], HTML_TYPE
  jmp .end
.css:
  mov dword [ebp+8], CSS_TYPE
  jmp .end
.json:
  mov dword [ebp+8], JSON_TYPE
  jmp .end
.js:
  mov dword [ebp+8], JS_TYPE
  jmp .end
.ico:
  mov dword [ebp+8], ICO_TYPE
  jmp .end
.bin:
  mov dword [ebp+8], PNG_TYPE
  jmp .end
.png:
  mov dword [ebp+8], BINARY_TYPE
  jmp .end
.svg:
  mov dword [ebp+8], SVG_TYPE
  jmp .end
.end:
  pop edx
  pop eax
  pop ebp
  ret

; returns a ptr to the start of the file extension (after the first '.')
getExtension:
  push ebp
  mov ebp, esp
  push ebx
  push ecx
  mov ebx, [ebp+8] ; full path

  push ebx
  call igetLength
  pop ecx
  add ebx, ecx ; ebx pointing to the end

.nextChar:
  cmp byte [ebx], '.'
  jz .end

  dec ebx
  loop .nextChar
.end:
  inc ebx
  mov [ebp+8], ebx
  pop ecx
  pop ebx
  pop ebp
  ret
%endif
