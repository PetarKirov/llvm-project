; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A member of a buffer whose struct carries explicit offsets (spirv.Layout) is
; reached by its index, as in a buffer laid out by the data layout.

; CHECK-DAG: OpMemberDecorate %[[U:[0-9]+]] 4 Offset 32
; CHECK-DAG: OpMemberDecorate %[[U]] 1 Offset 12
; CHECK-DAG: OpMemberDecorate %[[U]] 3 Offset 24
; CHECK-DAG: %[[FLOAT:[0-9]+]] = OpTypeFloat 32
; CHECK-DAG: %[[U]] = OpTypeStruct %{{[0-9]+}} %[[FLOAT]] %{{[0-9]+}} %[[FLOAT]] %{{[0-9]+}}
%U = type { <3 x float>, float, <2 x float>, float, <4 x float> }

@.str = private unnamed_addr constant [2 x i8] c"U\00", align 1
@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %h = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %U, 48, 0, 12, 16, 24, 32), 2, 0) @llvm.spv.resource.handlefrombinding.L(i32 0, i32 1, i32 1, i32 0, ptr nonnull @.str)
; CHECK: %[[PB:[0-9]+]] = OpAccessChain %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}}
; CHECK: OpLoad %[[FLOAT]] %[[PB]]
  %pb = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.L(target("spirv.VulkanBuffer", target("spirv.Layout", %U, 48, 0, 12, 16, 24, 32), 2, 0) %h, i32 1)
  %b = load float, ptr addrspace(12) %pb
; CHECK: %[[PD:[0-9]+]] = OpAccessChain %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}} %{{[0-9]+}}
; CHECK: OpLoad %[[FLOAT]] %[[PD]]
  %pd = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.L(target("spirv.VulkanBuffer", target("spirv.Layout", %U, 48, 0, 12, 16, 24, 32), 2, 0) %h, i32 3)
  %d = load float, ptr addrspace(12) %pd
  %s = fadd float %b, %d
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %s, ptr addrspace(11) %po
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
