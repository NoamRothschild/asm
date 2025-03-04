%ifndef FILEMANAGER_INCLUDE
%define FILEMANAGER_INCLUDE

newFile:
	push ebp
	mov ebp, esp
	push eax
	push ebx
	push ecx

	mov ecx, 0777o ; full file perms
	mov ebx, [ebp+8] ; file name as arg
	mov eax, 8
	int 80h

	mov [ebp+8], eax ; return the file descriptor
	pop ecx
	pop ebx
	pop eax
	pop ebp
	ret

writeFile: ;(name, contents) -> Null
	push ebp
	mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx

	mov eax, [ebp+12] ; file name
	push eax
	call newFile
	pop ebx ; ebx file descriptor

	mov ecx, [ebp+8] ; file contents

	push ecx
	call igetLength
	pop edx ; edx num of bytes to write

	mov eax, 4 ; invokes SYS_WRITE (kernel opcode 4)
	int 80h

    pop edx
    pop ecx
    pop ebx
    pop eax
	pop ebp
	ret 8

; returns file descriptor given a path
openFile:
	push ebp
	mov ebp, esp
	push eax
	push ebx
	push ecx

	mov ebx, [ebp+8] ; file name
	mov ecx, 0
	mov eax, 5 ; invokes SYS_OPEN (kernel opcode 5)
	int 80h

	test eax, eax
	jns .ok
	mov eax, -1
	
	.ok:
	mov [ebp+8], eax
	pop ecx
	pop ebx
	pop eax
	pop ebp
	ret

; stores file contents given a file descriptor, location to store in and number of bytes
readFile: ; (unsigned int fd, char *buf, size_t count)
	push ebp
	mov ebp, esp
	push eax
	push ebx
	push ecx
	push edx

	mov ebx, [ebp+16] ; file descriptor
	mov ecx, [ebp+12] ; place to store in memory
	mov edx, [ebp+8] ; number of bytes to read
	mov eax, 3
	int 80h

	pop edx
	pop ecx
	pop ebx
	pop eax
	pop ebp
	ret 12

; closes a file given a file descriptor
closeFile:
	push ebp
	mov ebp, esp

	mov ebx, [esp+8] ; file descriptor
	mov eax, 6
	int 80h

	pop ebp
	ret 4

; deletes a file given a file path
deleteFile:
	push ebp
	mov ebp, esp
    push ebx
    push eax

	mov ebx, [ebp+8] ; file name
	mov eax, 10
	int 80h

    pop eax
    pop ebx
	pop ebp
	ret 4

; WARNING: DOES NOT WORK WITH 'OPENFILE', NO WRITE PERMS GIVEN
appendFile:
	push ebp
	mov ebp, esp
    push eax
	push ebx
	push ecx
	push edx

	mov edx, 2 ; SEEK_END
	mov ecx, 0 ; offset of 0 from the end
	mov ebx, [ebp+12] ; file descriptor
	mov eax, 19 ; SYS_LSEEK
	int 80h

	mov edx, [ebp+8]
	push edx
	call igetLength
	pop edx ; edx amm of bytes to write
	mov ecx, [ebp+8] ; message to write
	mov ebx, [ebp+12] ; file descriptor
	mov eax, 4 ; SYS_WRITE
	int 80h

    pop edx
	pop ecx
	pop ebx
	pop eax
	pop ebp
	ret 8

iLengthFile:
	push ebp
	mov ebp, esp
	push eax
	push ebx
	push ecx
	push edx

    push dword [ebp+8] ; filename
    call openFile
    pop eax

    mov edx, 2  ; whence argument (SEEK_END)
    mov ecx, 0  ; move the cursor 0 bytes
    mov ebx, eax  ; move the opened file descriptor into EBX
    mov eax, 19  ; invoke SYS_LSEEK (kernel opcode 19)
    int 80h  ; call the kernel

	test eax, eax
	jns .end
	mov eax, -1

.end:
	mov [ebp+8], eax
	pop edx
	pop ecx
	pop ebx
	pop eax
	pop ebp
	ret
%endif