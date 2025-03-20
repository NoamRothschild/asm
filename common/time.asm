%ifndef TIME_INCLUDE
%define TIME_INCLUDE
%include '../common/debug.asm'
section .data
    SECONDS_IN_DAY equ 86400
    DAYS_IN_4_YEARS equ 3*365+366
    DAYS_IN_100_YEARS equ 76*365 + 24*366
    DAYS_IN_400_YEARS equ 303*365 + 97*366

    daysInMonths db 31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

section .text

unixNow:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push edx

    mov eax, 13
    xor ebx, ebx
    int 80h
    mov ebx, eax

    mov eax, [ebp+8]
    mov ecx, 60*60
    mul ecx
    add ebx, eax

    mov [ebp+8], ebx

    pop edx
    pop ebx
    pop eax
    pop ebp
    ret

timeYrMoDy:
    push dword [esp]
    push dword [esp]
    push ebp
    mov ebp, esp
    push eax
    push ecx
    push edx
    push edi
    ; edi - days
    ; return:
    ;   ebp+8: year
    ;   ebp+12: month
    ;   ebp+16: day

    mov dword [ebp+8], 1970

    xor edx, edx
    mov eax, [ebp+16] ; unix
    mov ecx, SECONDS_IN_DAY
    div ecx
    mov edi, eax ; store days var

    xor edx, edx
    mov ecx, DAYS_IN_400_YEARS
    div ecx
    xor edx, edx
    mov ecx, 400
    mul ecx
    add dword [ebp+8], eax
    mov ecx, DAYS_IN_400_YEARS
    xor edx, edx
    mov eax, edi
    div ecx
    mov edi, edx

    xor edx, edx
    mov eax, edi
    mov ecx, DAYS_IN_100_YEARS
    div ecx
    xor ecx, ecx
    cmp eax, 4 ; Edge case: exactly at a 400-year mark
    sete cl
    sub eax, ecx
    xor edx, edx
    mov ecx, 100
    mul ecx
    add dword [ebp+8], eax
    mov ecx, DAYS_IN_100_YEARS
    xor edx, edx
    mov eax, edi
    div ecx
    mov edi, edx
    
    xor edx, edx
    mov eax, edi
    mov ecx, DAYS_IN_4_YEARS
    div ecx
    shl eax, 2
    add dword [ebp+8], eax
    mov ecx, DAYS_IN_4_YEARS
    xor edx, edx
    mov eax, edi
    div ecx
    mov edi, edx

    xor ecx, ecx
    inc ecx
    shl ecx, 2 ; mov ecx, 4
.remainingYears:
    push ecx

    xor edx, edx
    mov eax, dword [ebp+8]
    mov ecx, 4
    div ecx ; DX: Carry
    xor ecx, ecx
    test edx, edx
    sete cl
    add ecx, 365
    cmp ecx, edi
    ja .endRemainingYears

    sub edi, ecx
    inc dword [ebp+8]

    pop ecx
    loop .remainingYears
    push ecx
.endRemainingYears:
    pop ecx

    ; account for extra day in month for leap year
    xor edx, edx
    mov eax, dword [ebp+8]
    mov ecx, 4
    div ecx
    test eax, eax
    xor ecx, ecx
    sete cl
    push ecx ; save in stack temporary
    xor edx, edx
    mov eax, dword [ebp+8]
    mov ecx, 100
    div ecx
    test eax, eax
    xor ecx, ecx
    setne cl
    and ecx, dword [esp] ; (year % 4 == 0 and year % 100 != 0)
    mov dword [esp], ecx ; save in stack new value
    xor edx, edx
    mov eax, dword [ebp+8]
    mov ecx, 400
    div ecx
    test eax, eax
    xor ecx, ecx
    sete cl
    or ecx, dword [esp]
    add esp, 4 ; deallocate from stack
    add ecx, 28 ; 29 if isLeap else 28
    mov byte [daysInMonths+1], cl

    mov dword [ebp+12], 1
    xor ecx, ecx
.computeMonthDay:
    push ecx

    add ecx, daysInMonths
    xor eax, eax
    mov al, byte [ecx] ; days in month

    cmp eax, edi
    ja .endComputeMonthDay
    sub edi, eax
    inc dword [ebp+12]

    pop ecx
    inc ecx
    cmp ecx, 12
    jnz .computeMonthDay
    push ecx
.endComputeMonthDay:
    pop ecx
    inc edi

    mov [ebp+16], edi
    pop edi
    pop edx
    pop ecx
    pop eax
    pop ebp
    ret

timeHrMinSec:
    push dword [esp]
    push dword [esp]
    push ebp
    mov ebp, esp
    push eax
    push ecx
    push edx
    push edi

    xor edx, edx
    mov eax, [ebp+16] ; timestamp
    mov ecx, SECONDS_IN_DAY
    div ecx
    mov edi, edx

    xor edx, edx
    mov eax, edi
    mov ecx, 3600
    div ecx
    mov dword [ebp+8], eax ; hour
    
    mov eax, edx
    xor edx, edx
    mov ecx, 60
    div ecx
    mov dword [ebp+12], eax ; minute

    xor edx, edx
    mov eax, edi
    mov ecx, 60
    div ecx
    mov dword [ebp+16], edx ; second

    pop edi
    pop edx
    pop ecx
    pop eax
    pop ebp
    ret

timeFormatPrint:
    push ebp
    mov ebp, esp

    push dword [ebp+8] ; unix timestamp
    call timeYrMoDy
    push dword [esp+8]
    call printInt
    push '/'
    call printChar
    push dword [esp+4]
    call printInt
    push '/'
    call printChar
    push dword [esp]
    call printInt
    add esp, 12

    push ' '
    call printChar
    push dword [ebp+8] ; unix timestamp
    call timeHrMinSec
    push dword [esp]
    call printInt
    push ':'
    call printChar
    push dword [esp+4]
    call printInt
    push ':'
    call printChar
    push dword [esp+8]
    call printInt
    add esp, 12

    pop ebp
    ret 4
%endif