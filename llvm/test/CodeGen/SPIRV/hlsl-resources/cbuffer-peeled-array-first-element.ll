; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}
; RUN: %if spirv-tools %{ llc -O2 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A load from a peeled array's own address reads its element 0, which is one
; index into the array it is: the peeled struct is not walked as the three
; levels of LLVM type it is spelled with.

; CHECK-DAG: %[[FLOAT:[0-9]+]] = OpTypeFloat 32
; CHECK-DAG: %[[UINT:[0-9]+]] = OpTypeInt 32 0
; CHECK-DAG: %[[ZERO:[0-9]+]] = OpConstant %[[UINT]] 0{{$}}
; CHECK-DAG: %[[FOUR:[0-9]+]] = OpConstant %[[UINT]] 4{{$}}
; CHECK-DAG: %[[ARR:[0-9]+]] = OpTypeArray %[[FLOAT]] %[[FOUR]]
; CHECK-DAG: OpDecorate %[[ARR]] ArrayStride 16
; CHECK: %[[PW:[0-9]+]] = OpAccessChain %{{[0-9]+}} %{{[0-9]+}} %[[ZERO]] %[[ZERO]]{{$}}
; CHECK: %[[P0:[0-9]+]] = Op{{(InBounds)?}}AccessChain %{{[0-9]+}} %[[PW]] %[[ZERO]]{{$}}
; CHECK: OpLoad %[[FLOAT]] %[[P0]]

%Peeled = type <{ [3 x <{ float, target("spirv.Padding", 12) }>], float }>
%Block = type <{ %Peeled, target("spirv.Padding", 12), float, target("spirv.Padding", 12) }>

@.str.u = private unnamed_addr constant [2 x i8] c"U\00", align 1
@.str.o = private unnamed_addr constant [4 x i8] c"Out\00", align 1

define void @main() #0 {
entry:
  %u = tail call target("spirv.VulkanBuffer", target("spirv.Layout", %Block, 80, 0, 52, 64, 68), 2, 0) @llvm.spv.resource.handlefrombinding.U(i32 0, i32 1, i32 1, i32 0, ptr nonnull @.str.u)
  %pw = tail call ptr addrspace(12) @llvm.spv.resource.getpointer.p12.U(target("spirv.VulkanBuffer", target("spirv.Layout", %Block, 80, 0, 52, 64, 68), 2, 0) %u, i32 0)
  %a = load float, ptr addrspace(12) %pw
  %o = tail call target("spirv.VulkanBuffer", [0 x float], 12, 1) @llvm.spv.resource.handlefrombinding.O(i32 0, i32 2, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11) @llvm.spv.resource.getpointer.p11.O(target("spirv.VulkanBuffer", [0 x float], 12, 1) %o, i32 0)
  store float %a, ptr addrspace(11) %po
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
