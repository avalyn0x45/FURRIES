// FURRIES: Frickin UnReadable Ridiculous language Including Erroneous Syntax
// Copyright (C) 2025 Avalyn Baldyga
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

.globl _start
.globl print
.globl exit
.globl syscall0
.globl syscall1
.globl syscall2
.globl syscall3
.globl syscall4
.globl syscall5
.globl memcpy
.globl if
.globl jump
.globl while
.globl array
.globl gt
.globl lt
.globl ge
.globl le
.globl eq
.globl ne
.globl set

.text
    _start:
        call main
        xorl %ebx, %ebx
    exit:
        endbr32
        movl $1, %eax
        int $0x80
    syscall0:
        endbr32
        movl %ebx, %eax
        int $0x80
        ret
    syscall1:
        endbr32
        movl %ebx, %eax
        movl %ecx, %ebx
        int $0x80
        ret
    syscall2:
        endbr32
        movl %ebx, %eax
        movl %ecx, %ebx
        movl %edx, %ecx
        int $0x80
        ret
    syscall3:
        endbr32
        movl %ebx, %eax
        movl %ecx, %ebx
        movl %edx, %ecx
        movl %esi, %edx
        int $0x80
        ret
    syscall4:
        endbr32
        movl %ebx, %eax
        movl %ecx, %ebx
        movl %edx, %ecx
        movl %esi, %edx
        movl %edi, %esi
        int $0x80
        ret
    syscall5:
        endbr32
        movl %ebx, %eax
        movl %ecx, %ebx
        movl %edx, %ecx
        movl %esi, %edx
        movl %edi, %esi
        movl %ebp, %edi
        int $0x80
        ret
    print:
        endbr32
        xorl %edx, %edx
        len_loop:
            movb (%edx, %ebx, 1), %cl
            test %cl, %cl
            jz loop_exit
            addl $1, %edx
            jmp len_loop
        loop_exit:
        movl $4, %eax
        movl %ebx, %ecx
        movl $1, %ebx
        int $0x80
        ret
    memcpy:
        endbr32
        movl %ebx, %esi
        movl %eax, %edi
        rep movsb
        ret
    while:
        endbr64
        subl $4, %esp
    if:
        endbr32
        test %ecx, %ecx
        jz ret
        // ebx
        xchg %edx, %ebx
        //ecx
        xchg %esi, %ecx
        //edx
        xchg %edi, %edx

        jmp *%edi
        ret
    jump:
        endbr32
        subl $4, %esp
        jmp *%eax
    byte:
        endbr32
        movb (%ebx, %ecx, 1), %al
        ret
    setbyte:
        endbr32
        movb %cl, (%eax, %ebx, 1)
        ret
    array:
        endbr32
        movl (%ebx, %ecx, 1), %eax
        ret
    set:
        endbr32
        movl %ecx, (%eax, %ebx, 1)
        ret
    gt:
        endbr32
        movl $0, %eax
        test %ebx, %ecx
        jg ret
        movl $1, %eax
        ret   
    lt:
        endbr32
        movl $0, %eax
        test %ebx, %ecx
        jl ret
        movl $1, %eax
        ret
    ge:
        endbr32
        movl $0, %eax
        test %ebx, %ecx
        jge ret
        movl $1, %eax
        ret
    le:
        endbr32
        movl $0, %eax
        test %ebx, %ecx
        jle ret
        movl $1, %eax
        ret
    eq:
        endbr32
        movl $0, %eax
        test %ebx, %ecx
        je ret
        movl $1, %eax
        ret
    ne:
        endbr32
        movl $0, %eax
        test %ebx, %ecx
        jne ret
        movl $1, %eax
        ret
    ret:
        endbr32
        ret
