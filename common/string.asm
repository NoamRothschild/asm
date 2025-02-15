strlen:
    push ebp
	mov ebp, esp
	push eax
	push ebx
	mov ebx, [ebp+8] ; msg* (ends with a null terminator)
	mov eax, ebx
.nextChar:
	cmp byte [eax], 0
	jz .finished
	inc eax
	jmp .nextChar
.finished:
	sub eax, ebx
	mov [ebp+8], eax
	pop ebx
	pop eax
	pop ebp
    ret

; strcpy(location*, msg*) 
; returns end of message ptr
strcpy:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx

    mov eax, [ebp+8] ; load msg*
    lea eax, [eax]

    mov ebx, [ebp+12] ; load location*
    lea ebx, [ebx]

.copyChar:
    mov cl, byte [eax]
    mov byte [ebx], cl

    cmp cl, 0
    jz .end

    inc ebx
    inc eax
    jmp .copyChar

.end:
    mov [ebp+12], ebx

    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 4

sprintf:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx

    mov eax, [ebp+12] ; load msg*
    mov ebx, [ebp+8] ; load buffer

    mov edi, ebp
    add edi, 12 ; store the location of the args

.copyChar:
    mov cl, byte [eax]

    cmp cl, '%'
    jz .newArg
    cmp cl, 0
    jz .end
    ; for character in message: add character to buffer.
    ; if character is '%' pop next value from stack and use it as an offset to a location in memory and add it to the buffer

    mov byte [ebx], cl
    inc ebx
    inc eax
    jmp .copyChar

.newArg:
    add edi, 4
    mov ecx, [edi]

    push ebx ; push buffer
    push ecx ; push message*
    call strcpy
    pop ebx ; load new position in buffer to continue from
    inc eax
    jmp .copyChar

.end:
    mov [ebp+8], ebx ; return end of buffer pointer
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret

toString:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx
    push edi

    mov eax, [ebp+8] ; number
    mov edi, [ebp+12] ; buffer*
    xor ecx, ecx
.digitLoop:
    inc ecx

    xor edx, edx
    mov ebx, 10
    div ebx
    
    add edx, '0'
    push edx

    cmp eax, 0
    jz .loopEnd
    jmp .digitLoop
.loopEnd:
    pop edx
    mov byte [edi], dl
    inc edi
    loop .loopEnd
    mov byte [edi], 0 ; end with a null terminator
.end:
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 8

; checks if 2 strings are equal (0 ? 1)
strcmp:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx

    mov eax, [ebp+8] ; a
    mov ebx, [ebp+12] ; b
    mov dword [ebp+12], 1 ; assume equality
.nextChar:
    mov cl, byte [eax]
    cmp cl, byte [ebx]

    jnz .fail

    inc ebx
    inc eax
    cmp byte [eax], 0 ; End of string
    jz .lenCheck
    cmp byte [ebx], 0 ; End of string
    jz .lenCheck
    jmp .nextChar
.lenCheck: ; gets here only if one of them ended
    mov cl, byte [eax]
    cmp cl, byte [ebx]
    jz .end

.fail:
    mov dword [ebp+12], 0
.end:
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 4

; src str, str2 - (0 ? 1) =? does str start with str2
; assumes strlen(str) >= strlen(str2)
startswith:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx

    mov eax, [ebp+8] ; str2
    mov ebx, [ebp+12] ; str
    mov dword [ebp+12], 1 ; assume equality
.nextChar:
    mov cl, byte [eax]
    test cl, cl
    jz .end
    cmp cl, byte [ebx]
    jnz .fail
    inc ebx
    inc eax
    jmp .nextChar
.fail:
    mov dword [ebp+12], 0
.end:
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 4

; locates a substring
strstr:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push edx

    mov eax, [ebp+8] ; substr
    mov ebx, [ebp+12] ; str
    mov dword [ebp+12], 0 ; return null as default case (not found)
    mov cl, byte [eax]
.byteLoop:
    test cl, cl
    jz .end ; exit on null terminator
    cmp cl, byte [ebx]
    jz .possibleMatch

    inc ebx
.possibleMatch:
    push ebx
    push eax
    call startswith
    pop edx

    inc ebx
    test edx, edx
    jz .byteLoop
    dec ebx
    mov dword [ebp+12], ebx ; return ptr of start of substr
.end:
    pop edx
    pop ebx
    pop eax
    pop ebp
    ret 4