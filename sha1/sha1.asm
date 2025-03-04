%ifndef SHA1_INCLUDE
%define SHA1_INCLUDE
%include '../common/general.asm'
%include '../common/debug.asm'
section .data
    SHA1_CHUNK_SIZE_BYTES equ 64
    SHA1_CHUNK_SIZE_BITS  equ SHA1_CHUNK_SIZE_BYTES * 8
    SHA1_CHUNK_DATA_LEN   equ SHA1_CHUNK_SIZE_BITS - 64
    SHA1_W_BUFF_BYTES     equ 80 * 4

    SHA1_OUTPUT_SIZE_BITS equ 160
    SHA1_OUTPUT_SIZE_BYTES equ SHA1_OUTPUT_SIZE_BITS / 8

    SHA1_K_CONST1 equ 0x5A827999
    SHA1_K_CONST2 equ 0x6ED9EBA1
    SHA1_K_CONST3 equ 0x8F1BBCDC
    SHA1_K_CONST4 equ 0xCA62C1D6

    SHA1_H0_DEFAULT equ 0x67452301
    SHA1_H1_DEFAULT equ 0xEFCDAB89
    SHA1_H2_DEFAULT equ 0x98BADCFE
    SHA1_H3_DEFAULT equ 0x10325476
    SHA1_H4_DEFAULT equ 0xC3D2E1F0
    
    sha1H0 dd SHA1_H0_DEFAULT
    sha1H1 dd SHA1_H1_DEFAULT
    sha1H2 dd SHA1_H2_DEFAULT
    sha1H3 dd SHA1_H3_DEFAULT
    sha1H4 dd SHA1_H4_DEFAULT

section .bss
    chunk: resb SHA1_CHUNK_SIZE_BYTES ; reserve 512 bits
    wBuff: resb SHA1_W_BUFF_BYTES

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

    pop edx
    pop ebx
    pop eax
    pop ebp
    ret 8

; adds the given length in bytes to the end of the chunk
addLen:
    push ebp
    mov ebp, esp
    push edx
    push ebx
    push eax

    ; adding the length of the message into the chunk. see SHA-1 RFC section 4.c
    xor edx, edx
    mov ebx, [ebp+8]
    mov eax, 8
    mul ebx
    
    bswap edx
    bswap eax
    mov dword [chunk + SHA1_CHUNK_DATA_LEN / 8], edx
    mov dword [chunk + 4 + SHA1_CHUNK_DATA_LEN / 8], eax

    pop eax
    pop ebx
    pop edx
    pop ebp
    ret 4

; f(t;B,C,D)
; psh t, b, c, d; call f
functionFInvalid: db "Invalid value passed for t in f(t;B,C,D): 0x", 0
functionF:
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
    jl .outBounds
    cmp eax, 20
    jl .case1
    cmp eax, 40
    jl .case2
    cmp eax, 60
    jl .case3
    cmp eax, 80
    jl .case2 ; case 4 & 2 are the same
    jmp .outBounds

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
.outBounds:
    push dword functionFInvalid
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


functionKInvalid: db "Invalid value passed for k in constants map: 0x", 0
constantsK:
    push ebp
    mov ebp, esp
    push eax
    push edi

    mov eax, [ebp+8] ; k
    cmp eax, 0
    jl .outBounds
    cmp eax, 20
    jl .case1
    cmp eax, 40
    jl .case2
    cmp eax, 60
    jl .case3
    cmp eax, 80
    jl .case4
    jmp .outBounds

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
.outBounds:
    push dword functionKInvalid
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
    push esi
    push ecx
    push ebx
    push eax

    push dword wBuff
    push dword 0x0
    push dword SHA1_W_BUFF_BYTES
    call memset

    push dword wBuff
    push dword chunk
    push SHA1_CHUNK_SIZE_BYTES
    call memcpy
    add esp, 4

    mov ecx, 16 
.extendBuff: ; Extending 16bit buff to 80 bits. see SHA-1 RFC section 6.1-b

    mov ebx, ecx
    sub ebx, 3
    shl ebx, 2
    add ebx, wBuff
    mov ebx, [ebx]
    bswap ebx
    mov esi, ebx ; W(t-3)

    mov ebx, ecx
    sub ebx, 8
    shl ebx, 2
    add ebx, wBuff
    mov ebx, [ebx]
    bswap ebx
    xor esi, ebx ; W(t-8)

    mov ebx, ecx
    sub ebx, 14
    shl ebx, 2
    add ebx, wBuff
    mov ebx, [ebx]
    bswap ebx
    xor esi, ebx ; W(t-14)

    mov ebx, ecx
    sub ebx, 16
    shl ebx, 2
    add ebx, wBuff
    mov ebx, [ebx]
    bswap ebx
    xor esi, ebx ; W(t-16)
    rol esi, 1 ; S^1
    bswap esi

    mov ebx, ecx
    shl ebx, 2
    add ebx, wBuff
    mov [ebx], esi

    inc ecx
    cmp ecx, 80
    jl .extendBuff
    sub esp, 4*6 ; reserving space for 6 dwords
    mov edi, esp
    ; edi+0  - A
    ; edi+4  - B
    ; edi+8  - C
    ; edi+12 - D
    ; edi+16 - E
    ; edi+20 - TEMP

    mov esi, [sha1H0]
    mov dword [edi+0 ], esi
    mov esi, [sha1H1]
    mov dword [edi+4 ], esi
    mov esi, [sha1H2]
    mov dword [edi+8 ], esi
    mov esi, [sha1H3]
    mov dword [edi+12], esi
    mov esi, [sha1H4]
    mov dword [edi+16], esi

    xor ecx, ecx
.sectionD:

    mov esi, [edi+0]
    rol esi, 5 ; S^5(A)

    push ecx             ; t
    push dword [edi+4 ]  ; B
    push dword [edi+8 ]  ; C
    push dword [edi+12]  ; D
    call functionF
    pop ebx

    add esi, ebx
    add esi, dword [edi+16] ; E

    mov ebx, ecx
    shl ebx, 2
    add ebx, wBuff
    mov ebx, [ebx]
    bswap ebx
    add esi, ebx ; W(t)

    push ecx
    call constantsK
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

    mov ebx, [edi+20]
    mov [edi+0], ebx ; A = TEMP;

    inc ecx
    cmp ecx, 80
    jl .sectionD

    mov eax, [ebp+8] ; output buffer

    mov ebx, [sha1H0]
    add ebx, [edi+0]
    mov [sha1H0], ebx
    bswap ebx
    mov [eax], ebx

    mov ebx, [sha1H1]
    add ebx, [edi+4]
    mov [sha1H1], ebx
    bswap ebx
    mov [eax+4], ebx

    mov ebx, [sha1H2]
    add ebx, [edi+8]
    mov [sha1H2], ebx
    bswap ebx
    mov [eax+8], ebx

    mov ebx, [sha1H3]
    add ebx, [edi+12]
    mov [sha1H3], ebx
    bswap ebx
    mov [eax+12], ebx

    mov ebx, [sha1H4]
    add ebx, [edi+16]
    mov [sha1H4], ebx
    bswap ebx
    mov [eax+16], ebx

    add esp, 4*6 ; deallocating variables

    pop eax
    pop ebx
    pop ecx
    pop esi
    pop ebp
    ret 4

sha1ResetH:
    mov dword [sha1H0], SHA1_H0_DEFAULT
    mov dword [sha1H1], SHA1_H1_DEFAULT
    mov dword [sha1H2], SHA1_H2_DEFAULT
    mov dword [sha1H3], SHA1_H3_DEFAULT
    mov dword [sha1H4], SHA1_H4_DEFAULT
    ret

sha1InvalidLength: db "Invalid msg length given: ", 0
sha1:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push edi
    push esi
    
    call sha1ResetH
    mov esi, [ebp+8]
.cmpStart:
    cmp dword esi, 0
    jb .outBounds
    cmp dword [ebp+8], 56
    jb .short
    cmp dword [ebp+8], SHA1_CHUNK_SIZE_BYTES
    jb .medium
    jmp .long

.short:
    push dword [ebp+12]
    push dword [ebp+8]
    call makeChunk
    push dword esi ;[ebp+8]
    call addLen
    push dword [ebp+16]
    call digest
    jmp .end
.medium:
    push dword [ebp+12]
    push dword [ebp+8]
    call makeChunk
    push dword [ebp+16]
    call digest

    push dword chunk
    push dword 0x0
    push dword SHA1_CHUNK_SIZE_BYTES
    call memset
    push dword esi ;[ebp+8]
    call addLen

    push dword [ebp+16]
    call digest
    jmp .end
.long:
    ; copying message into buffer
    mov eax, SHA1_CHUNK_SIZE_BYTES
    mov ebx, [ebp+12]; message*
    push dword chunk
    push ebx
    push eax
    call memcpy
    add esp, 4
    push dword [ebp+16]
    call digest
    sub dword [ebp+8], SHA1_CHUNK_SIZE_BYTES
    add dword [ebp+12], SHA1_CHUNK_SIZE_BYTES
    jmp .cmpStart
.outBounds:
    push dword sha1InvalidLength
    call printMessage
    mov eax, esi
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
    pop edi
    pop ebx
    pop eax
    pop ebp
    ret 12
%endif