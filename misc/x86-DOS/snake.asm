IDEAL
MODEL small
STACK 100h
DATASEG
; --------------------------
youlost db 'YOU LOST!$'
youwon db 'YOU WON!$'
scoreMsg db 'Score: $'
snakeColor db 00100000b
lastDir dw -2
len dw 3
head dw 4000 dup(0)
; --------------------------
CODESEG

;					Start General purposes functions					;

; -====================================================================-
; sleeps for 1/2 a second on average
;		in: None
;		out: None
; -====================================================================-
proc slp
	push bx
	push cx
	xor bx, bx
	lop1s:
		xor cx, cx
		cmp bx, 0FFFFh
		jz endr
		inc bx
		lop2s:
			cmp cx, 25
			jz lop1s
			inc cx
			jmp lop2s
	endr:
	pop cx
	pop dx
	ret
endp

; -====================================================================-
;	initializes the screen with white borders
;
; -====================================================================-
proc cls
	push di
	push ax

	mov al, ' '
	xor ah, ah
	xor di, di
	clsc:
		cmp di, 4000
		jz end1
		add di, 2
		mov [es:di], ax ; '' with color 0
		jmp clsc
	end1:

	; adding borders
	mov ah, 01110000b
	
	xor di, di
	clsu:
		mov [es:di], ax
		add di, 2
		cmp di, 160
		jnz clsu

	mov di, 3840
	clsd:
		mov [es:di], ax
		add di, 2
		cmp di, 3840+160
		jnz clsd

	xor di, di
	clsl:
		mov [es:di], ax
		add di, 160
		cmp di, 3840
		jnz clsl
	
	mov di, 158
	clsr:
		mov [es:di], ax
		add di, 160
		cmp di, 3998
		jnz clsr
	
	pop ax
	pop di
	ret
endp

; -====================================================================-
;	returns a pointer to last element of the list (assumes each element is a word)
;	@params:
;		head*	- The offset to the start of the list in memory 	: by reference
;		len		- The list length									: by value
;	@output:
;		A pointer to the last element of the list					: by reference
;
; -====================================================================-
proc getLast
	push bp
	mov bp, sp

	push bx

	; tail = [head] + 2*[len]-2
	mov bx, [bp+6] ; head offset
	add bx, [bp+4] ; snake length
	add bx, [bp+4] ; snake length
	sub bx, 2; [bx] = tail

	;mov dx, bx
	mov [bp+6], bx

	pop bx
	pop bp
	ret 2
endp

; -====================================================================-
;	Call to return a random number
;	@output:
;		random even number in range 0..4000 
;
;	Time Complexity: O(1)
; -====================================================================-
proc random ; returns an even number between 1 - 4000 using the clock
	push bp
	mov bp, sp
	
	push ax
	push bx
	push cx
	push dx

	mov ah, 2Ch
	int 21h
	
	mov ax, dx
	xor dx, dx
	mov cx, 2000
	div cx ; num % x = num in range 0..x-1
	add dx, dx

	mov [bp+4], dx

	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret
endp


; -====================================================================-
;	Prints the player score at the given location
;	@params:
;		baseOffset - The place where the text will be drawn		: by value +12
;		textColor  - The color of the text						: by value +10
;		padding    - Spacing between the score & the scoreMsg	: by value +8
;		score 	   - The score of the player (int)				: by value
;		scoreMsg*  - The offset of a score message in memory 	: by reference
;
; -====================================================================-
proc scoreView
	push bp
	mov bp, sp
	push di
	push dx
	push bx
	push ax
	push cx
	mov ax, [bp+10] ; load TextColor

	mov di, [bp+12]
	mov bx, [bp+4]
	scoreTitle:
		cmp [byte ptr bx], '$'
		jz endend2
		mov al, [bx]
		mov [es:di], ax
		add di, 2
		inc bx
		jmp scoreTitle
	endend2:
	add di, [bp+8] ; padding
	mov ax, [bp+6] ; get score
	mov dx, ax
	xor ax, ax
	mov al, dl
	mov bx, [bp+10]
	whiletrue2:
		; if mynum == 0
		cmp al, 0
		jz scoreEnd

		mov cl, 10
		div cl
		; al: num, ah: remainder
		; print ah
		mov bl, ah
		add bl, '0'
		;mov bh, 01110000b
		mov [es:di], bx
		sub di, 2
		xor ah, ah
	jmp whiletrue2
	
	scoreEnd:
	
	pop cx
	pop ax
	pop bx
	pop dx
	pop di
	pop bp
	ret 10
endp


; -====================================================================-
;	Prints a message in the middle of the screen along with the score
;	@params:
;		textColor	- The color of the text to be displayed				: by value
;		titleMsg*	- A pointer to the title message to be printed		: by reference
;		msg*		- A pointer to the main message to be displayed		: by reference
;		number		- The score to be printed as part of the message	: by value
; -====================================================================-
proc MessagePopup
	push bp
	mov bp, sp
	push si
	push bx
	push ax
	push di

	mov si, (10 * 80 + 35) * 2
	mov bx, [bp+8] ; titleMsg*
	mov ax, [bp+10] ; color stays in ah
	printTitle:
		cmp [byte ptr bx], '$'
		jz mid
		mov al, [bx]
		mov [es:si], ax
		add si, 2
		inc bx
		jmp printTitle
	mid:

	push (12 * 80 + 30) * 2 ; base offset
	push [bp+10] ; push color
	push 12 ; push padding
	push [bp+4] ; push score
	push [bp+6] ; message*
	call scoreView

	pop di
	pop ax
	pop bx
	pop si
	pop bp
	ret 8
endp

;					End General purposes functions					;


;					Start Snake specific functions					;

; -====================================================================-
;	Call to spawn a new apple on map
;
;	The code will generate a random position and if valid, 
;		place an apple at said location
;
; -====================================================================-
proc spawnApple
	push dx
	push di
	push ax
	push bx

	mov al, ' '
	mov ah, 0

	lopApple:
	push ax ; junk value
	call random ; rand(0, 4000) & is even
	pop di

	cmp [es:di], ax
	jnz lopApple ; make sure apple spawns only on background

	mov ah, 01000000b
	mov [es:di], ax ; place apple on grid

	pop bx
	pop ax
	pop di
	pop dx
	ret
endp

; -====================================================================-
;	Increases the sanke's length by 1
;	@params:
;		head*	- a reference to the head ptr		: by reference
;		length	- the sankes current length			: by reference
; -====================================================================-
proc inclen
	push bp
	mov bp, sp 
	push bx
	push cx
	push dx
	push di

	mov di, [bp+4]
	push [bp+6]
	xor bx, bx
	add bx, [di]
	push bx
	call getLast
	pop bx
	
	mov cx, [bx]
	;add cx, 2 ; x+=2
	add bl, 2
	mov [word ptr bx], cx

	mov bx, [di]
	inc bx
	mov [di], bx

	pop di
	pop dx
	pop cx
	pop bx
	pop bp
	ret 4
endp

; -====================================================================-
;	returns given input direction (from keyboard)
;	returns last direction if none was given
;	@params:
;		lastDirection								: by reference
; -====================================================================-
proc input_direction
	push bp
	mov bp, sp

	push ax
	push di
	push dx
	
	mov di, [bp+4]
	mov dx, [word ptr di] ; dx = lastDirection value
	mov ah, 1
	int 16h
	je input_cont
	mov ah, 0
	int 16h

	cmp al, 'w'
	jz up
	cmp al, 'a'
	jz lft
	cmp al, 's'
	jz dwn
	cmp al, 'd'
	jz rght
	cmp al, 'q'
	jz ext
	jmp input_cont
	
	up:
	mov dx, -160
	jmp input_cont
	dwn:
	mov dx, 160
	jmp input_cont
	lft:
	mov dx, -2
	jmp input_cont
	rght:
	mov dx, 2
	jmp input_cont
	ext:
	mov ax, 4c00h
	int 21h

	input_cont:
	push dx
	push [word ptr di] ; lastDirection
	call revertDirection
	pop dx

	mov [di], dx
	mov [bp+4], dx

	pop dx
	pop di
	pop ax
	pop bp
	ret
endp

; -====================================================================-
;	Determines if the next move direction should be reverted
;	@params:
;		direction - output of input_direction			: by value
;		lastDirection - the last direction moved to		: by value
;
;	This function fixes the bug where a snake can 
;	  turn 180*, hit itself & die
; -====================================================================-
proc revertDirection
	push bp
	mov bp, sp

	push dx

	mov dx, [bp+6] 

	not dx
	inc dx
	cmp dx, [bp+4]
	jnz endRevert
	not dx
	inc dx
	
	endRevert:
	not dx
	inc dx

	mov [bp+6], dx
	pop dx
	pop bp
	ret 2
endp

; -====================================================================-
;	Call to move each part of the snake in memory 1 to the right
;	@params:
;		length			-	The snakes length				: by value
;		new_head_pos	- 	The snakes new head				: by value
;		head*			-	The pointer to the sankes head	: by reference
;
;	Time Complexity: O(1)
; -====================================================================-
proc shiftMemory
	push bp
	mov bp, sp

	push di
	push ax
	push bx
	push dx

	mov di, [bp+6] ; di = new head pos

	push [bp+4]
	xor ax, ax
	add al, [bp+8]
	push ax
	call getLast
	pop bx

	loopy:
		cmp bx, [bp+4] ; head offset
		jz shiftcont
		mov ax, [bx-2]
		mov [bx], ax
		sub bx, 2
		jmp loopy
	shiftcont:
	mov bx, [bp+4]
	mov [word ptr bx], di

	pop dx
	pop bx
	pop ax
	pop di
	pop bp
	ret 6
endp

; -====================================================================-
;	initializes the snake of length len
;	@params:
;		color	  - The snakes color							- by value
;		length 	  - The length of the snake						- by value
;		head*	  - The offset of the head of the snake		 	- by reference
;
;	Time Complexity: O(1)
; -====================================================================-
proc createSnake
	push bp
	mov bp, sp
	push bx
	push dx
	push cx
	push di
	push ax

	; creating the snake
	mov al, ' '
	mov ah, 00100000b
	mov bx, [bp+4]
	xor dx, dx
	mov dx, 2 * (12 * 80 + 40)
	xor cx, cx
	mov cx, [bp+6]
	initLoop:
		mov [bx], dx
		mov di, [bx]
		mov [es:di], ax
		add dx, 2
		add bx, 2
	loop initloop

	pop ax
	pop di
	pop cx
	pop dx
	pop bx
	pop bp
	ret 4
endp

;					End Snake specific functions					;

start:
	mov ax, @data
	mov ds, ax
	mov ax, 0B800h
	mov es, ax
; --------------------------
; Your code here
	call cls
	call spawnApple

	mov al, ' '
	mov ah, [snakecolor]
	push ax
	push [len]
	push offset head
	call createsnake
	
	mov di, [head]
	mov al, ' '
	mov ah, [snakecolor] ; snakes color
	mainLoop:
		call slp
		push offset lastdir
		call input_direction
		pop dx
		; ^^^ mov dx, input_direction
		add di, dx

		; switch head.color
		mov bx, [es:di]
		cmp bh, 01000000b ; cmp head.color, apple.color
			jz ate
		cmp bh, 01110000b ; cmp head.color, border.color
			jz collide
		cmp bh, [snakecolor] ; cmp head.color, self.color
			jz collide
		
		push offset head
		push [len]
		call getLast
		pop bx

		mov si, [bx]
		mov [es:si], 0d

		jmp tickEnd
		ate:
			call spawnApple
			push offset head
			push offset len
			call inclen

			push 4
			mov bh, 01110000b
			mov bl, ' '
			push bx
			push 6
			mov bx, [len]
			sub bx, 3
			push bx ; push score
			push offset scoreMsg
			call scoreView

			jmp tickEnd
		collide: ; either with yourself or border
			sub di, dx ; stay at the same position
			jmp endscreen
		tickEnd:

		push [len]
		push di ; passing new_head.pos
		push offset head
		call shiftMemory
		mov [es:di], ax ; draw head

	jmp mainLoop

	endscreen:
	mov bh, 01101111b
	mov bl, ' ' 
	push bx ; push color
	push offset youlost
	push offset scoremsg
	mov bx, [len]
	sub bx, 3
	push bx
	call MessagePopup
; --------------------------
	
exit:
	mov ax, 4c00h
	int 21h
END start