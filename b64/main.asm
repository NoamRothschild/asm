%include '../common/general.asm'
%include '../common/debug.asm'
%include 'b64.asm'

section .data
  msg db 'encode me!', 0
  msgLen db 10

  msgEncoded db 0b00010000, 0b00010110, 0b00111001, 0b00100100, 0
  msgEncoded2 db "8ZyDIglks6GQA9r5If//vA0H4Qo=", 0

  msg2 db "hello world!", 0
  msg2LengthBytes dd 12

section .bss
  ; output buffer must be equal or above the (original length)*4/3
  output: resb 20 
  output2: resb 20

section .text

global _start

_start:

.decode1:

  push dword [msg2LengthBytes]
  push output
  push msg2
  call b64Encode

  push output
  call printMessage
  call printTerminator

  push output2
  push msgEncoded2
  call b64Decode

  push output2
  call printMessage
  call printTerminator

  jmp .end

.decode2:
  push dword 4
  push msgEncoded
  call printBin

  push output
  push msgEncoded
  call b64Decode

  push dword 3 
  push output
  call printBin

  mov ecx, 14
  mov edi, output
.clearOut:
  mov byte [edi], 0
  inc edi
  loop .clearOut

.encodeTest:
  push dword [msgLen]
  push output
  push msg
  call b64Encode
  
  push output
  call printMessage

.end:
  call exit
