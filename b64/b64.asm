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
%endif