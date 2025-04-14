%ifndef USERS_DB_INCLUDE
%define USERS_DB_INCLUDE

%include "../database/database.asm"
%include "../common/threading.asm"
%include "../common/debug.asm"
%include "../common/string.asm"
%include "../sha1/sha1.asm"
%include "../common/general.asm"
%include "../common/time.asm"

section .data
  ; LOCKED_BYTE_OFFSET equ 0

  USR_DATA_START_OFFSET equ 1

  USR_ID_OFFSET equ 0
  USR_ID_SIZE equ 1

  USR_NAME_OFFSET equ USR_ID_OFFSET + USR_ID_SIZE
  USR_NAME_SIZE equ 255

  USR_PWD_OFFSET equ USR_NAME_OFFSET + USR_NAME_SIZE
  USR_PWD_SIZE equ SHA1_OUTPUT_SIZE_BYTES

  USR_TOKEN_OFFSET equ USR_PWD_OFFSET + USR_PWD_SIZE
  USR_TOKEN_SIZE equ SHA1_OUTPUT_SIZE_BYTES

  USR_PROPS_OFFSET equ USR_TOKEN_OFFSET + USR_TOKEN_SIZE
  USR_PROPS_SIZE equ 1

  USR_TOTAL_SIZE equ USR_PROPS_OFFSET + USR_PROPS_SIZE

  USR_ERR_WRONG_PASS equ 0
  USR_ERR_NOT_FOUND equ USR_ERR_WRONG_PASS + 1

section .text

; create_users_database(MAX_USER_AMM) -> db*
create_users_database:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push edx
  
  xor edx, edx
  mov eax, [ebp + 8] ; max user amm
  mov ebx, USR_TOTAL_SIZE
  mul ebx

  push eax
  call create_database
  pop ebx

  cmp ebx, -1
  jz .end

  mov byte [ebx + USR_DATA_START_OFFSET + USR_ID_OFFSET], 255

.end:
  mov [ebp + 8], ebx
  pop edx
  pop ebx
  pop eax
  pop ebp
  ret

; create_user(db*, uname*, password*, isAdmin) -> token* (20 bytes)
create_user:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx

  mov eax, [ebp + 8] ; db*
  lea eax, [eax + USR_DATA_START_OFFSET]
  xor ecx, ecx

  dec cl ; fix first loop
  sub eax, USR_TOTAL_SIZE
.findEnd:
  inc cl 
  add eax, USR_TOTAL_SIZE
  cmp byte [eax + USR_ID_OFFSET], cl
  jz .findEnd

  mov ebx, [ebp + 8] ; db*
.waitUnlocked:
  cmp byte [ebx + LOCKED_BYTE_OFFSET], 0
  jnz .waitUnlocked

  mov byte [ebx + LOCKED_BYTE_OFFSET], 1 ; locking write
  mov [eax + USR_ID_OFFSET], cl ; copying user id

  lea ebx, [eax + USR_NAME_OFFSET]
  push ebx
  push dword [ebp + 12] ; username
  call strcpy
  add esp, 4

  lea ebx, [eax + USR_PWD_OFFSET]
  push ebx
  push dword [ebp + 16] ; password
  push dword [ebp + 16]
  call igetLength       ; get password length
  call sha1

  push ecx             ; user id
  push dword [ebp + 8] ; db*
  call create_token    ; create token

  mov ebx, [ebp + 20] ; props (isAdmin)
  mov [eax + USR_PROPS_OFFSET], bl

  mov cl, [eax + USR_ID_OFFSET]
  mov byte [eax + USR_TOTAL_SIZE + USR_ID_OFFSET], cl ; setting an invalid id for next user

  lea ebx, [eax + USR_TOKEN_OFFSET]
  mov [ebp + 20], ebx

  mov ebx, [ebp + 8]
  mov byte [ebx + LOCKED_BYTE_OFFSET], 0 ; unlocking write

  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 12

create_token:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edi
  mov ecx, USR_NAME_SIZE + USR_PWD_SIZE + USR_ID_SIZE + 4
  sub esp, ecx
  mov edi, esp
  push edi ; store for later

  push dword [ebp + 12] ; user id
  push dword [ebp + 8 ] ; db *
  call get_usr_ptr
  pop eax

  lea ebx, [eax + USR_NAME_OFFSET]
  push edi
  push ebx
  push dword USR_NAME_SIZE
  call memcpy
  
  lea ebx, [eax + USR_PWD_OFFSET]
  push ebx
  push dword USR_PWD_SIZE
  call memcpy

  lea ebx, [eax + USR_ID_OFFSET]
  push ebx
  push dword USR_ID_SIZE
  call memcpy
  pop edi
  
  push dword 0
  call unixNow
  pop ebx
  mov dword [edi], ebx

  pop edi ; retreive base ptr of buffer
  lea ebx, [eax + USR_TOKEN_OFFSET]
  push ebx
  push edi
  push ecx
  call sha1

  add esp, ecx
  pop edi
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 8

; get_usr_ptr(db*, user_id) -> usr_ptr
get_usr_ptr:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push edx

  xor edx, edx
  mov eax, [ebp + 12] ; user id
  mov ebx, USR_TOTAL_SIZE
  mul ebx
  add eax, USR_DATA_START_OFFSET
  add eax, [ebp + 8] ; db*
 
  mov [ebp + 12], eax
  pop edx
  pop ebx
  pop eax
  pop ebp
  ret 4

get_user_count:
  push ebp
  mov ebp, esp
  push eax
  push ecx

  mov eax, [ebp + 8] ; db*
  lea eax, [eax + USR_DATA_START_OFFSET]
  xor ecx, ecx

  dec cl ; fix first loop
  sub eax, USR_TOTAL_SIZE
.findLast:
  inc cl
  add eax, USR_TOTAL_SIZE
  cmp byte [eax + USR_ID_OFFSET], cl
  jz .findLast

  mov dword [ebp + 8], ecx
  pop ecx
  pop eax
  pop ebp
  ret

get_usr_by_token:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx

  mov eax, [ebp + 8] ; db*
  push eax ; db* 
  call get_user_count
  pop ecx

  cmp ecx, 0
  jz .fail

  add eax, USR_DATA_START_OFFSET
.nextUser:
  
  lea ebx, [eax + USR_TOKEN_OFFSET]
  push dword [ebp + 12] ; token*
  push ebx
  push USR_TOKEN_SIZE
  call memcmp
  pop edx
  cmp edx, 1 ; equal?
  jz .found
 
  add eax, USR_TOTAL_SIZE 
  loop .nextUser

.fail:
  mov dword [ebp + 12], 0 ; return 0 if failed 
  jmp .end
.found:
  mov dword [ebp + 12], eax ; return user ptr in db
.end:
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 4

authenticate_usr:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx

  push dword [ebp + 12] ; uname
  call printMessage
  call printTerminator
  push dword [ebp + 16] ; pwd
  call printMessage

  mov eax, [ebp + 8] ; db*

  push eax ; db* 
  call get_user_count
  pop ecx

  add eax, USR_DATA_START_OFFSET
.nextUser:
  
  lea ebx, [eax + USR_NAME_OFFSET]

  push dword [ebp + 12] ; uname*
  push ebx
  call strcmp 
  pop edx
  cmp edx, 1 ; equal?
  jz .foundUser

  add eax, USR_TOTAL_SIZE
  loop .nextUser

.fail:
  mov dword [ebp + 16], USR_ERR_NOT_FOUND
  jmp .end
.foundUser:

  sub esp, USR_PWD_SIZE
  mov edx, esp 

  lea ebx, [eax + USR_PWD_OFFSET]

  push edx
  push dword [ebp + 16] ; password
  push dword [ebp + 16]
  call igetLength       ; get password length
  call sha1

  push edx ; pwd*
  push ebx
  call strcmp
  pop edx

  add esp, USR_PWD_SIZE

  cmp edx, 1 ; equal?
  jz .authenticate

  mov dword [ebp + 16], USR_ERR_WRONG_PASS
  jmp .end

.authenticate:
  
  xor edx, edx
  mov dl, [eax + USR_ID_OFFSET]
  push edx             ; usr id
  push dword [ebp + 8] ; db*
  call create_token

  lea edx, [eax + USR_TOKEN_OFFSET]
  mov dword [ebp + 16], edx

.end:
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 8

%endif
