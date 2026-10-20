; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; Two structs with the same members stay two types when their members are
; named (spirv.MemberNames): each id carries its own OpName and
; OpMemberNames. Structs without member names still merge.

; CHECK-DAG: OpName %[[A:[0-9]+]] "A"
; CHECK-DAG: OpMemberName %[[A]] 0 "a"
; CHECK-DAG: OpName %[[B:[0-9]+]] "B"
; CHECK-DAG: OpMemberName %[[B]] 0 "b"
; CHECK-DAG: %[[FLOAT:[0-9]+]] = OpTypeFloat 32
; CHECK-DAG: %[[A]] = OpTypeStruct %[[FLOAT]] %[[FLOAT]] %[[FLOAT]] %[[FLOAT]]{{$}}
; CHECK-DAG: %[[B]] = OpTypeStruct %[[FLOAT]] %[[FLOAT]] %[[FLOAT]] %[[FLOAT]]{{$}}
; CHECK-NOT: OpName %[[A]] "B"
; CHECK-NOT: OpName %[[B]] "A"

%A = type { float, float, float, float }
%B = type { float, float, float, float }

@.str.a = private unnamed_addr constant [2 x i8] c"x\00", align 1
@.str.b = private unnamed_addr constant [2 x i8] c"y\00", align 1
@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %ha = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %A, 16, 0, 4, 8, 12), 2, 0) @llvm.spv.resource.handlefrombinding.A(i32 0, i32 1, i32 1, i32 0, ptr nonnull @.str.a)
  %pa = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.A(target("spirv.VulkanBuffer", target("spirv.Layout", %A, 16, 0, 4, 8, 12), 2, 0) %ha, i32 0)
  %a = load float, ptr addrspace(12) %pa
  %hb = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %B, 16, 0, 4, 8, 12), 2, 0) @llvm.spv.resource.handlefrombinding.B(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.b)
  %pb = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.B(target("spirv.VulkanBuffer", target("spirv.Layout", %B, 16, 0, 4, 8, 12), 2, 0) %hb, i32 0)
  %b = load float, ptr addrspace(12) %pb
  %s = fadd float %a, %b
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 3, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %s, ptr addrspace(11) %po
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }

!llvm.module.flags = !{!0}
!spirv.MemberNames = !{!1, !2}
!0 = !{i32 1, !"spirv.struct-blocks", i32 1}
!1 = !{%A poison, !"a"}
!2 = !{%B poison, !"b"}
