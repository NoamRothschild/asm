%ifndef DATABASE_INCLUDE
%define DATABASE_INCLUDE

%include "../common/threading.asm"
%include "../common/debug.asm"
%include "../common/string.asm"

section .data
  LOCKED_BYTE_OFFSET equ 0
  TAIL_PTR_OFFSET equ LOCKED_BYTE_OFFSET + 1
  DATA_START_OFFSET equ TAIL_PTR_OFFSET + 4 
section .text

str_db_fail_create: db "Allocating %d bytes for db failed.", 10, 0 
str_db_fail_attach: db "Attaching to db failed.", 10, 0
create_database:
  push ebp
  mov ebp, esp
  push edx

  push dword [ebp+8] ; allocated size
  call createSharedMemory
  pop edx ; shmid
  cmp edx, -1
  jz .failCreate

  push edx
  call attachSharedMemory
  pop edx

  cmp edx, -1 ; shmaddr or -1
  jz .failAttach

  push eax
  lea eax, [edx + DATA_START_OFFSET]

  mov byte  [edx + LOCKED_BYTE_OFFSET], 0     ; setting locked to false
  mov dword [edx + TAIL_PTR_OFFSET   ], eax   ; setting tail  ptr to first element
  mov dword [edx + DATA_START_OFFSET ], 0     ; setting first ptr to NULL
  mov [ebp+8], edx ; return addr

  pop eax
  jmp .end

.failCreate:
  push dword [ebp+8]
  push str_db_fail_create
  call printf
  add esp, 8
  mov dword [ebp+8], -1 ; set return value as -1
  jmp .end
.failAttach:
  push str_db_fail_attach
  call printMessage
  mov dword [ebp+8], -1 ; set return value as -1
.end:
  pop edx
  pop ebp
  ret

; ebp+8 - data*, ebp+12 - database*
append_data:
  push ebp
  mov ebp, esp
  push ebx
  push esi
  push edi

  mov ebx, [ebp+12] ; database*
.waitUnlocked:
  cmp byte [ebx + LOCKED_BYTE_OFFSET], 0
  jnz .waitUnlocked

  mov byte [ebx + LOCKED_BYTE_OFFSET], 1 ; locking write
  
  mov edi, [ebx + TAIL_PTR_OFFSET]
.stepToLast:
  cmp dword [edi], 0 ; stop here
  jz .copyData
  mov edi, dword [edi] ; step through the linked list
  jmp .stepToLast
.copyData:
  lea esi, [edi + 4] ; start of data
  push esi
  push dword [ebp+8] ; data*
  call strcpy
  pop esi
  inc esi
  mov dword [esi], 0 ; setting next to null
  mov [edi], esi

  mov [ebx + TAIL_PTR_OFFSET], esi
  mov byte [ebx + LOCKED_BYTE_OFFSET], 0 ; unlocking write

  pop edi
  pop esi
  pop ebx
  pop ebp
  ret 8

%endif
