; decomment according to platform (Linux or Windows)
;%include "include/io.lin.inc"
%include "include/io.win.inc"

section .data
    byteArray:    times 200 db 0 ; array of bytes where we have the current layer of addition after multiplication with number b's bytes
    byteArray2:   times 200 db 0 ; array of bytes where we have the current layer after multiplication with each b's byte
    multiplier:   db 0           ; address of multiplier
    byteArrayEnd: dd 0           ; length of arrays (they have the same length eventually, because we add their elements byte by byte)

section .text

global do_operation

; TODO dissasemble the main.o file. Be sure not to overwrite registers used
; by main.o that he does not save himself.
; If you see your program going nuts, consider looking in the main.o disassembly
; for the causes mentioned earlier.

do_operation:
    ; TODO
    push ebp
    mov ebp, esp
    
    mov eax, dword [ebp+8]       ; number a (first argument)
    mov ebx, dword [ebp+12]      ; number b (second argument)
    mov edx, dword [ebp+16]      ; operation (third argument)

    mov esi, dword [eax+4]       ; length of number a
    mov edi, dword [ebx+4]       ; length of number b     

    xor ecx, ecx                 ; initializing ecx with zero

    ; check operator
    cmp byte [edx], '|'
    jz or_operation
    
    cmp byte [edx], '&'
    jz and_operation
    
    cmp word [edx], "<<"
    jz shl_operation
    
    cmp word [edx], ">>"
    jz shr_operation
    
    cmp byte [edx], '+'
    jz addition_operation
    
    cmp byte [edx], '*'
    jz multiplication_operation
    jnz exit

;;; OR OPERATION ;;;
or_operation:   
    mov dl, byte [eax+8+ecx]     ; take byte from number a in little endian order
    mov dh, byte [ebx+8+ecx]     ; take byte from number b in little endian order  
    or dl, dh                    ; do the operation on bytes
    mov [eax+8+ecx], dl          ; put the result back in a, at the place where we read the certain byte
    inc ecx                      ; increase the position for the next byte
    cmp ecx, esi                 ; check if number a has any bytes left
    jge exit_or                  ; esi <= edi (length_a <= length_b) -> we must complete a with b's remaining byte
    cmp ecx, edi                 ; check if number b has any bytes left
    jl or_operation              ; repeat for the remaining bytes
    jmp exit                     ; esi >= edi (length_a >= length_b) -> we're done
    
; or_operation : put the rest of the bytes in a
exit_or:
    mov ecx, esi                 ; start from the position we finished
    mov [eax+4], edi             ; the new length_a is now length_b (length_a <= length_b)
for_exit_or:
    cmp ecx, edi                 ; if lengths are equal we're done
    jz exit
    mov dl, byte [ebx+8+ecx]     ; take byte from number b in little endian order
    mov [eax+8+ecx], dl          ; add in number a at the certain position
    inc ecx                      ; go to the next byte
    jmp for_exit_or              ; loop

;;; AND OPERATION ;;;   
and_operation:   
    mov dl, byte [eax+8+ecx]     ; take byte from number a in little endian order
    mov dh, byte [ebx+8+ecx]     ; take byte from number b in little endian order
    and dl, dh                   ; do the operation on bytes
    mov [eax+8+ecx], dl          ; put the result back in a, at the place where we read the certain byte
    inc ecx                      ; increase the position for the next byte
    cmp ecx, esi                 ; check if number a has any bytes left
    jge exit                     ; esi <= edi (length_a <= length_b) -> we're done
    cmp ecx, edi                 ; check if number b has any bytes left
    jl and_operation             ; repeat for the remaining bytes
    jmp exit_and                 ; esi >= edi (length_a >= length_b) -> we must overwrite a's remaining bytes with zero
    
; and_operation : put zeros, because length_a >= length_b
exit_and:
    mov ecx, edi                 ; start from the position we finished
    mov [eax+4], edi             ; the new length_a is now length_b (length_a >= length_b)
for_exit_and:
    cmp ecx, esi                 ; if lengths are equal we're done
    jz exit
    mov dl, 0                    ; make byte zero
    mov [eax+8+ecx], dl          ; add that byte at number a's certain position
    inc ecx                      ; go to the next byte
    jmp for_exit_and             ; loop

;;; SHL OPERATION ;;;
shl_operation:
    mov ebx, [ebx+8]             ; number of left shifts
for_multiple_shl:
    xor edi, edi                 ; we don't need it anymore, so we'll put the carry here
    xor edx, edx                 ; make sure it's zero, because we will put carry here
    xor ecx, ecx                 ; reinitialize it for every shift

for_shl:    
    xor edx, edx                 ; double make sure it's zero, we will put carry here
    mov dl, byte [eax+8+ecx]     ; take byte from number a in little endian order
    shl byte dl, 1               ; do the operation
    adc dh, 0                    ; add carry for keeping track of it
    add edx, edi                 ; add carry after shift if it is any carry
    mov [eax+8+ecx], dl          ; put the result back in a, at the place where we read the certain byte
    cmp dh, 0                    ; if there was carry
    jnz shl_carry
    xor edi, edi                 ; reinitialize
    inc ecx                      ; go to the next byte
    cmp ecx, esi                 ; if shift is not finished
    jl for_shl
    jmp exit_shl                 ; if shift is finished, check if it is needed to do it again from the beginning
    
shl_carry:                       ; if carry
    mov edi, 1                   ; 0000 0001 -> value to be added after left shift on byte
    inc ecx                      ; go to the next byte
    cmp ecx, esi                 ; if shift is not finished
    jl for_shl
    inc esi                      ; shift is finished, but we have carry, so we resize number a
    mov [eax+4], esi             ; put the new length in a (thus a will have a new byte)
    mov dl, 1                    ; add carry in the new byte of a
    mov [eax+8+ecx], dl          ; put the new byte value in a
    jmp exit_shl                 ; check if it is needed to do shift again form the beginning
    
exit_shl:
    dec ebx                      ; decrease number of shifts
    cmp ebx,0                    ; if there is needed another shift
    jg for_multiple_shl
    
    jmp exit
    
;;; SHR OPERATION ;;;
shr_operation:
    mov ebx, [ebx+8]             ; number of right shifts
for_multiple_shr:
    xor edi, edi                 ; we don't need it anymore, so we'll put the carry here
    mov ecx, esi                 ; reinitialize it for every shift
    dec ecx                      ; last byte of number a is at position (length_a - 1)

    xor edx, edx                 ; make sure it's zero, because we will put carry here
    mov dl, byte [eax+8+ecx]     ; take byte from number a in big endian order
    cmp dl, 1                    ; if first byte is 1 it will for sure be zero after right shift, so we'll resize number a
    jnz for_shr
    cmp esi, 1                   ; we can't have length_a less than 1
    jz for_shr
    dec esi                      ; resize length_a
    mov [eax+4], esi             ; update the new length in number a
    
for_shr:
    xor edx, edx                 ; make sure it's zero, because we will put carry here
    mov dl, byte [eax+8+ecx]     ; take byte from number a in big endian order
    shr byte dl, 1               ; do the operation
    adc dh, 0                    ; add carry for keeping track of it
    add edx, edi                 ; add carry after shift if it is any carry
    mov [eax+8+ecx], dl          ; put the result back in a, at the place where we read the certain byte
    cmp dh, 0                    ; if there was carry
    jnz shr_carry
    xor edi, edi                 ; reinitialize
    dec ecx                      ; go to the next byte
    cmp ecx, 0                   ; if shift is not finished
    jge for_shr
    jmp exit_shr
    
shr_carry:                       ; if carry
    mov edi, 0x80                ; 1000 0000 -> value to be added after right shift on byte
    dec ecx                      ; go to the next byte
    cmp ecx, 0                   ; if shift is not finished
    jge for_shr
    
    jmp exit_shr
    
exit_shr:
    dec ebx                      ; decrease number of shifts
    cmp ebx,0                    ; if there is needed another shift
    jg for_multiple_shr
    
    jmp exit

;;; ADDITION OPERATION ;;;   
addition_operation:
    cmp esi, edi                 ; check lengths of numbers a and b
    jz continue_addition         ; esi = edi (length_a = length_b) -> we're done
    jl length_a_increase         ; esi < edi (length_a < length_b)

length_b_increase:               ; esi > edi (length_a > length_b)
    mov dl, 0                    ; make zero on the added byte
    mov [ebx+8+esi], dl          ; add zeros on the added bytes
    inc edi                      ; increase size of number b
    mov [ebx+4], edi             ; update length_b
    cmp edi, esi                 ; if lengths are equals -> we're done
    jl length_b_increase
    jmp continue_addition
  
length_a_increase:               ; esi < edi (length_a < length_b)
    mov dl, 0                    ; make zero on the added byte
    mov [eax+8+esi], dl          ; add zeros on the added bytes
    inc esi                      ; increase size of number a
    mov [eax+4], esi             ; update length_a
    cmp esi, edi                 ; if lengths are equals -> we're done
    jl length_a_increase
    jmp continue_addition
                     
continue_addition:
    mov ecx, dword [eax]         ; sign of number a
    mov edx, dword [ebx]         ; sign of number b
    cmp ecx, edx                 ; verifies numbers' signs
    jz addition_same_sign
    jg addition_unsigned_signed
    xor ecx, ecx                 ; initialize ecx with zero
    
switch_to_unsigned_signed:       ; we switch numbers in case signed_unsigned to be treated like case unsigned_signed
    mov dl, byte [eax+8+ecx]     ; take byte from number a in little endian order
    mov dh, byte [ebx+8+ecx]     ; take byte from number a in little endian order
    mov [eax+8+ecx], dh          ; switch bytes of numbers a and b
    mov [ebx+8+ecx], dl
    inc ecx                      ; go to the next bytes
    cmp ecx, esi                 ; both numbers have now the same length; we do this until the end of length
    jl switch_them

    mov ecx, dword [eax]         ; sign of number a
    mov edi, dword [ebx]         ; sign of number b
    mov [eax], edi               ; switch signs
    mov [ebx], ecx
    
    jmp addition_unsigned_signed
    
addition_unsigned_signed:        ; unsigned_signed = 'us' form now on (number a unsigned, number b signed)
    mov ecx, [eax+8+esi-1]       ; MSB byte of number a
    mov edi, [ebx+8+esi-1]       ; MSB byte of number b
    cmp ecx, edi                 ; we want to subtract from the bigger number the smaller number
    jge do_not_switch_them
    xor ecx, ecx                 ; initialize ecx with zero
switch_them:
    mov dl, byte [eax+8+ecx]     ; take byte from number a in little endian order
    mov dh, byte [ebx+8+ecx]     ; take byte from number a in little endian order
    mov [eax+8+ecx], dh          ; switch bytes of numbers a and b
    mov [ebx+8+ecx], dl
    inc ecx                      ; go to the next bytes
    cmp ecx, esi                 ; both numbers have now the same length; we do this until the end of length
    jl switch_them

    mov ecx, dword [eax]         ; sign of number a
    mov edi, dword [ebx]         ; sign of number b
    mov [eax], edi               ; we switch signs, sign of the bigger number will dominate
    mov [ebx], ecx
    
do_not_switch_them:
    xor ecx, ecx                 ; reinitialize ecx with zero
    xor edi, edi                 ; initialize edi with zero; both numbers have the same length; it will have the carry
    clc                          ; make sure CF is cleared

for_add_us:  
    xor edx, edx                 ; always initialize edx with zero
    mov dl, byte [eax+8+ecx]     ; take byte from number a in little endian order
    mov dh, byte [ebx+8+ecx]     ; take byte from number b in little endian order
    cmp edi, 0                   ; if carry
    jz no_carry_add_us
    stc                          ; set carry
    
no_carry_add_us:
    sbb dl, dh                   ; subtract with borrow
    mov [eax+8+ecx], dl          ; put the result back in a, at the place where we read the certain byte
    inc ecx                      ; go to the next bytes
    jc set_carry_add_us          ; if there resulted a carry from subtraction
    xor edi, edi                 ; no carry, so we put zero
continue_for_add_us:
    cmp ecx, esi                 ; if we read all bytes
    jl for_add_us
    jmp exit_add_us              ; last check
    
set_carry_add_us:
    mov edi, 1                   ; edi is the carry
    jmp continue_for_add_us
    
exit_add_us:
    cmp edi, 0                   ; if final addition didn't throw a carry
    jz continue_exit_add_us
    mov ecx, 0xFFFFFFFF          ; if there was a carry it means the first number a was smaller than number b
    mov [eax], ecx               ; we update the sign

continue_exit_add_us:
    mov edi, ecx                 ; we iterate from MSB to LSB to check if there are zeros
    sub edi, 1                   ; MSB position
check_first_zeros:
    mov dl, byte [eax+8+edi]     ; take byte from number b in big endian order
    cmp dl, 0                    ; if certain block is zero
    jnz exit
    cmp ecx, 1                   ; if length is bigger than 1
    jz exit
    dec ecx                      ; decrease size of number a
    mov [eax+4], ecx             ; update length_a
    sub edi, 1                   ; go to the next position
    cmp edi, 0                   ; if there is any byte left
    jge check_first_zeros
    
    jmp exit
    
addition_same_sign:              ; same_sign = 'ss' for now on (both numbers have the same sign)
    xor ecx, ecx                 ; reinitialize ecx with zero
    xor edi, edi                 ; numbers have the same length now, so we use only esi for length, edi is for carry
    clc
    
for_add_ss:
    cmp edi, 0                   ; if there was carry
    jz no_carry_for_add_ss
    stc                          ; set carry
no_carry_for_add_ss:
    mov dl, byte [eax+8+ecx]     ; take byte from number a in little endian order
    mov dh, byte [ebx+8+ecx]     ; take byte from number b in little endian order
    adc dl, dh                   ; add bytes with carry
    mov [eax+8+ecx], dl          ; put the result back in a, at the place where we read the certain byte
    inc ecx                      ; go to the next byte
    jc set_carry_add_ss          ; if carry from addition
    xor edi, edi                 ; no carry
continue_for_add_ss: 
    cmp ecx, esi                 ; if addition is not finished
    jl for_add_ss      
    jmp exit_add_ss              ; final verification for carry
    
set_carry_add_ss:
    mov edi, 1                   ; edi is the carry
    jmp continue_for_add_ss
    
exit_add_ss:
    cmp edi, 0                   ; if final addition didn't throw a carry
    jz exit
    mov dl, 1                    ; if there was a carry at the end
    mov [eax+8+ecx], dl          ; put the carry in a new byte in number a
    inc ecx                      ; increase size of number a
    mov [eax+4], ecx             ; update length_a
    
    jmp exit

;;; MULTIPLICATION OPERATION ;;;  
multiplication_operation: 
    cmp esi, edi                 ; check lengths of numbers a and b
    jz continue_multiply         ; esi = edi (length_a = length_b) -> we're done
    jl length_a_increase_mul     ; esi < edi (length_a < length_b)

length_b_increase_mul:           ; esi > edi (length_a > length_b)
    mov dl, 0                    ; make zero on the added byte
    mov [ebx+8+esi], dl          ; add zeros on the added bytes
    inc edi                      ; increase size of number b
    mov [ebx+4], edi             ; update length_b
    cmp edi, esi                 ; if lengths are equals -> we're done
    jl length_b_increase_mul
    jmp continue_multiply
  
length_a_increase_mul:           ; esi < edi (length_a < length_b)
    mov dl, 0                    ; make zero on the added byte
    mov [eax+8+esi], dl          ; add zeros on the added bytes
    inc esi                      ; increase size of number a
    mov [eax+4], esi             ; update length_a
    cmp esi, edi                 ; if lengths are equals -> we're done
    jl length_a_increase_mul
    jmp continue_multiply
 
continue_multiply:   
    xor edi, edi                 ; numbers a and b have the same length, so we will use just esi for size
    xchg eax, edi                ; we will use eax for multiplication; edi will be number a now
    xor ecx, ecx                 ; reinitialize ecx with zero
    xor edx, edx                 ; make sure edx is zero, we will store byte in dl and dh
    mov [byteArrayEnd], esi      ; initial length of arrays is the length of numbers

    mov dl, byte [ebx+8+ecx]     ; take byte from number b in little endian order (take the LSB now)
    mov [multiplier], dl         ; this byte will be the multiplier
multiplying:
    mov al, byte [edi+8+ecx]     ; take byte from number a in little endian order
    mov dl, byte [multiplier]    ; take the multiplier
    mul dl                       ; multiply (product will be in al and carry in ah)
    mov dl, ah                   ; save carry in dl (dl isn't needed after multiplication of bytes)
    add al, dh                   ; add the previous carry to product
    adc dl, 0                    ; add the carry of the previous addition
    mov dh, dl                   ; save current carry for the next multiplication
    mov [byteArray+ecx], al      ; put the current product in the addition array
    inc ecx                      ; go to the next byte
    cmp ecx, esi                 ; if there is any byte left
    jl multiplying
    cmp dh, 0                    ; if the last operation throws a carry
    jz continue_mul              ; no carry
    mov [byteArray+ecx], dh      ; put that carry in the addition array
    mov ecx, [byteArrayEnd]      ; update the arrays' length
    inc ecx
    mov [byteArrayEnd], ecx
    
continue_mul: 
    xor ecx, ecx                  ; reinitialize ecx with zero
    push ecx                      ; put it on stack
repeat_for_all_bytes:   
    pop ecx                       ; take if off from stack
    inc ecx                       ; increase it (it represents the position of the byte of number b in little endian order)
    cmp ecx, esi                  ; if there is any byte left in number b
    jge final
    push ecx                      ; if there are bytes left we put the current position on stack
    mov dl, byte [ebx+8+ecx]      ; take byte from number b in little endian order
    mov [multiplier], dl          ; this byte will be the multiplier
    mov ebx, ecx                  ; position for where we put products on multiplication layer array
    xor ecx, ecx                  ; initialize ecx with zero
    xor edx, edx                  ; make sure edx is zero, we will store byte in dl and dh
multiplying_next_bytes:
    mov al, byte [edi+8+ecx]      ; take byte from number a in little endian order
    mov dl, byte [multiplier]     ; take the multiplier
    mul dl                        ; multiply (product will be in al and carry in ah)
    mov dl, ah                    ; save carry in dl (dl isn't needed after multiplication of bytes)
    add al, dh                    ; add the previous carry to product
    adc dl, 0                     ; add the carry of the previous addition
    mov dh, dl                    ; save current carry for the next multiplication
    mov [byteArray2+ebx], al      ; put the current product in the multiplication layer array
    inc ecx                       ; go to the next byte
    inc ebx                       ; go to the next position in the multiplication layer array
    cmp ecx, esi                  ; if there is any byte left
    jl multiplying_next_bytes
    mov [byteArrayEnd], ebx       ; the arrays' length will be (the last position + 1) in the multiplication layer array
    cmp dh, 0                     ; if the last operation throws a carry
    jz add_arrays                 ; no carry
    mov [byteArray2+ebx], dh      ; put that carry in the multiplication layer array
    inc ebx                       ; update the arrays' length
    mov [byteArrayEnd], ebx
    
; adding addition array with multiplication layer array (result will be the addition array)
add_arrays:
    xor ecx, ecx                  ; reinitialize ecx with zero
    xor edi, edi                  ; we need edi for addition carry; we'll put number a back in it afterwards
    clc

for_add_arrays:
    cmp edi, 0                    ; if there was carry
    jz no_carry_for_add_arrays
    stc                           ; set carry

no_carry_for_add_arrays:
    mov dl, byte [byteArray+ecx]  ; take byte from addition array in little endian order
    mov dh, byte [byteArray2+ecx] ; take byte from multiplication layer array in little endian order
    adc dl, dh                    ; add bytes with carry
    mov [byteArray+ecx], dl       ; put the result in addition array, at the place where we read the certain byte
    inc ecx                       ; go to the next byte
    jc set_carry_add_arrays       ; if carry from addition
    xor edi, edi                  ; no carry
continue_for_add_arrays:
    cmp ecx, [byteArrayEnd]       ; if addition is not finished
    jl for_add_arrays
    jmp exit_add_arrays           ; final verification for carry
    
set_carry_add_arrays:
    mov edi, 1                    ; edi is the carry
    jmp continue_for_add_arrays
    
exit_add_arrays:
    cmp edi, 0                    ; if final addition didn't throw a carry 
    jz check_if_repeat
    mov dl, 1                     ; if there was a carry at the end
    mov [byteArray+ecx], dl       ; put the carry in a new byte in addition array
    inc ecx                       ; increase size of arrays
    mov [byteArrayEnd], ecx       ; update arrays' length

; before repeat we must make zeros in the multiplication layer array
; we must also restore edi as being number a
check_if_repeat:
    mov edi, dword [ebp + 8]      ; number a
    mov ebx, dword [ebp + 12]     ; number b
    xor ecx, ecx                  ; initialize with zero, because we have to make zeroes in multiplicaton layer array
make_zero_array2:
    mov dl, 0
    mov [byteArray2+ecx], dl      ; make each byte zero in multiplication layer array
    inc ecx                       ; go to next byte
    cmp ecx, [byteArrayEnd]       ; if there is any byte left
    jl make_zero_array2
    
    jmp repeat_for_all_bytes      ; go to next byte in number b for multiplication  

; we must eliminate MSB zeros from addition array
final:
    mov ecx, [byteArrayEnd]        ; we go from MSB to LSB
eliminate_zeros_mul:
    mov dl, byte [byteArray+ecx-1] ; take byte from addition array in big endian order
    cmp dl, 0                      ; if it is zero
    jnz recreate_number_a          ; not zero
    mov eax, [byteArrayEnd]        ; decrease arrays' length
    cmp eax, 1                     ; we cannot have length smaller than 1
    jz recreate_number_a
    dec eax                        ; decrease arrays' length
    mov [byteArrayEnd], eax        ; update the arrays' length
    dec ecx                        ; go to the next byte
    cmp ecx, 0                     ; if there is any byte left
    jg eliminate_zeros_mul

; we must put the result (addition array) in number a -> we copy addition array in number a
recreate_number_a:
    xor ecx, ecx                   ; reinitialize ecx with zero
    mov eax, [byteArrayEnd]        ; length of arrays
    mov [edi+4], eax               ; update length_a with arrays' length
for_end_mul:
    mov dl, byte [byteArray+ecx]   ; take byte from addition array in big endian order 
    mov [edi+8+ecx], dl            ; put byte in number a on the same position
    inc ecx                        ; go to the next byte
    cmp ecx, eax                   ; if there is any byte left
    jl for_end_mul
    mov eax, [edi]                 ; sign of number a
    mov ecx, [ebx]                 ; sign of number b
    cmp eax, 0                     ; if number a is unsigned
    jnz nr_a_signed_mul
    mov [edi], ecx                 ; result sign will be sign of number b
    jmp exit
nr_a_signed_mul:                   ; if number a is signed
    cmp ecx, 0                     ; if number b is signed
    jz exit                        ; number b is unsigned -> result sign will be sign of number a
    mov eax, 0                     ; both numbers are signed -> result will be unsigned
    mov [edi], eax    
    
exit:    
    leave
    ret
