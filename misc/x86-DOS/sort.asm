IDEAL
MODEL small
STACK 100h
DATASEG
; --------------------------
len db 10									; the length of the list
list db 9, 3, 1, 2, 6, 8, 4, 2, 4, 5 		; the list
; --------------------------
CODESEG

; -====================================================================-
;	Call on an array to return its smallest value ptr
;	@params:
;		length - The length of the array 			 	: by value
;		start* - A pointer to the start of the array	: by reference
;
;	The code will itterate through all memory locations
;	  in range start*..start*+length
;
;	Time Complexity: O(n)
; -====================================================================-
proc min
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	xor dx, dx
	
	mov cx, [bp+6] ; cx -> length
	mov bx, [bp+4] ; bx -> start ptr
	add cx, bx 
	dec cx ; last element ptr
	mov dl, [byte ptr bx]
	mov ax, bx
	
	min_loop:
		cmp bx, cx
		jz min_end

		cmp [byte ptr bx], dl
		jl min_new

		inc bx
		jmp min_loop
	min_new:
		mov dl, [byte ptr bx]
		mov ax, bx ; ax->smallest*
		inc bx
		jmp min_loop
	min_end:
	mov [bp+6], ax
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 2
endp

; -====================================================================-
;	Call on 2 pointers to swap their values
;	@params:
;		ptr1* - A pointer to the first position		: by reference
;		min*  - A pointer to the min position		: by reference
;
;	The code will swap the values in the given
;	  pointer position and the min pointer position.
;
;	Time Complexity: O(1)
; -====================================================================-
proc swap
	push bp
	mov bp, sp

	push ax
	push bx
	push cx
	push si

	mov si, [bp+6] ; ptr1*
	mov bx, [bp+4] ; min*

	mov al, [bx]
	mov cl, [si]
	mov [si], al
	mov [bx], cl

	pop si
	pop cx
	pop bx
	pop ax
	pop bp
	ret 4
endp

; -====================================================================-
;	Call on an array to sort it's values
;	@params:
;		length - The length of the array 			 	: by value
;		head*  - A pointer to the start of the array	: by reference
;
;	The code will itterate through all memory locations
;	  in range head*..head*+length and sort them out
;
;	Time Complexity: O(n^2)
; -====================================================================-
proc selectionSort
	push bp
	mov bp, sp
	push bx
	push cx
	push dx

	mov bx, [bp+4] ; array head pointer
	mov cx, [bp+6] ; array length
	add cx, bx
	mov dx, cx
	dec cx
	_LOP:
		; list length
		; (len + offset list) - bx
		push dx
		; head ptr
		push bx
		call min

		; push [bx] -> list[index]
		push bx
		call swap ; min ptr is already in stack so no need to take it out

		cmp bx, cx
		jz _END
		inc bx
		dec dx
		jmp _LOP
	_END:

	pop dx
	pop cx
	pop bx
	pop bp
	ret
endp

start:
	mov ax, @data
	mov ds, ax
	xor ax, ax
	xor si, si
	xor di, di
; --------------------------
	mov al, [len]
	push ax ; push len
	push offset list
	call selectionSort
; --------------------------

exit:
	mov ax, 4c00h
	int 21h
END start


; Pseudo codes:

; selection sort:
;	foreach index of nums
;	swap(
;	    nums[index], 
;	    min(nums) ; 
;	)
;	next index