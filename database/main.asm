%include "../common/debug.asm"
%include "../common/general.asm"
%include "database.asm"
section .data
  msg1 db "Hello! I am xyz.", 0
  msg2 db "Hi xyz!, nice to meet you!", 0
section .text

global _start

_start:
  push dword 4096
  call create_database
  pop edi

  push edi
  push msg1
  call append_data

  push edi
  push msg2
  call append_data

  call exit
