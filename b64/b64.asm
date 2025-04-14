%ifndef B64_INCLUDE
%define B64_INCLUDE
section .text

b64IndexTable: db 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

; populates given buffer by the b64 of the given byte array
b64Encode:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx
  push edi

  xor edx, edx ; bit counter (decides if should fetch the next byte)
  xor ecx, ecx ; digit loop counter (% of b64'ed byte)
  xor eax, eax ; ah - read byte, al - b64 byte
  mov ebx, [ebp+8]  ; * bytearray (end with NULL byte)
  mov edi, [ebp+12] ; buffer output
  add [ebp+16], ebx ; ptr to end of msg
  
  mov ah, byte [ebx]
  mov ecx, 6

  .b64Byte:
  
  mov dh, ah
  shr dh, 7
  and dh, 1 ; useless (?)
  add al, dh ; al += 0 || 1
  xor dh, dh
  ;adc al, 0 ; al+= 0 + cary
  shl ah, 1
  shl al, 1
  inc edx

  cmp edx, 8
  jz .nextByte

  loop .b64Byte
  shr al, 1

  push ecx
  xor ecx, ecx
  mov cl, al
  add ecx, b64IndexTable
  mov al, byte [ecx]
  pop ecx

  mov byte [edi], al
  xor al, al
  mov ecx, 6
  inc edi
  jmp .b64Byte


  .end:
  mov byte [edi], 0
  pop edi
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 12

  .nextByte:
  xor edx, edx
  inc ebx
  mov ah, byte [ebx]
  cmp ebx, [ebp+16] ; check if last byte was reached

  jz .eof

  loop .b64Byte
  shr al, 1

  push ecx
  xor ecx, ecx
  mov cl, al
  add ecx, b64IndexTable
  mov al, byte [ecx]
  pop ecx

  mov byte [edi], al
  xor al, al
  mov ecx, 6
  inc edi
  jmp .b64Byte

  .eof:
  dec ecx
  shl al, cl
  shr al, 1

  push ecx
  xor ecx, ecx
  mov cl, al
  add ecx, b64IndexTable
  mov al, byte [ecx]
  pop ecx

  mov byte [edi], al
  inc edi
  shr ecx, 1
  cmp ecx, 0
  jz .end

  .placeEqualSign:
  mov byte [edi], '='
  inc edi
  loop .placeEqualSign
  jmp .end

b64UnmapEncoding:
  push ebp
  mov ebp, esp
  push ecx
  push eax
  push ebx

  xor ecx, ecx

  mov eax, [ebp + 8] ; character
  ;push eax
  ;call printChar
  mov ebx, b64IndexTable
.findRepresentor:
  cmp al, byte [ebx]
  jz .end
  inc ecx
  inc ebx
  jmp .findRepresentor

.end:
  and ecx, 0b00000000000000000000000000111111
  mov dword [ebp + 8], ecx
  pop ebx
  pop eax
  pop ecx
  pop ebp
  ret

b64Decode:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx
  push edi

  mov ebx, [ebp + 8 ]  ; b64 string (end with NULL byte)
  mov edi, [ebp + 12]  ; output buffer

  ; cl: out byte
  ; al: in byte
  ; dl: state ctr
  xor edx, edx
  xor ecx, ecx
  xor eax, eax

.loop:
  mov al, byte [ebx]
  cmp al, '='
  jz .end
  cmp al, 0 
  jz .end

  push eax
  call b64UnmapEncoding
  pop eax

  cmp dl, 0
  jz .state0
  cmp dl, 1
  jz .state1
  cmp dl, 2
  jz .state2
  cmp dl, 3
  jz .state3

.state0:
  shl al, 2
  or cl, al
  mov byte [edi], cl

  inc dl
  inc ebx
  jmp .loop
.state1:
  shr al, 4
  or cl, al ; first byte cl is now done
  mov byte [edi], cl

  inc edi
  xor cl, cl

  mov al, byte [ebx]
  cmp al, '='
  jz .end
  cmp al, 0 
  jz .end
  push eax
  call b64UnmapEncoding
  pop eax

  shl al, 4
  or cl, al
  mov byte [edi], cl

  inc dl
  inc ebx
  jmp .loop
.state2:
  shr al, 2
  or cl, al
  mov byte [edi], cl

  inc edi
  xor cl, cl

  mov al, byte [ebx]
  cmp al, '='
  jz .end
  cmp al, 0 
  jz .end
  push eax
  call b64UnmapEncoding
  pop eax


  shl al, 6
  or cl, al
  mov byte [edi], cl

  inc dl
  inc ebx
  jmp .loop
.state3:
  or cl, al
  mov byte [edi], cl

  inc edi
  
  xor cl, cl
  xor dl, dl
  inc ebx
  jmp .loop

.end:
  pop edi
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 8
%endif