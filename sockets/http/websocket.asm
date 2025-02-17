section .data
    
    ws_magic_string db "258EAFA5-E914-47DA-95CA-C5AB0DC85B11", 0
section .bss

    ws_buffer: resb 128
    ws_sha1_buff: resb SHA1_OUTPUT_SIZE_BYTES
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