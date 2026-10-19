; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; An optimiser merges the stores that clear a local into one memset. Logical
; SPIR-V has no byte-wise copy, so a memset of a whole object of known type is
; a store of the constant it leaves: its null, or all ones.

; CHECK-NOT: OpCopyMemory
; CHECK-NOT: OpBitcast
; CHECK-DAG: %[[UINT:[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: %[[FOUR:[0-9]+]] = OpConstant %[[UINT]] 4{{$}}
; CHECK-DAG: %[[ARR:[0-9]+]] = OpTypeArray %[[UINT]] %[[FOUR]]
; CHECK-DAG: %[[NULL:[0-9]+]] = OpConstantNull %[[ARR]]
; CHECK-DAG: %[[ONES:[0-9]+]] = OpConstant %[[UINT]] 4294967295
; CHECK-DAG: %[[ALLONES:[0-9]+]] = OpConstantComposite %[[ARR]] %[[ONES]] %[[ONES]] %[[ONES]] %[[ONES]]
; CHECK: OpStore %[[A:[0-9]+]] %[[NULL]]
; CHECK: OpStore %[[B:[0-9]+]] %[[ALLONES]]

@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %a = alloca [4 x i32], align 4
  %b = alloca [4 x i32], align 4
  call void @llvm.memset.p0.i64(ptr align 4 %a, i8 0, i64 16, i1 false)
  call void @llvm.memset.p0.i64(ptr align 4 %b, i8 -1, i64 16, i1 false)
  %tid = tail call i32 @llvm.spv.thread.id.i32(i32 0)
  %i = and i32 %tid, 3
  %pa = getelementptr inbounds [4 x i32], ptr %a, i32 0, i32 %i
  store i32 1, ptr %pa, align 4
  %pa1 = getelementptr inbounds [4 x i32], ptr %a, i32 0, i32 1
  %va = load i32, ptr %pa1, align 4
  %pb = getelementptr inbounds [4 x i32], ptr %b, i32 0, i32 %i
  %vb = load i32, ptr %pb, align 4
  %s = add i32 %va, %vb
  %o = tail call target("spirv.VulkanBuffer", [0 x i32], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x i32], 12, 1) %o, i32 0)
  store i32 %s, ptr addrspace(11) %po
  ret void
}

declare i32 @llvm.spv.thread.id.i32(i32)
declare void @llvm.memset.p0.i64(ptr, i8, i64, i1)

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
