%ifndef CUBES_INCLUDE
%define CUBES_INCLUDE

%include '../common/general.asm'
%include '../common/fileManager.asm'

section .data

    SCREEN_WIDTH equ 320
    SCREEN_HEIGHT equ 200

    playerX dd SCREEN_WIDTH / 2
    playerY dd SCREEN_HEIGHT / 2

    playersRegionPtr dd 0
    playerOffset dd 0

    PLAYER_DATA_OFFSET_START equ 2
    PLAYER_UID_OFFSET equ 0
    PLAYER_UID_SIZE equ 1
    PLAYER_X_OFFSET equ PLAYER_UID_OFFSET + PLAYER_UID_SIZE
    PLAYER_X_SIZE equ 4
    PLAYER_Y_OFFSET equ PLAYER_X_OFFSET + PLAYER_X_SIZE
    PLAYER_Y_SIZE equ 4

    PLAYER_STRUCT_SIZE equ PLAYER_Y_OFFSET + PLAYER_Y_SIZE

    PLAYER_COUNT equ 30
    ; include a bit for flags & last modifier UID
    PLAYERS_BUFFER_SIZE equ 2 + PLAYER_COUNT * PLAYER_STRUCT_SIZE
section .bss

    framebuffer:    resb SCREEN_WIDTH*SCREEN_HEIGHT
    playerStruct:   resb PLAYER_STRUCT_SIZE

section .text

str_registering_in_progress: db "Registering player...", 10, 0
str_registering_done: db "Registered player!", 10, 0
registerPlayer:
    push eax
    push ebx
    push ecx

    push str_registering_in_progress
    call printMessage

    mov ebx, [playersRegionPtr]
.waitUnlocked:
    mov al, byte [ebx]
    and al, 0b00000001
    cmp al, 1
    jz .waitUnlocked
    mov al, byte [ebx]
    or al, 0b00000001 ; set locked mode
    add ebx, PLAYER_DATA_OFFSET_START ; jump to start of data
    sub ebx, PLAYER_STRUCT_SIZE ; cancel the first element increment
    xor ecx, ecx
.findAvailable:
    inc cl
    add ebx, PLAYER_STRUCT_SIZE
    cmp byte [ebx + PLAYER_UID_OFFSET], 0
    jz .foundAvailable
    cmp byte [ebx + PLAYER_UID_OFFSET], -1 ; next until a NULL UID or de-registered player was found.
    jz .foundAvailable
    jmp .findAvailable
.foundAvailable:
    mov byte [ebx + PLAYER_UID_OFFSET], cl ; get a UID for player.
    mov dword [ebx + PLAYER_X_OFFSET], SCREEN_WIDTH / 2
    mov dword [ebx + PLAYER_Y_OFFSET], SCREEN_HEIGHT / 2

    mov dword [playerOffset], ebx

    mov ebx, [playersRegionPtr]
    mov al, byte [ebx]
    and al, 0b11111110 ; unset locked mode

    push str_registering_done
    call printMessage

    pop ecx
    pop ebx
    pop eax
    ret

strRemovePlayer: db "Removed player from list", 10, 0
removePlayer:
    push ebx
    mov ebx, [playerOffset]
    mov byte [ebx + PLAYER_UID_OFFSET], -1 ; free the slot for another player.

    push ANSI_RED
    push strRemovePlayer
    call printMessage
    pop ebx
    ret

calc_frame:
    push eax
    push ebx
    push ecx
    push edx

    push framebuffer
    push dword 0
    push dword SCREEN_WIDTH*SCREEN_HEIGHT
    call memset

    mov ebx, [playersRegionPtr]
    add ebx, PLAYER_DATA_OFFSET_START ; go to start of players data
.addPlayers:
    ; y * 320 + x
    xor edx, edx
    mov eax, SCREEN_WIDTH
    mov ecx, [ebx + PLAYER_Y_OFFSET]
    mul ecx
    add eax, [ebx + PLAYER_X_OFFSET]
    mov dl, [ebx + PLAYER_UID_OFFSET]

    mov byte [framebuffer + eax], dl ; drawing a pixel on the screen to represent a player.
    add ebx, PLAYER_STRUCT_SIZE
    cmp byte [ebx + PLAYER_UID_OFFSET], 0 ; next until a NULL UID is found.
    jnz .addPlayers

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret


move_camera:
    push ebp
    mov ebp, esp
    push eax
    push ebx

    mov ebx, [playerOffset]

    mov eax, [ebp+8]
    cmp al, "W"
    jz .forward
    cmp al, "S"
    jz .backwards
    cmp al, "A"
    jz .left
    cmp al, "D"
    jz .right
    jmp .end

.left:
    sub [ebx + PLAYER_X_OFFSET], dword 5
    jmp .setLastUpdater
.right:
    add [ebx + PLAYER_X_OFFSET], dword 5
    jmp .setLastUpdater
.forward:
    sub [ebx + PLAYER_Y_OFFSET], dword 5
    jmp .setLastUpdater
.backwards:
    add [ebx + PLAYER_Y_OFFSET], dword 5
    jmp .setLastUpdater
.setLastUpdater:
    mov al, [ebx + PLAYER_UID_OFFSET]
    mov bl, al
    mov eax, [playersRegionPtr]
    mov byte [eax + 1], bl ; update last changer's UID
.end:
    pop ebx
    pop eax
    pop ebp
    ret 4

%endif