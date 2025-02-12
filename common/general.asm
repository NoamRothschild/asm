igetLength:
	push ebp
	mov ebp, esp
	push eax
	push ebx
	; bx -> offset msg
	mov ebx, [ebp+8]
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

chrtoi:
    push    ebx             ; preserve ebx on the stack to be restored after function runs
    push    ecx             ; preserve ecx on the stack to be restored after function runs
    push    edx             ; preserve edx on the stack to be restored after function runs
    push    esi             ; preserve esi on the stack to be restored after function runs
    push    eax             ; preserve eax on the stack to be restored after function runs
    mov     esi, eax        ; move pointer in eax into esi (our number to convert)
    mov     eax, 0          ; initialise eax with decimal value 0
    mov     ecx, 0          ; initialise ecx with decimal value 0
 
.multiplyLoop:
    xor     ebx, ebx        ; resets both lower and uppper bytes of ebx to be 0
    mov     bl, [esi+ecx]   ; move a single byte into ebx register's lower half
    cmp     bl, 48          ; compare ebx register's lower half value against ascii value 48 (char value 0)
    jl      .finished       ; jump if less than to label finished
    cmp     bl, 57          ; compare ebx register's lower half value against ascii value 57 (char value 9)
    jg      .finished       ; jump if greater than to label finished
 
    sub     bl, 48          ; convert ebx register's lower half to decimal representation of ascii value
    add     eax, ebx        ; add ebx to our integer value in eax
    mov     ebx, 10         ; move decimal value 10 into ebx
    mul     ebx             ; multiply eax by ebx to get place value
    inc     ecx             ; increment ecx (our counter register)
    jmp     .multiplyLoop   ; continue multiply loop
 
.finished:
    cmp     ecx, 0          ; compare ecx register's value against decimal 0 (our counter register)
    je      .restore        ; jump if equal to 0 (no integer arguments were passed to atoi)
    mov     ebx, 10         ; move decimal value 10 into ebx
    div     ebx             ; divide eax by value in ebx (in this case 10)
 
.restore:
	pop     esi             ; restore eax from the value we pushed onto the stack at the start
    pop     esi             ; restore esi from the value we pushed onto the stack at the start
    pop     edx             ; restore edx from the value we pushed onto the stack at the start
    pop     ecx             ; restore ecx from the value we pushed onto the stack at the start
    pop     ebx             ; restore ebx from the value we pushed onto the stack at the start
    ret

sreadInput:
    push ebp
    mov ebp, esp
    push edx
    push ecx
    push ebx
    push eax

    mov edx, 255		; number of bytes to read
	mov ecx, [ebp+8]		; reserved space to store inside
	mov ebx, 0		; read from stdin
	mov eax, 3		; invokes SYS_READ (kernel opcode 3)
	int 80h

    pop eax
    pop ebx
    pop ecx
    pop edx
    pop ebp
    ret 4

exit:
    mov ebx, 0 ; RETURN WITH STATUS CODE 0
	mov eax, 1 ; invokes SYS_EXIT (kernel opcode 1)
	int 80h
    ret
