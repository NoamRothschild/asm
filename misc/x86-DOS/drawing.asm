IDEAL
MODEL small
STACK 100h
DATASEG
; --------------------------
; Your variables here
chr db 32d
color db 30h
achrX dw 40d
achrY dw 12d
dltX dw 
dltY dw 
x0 dw 
y0 dw 
x1 dw 
y1 dw 
tmpX dw 
isNeg db 
tringMode db 
tmpBX dw
tmpCX dw
; --------------------------
CODESEG

; Screen range (x, y) =>  0 <= x < 80,  0 <= y < 25

proc cls
  mov bx, 0 ; x counter
  mov si, 0 ; y counter
  mov dx, 0
  lopY: ; for y in range(25)
  	mov bx, 0
  	cmp si, 25d
  	jz end1
  	lopX: ; for x in range(80)
  		cmp bx, 80d
  		jz end2
  		; code here
  		; mov di, (si * 80 + bx) * 2 => 2*(80*si) + 2*bx
  		mov ax, 160d ; for multiplication
  		mul si ; result goes into DX:AX
  		add ax, bx
  		add ax, bx
  		mov di, ax
  		mov [es:di], 0020h ; '' with color 0

  		inc bx
  		jmp lopX
  	end2:
  	inc si
  	jmp lopY
  end1:
  ret
endp

proc circle ; args: cx, cy, r(dx)
  ; x: bx
  ; y: cx
  ; p: si
  ; y*-1: dx
  xor bx, bx ; x = 0
  mov cx, dx ; y = r = 3
  not cx
  inc cx ; two's compliment to turn 3 into -3
  		; y = -3
  mov si, cx ; p = y = -r = -3

  whl: ; while x < -y
  	xor dx, dx
  	mov dx, cx
  	not dx
  	inc dx ; dx = -y
  	cmp bx, dx ; x & -y ; FIXME: POSSIBILITY OF A BUG DUE TO UNSINGED CHECK
  	jl cont
  	jmp endw
  	cont:
  	; condition met, now start of loop
  	cmp si, 0
  	jg pass
  	jmp fail
  	pass:
  		inc cx ; y++
  		add si, bx
  		add si, bx ; p+=2x
  		add si, cx
  		add si, cx ; p+=2y
  		inc si ; p++
  		jmp cont2
  	fail:
  		add si, bx
  		add si, bx ; p+=2x
  		inc si ; p++
  	
  	cont2:
  	; Putting pixels...
  	
  	; oct 1:
  	call drawl ; (x,y)
  	not bx
  	inc bx ; x = -x
  	; oct 2:
  	call drawl ; (-x, y)
  	not cx
  	inc cx ; y = -y
  	; oct 3:
  	call drawl ; (-x,-y)
  	not bx
  	inc bx ; -x = x
  	; oct 4:
  	call drawl ; (x, -y)
  	not cx
  	inc cx ; -y = y

  	xor bx, cx
  	xor cx, bx
  	xor bx, cx ; switch values between bx & cx

  	; oct 5:
  	call drawl ; (x,y)
  	not bx
  	inc bx ; x = -x
  	; oct 6:
  	call drawl ; (-x, y)
  	not cx
  	inc cx ; y = -y
  	; oct 7:
  	call drawl ; (-x,-y)
  	not bx
  	inc bx ; -x = x
  	; oct 8:
  	call drawl ; (x, -y)
  	not cx
  	inc cx ; -y = y

  	xor bx, cx
  	xor cx, bx
  	xor bx, cx ; switch back values between bx & cx

  	inc bx
  	jmp whl
  endw:
  ret
endp

proc draw ; overwrites ax, dx & di!!!
  add bx, [achrX] ;40
  add cx, [achrY] ;12
  ;(x, y)  => (y * 80 + x) * 2 
  ; bx: x
  ; cx: y
  mov ax, cx ; load y into ax
  mov dx, 160
  mul dx

  add ax, bx
  add ax, bx

  mov di, ax
  mov al, [chr] ;''
  mov ah, [color] ;30h
  mov [es:di], ax
  sub bx, [achrX] ;40
  sub cx, [achrY] ;12
  ret
endp

proc drawl ; draw line from (-x, y) to (x, y)
  ;(x, y)  => (y * 80 + x) * 2 
  ; bx: x
  ; cx: y
  ; for value between -x & x:
  cmp bx, 0
  jl swt
  jmp drcnt
  swt:
  not bx
  inc bx
  mov [isNeg], 1
  drcnt:

  mov [tmpX], bx ; [tmpX]->x
  not bx
  inc bx ; x = -x

  drwl: ;draw line loop
  cmp bx, [tmpX]
  jz drawle
  call draw
  inc bx
  jmp drwl

  drawle:
  cmp [isNeg], 1
  jnz drwle
  not bx
  inc bx

  drwle:
  mov [isNeg], 0
  ret
endp

proc line
  ; x: bx
  ; y: cx
  ; D: si
  ; [11,12] -> deltaX
  ; [13,14] -> deltaY
  ; [15,16] -> x0
  ; [17,18] -> y0
  ; [19,20] -> x1
  ; [21,22] -> y1
  mov dx, [x1]
  sub dx, [x0] ; deltaX

  mov ax, [y1]
  sub ax, [y0]; deltaY 

  mov [dltX], dx
  mov [dltY], ax ; store delta values in memory

  mov si, ax
  add si, ax
  sub si, dx ; D = deltaY*2 - deltaX

  mov cx, [y0] ; y = y0
  mov bx, [x0] ; x = x0 to x = x1
  lifr: ; line for
  	cmp bx, [x1]
  	jg lien ; if x > x1 end

  	; place pixel at (x,y)
  	cmp [tringMode], 1 ; check if trigangle mode is set.
  	jz trg
  	call draw
  	jmp cnt
  	trg:
  	call drawl
  	cnt:
  	cmp si, 0
  	jg larg
  	jmp lincon
  	larg:
  		inc cx
  		sub si, [dltX]
  		sub si, [dltX]
  	lincon:
  	add si, [dltY]
  	add si, [dltY] ; D += 2dy
  	inc bx
  	jmp lifr
  lien: ; line end
  ret
endp

proc triangle ; isosceles triangle
  mov [tringMode], 1
  call line
  mov [tringMode], 0
  ret
endp

proc pcircle ; perfect circle
  mov si, offset achrX

  mov bl, [si]
  add bl, 3
  mov [si], bl
  mov dx, 10
  call circle
  
  mov si, offset achrX
  mov bl, [si]
  sub bl, 6
  mov [si], bl
  mov dx, 10
  call circle

  mov si, offset achrX
  mov bl, [si]
  add bl, 3
  mov [si], bl
  ret
endp

proc slp
  mov [tmpbx], bx
  mov [tmpcx], cx
  xor bx, bx
  lop1s:
  	xor cx, cx
  	cmp bx, 0FFFFh
  	jz endr
  	inc bx
  	lop2s:
  		cmp cx, 500
  		jz lop1s
  		inc cx
  		jmp lop2s
  endr:
  mov bx, [tmpbx]
  mov cx, [tmpcx]
  ret
endp

start:
  mov ax, @data
  mov ds, ax
  mov ax, 0B800h
  mov es, ax
; --------------------------
; Your code here
  xor ax, ax
  xor bx, bx
  xor cx, cx
  xor dx, dx
  xor si, si
  xor di, di

  ; NOTE: When adding to 16 bit integer a value from memory, 
  ;	The register will take the selected value & the value from the next location 

  call cls

  call pcircle

  mov [color], 25h
  mov [x0], 0
  mov [y0], 0
  mov [x1], 23
  mov [y1], 10
  call triangle


; --------------------------
  
exit:
  mov ax, 4c00h
  int 21h
END start