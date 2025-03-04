%ifndef DEBUG_INCLUDE
%define DEBUG_INCLUDE
section .data
    ANSI_ESC equ 27
    ANSI_BLACK    db ANSI_ESC, '[30m', 0  ; Black
    ANSI_RED      db ANSI_ESC, '[31m', 0  ; Red
    ANSI_GREEN    db ANSI_ESC, '[32m', 0  ; Green
    ANSI_YELLOW   db ANSI_ESC, '[33m', 0  ; Yellow
    ANSI_BLUE     db ANSI_ESC, '[34m', 0  ; Blue
    ANSI_MAGENTA  db ANSI_ESC, '[35m', 0  ; Magenta
    ANSI_CYAN     db ANSI_ESC, '[36m', 0  ; Cyan
    ANSI_WHITE    db ANSI_ESC, '[37m', 0  ; White
    ANSI_RESET    db ANSI_ESC, '[0m', 0   ; Reset to default color

section .text

setDefaultColor:
    push dword [esp+4] ; ansiColor
    call printMessage
    ret 4
resetDefaultColor:
    push ANSI_RESET
    call printMessage
    ret

;ansiColor, msg
printColored:
    push ebp
    mov ebp, esp

    push dword [ebp+12] ; color
    call printMessage
    push dword [ebp+8] ; msg
    call printMessage
    push ANSI_RESET
    call printMessage

    pop ebp
    ret 8

printChar:
	push ebp
    mov ebp, esp
    push eax
    push ecx
	push edx
	push ebx

	mov eax, [ebp+8]
	push eax
	mov edx, 1
	mov ecx, esp
	mov ebx, 1
	mov eax, 4
	int 80h
	pop eax

	pop ebx
	pop edx
    pop ecx
	pop eax
	pop ebp
	ret 4

printMessage: ;(offset msg)
	push ebp
	mov ebp, esp
	push ecx
	push edx
	push ebx
	push eax

	mov ecx, [ebp+8] ; first given argument

	push ecx
	call igetLength
	pop edx

	mov ebx, 1		; write to STDOUT
	mov eax, 4		; invokes SYS_WRITE (kernel opcode 4)
	int 80h

	pop eax
	pop ebx
	pop edx
	pop ecx
	pop ebp
	ret 4

printUntil:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx

    mov eax, [ebp+12] ; message pointer
    mov edx, [ebp+8] ; end character

    mov ebx, [ebp+12]
	mov eax, ebx
.nextChar:
	cmp byte [eax], dl
	jz .finished
	inc eax
	jmp .nextChar
.finished:
	sub eax, ebx
	
    mov ecx, [ebp+12] ; first given argument
	mov edx, eax
	mov ebx, 1		; write to STDOUT
	mov eax, 4		; invokes SYS_WRITE (kernel opcode 4)
	int 80h

    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 8

printTerminator:
	push 0Ah
	call printChar
	ret

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

printInt:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx

    mov eax, [ebp+8] ; number
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
    call printChar
    loop .loopEnd
.end:
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 4
%endif