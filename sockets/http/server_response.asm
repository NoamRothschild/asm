section .data
    RESP_BUFFER_SIZE equ 16384
    MAX_READ_BYTES_DISK_FILE equ 4096
    FILE_LENGTH_STR_SIZE equ 6 ; potentially hold up to '99999' (ends with a NULL terminator)

    RESP_TEMPLATE db 'HTTP/1.1 %', 0Dh, 0Ah, 'Content-Type: %', 0Dh, 0Ah, 'Connection: close', 0Dh, 0Ah, 'Content-Length: %', 0Dh, 0Ah, 0Dh, 0Ah, '%', 0Dh, 0Ah, 0
    TRACEBACK_FILE db 'temporary/index.html', 0 ; file to be displayed when the path provided an invalid file

    ; response codes

    STR_CODE_200 db "200 OK", 0
    STR_CODE_404 db "404 Not Found", 0
    STR_CODE_501 db "501 Not Implemented", 0
    STR_CODE_414 db "414 URI Too Long", 0
    STR_CODE_101 db "101 Switching Protocols", 0

    ; file extensions

    HTML_EXT db 'html', 0
    CSS_EXT db 'css', 0
    JSON_EXT db 'json', 0
    JS_EXT db 'js', 0
    ICO_EXT db 'ico', 0
    PNG_EXT db 'png', 0

    ; mime types

    HTML_TYPE db 'text/html', 0
    CSS_TYPE db 'text/css', 0
    JSON_TYPE db 'application/json', 0
    JS_TYPE db 'application/javascript', 0
    ICO_TYPE db 'image/x-icon', 0
    PNG_TYPE db 'image/png', 0
section .bss
    response_buffer: resb RESP_BUFFER_SIZE ; this buffer would hold the request sent to the client

section .text

; takes a client request struct and a socket connection descriptor and pushes a response
respond_http:
    push ebp
	mov ebp, esp
	push eax
    push ebx
	push ecx
	push edx
	push edi
    push esi

    sub esp, FILE_LENGTH_STR_SIZE
    mov edi, esp

    mov ebx, [ebp+8] ; request struct

    mov edx, ebx
    add edx, REQ_PATH_OFFSET
    inc edx

    push edx ; file path
    call iLengthFile
    pop ecx ; file length

    test ecx, ecx
    jns .readFile

    ; handle file not found here (404)
    mov word [ebx + REQ_RESP_CODE_OFFSET], 404
    mov edx, TRACEBACK_FILE ; change the file path to the one of a valid file

    push edx
    call iLengthFile
    pop ecx ; file length

.readFile:

    push edx
    call getExtension
    call getMime
    pop eax ; mime type

    push edx
    call openFile
    pop edx ; get the file descriptor of the given file

    sub esp, MAX_READ_BYTES_DISK_FILE
    mov esi, esp

    push edx ; file descriptor
    push esi ; file contents buffer
    push dword MAX_READ_BYTES_DISK_FILE ; amm of bytes to read
    call readFile

    push esi ; first argument for sprintf

    push edi ; file length buffer
    push ecx ; file length
    call toString

    push edi ; second argument for sprintf
    push eax ; third argument for sprintf
    xor eax, eax
    mov ax, word [ebx + REQ_RESP_CODE_OFFSET]
    push eax
    call getResonseCodeStr

    push RESP_TEMPLATE
    push response_buffer
    call sprintf
    pop edi ; the pointer to the end of the buffer 
    add esp, 5*4 ; remove 5 out of 6 pushed args from stack

    sub edi, response_buffer ; return only the length of the response buffer

    mov [ebp+8], edi

    add esp, MAX_READ_BYTES_DISK_FILE
    add esp, FILE_LENGTH_STR_SIZE
.end:

    pop esi
    pop edi
	pop edx
	pop ecx
    pop ebx
	pop eax
	pop ebp
    ret 

; given a status code (number), return its string representation pointer
getResonseCodeStr:
    cmp dword [esp+4], 101
    jz .101
    cmp dword [esp+4], 200
    jz .200
    cmp dword [esp+4], 404
    jz .404
    cmp dword [esp+4], 414
    jz .414
    cmp dword [esp+4], 501
    jz .501
.101:
    mov dword [esp+4], STR_CODE_101
    ret
.200:
    mov dword [esp+4], STR_CODE_200
    ret
.404:
    mov dword [esp+4], STR_CODE_404
    ret
.414:
    mov dword [esp+4], STR_CODE_414
    ret
.501:
    mov dword [esp+4], STR_CODE_501
    ret

; getMime(fname_extension*) -> content-type
getMime:
    push ebp
    mov ebp, esp
    push eax
    push edx

    mov eax, [ebp+8] ; fname extension ptr

    push eax
    push HTML_EXT
    call strcmp
    pop edx
    cmp edx, 1
    jz .html

    push eax
    push CSS_EXT
    call strcmp
    pop edx
    cmp edx, 1
    jz .css

    push eax
    push JS_EXT
    call strcmp
    pop edx
    cmp edx, 1
    jz .js

    push eax
    push JSON_EXT
    call strcmp
    pop edx
    cmp edx, 1
    jz .json

    push eax
    push ICO_EXT
    call strcmp
    pop edx
    cmp edx, 1
    jz .ico

    push eax
    push PNG_EXT
    call strcmp
    pop edx
    cmp edx, 1
    jz .png

    ; assumes html if type not found
.html:
    mov dword [ebp+8], HTML_TYPE
    jmp .end
.css:
    mov dword [ebp+8], CSS_TYPE
    jmp .end
.json:
    mov dword [ebp+8], JSON_TYPE
    jmp .end
.js:
    mov dword [ebp+8], JS_TYPE
    jmp .end
.ico:
    mov dword [ebp+8], ICO_TYPE
    jmp .end
.png:
    mov dword [ebp+8], PNG_TYPE
    jmp .end ; Not needed but for visibility
.end:
    pop edx
    pop eax
    pop ebp
    ret

; returns a ptr to the start of the file extension (after the first '.')
getExtension:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    mov ebx, [ebp+8] ; full path

    push ebx
    call igetLength
    pop ecx
    add ebx, ecx ; ebx pointing to the end

.nextChar:
    cmp byte [ebx], '.'
    jz .end

    dec ebx
    loop .nextChar
.end:
    inc ebx
    mov [ebp+8], ebx
    pop ecx
    pop ebx
    pop ebp
    ret