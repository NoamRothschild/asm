%ifndef WEBSOCKET_INCLUDE
%define WEBSOCKET_INCLUDE
%include '../sha1/sha1.asm'
%include '../b64/b64.asm'
%include '../common/general.asm'
%include '../common/debug.asm'
%include '../sockets/sockets.asm'
section .data
  WS_HEADERS_SIZE equ 10 ; maximum length the headers can take (not including mask key)
  WS_PAYLOAD_OFFSET equ 1 ;
  WS_MASK_KEY_SIZE equ 4 ; mask key is granteed to be 4 bytes in length

  WS_MAX_VALUE_UNSIGNED_16BIT equ 65535
  wsMagicString db "258EAFA5-E914-47DA-95CA-C5AB0DC85B11", 0
  WS_MAGIC_STRING_LEN equ $ - wsMagicString - 1
section .bss
  wsBuffer: resb 128
  wsSha1Buff: resb SHA1_OUTPUT_SIZE_BYTES

  wsHeaders: resb WS_HEADERS_SIZE
  wsMaskKey: resb WS_MASK_KEY_SIZE
  wsReqData: resb 2*WS_MAX_VALUE_UNSIGNED_16BIT ; TODO: This number is just an estimate and does not represent anything!
  wsRespBuff: resb 2*WS_MAX_VALUE_UNSIGNED_16BIT ; TODO: This number is just an estimate and does not represent anything!

  wsTmpLen: resb 4

section .text

; given the sec-websocket-key and a buffer pointer, stores inside buffer the response
wsSecAccept:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx

  mov eax, [ebp+8] ; sec-websocket-key
  mov ebx, wsBuffer

.copyKey:
  mov cl, byte [eax]
  cmp cl, 0
  jz .copyStr
  mov byte [ebx], cl

  inc eax
  inc ebx
  jmp .copyKey
.copyStr:

  push ebx
  push wsMagicString
  push wsMagicString
  call igetLength
  call memcpy
  pop eax

  push wsSha1Buff
  push wsBuffer
  push wsBuffer
  call igetLength
  call sha1

  push wsBuffer
  push dword 0x0
  push 128
  call memset

  push dword SHA1_OUTPUT_SIZE_BYTES
  push wsBuffer
  push wsSha1Buff
  call b64Encode

  mov dword [ebp+8], wsBuffer

  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret

; !! TODO: Changed the return of the function to binary format!!!
; returns the response length
makeResponse:
  push ebp
  mov ebp, esp
  push ebx
  push ecx

  ;//push dword wsRespBuff
  ;//push dword 0x0
  ;//push dword 512
  ;//call memset

  xor ebx, ebx
  mov bl, 0x2 ; OPCODE, 0x1 for text (which is always encoded in UTF-8)
  or bl, 0b10000000 ; turn on FIN flag
  ;//shl bl, 4 ; position OPCODE
  ;//or bl, 0b00000001 ; turn on FIN flag
  ;//bswap bl ; change endianess

  mov ecx, [ebp+12] ; msg len
  cmp ecx, 126
  jb .smallestMsgLen
  cmp ecx, WS_MAX_VALUE_UNSIGNED_16BIT + 1
  jb .mediumMsgLen
  jmp .largestMsgLen

.smallestMsgLen:
  mov bh, cl
  mov word [wsRespBuff], bx

  push dword wsRespBuff+2
  push dword [ebp+8] ; message
  push ecx
  call memcpy
  add esp, 4

  add dword [ebp+12], 2
  
  mov ecx, [ebp+12]
  mov dword [wsTmpLen], ecx
  jmp .end
.mediumMsgLen:
  mov bh, 126
  mov word [wsRespBuff], bx

  mov bx, cx
  xchg bl, bh ; length prepeared to be stored in big endian on memory
  mov word [wsRespBuff+2], bx

  push dword wsRespBuff+4
  push dword [ebp+8] ; message
  push ecx
  call memcpy
  add esp, 4

  add dword [ebp+12], 4
  
  mov ecx, [ebp+12]
  mov dword [wsTmpLen], ecx
  jmp .end

.largestMsgLen:
  mov ecx, [wsTmpLen]
  mov dword [ebp+12], ecx
  ;//add dword [ebp+12], 2 ;!! TEMPORARY !!
.end:
  pop ecx
  pop ebx
  pop ebp
  ret 4

unmaskData:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx
  push edx
  push esi

  mov eax, [ebp+8] ; mask key
  mov esi, [ebp+12] ; msg ptr
  xor ecx, ecx

.decodeChar:
  mov ebx, ecx
  and ebx, WS_MASK_KEY_SIZE-1 ; keep index in bounds of mask key
  mov dl, byte [eax+ebx]
  xor byte [esi+ecx], dl

  inc ecx
  cmp ecx, [ebp+16] ; msg length
  jnz .decodeChar

  pop esi
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 12

messageTooLongStr: db "Received message is too long!", 10, 0
parseRequest:
  push ebp
  mov ebp, esp
  push ebx
  push ecx
  push edi
  push edx

  ; *TODO: Make all functions support this
  ; msg length edx:edi
  ; (msg length edi if edx == 0)

  ; *TODO: Handle message splitted (check using FIN bit)

  xor ebx, ebx
  push dword wsHeaders
  push dword 0x0
  push dword WS_HEADERS_SIZE
  call memset

  push dword 2 ; only read the first 2 bytes for now
  push dword [ebp+8] ; websocket file descriptor
  push wsHeaders
  call readSocket
  
  xor edx, edx
  mov bl, byte [wsHeaders+WS_PAYLOAD_OFFSET]
  and bl, 0b01111111 ; removing the mask indicator bit from payload len byte
  ;//call printTerminator
  ;//call printTerminator
  ;//push ebx
  ;//call printInt
  ;//call printTerminator
  cmp bl, 126
  jb .smallestMsgLen
  cmp bl, 126
  jz .mediumMsgLen
  cmp bl, 127
  jz .largestMsgLen
  jmp .end

.smallestMsgLen:
  mov edi, ebx
  jmp .unmask
.mediumMsgLen:
  sub esp, 2

  mov edi, esp
  push dword 2
  push dword [ebp+8]
  push edi
  call readSocket
  mov bx, word [edi]
  xchg bl, bh

  add esp, 2
  mov edi, ebx
  jmp .unmask

.largestMsgLen:
  sub esp, 4

  mov edi, esp
  push dword 8
  push dword [ebp+8]
  push edi
  call readSocket

  mov edx, [edi]
  bswap edx
  mov edi, [edi+4]
  bswap edi

  add esp, 4
  jmp .unmask

.unmask:

  push dword WS_MASK_KEY_SIZE
  push dword [ebp+8]
  push wsMaskKey
  call readSocket

  push edi ; message size in bytes
  push dword [ebp+8]
  push wsReqData
  call readSocket

  push edi ; message size in bytes
  push wsReqData
  push wsMaskKey
  call unmaskData

  call dword [ebp+12] ; calling the given callback
  mov dword [ebp+12], ecx ; return the response length
  jmp .end
.end:
  pop edx
  pop edi
  pop ecx
  pop ebx
  pop ebp
  ret 4

_return:
  ret

printWSDebug:
  call printTerminator
  push ' '
  push '>'
  call printChar
  call printChar
  push wsReqData
  call printMessage
  push edi
  push wsReqData
  call makeResponse
  pop ecx
  ret
%endif
