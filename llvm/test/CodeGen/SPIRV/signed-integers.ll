; With the module flag `spirv.signed-integers`, LLVM's signless integers of 32
; bits and more are emitted signed, and no unsigned one of those is left in
; the module. Narrower ones stay unsigned, so their literals, written
; zero-extended, stay valid.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan %s -o - | FileCheck %s --implicit-check-not="OpTypeInt 32 0"
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-unknown-vulkan %s -o - -filetype=obj | spirv-val %}

; CHECK-DAG: [[int:%[0-9]+]] = OpTypeInt 32 1
; CHECK-DAG: [[v2int:%[0-9]+]] = OpTypeVector [[int]] 2
; CHECK-DAG: [[char:%[0-9]+]] = OpTypeInt 8 0
; CHECK-DAG: OpConstant [[char]] 128
; CHECK: OpLoad [[int]]
; CHECK: OpIAdd [[int]]

@n = external hidden addrspace(2) global i32
@p = external hidden addrspace(2) global <2 x i32>
@b = external hidden addrspace(2) global i8

define i32 @read(i32 %a) {
entry:
  %n = load i32, ptr addrspace(2) @n
  %p = load <2 x i32>, ptr addrspace(2) @p
  %y = extractelement <2 x i32> %p, i32 1
  %s = add i32 %n, %a
  %r = sdiv i32 %s, %y
  %b = load i8, ptr addrspace(2) @b
  %x = xor i8 %b, -128
  %w = sext i8 %x to i32
  %t = add i32 %r, %w
  ret i32 %t
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"spirv.signed-integers", i32 1}
