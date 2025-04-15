%ifndef THREADING_INCLUDE
%define THREADING_INCLUDE
%include '../common/general.asm'
%include '../common/debug.asm'
%include '../common/time.asm'
section .data
  IPC_PRIVATE equ 0
  IPC_CREAT equ 512

  PROT_READ equ 1
  PROT_WRITE equ 2

  MAP_ANONYMOUS equ 32
  MAP_PRIVATE equ 2
  MAP_SHARED equ 1

  MAP_FAILED equ 0xffffffff

section .bss
  example_buffer: resb 1024

section .text

extern shmat
; when resulting in 0, executor is child process, else parent.
fork:
  push dword [esp]
  push ebp
  mov ebp, esp
  push eax

  mov eax, 2 ; invokes SYS_FORK (kernel opcode 2)
  int 80h
  mov [ebp+8], eax

  call closeTerminated

  pop eax
  pop ebp
  ret

; closes terminated child processes
closeTerminated:
  push eax
  push ebx
  push ecx
  push edx
  
  mov eax, 7 ; waitpid opcode
  mov ebx, -1 ; target all child processes
  mov ecx, 0 ; status (ignored)
  mov edx, 1 ; WNOHANG - Dont wait for child to finish
  int 80h

  pop edx
  pop ecx
  pop ebx
  pop eax
  ret

strUnableToAllocateSHMGET: db "Unable to allocate shared memory using shmget.", 10, 0
createSharedMemory:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx
  push esi

  mov ecx, [ebp+12] ; key

  mov eax, 0x75 ; ipc
  mov ebx, 23 ; SHMGET
  mov edx, [ebp+8] ; ammount of bytes to allocate
  mov esi, IPC_CREAT
  or esi, 0x1B6 ; 0666 permissions in octal (read-write)
  int 0x80

  cmp eax, -1
  jnz .end

  push ANSI_RED
  push strUnableToAllocateSHMGET
  call printColored
.end:
  mov dword [ebp+12], eax ; shmid or -1
  pop esi
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 4

strUnableToAttachSHMAT: db "Unable to attach to shared memory using shmat.", 10, 0
attachSharedMemory:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx
  sub esp, 4

  mov eax, 117       ; sys_ipc syscall number
  mov ebx, 21        ; SHMAT operation (IPC_SHMAT)
  mov ecx, [ebp+8]         ; shmid = 7
  mov edi, 0         ; shmaddr = NULL
  mov edx, 0         ; shmflg = 0
  lea esi, [esp]
  int 0x80           ; Call the kernel
  pop edx

  cmp eax, 0
  jz .end

  push ANSI_RED
  push strUnableToAttachSHMAT
  call printColored
  mov edx, -1
.end:
  mov [ebp+8], edx
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret

mmap:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx
  push esi
  push edi

  push ebp

  mov eax, 0xc0 ; mmap2
  mov ebx, 0
  mov ecx, [ebp + 8] ; size of allocated region
  mov edx, PROT_READ
  or edx, PROT_WRITE
  mov esi, MAP_ANONYMOUS
  or esi, MAP_SHARED
  mov edi, -1
  mov ebp, 0
  int 0x80

  pop ebp
  mov [ebp + 8], eax

  pop edi
  pop esi
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret

munmap:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx

  mov eax, 0x5b       ; munmap
  mov ebx, [ebp + 8 ] ; addr to umap
  mov ecx, [ebp + 12] ; size of region to unmap
  int 0x80

  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 8

; global _start
; 
; _start:
;      xor eax, eax
;      push dword 4096
;      call mmap
;      pop eax
;
;      push eax
;      call printInt
;      call printTerminator
;      
;      push dword 4096
;      push eax
;      call munmap
;
;      mov byte [eax], '5'
;      mov byte [eax + 1], 0
;
;      push eax
;      call printMessage
;
;
;     push dword 1024
;     call createSharedMemory
;     cmp dword [esp], -1 ; shmid or -1
;     jz .end
;     call attachSharedMemory
;     pop edx
; 
;     push edx
;     push dword "&"
;     push dword 5
;     call memset
; 
;     push edx
;     call printMessage
;     call exit
%endif
