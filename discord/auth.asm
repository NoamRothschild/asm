%include "../sockets/http/client_request.asm"
%include "../database/users_db.asm"
%include "../b64/b64.asm"

section .data
  cookie_header db "Cookie: token=", 0

section .text

; +8 req_data, +12 users_db
is_request_authenticated:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx
  push edi

  ;// mov ebx, http_request_data
  mov ebx, [ebp + 8] ; http_request_data
.nextHeader:
  mov edx, dword [DATA_START] ; \r\n
  inc ebx
  cmp word [ebx], dx
  jnz .nextHeader
  cmp dword [ebx], edx
  jz .fail 
  add ebx, 2

  push ebx
  push cookie_header
  call startswith 
  pop edx
  
  cmp edx, 1
  jnz .nextHeader
.validateCookie:

  mov eax, ebx
  push cookie_header
  call igetLength
  add eax, [esp]
  add esp, 4
  
  mov ecx, 30
  sub esp, ecx
  mov edi, esp
  push edi
.copyCookie:
  mov dl, byte [eax]
  cmp dl, 0xD
  jz .endCopyCookie
  mov byte [edi], dl
  inc eax
  inc edi

  loop .copyCookie
.endCopyCookie:
  mov byte [edi], 0
  pop edi

  push edi
  push edi
  call b64Decode

  push edi
  push dword [ebp + 12] 
  call get_usr_by_token
  pop edx

  add esp, 30
  mov [ebp + 12], edx
  jmp .end
.fail:
  mov dword [ebp + 12], 0 ; NULL (not found)
.end:
  pop edi
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 4

