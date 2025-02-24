section .data
    WS_HEADERS_SIZE equ 10 ; maximum length the headers can take (not including mask key)
    WS_PAYLOAD_OFFSET equ 1 ;
    WS_MASK_KEY_SIZE equ 4 ; mask key is granteed to be 4 bytes in length

    WS_MAX_VALUE_UNSIGNED_16BIT equ 65535
    ws_magic_string db "258EAFA5-E914-47DA-95CA-C5AB0DC85B11", 0
    WS_MAGIC_STRING_LEN equ $ - ws_magic_string - 1
section .bss
    ws_buffer: resb 128
    ws_sha1_buff: resb SHA1_OUTPUT_SIZE_BYTES

    ws_headers: resb WS_HEADERS_SIZE
    ws_mask_key: resb WS_MASK_KEY_SIZE
    ws_req_data: resb 2*WS_MAX_VALUE_UNSIGNED_16BIT ; TODO: This number is just an estimate and does not represent anything!
    ws_resp_buff: resb 2*WS_MAX_VALUE_UNSIGNED_16BIT ; TODO: This number is just an estimate and does not represent anything!

    ws_tmp_len: resb 4

section .text

; given the sec-websocket-key and a buffer pointer, stores inside buffer the response
wsSecAccept:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx

    mov eax, [ebp+8] ; sec-websocket-key
    mov ebx, ws_buffer

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
    push ws_magic_string
    push ws_magic_string
    call igetLength
    call memcpy
    pop eax

    push ws_sha1_buff
    push ws_buffer
    push ws_buffer
    call igetLength
    call sha1

    push ws_buffer
    push dword 0x0
    push 128
    call memset

    push dword SHA1_OUTPUT_SIZE_BYTES
    push ws_buffer
    push ws_sha1_buff
    call b64_encode

    mov dword [ebp+8], ws_buffer

    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret

; returns the response length
makeResponse:
    push ebp
    mov ebp, esp
    push ebx
    push ecx

    ;//push dword ws_resp_buff
    ;//push dword 0x0
    ;//push dword 512
    ;//call memset

    xor ebx, ebx
    mov bl, 0x1 ; OPCODE, 0x1 for text (which is always encoded in UTF-8)
    or bl, 0b10000000 ; turn on FIN flag
    ;//shl bl, 4 ; position OPCODE
    ;//or bl, 0b00000001 ; turn on FIN flag
    ;//bswap bl ; change endianess

    mov ecx, [ebp+12] ; msg len
    cmp ecx, 126
    jb .smallest_msg_len
    cmp ecx, WS_MAX_VALUE_UNSIGNED_16BIT + 1
    jb .medium_msg_len
    jmp .largest_msg_len

.smallest_msg_len:
    mov bh, cl
    mov word [ws_resp_buff], bx

    push dword ws_resp_buff+2
    push dword [ebp+8] ; message
    push ecx
    call memcpy
    add esp, 4

    add dword [ebp+12], 2
    
    mov ecx, [ebp+12]
    mov dword [ws_tmp_len], ecx
    jmp .end
.medium_msg_len:
    mov bh, 126
    mov word [ws_resp_buff], bx

    mov bx, cx
    xchg bl, bh ; length prepeared to be stored in big endian on memory
    mov word [ws_resp_buff+2], bx

    push dword ws_resp_buff+4
    push dword [ebp+8] ; message
    push ecx
    call memcpy
    add esp, 4

    add dword [ebp+12], 4
    
    mov ecx, [ebp+12]
    mov dword [ws_tmp_len], ecx
    jmp .end

.largest_msg_len:
    mov ecx, [ws_tmp_len]
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

message_too_long_str: db "Received message is too long!", 10, 0
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
    push dword ws_headers
    push dword 0x0
    push dword WS_HEADERS_SIZE
    call memset

    push dword 2 ; only read the first 2 bytes for now
    push dword [ebp+8] ; websocket file descriptor
	push ws_headers
	call readSocket
    
    xor edx, edx
    mov bl, byte [ws_headers+WS_PAYLOAD_OFFSET]
    and bl, 0b01111111 ; removing the mask indicator bit from payload len byte
    ;//call printTerminator
    ;//call printTerminator
    ;//push ebx
    ;//call printInt
    ;//call printTerminator
    cmp bl, 126
    jb .smallest_msg_len
    cmp bl, 126
    jz .medium_msg_len
    cmp bl, 127
    jz .largest_msg_len
    jmp .end

.smallest_msg_len:
    mov edi, ebx
    jmp .unmask
.medium_msg_len:
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

.largest_msg_len:
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
    ;//push edi
    ;//push edx
    ;//call printInt
    ;//call printInt

    push dword ws_req_data
    push dword 0x0
    push dword 512
    call memset

    push dword WS_MASK_KEY_SIZE
    push dword [ebp+8]
    push ws_mask_key
    call readSocket

    push edi ; message size in bytes
    push dword [ebp+8]
    push ws_req_data
    call readSocket


    push edi ; message size in bytes
    push ws_req_data
    push ws_mask_key
    call unmaskData

    call printTerminator
    push ' '
    push '>'
    call printChar
    call printChar
    push ws_req_data
    call printMessage

    push edi
    push ws_req_data
    call makeResponse
    pop ecx
    mov dword [ebp+8], ecx ; return the response length
    jmp .end
.end:
    pop edx
    pop edi
    pop ecx
    pop ebx
    pop ebp
    ret