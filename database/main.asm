%include "../common/debug.asm"
%include "../common/general.asm"
%include "database.asm"
%include "users_db.asm"

section .data
  msg1 db "Hello! I am xyz.", 0
  msg2 db "Hi xyz!, nice to meet you!", 0

  s_pwd1 db "pwd", 0
  s_pwd2 db "Hello world!", 0
  s_pwd3 db "lorem ipsum", 0

  s_uname1 db "John", 0
  s_uname2 db "Mike", 0
  s_uname3 db "Noam", 0
section .text

global _start

_start:
  push 50
  call create_users_database
  pop edi

  push dword 1
  push s_pwd1
  push s_uname1
  push edi
  call create_user
  add esp, 4

  push dword 0
  push s_pwd2
  push s_uname2
  push edi
  call create_user
  add esp, 4

  push dword 1
  push s_pwd3
  push s_uname3
  push edi
  call create_user
  add esp, 4

  jmp end

create_db:
  push dword 4096
  call create_database
  pop edi

  push edi
  push msg1
  call append_data

  push edi
  push msg2
  call append_data

end:
  call exit
