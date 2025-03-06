

About websocket callback parameter...

The function takes a function defined the following way

```
; please blackbox all registers except ecx!

foo:
    ; @edi: length of request
    ; @wsReqData: the buffer storing the request data
    ...

    ; return:
    ; @ecx: the generated response length
    ret


push dword foo
push dword [socketDescriptor]
call parseRequest
```