%ifndef SOCKETS_INCLUDE
%define SOCKETS_INCLUDE
%include '../common/debug.asm'
section .data
	F_GETFL equ 3
	F_SETFL equ 4
	O_NONBLOCK equ 2048

	pollfd:
		.fd 	 dd 0
		.events  dw 1
		.revents dw 1

	POLLIN  equ 1
    POLLERR equ 8
    POLLHUP equ 16
	POLLNVAL equ 32
	POLLRDHUP equ 8192

section .text
; returns the file descriptor for the created socket
createSocket:
    push dword [esp]
	push ebp
	mov ebp, esp
	push ecx
	push ebx
	push eax

	push byte 6 ; IPPROTO_TCP
	push byte 1 ; SOCK_STREAM
	push byte 2 ; PF_INET
	mov ecx, esp ; move args addrr into ecx
	mov ebx, 1   ; invokes subroutine SOCKET (1)
	mov eax, 102 ; invokes SYS_SOCKETCALL (kernel opcode 102)
	int 80h

	mov [ebp+8], eax

	add esp, 12

	pop eax
	pop ebx
	pop ecx
	pop ebp
	ret

; binds a socket given a file descriptor
bindSocket:
	push ebp
	mov ebp, esp
	push edi
	push ecx
	push ebx
	push eax

	mov edi, [ebp+8] ; created socket file descriptor
	push dword 0x00000000   ; push onto the stack the IP ADRESS of the socket (0.0.0.0)
	; port 5001: 0x8913, port 8000: 0x401F
	push word 0x401F	; push onto the stack the PORT (5001) - in little endian format
	push word 2		; AF_INET
	mov ecx, esp		; set ecx to point to the arguments

	push byte 16		; push length of args
	push ecx		; push addrr of args
	push edi		; push file descriptor

	mov ecx, esp		; move addr of args into ecx
	mov ebx, 2		; invokes subroutine BIND (2)
	mov eax, 102		; invokes SYS_SOCKETCALL (kernel opcode 102)
	int 80h

	mov esp, ebp
    sub esp, 16

	pop eax
	pop ebx
	pop ecx
	pop edi
	pop ebp
	ret 4

listenSocket:
	push ebp
	mov ebp, esp
	push edi
	push ecx
	push ebx
	push eax

	push byte 10	; max queue length
	mov edi, [ebp+8] ; file descriptor
	push edi
	mov ecx, esp ; move args addr to ecx
	mov ebx, 4	; invoke subroutine LISTEN (4)
	mov eax, 102	; invokes SYS_SOCKETCALL (kernel opcode 102)
	int 80h

	mov esp, ebp
	sub esp, 16

	pop eax
	pop ebx
	pop ecx
	pop edi
	pop ebp
	ret 4

acceptSocket:
	push ebp
	mov ebp, esp
	push ecx
	push ebx
	push eax

	push byte 0	; addr len
	push byte 0	; adrr
	push dword [ebp+8]	; file descriptor
	mov ecx, esp	; move addr of args into ecx
	mov ebx, 5	; invokes subroutine ACCEPT (5)
	mov eax, 102
	int 80h
	; program will wait here untill a connection will be established

	mov [ebp+8], eax ; return identifying socket file descriptor
	mov esp, ebp
	sub esp, 12

	pop eax
	pop ebx
	pop ecx
	pop ebp
	ret

readSocket:
	push ebp
	mov ebp, esp
    push eax
	push ebx
    push ecx
	push edx

	mov edx, [ebp+16] ; amm of bytes to read
	mov ecx, [ebp+8] ; buffer*
	mov ebx, [ebp+12] ; socket identifying descriptor
	mov eax, 3 ; invokes SYS_READ (kernel opcode 3)
	int 80h

    pop edx
	pop ecx
	pop ebx
	pop eax
	pop ebp
	ret 12

writeSocket:
	push ebp
	mov ebp, esp
    push edx
    push ecx

	mov ebx, [ebp+12] ; received socket identifying descriptor
	mov ecx, [ebp+8] ; message
    mov edx, [ebp+16] ; num of bytes to write
	mov eax, 4 ; invokes SYS_WRITE (kernel opcode 4)
	int 80h

    pop ecx
    pop edx
	pop ebp
	ret 8

closeSocket:
	push ebp
	mov ebp, esp
    push eax
    push ebx

    mov ebx, [ebp+8] ; socket file descriptor
    mov eax, 6
    int 80h

    pop ebx
    pop eax
	pop ebp
	ret 4

setNonBlocking:
	push ebp
	mov ebp, esp
    push eax
    push ebx
	push ecx
	push edx

	mov ecx, F_GETFL
    mov ebx, [ebp+8] ; socket file descriptor
    mov eax, 0x37 ; fcntl
    int 0x80
	or eax, O_NONBLOCK ; activate nonblocking mode in flags

	mov edx, eax ; flags
	mov ecx, F_SETFL
    mov ebx, [ebp+8] ; socket file descriptor
    mov eax, 0x37 ; fcntl
    int 0x80

	pop edx
	pop ecx
    pop ebx
    pop eax
	pop ebp
	ret 4

strSocketErr: db "Connection closed || Error while reading socket.", 10, 0
strSocketData: db "Found data on socket!", 10, 0
; returns if the socket fd has data
hasData:
	push ebp
	mov ebp, esp
	push eax
	push ebx

	mov eax, [ebp+8]
	mov [pollfd.fd], eax
	mov word [pollfd.events], POLLIN

	; timeout of 10ms
	mov edx, 200 ; 1000ms/10 = 100 (100 times every second)
	mov ecx, 1 ; number of fd's
	mov ebx, pollfd
	mov eax, 0xa8 ; SYS_POLL
	int 0x80
	cmp eax, 0
	jbe .end

	mov ebx, [pollfd.revents]
	and ebx, POLLIN
	cmp ebx, 0
	jz .checkClosed
.dataAvailable:
	; push ANSI_GREEN
	; push strSocketData
	; call printColored
	mov eax, 1
	jmp .end
.checkClosed:
	mov eax, POLLHUP
	or eax, POLLERR
	or eax, POLLRDHUP
	mov ebx, [pollfd.revents]
	and ebx, eax
	jz .setOk
	mov eax, -1
	push ANSI_RED
	push strSocketErr
	call printColored
	jmp .end
.setOk:
	mov eax, 0
.end:
	mov [ebp+8], eax
	pop ebx
	pop eax
	pop ebp
	ret

%endif