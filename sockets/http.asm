section .data
    REQ_METHOD_OFFSET equ 0
    REQ_METHOD_SIZE equ 1 ; 1 byte in length 
    REQ_PATH_OFFSET equ REQ_METHOD_OFFSET + REQ_METHOD_SIZE
    REQ_PATH_SIZE equ 256 ; 255 bytes in length + null terminator
    ;//REQ_CONTENT_LENGTH_OFFSET equ REQ_PATH_OFFSET + REQ_PATH_SIZE
    ;//REQ_CONTENT_LENGTH_SIZE equ 2 ; 2 bytes in length (potentially can store 65,535 in length)
    ;//REQ_DATA_OFFSET equ REQ_CONTENT_LENGTH_OFFSET + REQ_CONTENT_LENGTH_SIZE
    REQ_DATA_OFFSET equ REQ_PATH_OFFSET + REQ_PATH_SIZE
    REQ_DATA_SIZE equ 4096 ; 4096 bytes in length
    REQ_RESP_CODE_OFFSET equ REQ_DATA_OFFSET + REQ_DATA_SIZE
    REQ_RESP_CODE_SIZE equ 2 ; 2 bytes in length

    REQ_TOTAL_SIZE equ REQ_METHOD_SIZE + REQ_PATH_SIZE + REQ_DATA_SIZE + REQ_RESP_CODE_SIZE

    METHOD_MAX_STR_LEN equ 8
    METHOD_GET equ 0b00
    METHOD_POST equ 0b01
    METHOD_PUT equ 0b10
    METHOD_DELETE equ 0b11

    STR_ERR_UNKNOWN_METHOD db "Unknown method received in packet: ", 0
    STR_ERR_URI_TOO_LONG db "Request URI Too Long (Over 255)", 10, 0

    DATA_START db 0xD, 0xA, 0xD, 0xA

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

    push eax
    mov ecx, REQ_TOTAL_SIZE
.clean_struct:
    mov byte [eax], 0
    inc eax
    loop .clean_struct
    pop eax

    mov word [eax + REQ_RESP_CODE_OFFSET], 200 ; set 200 OK as default resp code

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
    test edx, edx
    jns .valid_method
    mov word [eax + REQ_RESP_CODE_OFFSET], 501 ; set 501 Not Implemented as resp code (can also be 405)
    .valid_method:
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

    cmp byte [ebx], ' '
    jz .endpath_byteLoop
    mov word [eax + REQ_RESP_CODE_OFFSET], 414 ; set 414 Request-URI Too Long as resp code

    push ANSI_RED
    push STR_ERR_URI_TOO_LONG
    call printColored

.endpath_byteLoop:
    mov byte [edi], 0 ; null terminate string
    
    mov edx, dword [DATA_START]

    .goto_DataStart:
    inc ebx
    cmp dword [ebx], edx
    jnz .goto_DataStart
    add ebx, 4

    mov edx, REQ_TOTAL_SIZE
    add edx, [ebp+12] ; get end of HTTP req ptr
    mov ecx, REQ_DATA_SIZE
    mov edi, eax
    add edi, REQ_DATA_OFFSET
    .copyData:
    cmp edx, ebx
    jbe .end

    mov dl, byte [ebx]
    mov byte [edi], dl

    inc ebx
    inc edi
    loop .copyData

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

    push ANSI_RED
    call setDefaultColor

    push STR_ERR_UNKNOWN_METHOD
    call printMessage
    push eax
    call printMessage
    call printTerminator

    call resetDefaultColor

    mov dword [ebp+8], -1
    add esp, 4*4
    jmp .end

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
str_data: db "Data: ", 0
str_status_code: db "Response status code: ", 0
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

    push str_data
    call printMessage
    mov ebx, eax
    add ebx, REQ_DATA_OFFSET
    push ebx
    call printMessage
    call printTerminator

    push str_status_code
    call printMessage
    xor ebx, ebx
    mov bx, word [eax + REQ_RESP_CODE_OFFSET]
    push ebx
    call printInt
    call printTerminator

    pop ebx
    pop eax
    pop ebp
    ret 4