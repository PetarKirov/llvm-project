# A TLS relocation against a linker-synthesized data symbol (__stack_high,
# __heap_base, ...) under --cooperative-threading or --shared-memory: wasm-ld
# reports "cannot be used against non-TLS symbol" and then dereferences the
# symbol's null segment.
#
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown -o %t.o %s
# RUN: not wasm-ld --cooperative-threading %t.o -o %t.wasm 2>&1 | FileCheck %s
# RUN: not wasm-ld --shared-memory --no-check-features %t.o -o %t.wasm 2>&1 | FileCheck %s

.globl __wasm_get_tls_base
__wasm_get_tls_base:
  .functype __wasm_get_tls_base () -> (i32)
  i32.const 0
  end_function

.globl _start
_start:
  .functype _start () -> (i32)
  call __wasm_get_tls_base
  i32.const __stack_high@TLSREL
  i32.add
  end_function

# CHECK: relocation R_WASM_MEMORY_ADDR_TLS_SLEB cannot be used against non-TLS symbol `__stack_high`
# CHECK-NOT: Stack dump
