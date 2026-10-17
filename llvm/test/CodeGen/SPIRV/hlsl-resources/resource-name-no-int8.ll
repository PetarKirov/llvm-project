; A resource's name reaches the module as an OpName on its variable. The
; string it is read from is not a value of the program, so it must not be
; materialised as an array of bytes: a Vulkan shader may not declare Int8
; unless the device enables it.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - | FileCheck %s --implicit-check-not="OpCapability Int8" --implicit-check-not="OpTypeInt 8"
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; CHECK: OpName [[buf:%[0-9]+]] "args"
; CHECK: [[buf]] = OpVariable {{%[0-9]+}} StorageBuffer

%args = type { i32 }
@name = private unnamed_addr constant [5 x i8] c"args\00"

define void @main() #0 {
entry:
  %h = call target("spirv.VulkanBuffer", %args, 12, 1) @llvm.spv.resource.handlefrombinding.tspirv.VulkanBuffer_s_argss_12_1t(i32 0, i32 0, i32 1, i32 0, ptr @name)
  %p = call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_s_argss_12_1t.i32(target("spirv.VulkanBuffer", %args, 12, 1) %h, i32 0)
  store i32 7, ptr addrspace(11) %p, align 4
  ret void
}

declare target("spirv.VulkanBuffer", %args, 12, 1) @llvm.spv.resource.handlefrombinding.tspirv.VulkanBuffer_s_argss_12_1t(i32, i32, i32, i32, ptr)
declare ptr addrspace(11) @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_s_argss_12_1t.i32(target("spirv.VulkanBuffer", %args, 12, 1), i32)

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
