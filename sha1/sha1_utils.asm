section .data
    SHA1_CHUNK_SIZE_BYTES equ 64
    SHA1_CHUNK_SIZE_BITS  equ SHA1_CHUNK_SIZE_BYTES * 8
    SHA1_CHUNK_DATA_LEN   equ SHA1_CHUNK_SIZE_BITS - 64
    SHA1_W_BUFF_BYTES     equ 80 * 4

    SHA1_K_CONST1 equ 0x5A827999
    SHA1_K_CONST2 equ 0x6ED9EBA1
    SHA1_K_CONST3 equ 0x8F1BBCDC
    SHA1_K_CONST4 equ 0xCA62C1D6

    SHA1_H0 equ 0x67452301
    SHA1_H1 equ 0xEFCDAB89
    SHA1_H2 equ 0x98BADCFE
    SHA1_H3 equ 0x10325476
    SHA1_H4 equ 0xC3D2E1F0

section .bss
    chunk: resb SHA1_CHUNK_SIZE_BYTES ; reserve 512 bits
    w_buff: resb SHA1_W_BUFF_BYTES

section .text

makeChunk:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push edx

    ; cleaning the chunk. see SHA-1 RFC section 4.b
    push dword chunk
    push dword 0x0
    push dword SHA1_CHUNK_SIZE_BYTES
    call memset

    ; copying message into buffer
    mov eax, [ebp+8] ; message length
    mov ebx, [ebp+12]; message*
    push dword chunk
    push ebx
    push eax
    call memcpy
    pop edx
    ; adding "1" to the message. see SHA-1 RFC section 4.a
    mov byte [edx], 10000000b

    ; adding the length of the message into the chunk. see SHA-1 RFC section 4.c
    xor edx, edx
    mov ebx, [ebp+8]
    mov eax, 8
    mul ebx
    
    bswap edx
    bswap eax
    mov dword [chunk + SHA1_CHUNK_DATA_LEN / 8], edx
    mov dword [chunk + 4 + SHA1_CHUNK_DATA_LEN / 8], eax

    pop edx
    pop ebx
    pop eax
    pop ebp
    ret 8

; memcpy(dest*, src*, byte_length) 
; returns end of message ptr
memcpy:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    mov eax, [ebp+12] ; load src*
    mov ebx, [ebp+16] ; load dest*
    add [ebp+8], ebx ; load end*
.copyChar:
    mov cl, byte [eax]
    mov byte [ebx], cl

    cmp ebx, [ebp+8]
    jz .end

    inc ebx
    inc eax
    jmp .copyChar
.end:
    mov [ebp+16], ebx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 8

; memset(dest*, byte, byte_length)
; sets all data in given range to given byte
memset:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    
    mov ebx, [ebp+16] ; load dest*
    mov eax, [ebp+12] ; load byte
    mov ecx, [ebp+8]  ; load bytes count

.copyChar:
    mov byte [ebx], al
    inc ebx
    loop .copyChar

    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 12

; f(t;B,C,D)
; psh t, b, c, d; call f
function_f_invalid: db "Invalid value passed for t in f(t;B,C,D): 0x", 0
function_f:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    ; offsets:
    ; 8: D, 12: C, 16: B, 20: t

    mov eax, [ebp+20] ; t
    cmp eax, 0
    jl .out_bounds
    cmp eax, 20
    jl .case1
    cmp eax, 40
    jl .case2
    cmp eax, 60
    jl .case3
    cmp eax, 80
    jl .case2 ; case 4 & 2 are the same
    jmp .out_bounds

.case1:
    mov esi, [ebp+16] ; B
    and esi, [ebp+12] ; B AND C
    mov ebx, esi

    mov esi, [ebp+16] ; B
    not esi
    and esi, [ebp+8] ; (NOT B) AND D

    or ebx, esi
    mov [ebp+20], ebx

    jmp .end
.case2:
    mov esi, [ebp+16] ; B
    xor esi, [ebp+12] ; XOR C
    xor esi, [ebp+8] ; XOR D

    mov [ebp+20], esi
    jmp .end
.case3:
    mov esi, [ebp+16] ; B
    and esi, [ebp+12] ; B AND C
    mov ebx, esi

    mov esi, [ebp+16] ; B
    and esi, [ebp+8] ; B AND D

    or ebx, esi ; (B AND C) OR (B AND D)

    mov esi, [ebp+12] ; C
    and esi, [ebp+8] ; C AND D

    or ebx, esi ; OR (C AND D)
    mov [ebp+20], ebx
    jmp .end
.out_bounds:
    push dword function_f_invalid
    call printMessage
    sub esp, 4
    mov edi, esp
    bswap eax
    mov dword [edi], eax
    push dword 4        ; print the full register (32 bit)
    push edi
    call printHex
    call printTerminator
    call exit
.end:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret 12


function_k_invalid: db "Invalid value passed for k in constants map: 0x", 0
constants_k:
    push ebp
    mov ebp, esp
    push eax
    push edi

    mov eax, [ebp+8] ; k
    cmp eax, 0
    jl .out_bounds
    cmp eax, 20
    jl .case1
    cmp eax, 40
    jl .case2
    cmp eax, 60
    jl .case3
    cmp eax, 80
    jl .case4
    jmp .out_bounds

.case1:
    mov dword [ebp+8], SHA1_K_CONST1
    jmp .end
.case2:
    mov dword [ebp+8], SHA1_K_CONST2
    jmp .end
.case3:
    mov dword [ebp+8], SHA1_K_CONST3
    jmp .end
.case4:
    mov dword [ebp+8], SHA1_K_CONST4
    jmp .end
.out_bounds:
    push dword function_k_invalid
    call printMessage
    sub esp, 4
    mov edi, esp
    bswap eax
    mov dword [edi], eax
    push dword 4        ; print the full register (32 bit)
    push edi
    call printHex
    call printTerminator
    call exit
.end:
    pop edi
    pop eax
    pop ebp
    ret

; digest(&buff)
; psh 160bit buffer, call digest
digest:
    push ebp
    mov ebp, esp

    ;//mov eax, [ebp+8] ; adress of output buffer, also used to store H0..H4
    ;//mov ebx, SHA1_H0
    ;//;bswap ebx ; todo: check if required
    ;//mov [eax], ebx
    ;//add eax, 4
    ;//mov ebx, SHA1_H1
    ;//;bswap ebx ; todo: check if required
    ;//mov [eax], ebx
    ;//add eax, 4
    ;//mov ebx, SHA1_H2
    ;//;bswap ebx ; todo: check if required
    ;//mov [eax], ebx
    ;//add eax, 4
    ;//mov ebx, SHA1_H3
    ;//;bswap ebx ; todo: check if required
    ;//mov [eax], ebx
    ;//add eax, 4
    ;//mov ebx, SHA1_H4
    ;//;bswap ebx ; todo: check if required
    ;//mov [eax], ebx

    ;memcpy(dest*, src*, byte_length) 
    
    push dword w_buff
    push dword 0x0
    push dword SHA1_W_BUFF_BYTES
    call memset

    push dword w_buff
    push dword chunk
    push SHA1_CHUNK_SIZE_BYTES
    call memcpy
    add esp, 4

    mov ecx, 16 
.extend_buff: ; Extending 16bit buff to 80 bits. see SHA-1 RFC section 6.1-b

    mov ebx, ecx
    sub ebx, 3
    shl ebx, 2
    add ebx, w_buff
    mov esi, [ebx] ; W(t-3)

    mov ebx, ecx
    sub ebx, 8
    shl ebx, 2
    add ebx, w_buff
    xor esi, dword [ebx] ; W(t-8)

    mov ebx, ecx
    sub ebx, 16
    shl ebx, 2
    add ebx, w_buff
    xor esi, dword [ebx] ; W(t-16)
    rol esi, 1 ; S^1

    mov ebx, ecx
    shl ebx, 2
    add ebx, w_buff
    mov [ebx], esi

    inc ecx
    cmp ecx, 80
    jl .extend_buff

    sub esp, 4*6 ; reserving space for 6 dwords
    mov edi, esp
    ; edi+0  - A
    ; edi+4  - B
    ; edi+8  - C
    ; edi+12 - D
    ; edi+16 - E
    ; edi+20 - TEMP

    mov dword [edi+0 ], SHA1_H0
    mov dword [edi+4 ], SHA1_H1
    mov dword [edi+8 ], SHA1_H2
    mov dword [edi+12], SHA1_H3
    mov dword [edi+16], SHA1_H4

    xor ecx, ecx
.section_d:

    mov esi, [edi+0]
    rol esi, 5 ; S^5(A)

    push ecx             ; t
    push dword [edi+4 ]  ; B
    push dword [edi+8 ]  ; C
    push dword [edi+12]  ; D
    call function_f
    pop ebx

    add esi, ebx
    add esi, dword [edi+16] ; E

    mov ebx, ecx
    shl ebx, 2
    add ebx, w_buff
    add esi, [ebx] ; W(t)

    push ecx
    call constants_k
    pop ebx
    add esi, ebx ; K(t)

    mov [edi+20], esi ; store in TEMP

    mov ebx, [edi+12]
    mov [edi+16], ebx ; E = D;

    mov ebx, [edi+8]
    mov [edi+12], ebx ; D = C;

    mov ebx, [edi+4]
    rol ebx, 30
    mov [edi+8], ebx ; C = S^30(B);

    mov ebx, [edi+0]
    mov [edi+4], ebx ; B = A;

    mov ebx, [ebp+20]
    mov [edi+0], ebx ; A = TEMP;

    inc ecx
    cmp ecx, 80
    jl .section_d

    mov eax, [ebp+8] ; output buffer

    mov ebx, SHA1_H0
    add ebx, [edi+0]
    bswap ebx
    mov [eax], ebx

    mov ebx, SHA1_H1
    add ebx, [edi+4]
    bswap ebx
    mov [eax+4], ebx

    mov ebx, SHA1_H2
    add ebx, [edi+8]
    bswap ebx
    mov [eax+8], ebx

    mov ebx, SHA1_H3
    add ebx, [edi+12]
    bswap ebx
    mov [eax+12], ebx

    mov ebx, SHA1_H4
    add ebx, [edi+16]
    bswap ebx
    mov [eax+16], ebx

    add esp, 4*6 ; deallocating variables

    pop ebp
    ret