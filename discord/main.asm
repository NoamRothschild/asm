%include "../common/general.asm"
%include "../common/debug.asm"
%include "../common/threading.asm"
%include "../sockets/sockets.asm"
%include "../sockets/http/http.asm"
%include "../sockets/http/websocket.asm"
%include "../database/database.asm"
%include "../database/users_db.asm"
%include "../common/fileManager.asm"
%include "../common/string.asm"
%include "../common/time.asm"

section .data
  USER_CAPACITY equ 50
  CHANNEL_BUFF_CAPACITY equ 10 * (1024 * 1024) / 1024 ; 10 MB
  REQUEST_READ_BYTES equ 4096

  base_path db "frontend", 0
  traceback_file db "frontend/404.html", 0
  homepage_file db "frontend/index.html", 0

  log_file_extension db ".log", 0
  logs_folder db "logs/", 0

section .bss
  users_db: resd 1
  channel_general: resd 1
  logs_file_fd: resd 1

  logs_file_name: resb 25
  http_request_data: resb REQUEST_READ_BYTES
  http_request_struct: resb REQ_TOTAL_SIZE

section .text
global _start

str_started: db "Server binded up successfully to http://localhost:8000", 10, 0

_start:
  ; creating a log file
  push dword logs_file_name
  push logs_folder
  call strcpy
  pop edi

  push edi 
  push dword 2
  call unixNow
  call toString

.findLogfileEnd:
  inc edi
  cmp byte [edi], 0
  jnz .findLogfileEnd

  push edi
  push log_file_extension
  call strcpy
  add esp, 4

  push logs_file_name
  call newFile
  pop edi
  mov dword [logs_file_fd], edi

  ; creating databases
  push dword USER_CAPACITY
  call create_users_database
  pop edi
  cmp edi, -1
  jz .end
  mov dword [users_db], edi

  push dword CHANNEL_BUFF_CAPACITY
  call create_database
  pop edi
  cmp edi, -1
  jz .end
  mov dword [channel_general], edi

  ; starting the server 
  call createSocket
  mov edi, [esp]
  call bindSocket
  push edi
  call listenSocket
  push str_started 
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
  push dword REQUEST_READ_BYTES
  push esi ; connected socket identifying descriptor
  push http_request_data 
  call readSocket

  push dword [logs_file_fd]
  push http_request_data
  call appendFile

  push base_path
  push http_request_data
  push http_request_struct 
  call generateRequestStruct

  push base_path
  push http_request_struct + REQ_PATH_OFFSET + 1
  call strcmp
  jnz .respond_http
  
  push http_request_struct + REQ_PATH_OFFSET + 1
  push homepage_file
  call strcpy
  add esp, 4

.respond_http:
  push http_request_struct 
  call printReqFormatted

  push traceback_file
  push http_request_struct
  call respondHttp
  pop edx

  push edx ; length of full response in bytes
  push esi
  push responseBuffer
  call writeSocket

  cmp word [http_request_struct + REQ_RESP_CODE_OFFSET], 101
  jnz .closeSocket
  ; call registerPlayer
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
  ; call voxelSpaceResponse
  push ecx
  push esi
  push wsRespBuff
  call writeSocket
  jmp .websocket
.ws_disconnect:
  ; call removePlayer
.closeSocket:
  push esi
  call closeSocket
.end:
  call exit
