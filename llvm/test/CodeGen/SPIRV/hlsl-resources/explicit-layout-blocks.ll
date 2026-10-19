; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s --check-prefix=NO-PAD
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A frontend that lays out its own blocks (std140 for uniform blocks, std430
; for push constants) states each member's offset with spirv.Layout, and an
; array whose stride is wider than its element as a peeled array. Neither
; adds a member to the block, and no padding type reaches the module.

; NO-PAD-NOT: OpTypeInt 8

; Uniform block, std140: { float3 a; float b; float c[4]; float4 d; }
; CHECK-DAG: OpMemberDecorate %[[U:[0-9]+]] 3 Offset 80
; CHECK-DAG: OpMemberDecorate %[[U]] 0 Offset 0
; CHECK-DAG: OpMemberDecorate %[[U]] 1 Offset 12
; CHECK-DAG: OpMemberDecorate %[[U]] 2 Offset 16
; CHECK-DAG: OpDecorate %[[ARR:[0-9]+]] ArrayStride 16
; CHECK-DAG: %[[FLOAT:[0-9]+]] = OpTypeFloat 32
; CHECK-DAG: %[[UINT:[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: %[[FOUR:[0-9]+]] = OpConstant %[[UINT]] 4
; CHECK-DAG: %[[ARR]] = OpTypeArray %[[FLOAT]] %[[FOUR]]
; CHECK-DAG: %[[U]] = OpTypeStruct %{{[0-9]+}} %[[FLOAT]] %[[ARR]] %{{[0-9]+}}
%U = type { <3 x float>, float, <{ [3 x <{ float, target("spirv.Padding", 12) }>], float }>, <4 x float> }

; Push constants, std430: { float3 a; float b; float2 c; }
; CHECK-DAG: %[[PC:[0-9]+]] = OpVariable %[[PTR_PC:[0-9]+]] PushConstant
; CHECK-DAG: %[[PTR_PC]] = OpTypePointer PushConstant %[[P:[0-9]+]]
; CHECK-DAG: OpMemberDecorate %[[P]] 0 Offset 0
; CHECK-DAG: OpMemberDecorate %[[P]] 1 Offset 12
; CHECK-DAG: OpMemberDecorate %[[P]] 2 Offset 16
; CHECK-DAG: OpDecorate %[[P]] Block
%P = type { <3 x float>, float, <2 x float> }
@pc = external hidden addrspace(13) externally_initialized global target("spirv.Layout", %P, 24, 0, 12, 16), align 4

@.str.u = private unnamed_addr constant [2 x i8] c"U\00", align 1
@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %u = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %U, 96, 0, 12, 16, 80), 2, 0) @llvm.spv.resource.handlefrombinding.U(i32 0, i32 1, i32 1, i32 0, ptr nonnull @.str.u)
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %i = tail call i32 @llvm.spv.thread.id.i32(i32 0)
  %idx = and i32 %i, 3

; A member by its index.
; CHECK: %[[PB:[0-9]+]] = OpAccessChain %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}}
; CHECK: OpLoad %[[FLOAT]] %[[PB]]
  %pb = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.U(target("spirv.VulkanBuffer", target("spirv.Layout", %U, 96, 0, 12, 16, 80), 2, 0) %u, i32 1)
  %b = load float, ptr addrspace(12) %pb

; An element of the strided array, by a dynamic index: one access chain step,
; straight to the float.
; CHECK: %[[PARR:[0-9]+]] = OpAccessChain %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}}
; CHECK: %[[PELT:[0-9]+]] = OpAccessChain %{{[0-9]+}} %[[PARR]] %{{[0-9]+}}
; CHECK: OpLoad %[[FLOAT]] %[[PELT]]
  %pc_arr = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.U(target("spirv.VulkanBuffer", target("spirv.Layout", %U, 96, 0, 12, 16, 80), 2, 0) %u, i32 2)
  %pe = getelementptr <{ float, target("spirv.Padding", 12) }>, ptr addrspace(12) %pc_arr, i32 %idx
  %e = load float, ptr addrspace(12) %pe

; The same array by a constant byte offset: element 2.
; CHECK: %[[PE2:[0-9]+]] = OpAccessChain %{{[0-9]+}} %[[PARR]] %{{[0-9]+}}
; CHECK: OpLoad %[[FLOAT]] %[[PE2]]
  %pe2 = getelementptr i8, ptr addrspace(12) %pc_arr, i32 32
  %e2 = load float, ptr addrspace(12) %pe2

; The last element, outside the peeled part, by a constant byte offset.
  %pe3 = getelementptr i8, ptr addrspace(12) %pc_arr, i32 48
  %e3 = load float, ptr addrspace(12) %pe3

; A push-constant member.
; CHECK: Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %[[PC]] %{{[0-9]+}}
  %ppb = getelementptr inbounds %P, ptr addrspace(13) @pc, i32 0, i32 1
  %pcb = load float, ptr addrspace(13) %ppb

  %s0 = fadd float %b, %e
  %s1 = fadd float %s0, %e2
  %s2 = fadd float %s1, %e3
  %s3 = fadd float %s2, %pcb
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %s3, ptr addrspace(11) %po
  ret void
}

declare i32 @llvm.spv.thread.id.i32(i32)

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
