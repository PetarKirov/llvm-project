; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A frontend whose index type is 64-bit (D's size_t) widens a 32-bit index
; before addressing, and writes constant indices at 64 bits. A logical access
; chain cannot index past 2^31 elements, so an index is taken from before the
; widening and a constant one at 32 bits, and no 64-bit integer type (nor the
; Int64 capability) reaches the module.

; CHECK-NOT: OpCapability Int64
; CHECK-NOT: OpTypeInt 64
; CHECK-DAG: %[[UINT:[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: %[[TWO:[0-9]+]] = OpConstant %[[UINT]] 2{{$}}
; CHECK: %[[IDX:[0-9]+]] = OpBitwiseAnd %[[UINT]]
; CHECK: Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %{{[0-9]+}} %[[IDX]]{{$}}
; CHECK: %[[IDX2:[0-9]+]] = OpBitwiseAnd %[[UINT]]
; CHECK: Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %{{[0-9]+}} %[[IDX2]]{{$}}
; CHECK: Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %{{[0-9]+}} %[[TWO]]{{$}}

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

; A byte-addressing GEP by a sign-extended index.
  %i = and i32 %tid, 1
  %si = sext i32 %i to i64
  %p = getelementptr inbounds [16 x i8], ptr %t, i64 %si
  %v = load <4 x float>, ptr %p, align 16

; A typed GEP by a zero-extended index.
  %j = and i32 %tid, 2
  %zj = zext i32 %j to i64
  %q = getelementptr inbounds [3 x <4 x float>], ptr %t, i64 0, i64 %zj
  %w = load <4 x float>, ptr %q, align 16

; A typed GEP by a 64-bit constant.
  %r = getelementptr inbounds [3 x <4 x float>], ptr %t, i64 0, i64 2
  %y = load <4 x float>, ptr %r, align 16

  %s0 = fadd <4 x float> %v, %w
  %s = fadd <4 x float> %s0, %y
  %x = extractelement <4 x float> %s, i32 0
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %x, ptr addrspace(11) %po
  ret void
}

declare i32 @llvm.spv.thread.id.i32(i32)

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
