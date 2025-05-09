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
%include "../b64/b64.asm"
%include "auth.asm"

section .data
  USER_CAPACITY equ 50
  CHANNEL_BUFF_CAPACITY equ 10 * (1024 * 1024) ; 10 MB
  REQUEST_READ_BYTES equ 1024 * 1024 
  CHANNEL_AMOUNT equ 1

  MAX_WEBSOCKET_DATA_SIZE equ (2 * WS_MAX_VALUE_UNSIGNED_16BIT) + (USR_NAME_SIZE + 1) + 4
  
  AUTH_TEMPLATE db 'HTTP/1.1 %', 0Dh, 0Ah, 'Connection: close', 0Dh, 0Ah, 'Set-Cookie: token=%', 0Dh, 0Ah, 0Dh, 0Ah, 0

  base_path db "frontend", 0
  traceback_file db "frontend/404.html", 0
  login_route db "frontend/login", 0
  register_route db "frontend/register", 0
  login_page db "frontend/login.html", 0
  register_page db "frontend/register.html", 0
  main_page db "frontend/index.html", 0
  profile_upload_page db "frontend/profiles/upload", 0
  profile_icons_directory db "frontend/profiles/", 0
  profile_file_extension db ".png", 0
  
  json_ok_page db "frontend/ok.json", 0
  empty_str_ db " ", 0

  ws_channel_general db "frontend/channels/general", 0
  ws_channel_help db "frontend/channels/help", 0
  ws_channel_about db "frontend/channels/about-this-project", 0
  ws_channel_announcements db "frontend/channels/announcements", 0

  tmp_valid_usr db "user valid!", 10, 0
  tmp_invalid_usr db "authentication failed!", 10, 0
  tmp_uname db "Noam", 0
  tmp_pwd db "123", 0

  log_file_extension db ".log", 0
  logs_folder db "logs/", 0


section .bss
  users_db: resd 1
  channel_general_db: resd 1
  channel_help_db: resd 1
  channel_about_db: resd 1
  channel_announcements_db: resd 1

  connected_channel: resd 1 ; a ptr to the value of channel_general / channel_...
  connected_user: resd 1 ; the sessions user (for websocket send)
  connected_last_read: resb 1 ; a ptr inside connected_channel of the last read message
  logs_file_fd: resd 1

  logs_file_name: resb 25
  http_request_data: resb REQUEST_READ_BYTES
  http_request_struct: resb REQ_TOTAL_SIZE
  websocket_data: resb MAX_WEBSOCKET_DATA_SIZE

section .text
global _start

str_started: db "Server binded up successfully to http://localhost:8000", 10, 0
str_client_disconnected: db "Client disconnected from server.", 10, 0

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
  mov dword [channel_general_db], edi

  push dword CHANNEL_BUFF_CAPACITY
  call create_database
  pop edi
  cmp edi, -1
  jz .end
  mov dword [channel_help_db], edi

  push dword CHANNEL_BUFF_CAPACITY
  call create_database
  pop edi
  cmp edi, -1
  jz .end
  mov dword [channel_announcements_db], edi

  push dword CHANNEL_BUFF_CAPACITY
  call create_database
  pop edi
  cmp edi, -1
  jz .end
  mov dword [channel_about_db], edi

  ; creating a temporary user
  push dword 0
  push tmp_pwd
  push tmp_uname
  push dword [users_db]
  call create_user
  add esp, 4

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
  pop edx
  cmp edx, 0
  jz .paths_http
  
  push http_request_struct + REQ_PATH_OFFSET + 1
  push main_page
  call strcpy
  add esp, 4

.paths_http:
  push http_request_struct 
  call printReqFormatted

  push dword .upload_profile
  push dword profile_upload_page
  call .path_subroutine

  push dword .login
  push dword login_route
  call .path_subroutine

  push dword .register
  push dword register_route
  call .path_subroutine

  push dword .index_page
  push dword main_page
  call .path_subroutine

  cmp word [http_request_struct + REQ_RESP_CODE_OFFSET], 101
  ; jnz .unknown_path
  jnz .respond_http
  ; websocket paths
  
  push dword [users_db]
  push http_request_data 
  call is_request_authenticated
  pop edx
  cmp edx, 0
  jz .unknown_path ; TODO: CHANGE TO 403 Unauthorized.
  mov dword [connected_user], edx

  push dword [channel_general_db]
  push dword ws_channel_general
  call .ws_subroutine

  push dword [channel_help_db]
  push dword ws_channel_help
  call .ws_subroutine

  push dword [channel_announcements_db]
  push dword ws_channel_announcements
  call .ws_subroutine

  push dword [channel_about_db]
  push dword ws_channel_about
  call .ws_subroutine

.unknown_path:
  mov word [http_request_struct + REQ_RESP_CODE_OFFSET], 404
  ; do not accept socket connection for an unknown path
  jmp .respond_http

.path_subroutine:
  mov eax, [esp + 8]     ; label
  mov ebx, [esp]         ; IP before call
  push dword [esp + 4]   ; path*
  push http_request_struct + REQ_PATH_OFFSET + 1
  call strcmp
  pop edx

  add esp, 8
  mov dword [esp], ebx 
  
  add esp, 4
  cmp edx, 1
  jnz .end_paths_subroutine
  jmp eax
.end_paths_subroutine:
  jmp dword [esp - 4]    ; ret replacement without removing IP from stack (already did)

.ws_subroutine: ; +8 str path, +12 channel db
  push ebp
  mov ebp, esp
  push dword .ws_succed_subroutine
  push dword [ebp + 8] ; str path
  call .path_subroutine
.ws_fail_subroutine:
  mov esp, ebp
  pop ebp
  ret 8
.ws_succed_subroutine:
  mov edx, [ebp + 12] ; channel db
  mov dword [connected_last_read], edx
  add dword [connected_last_read], DATA_START_OFFSET
  mov [connected_channel], edx
  pop ebp
  add esp, 12 ; clear args & IP
  jmp .respond_http

.upload_profile:
  push dword [users_db]
  push http_request_data 
  call is_request_authenticated
  pop edx

  cmp edx, 0
  jz .respond_http ; return 404 since path is not a valid file
  ; usr was found in db
  lea edx, [edx + USR_NAME_OFFSET]
 
  push profile_icons_directory
  call igetLength
  pop ecx
  add ecx, USR_NAME_SIZE
  sub esp, ecx
  mov edi, esp 

  push ecx ; keeping a reference to how many bytes to deallocate
  push edi ; keeping a reference to the start of the file name
  
  push edi 
  push profile_icons_directory
  call strcpy
  push edx
  call strcpy
  push profile_file_extension
  call strcpy
  add esp, 4

  call newFile ; file name already in stack from old reference
  pop ebx
  push http_request_data
  call getReqDataPtr
  pop ecx
  mov edx, [http_request_struct + REQ_CONTENT_LENGTH_OFFSET]
  mov eax, 4 ; invokes SYS_WRITE (kernel opcode 4)
  int 80h

  pop ecx
  add esp, ecx

  push http_request_struct + REQ_PATH_OFFSET + 1
  push json_ok_page
  call strcpy
  
  jmp .respond_http
.login:
  lea eax, [http_request_struct + REQ_DATA_OFFSET]

  push eax
  call igetLength
  inc dword [esp]
  add [esp], eax        ; pwd*
  push eax              ; uname*
  push dword [users_db] ; db*
  call authenticate_usr
  pop edx

  call printTerminator
  push edx
  call printInt
  call printTerminator

  mov ebx, STR_CODE_200

  cmp edx, USR_ERR_NOT_FOUND
  jz .login_invalidResponse
  cmp edx, USR_ERR_WRONG_PASS
  jz .login_invalidResponse

  jmp .login_createResponse
.login_invalidResponse:
  mov ebx, STR_CODE_400
  mov edx, empty_str_
.login_createResponse:

  push edi
  sub esp, 27
  mov edi, esp

  push dword USR_PWD_SIZE
  push edi
  push edx
  call b64Encode

  push edi
  push ebx
  push AUTH_TEMPLATE
  push responseBuffer
  call sprintf
  pop edx ; get end*
  sub edx, responseBuffer
  add esp, 12

  add esp, 27
  pop edi

  jmp .write_http
.register:
  lea eax, [http_request_struct + REQ_DATA_OFFSET]

  push eax
  call igetLength
  inc dword [esp]
  add [esp], eax        ; pwd*
  push eax              ; uname*
  push dword [users_db] ; db*
  call authenticate_usr
  pop edx

  mov ebx, STR_CODE_200
  cmp edx, USR_ERR_NOT_FOUND
  jz .register_createUser
  mov ebx, STR_CODE_400
  mov edx, empty_str_
  jmp .register_createResponse
.register_createUser:

  push dword 0          ; perms
  push eax
  call igetLength
  inc dword [esp]
  add [esp], eax        ; pwd*
  push eax              ; uname*
  push dword [users_db]
  call create_user
  pop edx

.register_createResponse:

  push edi
  sub esp, 27
  mov edi, esp

  push USR_PWD_SIZE
  push edi
  push edx
  call b64Encode

  push edi
  push ebx
  push AUTH_TEMPLATE
  push responseBuffer
  call sprintf
  pop edx ; get end*
  sub edx, responseBuffer
  add esp, 12

  add esp, 27
  pop edi

  jmp .write_http

.index_page:

  push http_request_struct + REQ_PATH_OFFSET + 1
  push login_page
  call strcpy

  push dword [users_db]
  push http_request_data 
  call is_request_authenticated
  pop edx

  cmp edx, 0
  jz .respond_http
  ; usr was found in db
  
  push http_request_struct + REQ_PATH_OFFSET + 1
  push main_page
  call strcpy

  push ANSI_GREEN
  call setDefaultColor

  push http_request_struct
  call printReqFormatted

  call resetDefaultColor

  jmp .respond_http

.respond_http:
  push traceback_file
  push http_request_struct
  call respondHttp
  pop edx

.write_http:
  push edx ; length of full response in bytes
  push esi
  push responseBuffer
  call writeSocket

  cmp word [http_request_struct + REQ_RESP_CODE_OFFSET], 101
  jnz .closeSocket

  push esi
  call setNonBlocking

  ; making any error on ws force close socket.
  mov ecx, .ws_disconnect
  mov ebx, 11 ; seg fault
  mov eax, 0x30 ; SYS_SIGNAL
  int 0x80
.websocket:
  push esi
  call hasData
  pop ecx
  cmp ecx, -1 ; close socket if closed by client
  jz .ws_disconnect
  cmp ecx, 1 ; only parse if data was found
  jnz .ws_send_recent
.ws_parse:
  push read_store_data ; the call function
  push esi
  call parseRequest
  pop ecx
  cmp ecx, -1
  jz .ws_disconnect
.ws_send_recent:
  mov edi, [connected_last_read]
.ws_send_recent_loop:
  cmp dword [edi], 0
  jz .ws_send_recent_end
  ; handle new message
  mov ecx, [edi]
  sub ecx, edi
  sub ecx, 4 ; getting message length
  
  push ecx
  push edi
  add dword [esp], 4
  call makeResponse
  ; pop ecx
  ; push ecx
  push esi
  push wsRespBuff
  call writeSocket

  mov edi, [edi]
  jmp .ws_send_recent_loop
.ws_send_recent_end:
  mov [connected_last_read], edi
  jmp .websocket
.ws_disconnect:
  push ANSI_YELLOW
  push str_client_disconnected
  call printColored

  ; TODO: send close frame
.closeSocket:
  push esi
  call closeSocket
.end:
  call exit

; push ecx
; push websocket_data
; call makeResponse
; pop ecx

read_store_data:
  push eax
  push esi
  ; @edi: length
  ; @wsReqData: data

  mov esi, websocket_data
  mov eax, [connected_user]
  lea ebx, [eax + USR_NAME_OFFSET]
  push ebx
  call igetLength
  push dword [esp] ; keep a save of the uname length in stack
  pop ecx ; uname length
  add ecx, edi ; msg length
  add ecx, 4 ; unix timestamp

  ; copying unix time
  push dword 0
  call unixNow
  pop edx
  mov [esi], edx
  add esi, 4
  pop edx ; uname length

  ; copying username
  push esi ; dest buffer
  push ebx ; uname
  push edx ; uname length
  call memcpy
  pop esi
  mov byte [esi], 0
  inc esi
 
  push esi ; dest buffer
  push wsReqData ; data
  push edi ; data length
  call memcpy
  add esp, 4

  push ecx
  push websocket_data
  push dword [connected_channel]
  call append_data

  ; @ecx: return
  pop esi
  pop eax
  ret

create_dbs_merged:
  push dword [esp]
  push ebp
  mov ebp, esp
  push eax
  push edi

  mov eax, (USER_CAPACITY * USR_TOTAL_SIZE) + 1
  add eax, CHANNEL_BUFF_CAPACITY * CHANNEL_AMOUNT

  push eax
  call create_database
  pop edi
  cmp edi, -1
  jz .fail

  mov dword [users_db], edi
  mov byte [edi + USR_DATA_START_OFFSET + USR_ID_OFFSET], 255
  add edi, (USER_CAPACITY * USR_TOTAL_SIZE) + 1

  mov dword [channel_general_db], edi
  lea eax, [edi + DATA_START_OFFSET]
  mov byte  [edi + LOCKED_BYTE_OFFSET], 0     ; setting locked to false
  mov dword [edi + TAIL_PTR_OFFSET   ], eax   ; setting tail  ptr to first element
  mov dword [edi + DATA_START_OFFSET ], 0     ; setting first ptr to NULL
  add edi, CHANNEL_BUFF_CAPACITY
  
  jmp .end
.fail:
  call exit
.end:
  mov [ebp + 8], edi
  pop edi
  pop eax
  pop ebp
  ret
