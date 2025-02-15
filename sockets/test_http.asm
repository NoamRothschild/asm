%include '../common/general.asm'
%include '../common/string.asm'
%include '../common/debug.asm'
%include '../common/threading.asm'
%include '../common/fileManager.asm'
%include 'http/client_request.asm'
%include 'http/server_response.asm'
section .data
    testcase1 db 'temporary/testcase_get.txt', 0
    testcase2 db 'temporary/testcase_post.txt', 0
    testcase3 db 'temporary/testcase_websock.txt', 0

section .bss
    buffer: resb 4096
    request_struct: resb REQ_TOTAL_SIZE

section .text

global _start

printReq:
    push request_struct
    call respond_http

    mov ecx, response_buffer
    pop edx
    mov ebx, 1		; write to STDOUT
	mov eax, 4		; invokes SYS_WRITE (kernel opcode 4)
	int 80h
    call printTerminator
    call printTerminator
    ret

_start:
    push testcase1
	call openFile
	push buffer
	push dword 4096
    call readFile

    push buffer
    push request_struct
    call requestStruct

    push request_struct
    call printStruct

    call printTerminator

    call printReq

    push testcase2
    call iLengthFile
    pop edx
    mov dword [buffer+edx], 0 ; after reading a file there is no null terminator at the end of the given buffer
    ; this means if we load a msg into the buffer smaller than its capacity and the buffer had data before
    ; we would not be able to determine the end of the last read message

    push testcase2
	call openFile
	push buffer
	push dword 4096
    call readFile

    push buffer
    push request_struct
    call requestStruct

    push request_struct
    call printStruct

    call printTerminator

    call printReq

    push testcase2
    call iLengthFile
    pop edx
    mov dword [buffer+edx], 0 ; after reading a file there is no null terminator at the end of the given buffer
    ; this means if we load a msg into the buffer smaller than its capacity and the buffer had data before
    ; we would not be able to determine the end of the last read message

    push testcase3
	call openFile
	push buffer
	push dword 4096
    call readFile

    push buffer
    push request_struct
    call requestStruct

    push request_struct
    call printStruct

    call printTerminator

    call printReq

    call exit