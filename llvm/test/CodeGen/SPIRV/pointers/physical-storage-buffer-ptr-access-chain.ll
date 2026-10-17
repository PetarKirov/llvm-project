; In a shader module that asks for buffer device addresses (the module flag
; `spirv.physical-storage-buffer`), a GEP that offsets a PhysicalStorageBuffer
; pointer, `p[i]`, is an OpPtrAccessChain on a pointer type decorated with its
; ArrayStride, never the in-bounds variant (which needs the Addresses
; capability). A GEP whose first index is a constant zero, a field of the
; pointee, stays an OpAccessChain without that index.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - | FileCheck %s --implicit-check-not=OpInBoundsPtrAccessChain --implicit-check-not="OpCapability Addresses"
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; CHECK-DAG: OpCapability PhysicalStorageBufferAddressesEXT
; CHECK-DAG: OpDecorate [[pfloat:%[0-9]+]] ArrayStride 4
; CHECK-DAG: OpDecorate [[ppair:%[0-9]+]] ArrayStride 8
; CHECK-DAG: [[float:%[0-9]+]] = OpTypeFloat 32
; CHECK-DAG: [[pair:%[0-9]+]] = OpTypeStruct [[float]] [[float]]
; CHECK-DAG: [[pfloat]] = OpTypePointer PhysicalStorageBufferEXT [[float]]
; CHECK-DAG: [[ppair]] = OpTypePointer PhysicalStorageBufferEXT [[pair]]
; CHECK-DAG: [[int:%[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: [[one:%[0-9]+]] = OpConstant [[int]] 1{{$}}

; CHECK: [[base:%[0-9]+]] = OpConvertUToPtr [[pfloat]]
; CHECK: [[i:%[0-9]+]] = OpSConvert
; CHECK: OpPtrAccessChain [[pfloat]] [[base]] [[i]]
; CHECK: OpPtrAccessChain [[pfloat]] [[base]] {{%[0-9]+}}
; CHECK: [[pairs:%[0-9]+]] = OpConvertUToPtr [[ppair]]
; CHECK: OpInBoundsAccessChain [[pfloat]] [[pairs]] [[one]]

%args = type { i64, i64 }
%pair = type { float, float }
@name = private unnamed_addr constant [5 x i8] c"args\00"

define void @main() #0 {
entry:
  %h = call target("spirv.VulkanBuffer", %args, 12, 0) @llvm.spv.resource.handlefrombinding.tspirv.VulkanBuffer_s_argss_12_0t(i32 0, i32 0, i32 1, i32 0, ptr @name)
  %slot = call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_s_argss_12_0t.i32(target("spirv.VulkanBuffer", %args, 12, 0) %h, i32 0)
  %addr = load i64, ptr addrspace(11) %slot, align 8
  %base = inttoptr i64 %addr to ptr addrspace(1)
  call void @llvm.spv.assign.ptr.type.p1(ptr addrspace(1) %base, metadata float poison, i32 1)
  %i = call i32 @llvm.spv.thread.id.i32(i32 0)
  %i64 = sext i32 %i to i64
  %elem = getelementptr inbounds float, ptr addrspace(1) %base, i64 %i64
  %v = load float, ptr addrspace(1) %elem, align 4
  %next = getelementptr float, ptr addrspace(1) %base, i64 1
  store float %v, ptr addrspace(1) %next, align 4
  %slot2 = call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_s_argss_12_0t.i32(target("spirv.VulkanBuffer", %args, 12, 0) %h, i32 1)
  %addr2 = load i64, ptr addrspace(11) %slot2, align 8
  %pairs = inttoptr i64 %addr2 to ptr addrspace(1)
  call void @llvm.spv.assign.ptr.type.p1(ptr addrspace(1) %pairs, metadata %pair poison, i32 1)
  %second = getelementptr inbounds %pair, ptr addrspace(1) %pairs, i64 0, i32 1
  store float %v, ptr addrspace(1) %second, align 4
  ret void
}

declare target("spirv.VulkanBuffer", %args, 12, 0) @llvm.spv.resource.handlefrombinding.tspirv.VulkanBuffer_s_argss_12_0t(i32, i32, i32, i32, ptr)
declare ptr addrspace(11) @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_s_argss_12_0t.i32(target("spirv.VulkanBuffer", %args, 12, 0), i32)
declare i32 @llvm.spv.thread.id.i32(i32)
declare void @llvm.spv.assign.ptr.type.p1(ptr addrspace(1), metadata, i32 immarg)

attributes #0 = { "hlsl.numthreads"="64,1,1" "hlsl.shader"="compute" }

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"spirv.physical-storage-buffer", i32 1}
