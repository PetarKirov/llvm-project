; With `spirv.signed-integers`, a zero-extension into a signed type cannot be
; an OpUConvert (its result must be unsigned): it sign-extends and clears the
; bits above the source's width. A sign-extension stays an OpSConvert, and
; without the flag a zero-extension stays an OpUConvert.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - | FileCheck %s --implicit-check-not=OpUConvert
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - -filetype=obj | spirv-val --target-env spv1.6 %}
; RUN: sed -e '/spirv.signed-integers/d' -e 's/^!llvm.module.flags.*//' %s | llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute -o - | FileCheck %s --check-prefix=UNSIGNED

; CHECK-DAG: [[int:%[0-9]+]] = OpTypeInt 32 1
; CHECK-DAG: [[long:%[0-9]+]] = OpTypeInt 64 1
; CHECK-DAG: [[short:%[0-9]+]] = OpTypeInt 16 0
; CHECK-DAG: [[v2long:%[0-9]+]] = OpTypeVector [[long]] 2
; CHECK-DAG: [[low32:%[0-9]+]] = OpConstant [[long]] 4294967295
; CHECK-DAG: [[low16:%[0-9]+]] = OpConstant [[int]] 65535
; CHECK-DAG: [[v2low32:%[0-9]+]] = OpConstantComposite [[v2long]] [[low32]] [[low32]]

; CHECK-LABEL: Begin function zext32to64
; CHECK: [[a:%[0-9]+]] = OpFunctionParameter [[int]]
; CHECK: [[e:%[0-9]+]] = OpSConvert [[long]] [[a]]
; CHECK: OpBitwiseAnd [[long]] [[e]] [[low32]]
define i64 @zext32to64(i32 %a) {
  %r = zext i32 %a to i64
  ret i64 %r
}

; CHECK-LABEL: Begin function zext16to32
; CHECK: [[b:%[0-9]+]] = OpFunctionParameter [[short]]
; CHECK: [[f:%[0-9]+]] = OpSConvert [[int]] [[b]]
; CHECK: OpBitwiseAnd [[int]] [[f]] [[low16]]
define i32 @zext16to32(i16 %b) {
  %r = zext i16 %b to i32
  ret i32 %r
}

; CHECK-LABEL: Begin function zextvector
; CHECK: [[g:%[0-9]+]] = OpSConvert [[v2long]]
; CHECK: OpBitwiseAnd [[v2long]] [[g]] [[v2low32]]
define <2 x i64> @zextvector(<2 x i32> %c) {
  %r = zext <2 x i32> %c to <2 x i64>
  ret <2 x i64> %r
}

; CHECK-LABEL: Begin function sext32to64
; CHECK: OpSConvert [[long]]
; CHECK-NOT: OpBitwiseAnd
; CHECK: OpReturnValue
define i64 @sext32to64(i32 %d) {
  %r = sext i32 %d to i64
  ret i64 %r
}

; UNSIGNED-COUNT-3: OpUConvert
; UNSIGNED-NOT: OpBitwiseAnd

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"spirv.signed-integers", i32 1}
