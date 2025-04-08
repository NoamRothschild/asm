; to play uncomment the bellow line:
; %define VOXEL_SPACE_PLAY
%ifndef VOXEL_SPACE_INCLUDE
%define VOXEL_SPACE_INCLUDE

%include '../common/general.asm'
%include '../common/fileManager.asm'

section .data

  SCREEN_WIDTH equ 320
  SCREEN_HEIGHT equ 200
  MAP_SCALE equ 1024
  VOXEL_SCALE equ 100

  file_heightmap db '../game_prototypes/heightmap_1024.bin', 0
  file_colormap  db '../game_prototypes/colormap_1024.bin', 0
  file_output    db '../game_prototypes/frame.bin', 0

  camera_x dd 512
  camera_y dd 512 - 425
  camera_zfar dd 400
  camera_height dd 100

  rx dd 0
  ry dd 0

  plx dd -400
  ply dd 400
  prx dd 400
  pry dd 400
  fdelta_y dd 0
  fdelta_x dd 0
  imax_height dd 200 ; SCREEN_HEIGHT
  imap_offset dd 0
  iheightonscreen dd 0

section .bss

  heightmap:      resb 1024*1024
  colormap:       resb 1024*1024

  framebuffer:    resb 320*200

section .text

;global _start

calc_frame:
  push ebp
  push eax
  push ebx
  push ecx
  push edx
  push esi
  push edi

  call clean_buffer

  ;mov ecx, SCREEN_WIDTH
  xor ecx, ecx
 .rays:
  push ecx

 ; ---------- Calculating deltas ---------- 
  push ecx
  call delta_by_ray
 ; ----- Defaulting rx, ry imax_height -----
  call ray_init_vars
 ; -------- loop for each z in ray -------- 
  xor edi, edi
  inc edi
  .zloop:
      movss xmm0, [fdelta_x]
      movss xmm1, [rx]
      addss xmm1, xmm0
      movss [rx], xmm1

      movss xmm0, [fdelta_y]
      movss xmm1, [ry]
      subss xmm1, xmm0
      movss [ry], xmm1

      call map_create_offset

      push edi
      call get_heightonscreen

      ; Only render the terrain pixels if the new projected height is taller than the previous max height
      mov eax, [iheightonscreen]
      cmp eax, [imax_height]
      jae .zloop_end
      push ecx
      call send_to_framebuffer

      .zloop_end:
      inc edi
      cmp edi, [camera_zfar]
  jnz .zloop

  pop ecx
  inc ecx
  cmp ecx, SCREEN_WIDTH
  jnz .rays
 ;loop .rays
  pop edi
  pop esi
  pop edx
  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret

; push ray_num, call send_to_framebuffer
send_to_framebuffer:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push edx
  push esi

  mov esi, [iheightonscreen]
  .yloop:
      mov eax, esi
      mov ebx, SCREEN_WIDTH
      xor edx, edx
      mul ebx
      add eax, [ebp+8] ; + ray num

      push colormap
      push dword [imap_offset]
      call value_at
      pop edx ; colormap[map_offset]

      mov ebx, framebuffer
      mov [ebx+eax], edx
      ;framebuffer[(x,y)] = colormap[map_offset]

      inc esi
      cmp esi, [imax_height]
  jnz .yloop

  ; updating max height to be newly found one
  mov esi, [iheightonscreen]
  mov [imax_height], esi

  pop esi
  pop edx
  pop ebx
  pop eax
  pop ebp
  ret 4

; return the byte at [x] given an array & x
value_at:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push esi

  mov esi, [ebp+12] ; arr
  mov ebx, [ebp+8]  ; index
  xor eax, eax
  mov al, byte [ebx+esi]

  mov [ebp+12], eax

  pop esi
  pop ebx
  pop eax
  pop ebp
  ret 4

; push z, call get_heightonscreen
get_heightonscreen:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push edx
  push esi
  xor edx, edx

  ;mov ebx, heightmap
  ;mov esi, [imap_offset]
  ;xor eax, eax
  ;mov al, byte [ebx+esi]
  push heightmap
  push dword [imap_offset]
  call value_at
  pop eax
  ; heightmap[map_offset]

  neg eax
  add eax, [camera_height]
  mov ebx, VOXEL_SCALE
  mul ebx
  mov ebx, [ebp+8]
  cdq ; sign extends eax to edx (modifies edx based on eax's MSB)
  idiv ebx

  ; making limits to not go out of bounds
  cmp eax, 0
  jl .fix_bellow
  cmp eax, SCREEN_HEIGHT
  ja .fix_above

  .end:
  mov [iheightonscreen], eax
  pop esi
  pop edx
  pop ebx
  pop eax
  pop ebp
  ret 4

  .fix_bellow:
  xor eax, eax
  jmp .end
  .fix_above:
  mov eax, SCREEN_HEIGHT
  dec eax
  jmp .end

map_create_offset:
  push eax
  push ebx
  push edx

  movss xmm0, [ry]
  cvtss2si ebx, xmm0
  mov edx, MAP_SCALE
  dec edx
  and ebx, edx ; keep ry inside map
  xor edx, edx
  mov eax, MAP_SCALE
  mul ebx ; MAP_SCALE * (int(ry) & (MAP_SCALE-1)

  ; BUG: When rx is 511 after the movss the value is treated as 513!
  movss xmm0, [rx]
  cvtss2si ebx, xmm0
  mov edx, MAP_SCALE
  dec edx
  and ebx, edx ; keep rx inside map

  add eax, ebx
  mov [imap_offset], eax

  pop edx
  pop ebx
  pop eax
  ret

ray_init_vars:
  push ebx
  mov ebx, [camera_x]
  cvtsi2ss xmm0, ebx
  movss [rx], xmm0

  mov ebx, [camera_y]
  cvtsi2ss xmm0, ebx
  movss [ry], xmm0

  mov [imax_height], dword SCREEN_HEIGHT
  pop ebx
  ret

delta_by_ray:
  push ebp
  mov ebp, esp
  push eax
  push ebx
  push ecx

  mov ecx, [ebp+8]

  ; delta_x:
  ; (plx / camera_zfar) + (ecx * (prx - plx) / (SCREEN_WIDTH * camera_zfar))

  ; ecx * (prx - plx)
  mov eax, [prx]
  sub eax, [plx]
  xor edx, edx
  mul ecx
  cvtsi2ss xmm0, eax

  ; (SCREEN_WIDTH * camera_zfar)
  mov eax, SCREEN_WIDTH
  mov ebx, [camera_zfar]
  mul ebx
  cvtsi2ss xmm1, eax
  divss xmm0, xmm1

  ; (plx / camera_zfar)
  mov eax, [plx]
  cvtsi2ss xmm2, eax
  mov ebx, [camera_zfar]
  cvtsi2ss xmm3, ebx
  divss xmm2, xmm3
  addss xmm0, xmm2
  movss [fdelta_x], xmm0
  ; delta_y:
  ; (ply / camera_zfar) + (ecx * (pry - ply) / (SCREEN_WIDTH * camera_zfar))

  ; ecx * (pry - plx)
  mov eax, [pry]
  sub eax, [ply]
  xor edx, edx
  mul ecx
  cvtsi2ss xmm0, eax

  ; (SCREEN_WIDTH * camera_zfar)
  mov eax, SCREEN_WIDTH
  mov ebx, [camera_zfar]
  mul ebx
  cvtsi2ss xmm1, eax

  divss xmm0, xmm1

  ; (ply / camera_zfar)
  mov eax, [ply]
  cvtsi2ss xmm2, eax
  mov ebx, [camera_zfar]
  cvtsi2ss xmm3, ebx
  divss xmm2, xmm3

  addss xmm0, xmm2
  movss [fdelta_y], xmm0

  pop ecx
  pop ebx
  pop eax
  pop ebp
  ret 4

init_files:
  push edx

  push file_heightmap
  call openFile
  pop edx
  push edx
  push heightmap
  push dword 1024*1024
  call readFile
  push edx
  call closeFile

  push file_colormap
  call openFile
  pop edx
  push edx
  push colormap
  push dword 1024*1024
  call readFile
  push edx
  call closeFile

  pop edx
  ret

move_camera:
  push ebp
  mov ebp, esp
  push eax

  mov eax, [ebp+8]
  cmp al, "W"
  jz .forward
  cmp al, "S"
  jz .backwards
  cmp al, "A"
  jz .left
  cmp al, "D"
  jz .right
  cmp al, "Z"
  jz .up
  cmp al, "X"
  jz .down
  jmp .end

 .left:
  sub [camera_x], dword 5
  jmp .end
 .right:
  add [camera_x], dword 5
  jmp .end
 .forward:
  sub [camera_y], dword 5
  jmp .end
 .backwards:
  add [camera_y], dword 5
  jmp .end
 .up:
  add [camera_height], dword 5
  jmp .end
 .down:
  sub [camera_height], dword 5
  jmp .end
 .end:
  pop eax
  pop ebp
  ret 4

clean_buffer:
  push ebx
  xor ebx, ebx
  .eachPixel:
      mov [ebx+framebuffer], dword 0
      add ebx, 4
      cmp ebx, 320*200 + 4
  jnz .eachPixel
  pop ebx
  ret

%ifdef VOXEL_SPACE_PLAY

_start:
  ; loading heightmap & colormap into memory
  call init_files

  ; calculating next frame
  call calc_frame

  mov eax, file_output
  push eax
  call newFile
  pop ebx ; ebx          file descriptor
  mov ecx, framebuffer ; pointer to the start of data
  mov edx, 1024*1024   ; num of bytes to write
  mov eax, 4 ; SYS_WRITE
  int 80h

  call exit

%endif
%endif