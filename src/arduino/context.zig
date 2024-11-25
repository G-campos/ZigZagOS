/// Credits to:
/// https://github.com/arbv/avr-context
const std = @import("std");

inline fn avr_context_asmconst(comptime name: []u8, comptime value: i32) noreturn {
    asm volatile (".equ " + name + "," + value + "\t");
}

comptime {
    avr_context_asmconst("AVR_CONTEXT_OFFSET_PC_L", 33);
    avr_context_asmconst("AVR_CONTEXT_OFFSET_PC_H", 34);
    avr_context_asmconst("AVR_CONTEXT_OFFSET_SP_L", 35);
    avr_context_asmconst("AVR_CONTEXT_OFFSET_SP_H", 36);
    avr_context_asmconst("AVR_CONTEXT_BACK_OFFSET_R26", 9);
}

pub const LowHighAVR = packed struct {
    const Self = @This();

    ptr: *void,

    pub fn low(self: Self) u8 {
        const val: u16 = self.ptr & (0xFF);
        return @intCast(val);
    }

    pub fn high(self: Self) u8 {
        const val: u16 = (self.ptr >> 8) & (0xFF);
        return @intCast(val);
    }
};

pub const ContextAVR = packed struct {
    sreg: u8,
    regs: [32]u8,
    pc: LowHighAVR,
    sp: LowHighAVR,
};

inline fn avr_savecontext(comptime presave_code: []u8, comptime load_address_to_Z_code: []u8) noreturn {
    const asm_str =
        \\
        \\# push Zdd 
        \\push r30
        \\push r31
        \\# Save SREG value using R0 as a temporary register.
        \\in r30, __SREG__
    + "\n" + presave_code + "\n" +
        \\push r0
        \\# Push SREG value.
        \\push r30
        \\# Load address of a context pointer structure to Z
    + load_address_to_Z_code +
        \\# save SREG to the context structure
        \\pop r0
        \\st Z+, r0
        \\# Restore initial R0 value.
        \\pop r0 
        \\# Save general purpose register values.
        \\st z+, r0
        \\st z+, r1
        \\st z+, r2
        \\st z+, r3
        \\st z+, r4
        \\st z+, r5
        \\st z+, r6
        \\st z+, r7
        \\st z+, r8
        \\st z+, r9
        \\st z+, r10
        \\st z+, r11
        \\st z+, r12
        \\st z+, r13
        \\st z+, r14
        \\st z+, r15
        \\st z+, r16
        \\st z+, r17
        \\st z+, r18
        \\st z+, r19
        \\st z+, r20
        \\st z+, r21
        \\st z+, r22
        \\st z+, r23
        \\st z+, r24
        \\st z+, r25
        \\st z+, r26
        \\st z+, r27
        \\st z+, r28
        \\st z+, r29
        \\# Switch to other index register (Z to Y) as its has been saved at this point
        \\mov r28, r30
        \\mov r29, r31
        \\# Restore and save values of registers 30 and 31 (Z)
        \\pop r31
        \\pop r30
        \\st y+, r30
        \\st y+, r31
        \\# Pop and save the return address
        \\pop r30
        \\pop r31
        \\st y+, r31
        \\st y+, r30
        \\# Save the stack pointer to the structure.
        \\in r26, __SP_L__
        \\in r27, __SP_H__
        \\st y+, r26
        \\st y, r27
        \\# Push the return address back at the top of the stack.
        \\push r31
        \\push r30
        \\# At this point the context is saved, but registers
        \\# 26, 27, 28, 29, 30, and 31 are clobbered.
        \\# In some cases we may not need to restore them,
        \\# but let's remain on the clean side and restore their values.
        \\# We have to do that because we provide a generic solution.
        \\mov r30, r28
        \\mov r31, r29
        \\# go to the offset of R26 in the context structure
        \\in r28, __SREG__
        \\sbiw r30, AVR_CONTEXT_BACK_OFFSET_R26
        \\out __SREG__, r28
        \\# Restore registers 26-29
        \\ld r26, Z+
        \\ld r27, Z+
        \\ld r28, Z+
        \\ld r29, Z+
        \\# save R28, R29 (Y) on the stack
        \\push r28
        \\push r29
        \\# switch to other index register (z to y) and read r30 and r31
        \\mov r28, r30
        \\mov r29, r31
        \\ld r30, Y+
        \\ld r31, Y
        \\# Restore R28, R29 (Y) from the stack
        \\pop r29
        \\pop r28
    ;
    asm volatile (asm_str);
}

inline fn avr_restorecontext(comptime load_address_to_Z_code: []u8) noreturn {
    const asm_str =
        \\#load address of a context structure pointer to Z
    + "\n" + load_address_to_Z_code + "\n" +
        \\#Go to the end of the context structure and
        \\#start restoring it from there.
        \\adiw r30, AVR_CONTEXT_OFFSET_SP_H
        \\#Restore the saved stack pointer.
        \\ld r0, Z
        \\out __SP_H__, r0
        \\ld r0, -Z
        \\out __SP_L__, r0
        \\#Put the saved return address (PC) back on the top of the stack.
        \\ld r1, -Z
        \\ld r0, -Z
        \\push r0
        \\push r1
        \\#Temporarily switch pointer from Z to Y,dd 
        \\#restore r31, r30 (Z) and put them on top of the stack.
        \\mov r28, r30
        \\mov r29, r31
        \\ld r31, -Y
        \\ld r30, -Y
        \\push r31
        \\push r30
        \\#Switch back from Y to Z.
        \\mov r30, r28
        \\mov r31, r29
        \\#Restore other general purpose registers.
        \\ld r29, -Z
        \\ld r28, -Z
        \\ld r27, -Z
        \\ld r26, -Z
        \\ld r25, -Z
        \\ld r24, -Z
        \\ld r23, -Z
        \\ld r22, -Z
        \\ld r21, -Z
        \\ld r20, -Z
        \\ld r19, -Z
        \\ld r18, -Z
        \\ld r17, -Z
        \\ld r16, -Z
        \\ld r15, -Z
        \\ld r14, -Z
        \\ld r13, -Z
        \\ld r12, -Z
        \\ld r11, -Z
        \\ld r10, -Z
        \\ld r9, -Z
        \\ld r8, -Z
        \\ld r7, -Z
        \\ld r6, -Z
        \\ld r5, -Z
        \\ld r4, -Z
        \\ld r3, -Z
        \\ld r2, -Z
        \\ld r1, -Z
        \\ld r0, -Z
        \\#Restore SREG
        \\push r0
        \\ld r0, -Z
        \\out __SREG__, r0
        \\pop r0
        \\#Restore r31, r30 (Z) from the stack.
        \\pop r30
        \\pop r3
    ;
    asm volatile (asm_str);
}

inline fn avr_save_context_global_pointer(comptime presave_code: []u8, comptime global_context_pointer: []u8) noreturn {
    avr_savecontext(presave_code,
        \\lds ZL, 
    + global_context_pointer + "\n" +
        \\lds ZH, 
    + global_context_pointer + "+ 1\n");
}

inline fn avr_restore_context_global_pointer(comptime global_context_pointer: []u8) noreturn {
    avr_restorecontext(
        \\lds ZL, 
    ++ global_context_pointer ++
        \\\n
        \\lds ZH, 
    ++ global_context_pointer ++
        \\+ 1\n"
    );
}

// void avr_getcontext(avr_context_t *cp) __attribute__ ((naked));
// void avr_getcontext(avr_context_t *cp)
// {
//     (void)cp; /* to avoid compiler warnings */
//     AVR_SAVE_CONTEXT(
//         "",
//         "mov r30, r24\n"
//         "mov r31, r25\n");
//     __asm__ __volatile__ ("ret\n");
// }

pub fn avr_getcontext(cp: *ContextAVR) callconv(.Naked) void {
    _ = cp;
    avr_savecontext("", "mov r30, r24\nmov r31, r25\n");
    asm volatile ("ret\n");
}

pub fn avr_setcontext(cp: *ContextAVR) callconv(.Naked) void {
    _ = cp;
    avr_restorecontext("", "mov r30, r24\nmov r31, r25\n");
    asm volatile ("ret\n");
}

pub fn avr_swapcontext(oucp: *ContextAVR, ucp: *ContextAVR) callconv(.Naked) void {
    _ = oucp;
    _ = ucp;
    avr_savecontext("", "mov r30, r24\nmov r31, r25\n");
    avr_restorecontext("", "mov r30, r22\nmov r31, r23\n");
    asm volatile ("ret\n");
}

const ContextFunc = *const fn (argp: *void) void;

fn avr_makecontext_callfunc(successor: *ContextAVR, func: ContextFunc, args: *void) void {
    func(args);
    avr_setcontext(successor);
}

pub fn avr_makecontext(cp: *ContextAVR, stackp: *void, stack_size: usize, successor_cp: *ContextAVR, funcp: ContextFunc, funcargs: *void) callconv(.Naked) void {
    var addr: u16 = undefined;
    const p: *u8 = @ptrCast(&addr);
    // initialise stack pointer and program counter
    var stack_pos: usize = @intFromPtr(stackp);
    stack_pos += @intCast(stack_size - 1);
    cp.*.sp.ptr = @ptrFromInt(stack_pos);
    cp.*.pc.ptr = avr_makecontext_callfunc;
    // initialise registers to pass arguments to avr_makecontext_callfunc
    // successor: registers 24,25; func registers 23, 22; funcarg: 21, 20.
    addr = @intFromPtr(successor_cp);
    cp.*.regs[24] = p[0];
    cp.*.regs[25] = p[1];
    addr = @intFromPtr(funcp);
    cp.*.regs[22] = p[0];
    cp.*.regs[23] = p[1];
    addr = @intFromPtr(funcargs);
    cp.*.regs[20] = p[0];
    cp.*.regs[21] = p[1];
}
