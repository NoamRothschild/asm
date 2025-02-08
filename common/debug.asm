; NOTE: `general.asm` must be included before including this file.

printBin:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx

    mov ebx, [ebp+8]
    mov ecx, [ebp+12] ; amm of bytes to print
.byteLoop:
    push ecx
    mov al, byte [ebx]
    mov ecx, 8
.bitLoop:
    xor edx, edx
    rol al, 1
    adc edx, 48
    push edx
    call printChar
    loop .bitLoop

    push dword ' '
    call printChar
    inc ebx
    pop ecx
    loop .byteLoop
    call printTerminator

    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 8

hexMap: db '0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f',0
printHex:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov ebx, [ebp+8]
    mov ecx, [ebp+12] ; amm of bytes to print
    xor esi, esi

.dataLoop:
    push ecx
    mov al, byte [ebx]

    mov ecx, 2
.byteLoop:
    push ecx
    xor edx, edx
    mov ecx, 4
.hexDigit:
    shl edx, 1
    rol al, 1
    adc edx, 0
loop .hexDigit
    add edx, hexMap
    mov cl, byte [edx]
    push ecx
    call printChar
    pop ecx ; get back value pushed at [printHex.byteLoop+1]
loop .byteLoop

    inc esi
    cmp esi, 4
    jnz .skipPadding
    push dword ' '
    call printChar
    xor esi, esi
.skipPadding:
    ;push ecx            ; TEMPORARY
    ;mov ecx, 7          ; TEMPORARY
;.printPadding:          ; TEMPORARY
    ;loop .printPadding  ; TEMPORARY
    ;pop ecx             ; TEMPORARY

    inc ebx
    pop ecx
loop .dataLoop

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 8
