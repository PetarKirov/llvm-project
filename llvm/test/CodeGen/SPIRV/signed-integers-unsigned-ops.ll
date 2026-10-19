; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; With spirv.signed-integers the module's integers are signed, but OpUDiv,
; OpUMod and OpConvertFToU are defined only for an unsigned result type. They
; compute in the unsigned twin of the type, between bitcasts, so a D `uint`
; division is valid and means what it does on the host.

; CHECK-DAG: %[[INT:[0-9]+]] = OpTypeInt 32 1
; CHECK-DAG: %[[UINT:[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: %[[INT2:[0-9]+]] = OpTypeVector %[[INT]] 2
; CHECK-DAG: %[[UINT2:[0-9]+]] = OpTypeVector %[[UINT]] 2

; CHECK: %[[A:[0-9]+]] = OpBitcast %[[UINT]] %{{[0-9]+}}
; CHECK: %[[B:[0-9]+]] = OpBitcast %[[UINT]] %{{[0-9]+}}
; CHECK: %[[Q:[0-9]+]] = OpUDiv %[[UINT]] %[[A]] %[[B]]
; CHECK: OpBitcast %[[INT]] %[[Q]]
; CHECK: %[[R:[0-9]+]] = OpUMod %[[UINT]]
; CHECK: OpBitcast %[[INT]] %[[R]]
; CHECK: %[[F:[0-9]+]] = OpConvertFToU %[[UINT]]
; CHECK: OpBitcast %[[INT]] %[[F]]
; CHECK: %[[QV:[0-9]+]] = OpUDiv %[[UINT2]]
; CHECK: OpBitcast %[[INT2]] %[[QV]]
; CHECK-NOT: OpUDiv %[[INT]]
; CHECK-NOT: OpUMod %[[INT]]

@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %a = tail call i32 @llvm.spv.thread.id.i32(i32 0)
  %b = tail call i32 @llvm.spv.thread.id.i32(i32 1)
  %q = udiv i32 %a, %b
  %r = urem i32 %q, %b
  %f = sitofp i32 %r to float
  %u = fptoui float %f to i32
  %va0 = insertelement <2 x i32> poison, i32 %a, i32 0
  %va = insertelement <2 x i32> %va0, i32 %u, i32 1
  %vb0 = insertelement <2 x i32> poison, i32 %b, i32 0
  %vb = insertelement <2 x i32> %vb0, i32 %b, i32 1
  %vq = udiv <2 x i32> %va, %vb
  %e = extractelement <2 x i32> %vq, i32 1
  %o = tail call target("spirv.VulkanBuffer", [0 x i32], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x i32], 12, 1) %o, i32 0)
  store i32 %e, ptr addrspace(11) %po
  ret void
}

declare i32 @llvm.spv.thread.id.i32(i32)

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"spirv.signed-integers", i32 1}
