; An optimiser writes `p[i]` on a buffer device address as a byte-addressing
; GEP (`getelementptr [4 x i8], p, i` or `getelementptr i8, p, 4 * i`). In a
; module that asks for buffer device addresses (`spirv.physical-storage-buffer`)
; an offset of whole pointees steps the pointer itself, an OpPtrAccessChain
; Element, and only the rest indexes into the pointee; the offset is never
; dropped. Every access through such a pointer is Aligned, as Vulkan
; requires, an aggregate one included.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; CHECK-DAG: [[float:%[0-9]+]] = OpTypeFloat 32
; The pointee of a buffer device address is laid out explicitly.
; CHECK-DAG: OpMemberDecorate [[pair:%[0-9]+]] 1 Offset 4
; CHECK-DAG: [[pair]] = OpTypeStruct [[float]] [[float]]
; CHECK-DAG: [[pfloat:%[0-9]+]] = OpTypePointer PhysicalStorageBufferEXT [[float]]
; CHECK-DAG: [[ppair:%[0-9]+]] = OpTypePointer PhysicalStorageBufferEXT [[pair]]
; CHECK-DAG: [[long:%[0-9]+]] = OpTypeInt 64 0
; CHECK-DAG: [[int:%[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: [[l1:%[0-9]+]] = OpConstant [[long]] 1{{$}}
; CHECK-DAG: [[i1:%[0-9]+]] = OpConstant [[int]] 1{{$}}

; CHECK: [[floats:%[0-9]+]] = OpConvertUToPtr [[pfloat]]
; CHECK: [[i:%[0-9]+]] = OpSConvert [[long]]
; `getelementptr [4 x i8], %floats, %i`: element i.
; CHECK: [[elem:%[0-9]+]] = OpPtrAccessChain [[pfloat]] [[floats]] [[i]]
; CHECK: [[v:%[0-9]+]] = OpLoad [[float]] [[elem]]
; `getelementptr i8, %floats, 4`: element 1.
; CHECK: [[next:%[0-9]+]] = OpPtrAccessChain [[pfloat]] [[floats]] [[l1]]
; CHECK: OpStore [[next]] [[v]]
; CHECK: [[pairs:%[0-9]+]] = OpConvertUToPtr [[ppair]]
; `getelementptr i8, %pairs, 4`: the second field of element 0.
; CHECK: [[second:%[0-9]+]] = OpInBoundsAccessChain [[pfloat]] [[pairs]] [[i1]]
; CHECK: OpStore [[second]] [[v]]
; `getelementptr i8, %pairs, 12`: the second field of element 1.
; CHECK: [[later:%[0-9]+]] = OpPtrAccessChain [[pfloat]] [[pairs]] [[l1]] [[i1]]
; CHECK: OpStore [[later]] [[v]]
; `getelementptr [8 x i8], %pairs, %i`: element i, whole.
; CHECK: [[pairI:%[0-9]+]] = OpPtrAccessChain [[ppair]] [[pairs]] [[i]]
; CHECK: OpLoad [[pair]] [[pairI]] Aligned 4

%args = type { i64, i64 }
%pair = type { float, float }
@name = private unnamed_addr constant [5 x i8] c"args\00"

define void @main() #0 {
entry:
  %h = call target("spirv.VulkanBuffer", %args, 12, 0) @llvm.spv.resource.handlefrombinding.tspirv.VulkanBuffer_s_argss_12_0t(i32 0, i32 0, i32 1, i32 0, ptr @name)
  %slot = call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_s_argss_12_0t.i32(target("spirv.VulkanBuffer", %args, 12, 0) %h, i32 0)
  %addr = load i64, ptr addrspace(11) %slot, align 8
  %floats = inttoptr i64 %addr to ptr addrspace(1)
  call void @llvm.spv.assign.ptr.type.p1(ptr addrspace(1) %floats, metadata float poison, i32 1)
  %i = call i32 @llvm.spv.thread.id.i32(i32 0)
  %i64 = sext i32 %i to i64
  %elem = getelementptr inbounds [4 x i8], ptr addrspace(1) %floats, i64 %i64
  %v = load float, ptr addrspace(1) %elem, align 4
  %next = getelementptr inbounds i8, ptr addrspace(1) %floats, i64 4
  store float %v, ptr addrspace(1) %next, align 4
  %slot2 = call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_s_argss_12_0t.i32(target("spirv.VulkanBuffer", %args, 12, 0) %h, i32 1)
  %addr2 = load i64, ptr addrspace(11) %slot2, align 8
  %pairs = inttoptr i64 %addr2 to ptr addrspace(1)
  call void @llvm.spv.assign.ptr.type.p1(ptr addrspace(1) %pairs, metadata %pair poison, i32 1)
  %second = getelementptr inbounds i8, ptr addrspace(1) %pairs, i64 4
  store float %v, ptr addrspace(1) %second, align 4
  %later = getelementptr inbounds i8, ptr addrspace(1) %pairs, i64 12
  store float %v, ptr addrspace(1) %later, align 4
  %pairI = getelementptr inbounds [8 x i8], ptr addrspace(1) %pairs, i64 %i64
  %whole = load %pair, ptr addrspace(1) %pairI, align 4
  %x = extractvalue %pair %whole, 0
  store float %x, ptr addrspace(1) %floats, align 4
  ret void
}

declare target("spirv.VulkanBuffer", %args, 12, 0) @llvm.spv.resource.handlefrombinding.tspirv.VulkanBuffer_s_argss_12_0t(i32, i32, i32, i32, ptr)
declare ptr addrspace(11) @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_s_argss_12_0t.i32(target("spirv.VulkanBuffer", %args, 12, 0), i32)
declare i32 @llvm.spv.thread.id.i32(i32)
declare void @llvm.spv.assign.ptr.type.p1(ptr addrspace(1), metadata, i32 immarg)

attributes #0 = { "hlsl.numthreads"="64,1,1" "hlsl.shader"="compute" }

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"spirv.physical-storage-buffer", i32 1}
