section .data
    SHA1_CHUNK_SIZE_BYTES equ 64
    SHA1_CHUNK_SIZE_BITS  equ SHA1_CHUNK_SIZE_BYTES * 8
    SHA1_CHUNK_DATA_LEN   equ SHA1_CHUNK_SIZE_BITS - 64

    SHA1_K_CONST1 equ 0x5A827999
    SHA1_K_CONST2 equ 0x6ED9EBA1
    SHA1_K_CONST3 equ 0x8F1BBCDC
    SHA1_K_CONST4 equ 0xCA62C1D6

section .bss
    chunk: resb SHA1_CHUNK_SIZE_BYTES ; reserve 512 bits

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
    pop eax
    pop ebp
    ret