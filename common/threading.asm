; when resulting in 0, executor is child process, else parent.
fork:
    push dword [esp]
    push ebp
    mov ebp, esp
    push eax

    mov eax, 2 ; invokes SYS_FORK (kernel opcode 2)
	int 80h
    mov [ebp+8], eax

    pop eax
    pop ebp
    ret

; closes terminated child processes
close_terminated:
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, 7 ; waitpid opcode
    mov ebx, -1 ; target all child processes
    mov ecx, 0 ; status (ignored)
    mov edx, 1 ; WNOHANG - Dont wait for child to finish
    int 80h

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

