; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A struct's OpName is its spirv.TypeNames name where it has one: two LLVM
; types, which LLVM must name apart, are both the shader's `Inner` -- the
; block, and the copy without the Block decoration that is a member of
; another block.

; CHECK-DAG: OpName %[[ROOT:[0-9]+]] "Inner"
; CHECK-DAG: OpName %[[MEMBER:[0-9]+]] "Inner"
; CHECK-DAG: OpName %[[OUTER:[0-9]+]] "Outer"
; CHECK-DAG: OpDecorate %[[ROOT]] Block
; CHECK-DAG: %[[OUTER]] = OpTypeStruct %[[MEMBER]] %{{[0-9]+}}{{$}}
; CHECK-NOT: OpName %{{[0-9]+}} "Inner.
; CHECK-NOT: OpDecorate %[[MEMBER]] Block

%Inner.block = type <{ float }>
%Inner.member = type <{ float }>
%Outer = type <{ %Inner.member, float }>

@.str.a = private unnamed_addr constant [2 x i8] c"a\00", align 1
@.str.b = private unnamed_addr constant [2 x i8] c"b\00", align 1
@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %ha = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %Inner.block, 4, 0), 2, 0) @llvm.spv.resource.handlefrombinding.A(i32 0, i32 1, i32 1, i32 0, ptr nonnull @.str.a)
  %pa = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.A(target("spirv.VulkanBuffer", target("spirv.Layout", %Inner.block, 4, 0), 2, 0) %ha, i32 0)
  %a = load float, ptr addrspace(12) %pa
  %hb = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %Outer, 8, 0, 4), 2, 0) @llvm.spv.resource.handlefrombinding.B(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.b)
  %pb = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.B(target("spirv.VulkanBuffer", target("spirv.Layout", %Outer, 8, 0, 4), 2, 0) %hb, i32 1)
  %b = load float, ptr addrspace(12) %pb
  %s = fadd float %a, %b
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 3, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %s, ptr addrspace(11) %po
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }

!llvm.module.flags = !{!0}
!spirv.TypeNames = !{!1, !2}
!spirv.MemberNames = !{!3, !4, !5}
!0 = !{i32 1, !"spirv.struct-blocks", i32 1}
!1 = !{%Inner.block poison, !"Inner"}
!2 = !{%Inner.member poison, !"Inner"}
!3 = !{%Inner.block poison, !"gain"}
!4 = !{%Inner.member poison, !"gain"}
!5 = !{%Outer poison, !"inner", !"k"}
