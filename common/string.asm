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
    ret 4