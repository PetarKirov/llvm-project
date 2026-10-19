; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; With the module flag spirv.struct-blocks, a uniform buffer whose contents
; are one struct makes that struct the block, as DXC emits a cbuffer: no
; struct wraps it, so the block's type keeps the struct's name and members,
; and a member is one access-chain index away.

; CHECK-DAG: OpName %[[LIGHT:[0-9]+]] "Light"
; CHECK-DAG: OpDecorate %[[LIGHT]] Block
; CHECK-DAG: OpMemberDecorate %[[LIGHT]] 0 Offset 0
; CHECK-DAG: OpMemberDecorate %[[LIGHT]] 1 Offset 12
; CHECK-DAG: %[[FLOAT:[0-9]+]] = OpTypeFloat 32
; CHECK-DAG: %[[V3:[0-9]+]] = OpTypeVector %[[FLOAT]] 3
; CHECK-DAG: %[[LIGHT]] = OpTypeStruct %[[V3]] %[[FLOAT]]{{$}}
; CHECK-DAG: %[[PTR:[0-9]+]] = OpTypePointer Uniform %[[LIGHT]]
; CHECK-DAG: %[[VAR:[0-9]+]] = OpVariable %[[PTR]] Uniform
; CHECK-DAG: %[[UINT:[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: %[[ONE:[0-9]+]] = OpConstant %[[UINT]] 1{{$}}
; CHECK-NOT: OpTypeStruct %[[LIGHT]]{{$}}
; CHECK: %[[PG:[0-9]+]] = OpAccessChain %{{[0-9]+}} %{{[0-9]+}} %[[ONE]]{{$}}
; CHECK: OpLoad %[[FLOAT]] %[[PG]]

%Light = type { <3 x float>, float }

@.str.u = private unnamed_addr constant [6 x i8] c"light\00", align 1
@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %u = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %Light, 16, 0, 12), 2, 0) @llvm.spv.resource.handlefrombinding.U(i32 0, i32 1, i32 1, i32 0, ptr nonnull @.str.u)
  %pg = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.U(target("spirv.VulkanBuffer", target("spirv.Layout", %Light, 16, 0, 12), 2, 0) %u, i32 1)
  %g = load float, ptr addrspace(12) %pg
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %g, ptr addrspace(11) %po
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"spirv.struct-blocks", i32 1}
