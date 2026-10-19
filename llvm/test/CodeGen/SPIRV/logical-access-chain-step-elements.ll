; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; An optimiser splits `t[i + 1]` into an element address and a constant byte
; offset past it: gep i8 (gep [16 x i8] t, i), 16. A logical access chain
; cannot step from one element to the next, so the whole elements the offset
; steps over join the index, t[i + 1], and only what is left indexes inside
; the element: t[i + 1].y for an offset of 20.

; CHECK-NOT: OpTypeInt 64
; CHECK-DAG: %[[UINT:[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: %[[ONE:[0-9]+]] = OpConstant %[[UINT]] 1{{$}}
; CHECK: %[[I:[0-9]+]] = OpBitwiseAnd %[[UINT]]
; CHECK: %[[J:[0-9]+]] = OpIAdd %[[UINT]] %[[I]] %[[ONE]]
; CHECK: Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %{{[0-9]+}} %[[J]]{{$}}
; CHECK: %[[K:[0-9]+]] = OpIAdd %[[UINT]] %[[I]] %[[ONE]]
; CHECK: %[[EK:[0-9]+]] = Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %{{[0-9]+}} %[[K]]{{$}}
; CHECK: Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %[[EK]] %[[ONE]]{{$}}

@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %t = alloca [3 x <4 x float>], align 16
  %t1 = getelementptr inbounds nuw i8, ptr %t, i64 16
  %t2 = getelementptr inbounds nuw i8, ptr %t, i64 32
  store <4 x float> <float 1.0, float 0.0, float 0.0, float 1.0>, ptr %t, align 16
  store <4 x float> <float 0.0, float 1.0, float 0.0, float 1.0>, ptr %t1, align 16
  store <4 x float> <float 0.0, float 0.0, float 1.0, float 1.0>, ptr %t2, align 16
  %tid = tail call i32 @llvm.spv.thread.id.i32(i32 0)
  %i = and i32 %tid, 1
  %si = sext i32 %i to i64
  %e = getelementptr [16 x i8], ptr %t, i64 %si

; t[i + 1]
  %n = getelementptr i8, ptr %e, i64 16
  %v = load <4 x float>, ptr %n, align 16

; t[i + 1].y
  %y = getelementptr i8, ptr %e, i64 20
  %w = load float, ptr %y, align 4

  %x = extractelement <4 x float> %v, i32 0
  %s = fadd float %x, %w
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %s, ptr addrspace(11) %po
  ret void
}

declare i32 @llvm.spv.thread.id.i32(i32)

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
