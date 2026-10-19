; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s --check-prefix=NO-PAD
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A frontend lays out a block's nested structs with spirv.Padding members in
; packed structs, as Clang does for a cbuffer. The padding is distance, not a
; member: an explicitly laid-out struct's SPIR-V type has only its other
; members, each at the offset the packed layout gives it, and an access chain
; indexes them by their place among those.

; NO-PAD-NOT: OpTypeInt 8

; std140: struct Inner { vec2 p; float q; } (size 16)
;         struct Block { float a; Inner inner; float b; }  inner at 16, b at 32
; CHECK-DAG: %[[FLOAT:[0-9]+]] = OpTypeFloat 32
; CHECK-DAG: %[[V2:[0-9]+]] = OpTypeVector %[[FLOAT]] 2
; CHECK-DAG: %[[INNER:[0-9]+]] = OpTypeStruct %[[V2]] %[[FLOAT]]{{$}}
; CHECK-DAG: %[[BLOCK:[0-9]+]] = OpTypeStruct %[[FLOAT]] %[[INNER]] %[[FLOAT]]{{$}}
; CHECK-DAG: OpMemberDecorate %[[INNER]] 0 Offset 0
; CHECK-DAG: OpMemberDecorate %[[INNER]] 1 Offset 8
; CHECK-DAG: OpMemberDecorate %[[BLOCK]] 0 Offset 0
; CHECK-DAG: OpMemberDecorate %[[BLOCK]] 1 Offset 16
; CHECK-DAG: OpMemberDecorate %[[BLOCK]] 2 Offset 32
; CHECK-DAG: %[[UINT:[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: %[[ONE:[0-9]+]] = OpConstant %[[UINT]] 1{{$}}
; CHECK-DAG: %[[TWO:[0-9]+]] = OpConstant %[[UINT]] 2{{$}}

%Inner = type <{ <2 x float>, float, target("spirv.Padding", 4) }>
%Block = type <{ float, target("spirv.Padding", 12), %Inner, float, target("spirv.Padding", 12) }>

@.str.u = private unnamed_addr constant [2 x i8] c"U\00", align 1
@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %u = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %Block, 48, 0, 4, 16, 32, 36), 2, 0) @llvm.spv.resource.handlefrombinding.U(i32 0, i32 1, i32 1, i32 0, ptr nonnull @.str.u)

; inner.q: LLVM member 2, then 1; SPIR-V member 1, then 1.
; CHECK: %[[PI:[0-9]+]] = OpAccessChain %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}} %[[ONE]]{{$}}
; CHECK: %[[PQ:[0-9]+]] = Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %[[PI]] %[[ONE]]{{$}}
; CHECK: OpLoad %[[FLOAT]] %[[PQ]]
  %pi = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.U(target("spirv.VulkanBuffer", target("spirv.Layout", %Block, 48, 0, 4, 16, 32, 36), 2, 0) %u, i32 2)
  %pq = getelementptr inbounds %Inner, ptr addrspace(12) %pi, i32 0, i32 1
  %q = load float, ptr addrspace(12) %pq

; b: LLVM member 3; SPIR-V member 2.
; CHECK: %[[PB:[0-9]+]] = OpAccessChain %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}} %[[TWO]]{{$}}
; CHECK: OpLoad %[[FLOAT]] %[[PB]]
  %pb = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.U(target("spirv.VulkanBuffer", target("spirv.Layout", %Block, 48, 0, 4, 16, 32, 36), 2, 0) %u, i32 3)
  %b = load float, ptr addrspace(12) %pb

  %s = fadd float %q, %b
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %s, ptr addrspace(11) %po
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
