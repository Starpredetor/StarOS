
[org 0x7c00]



mov ah, 0x0e
mov si, msg


print:
    mov al, [si]
    cmp al, 0
    je end
    int 0x10
    inc si
    jmp print
end:




jmp $
msg: db "Booting StarOS", 0


times 510-($-$$) db 0
db 0x55, 0xaa
