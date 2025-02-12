section .data
    REQ_METHOD_OFFSET equ 0
    REQ_METHOD_SIZE equ 1 ; 1 byte in length 
    REQ_PATH_OFFSET equ REQ_METHOD_OFFSET + REQ_METHOD_SIZE
    REQ_PATH_SIZE equ 255 ; 255 bytes in length
    REQ_DATA_OFFSET equ REQ_PATH_OFFSET + REQ_PATH_SIZE
    REQ_DATA_SIZE equ 4096 ; 4096 bytes in length

    REQ_TOTAL_SIZE equ REQ_METHOD_SIZE + REQ_PATH_SIZE + REQ_DATA_SIZE

    METHOD_MAX_STR_LEN equ 8
    METHOD_GET equ 0b00
    METHOD_POST equ 0b01
    METHOD_PUT equ 0b10
    METHOD_DELETE equ 0b11


section .text

requestStruct:
    push ebp
    mov ebp, esp
    push edx
    push ebx
    push edi
    push eax
    push ecx

    mov eax, [ebp+8] ; struct pointer
    mov ebx, [ebp+12] ; HTTP message pointer

    mov ecx, REQ_TOTAL_SIZE
.clean_struct:
    mov byte [eax], 0
    inc eax
    loop .clean_struct

    sub esp, METHOD_MAX_STR_LEN
    mov edi, esp ; reserve tmp buff for req

    push edi
    push dword 0x00
    push dword METHOD_MAX_STR_LEN
    call memset

    mov eax, [ebp+8] ; struct pointer
    mov ecx, METHOD_MAX_STR_LEN
    push edi ; save value in stack
.method_byteLoop:
    cmp byte [ebx], ' '
    jz .endmethod_byteLoop
    
    mov dl, byte [ebx]
    mov byte [edi], dl

    inc ebx
    inc edi
    loop .method_byteLoop
.endmethod_byteLoop:
    ; pop edi, push edi
    call getMethodType
    pop edx
    mov byte [eax + REQ_METHOD_OFFSET], dl

    add esp, METHOD_MAX_STR_LEN ; deallocate tmp buff

    mov edi, eax
    add edi, REQ_PATH_OFFSET

    mov ecx, REQ_PATH_SIZE
    dec ecx ; path size includes null terminator
.goto_pathStart:
    cmp byte [ebx], '/'
    jz .path_byteLoop
    inc ebx
    jmp .goto_pathStart

.path_byteLoop:
    cmp byte [ebx], ' '
    jz .endpath_byteLoop

    mov dl, byte [ebx]
    mov byte [edi], dl

    inc ebx
    inc edi
    loop .path_byteLoop
.endpath_byteLoop:
    mov byte [edi], 0 ; null terminate string
;.nextByte:
;    inc ebx
;    cmp byte [ebx], 0Dh
;    jnz .nextByte
;    inc ebx
;    cmp byte [ebx], 0Ah
;    jnz .nextByte
;    inc ebx
;    cmp byte [ebx], 0Dh
;    jnz .nextByte
;    inc ebx
;    cmp byte [ebx], 0Ah
;    jnz .nextByte
;    inc ebx ; start of msg data

.end:
    pop ecx
    pop eax
    pop edi
    pop ebx
    pop edx
    pop ebp
    ret 8

STR_GET: db "GET", 0
STR_POST: db "POST", 0
STR_PUT: db "PUT", 0
STR_DELETE: db "DELETE", 0
getMethodType:
    push ebp
    mov ebp, esp
    push eax
    push ebx

    mov eax, [ebp+8] ; suspected method

    push eax
    push STR_GET
    call strcmp
    cmp dword [esp], 1
    jz .get

    push eax
    push STR_POST
    call strcmp
    cmp dword [esp], 1
    jz .post
    
    push eax
    push STR_PUT
    call strcmp
    cmp dword [esp], 1
    jz .put
    
    push eax
    push STR_DELETE
    call strcmp
    cmp dword [esp], 1
    jz .delete
    call exit ;!!! DANGEROUS

    .get:
    mov dword [ebp+8], METHOD_GET
    add esp, 4
    jmp .end
    .post:
    mov dword [ebp+8], METHOD_POST
    add esp, 4*2
    jmp .end
    .put:
    mov dword [ebp+8], METHOD_PUT
    add esp, 4*3
    jmp .end
    .delete:
    mov dword [ebp+8], METHOD_DELETE
    add esp, 4*4
    jmp .end
.end:
    pop ebx
    pop eax
    pop ebp
    ret

str_log: db "Analisys of new packet:", 10, 0
str_method: db "Method: ", 0
str_path: db "Path: ", 0
printStruct:
    push ebp
    mov ebp, esp
    push eax
    push ebx

    mov eax, [ebp+8] ; struct
    push str_log
    call printMessage

    push str_method
    call printMessage
    xor ebx, ebx
    mov bl, byte [eax + REQ_METHOD_OFFSET]
    push ebx
    call printInt
    call printTerminator

    push str_path
    call printMessage
    mov ebx, eax
    add ebx, REQ_PATH_OFFSET
    push ebx
    call printMessage
    call printTerminator

    pop ebx
    pop eax
    pop ebp
    ret 4