; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv-vulkan-unknown %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-vulkan-unknown %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A push-constant global named by spirv.Name metadata keeps that name when
; the backend rebuilds it as a spirv.PushConstant: its LLVM name, unique in
; the module, is not the one the shader's interface is known by.

%struct.S = type <{ float }>

; CHECK-DAG: OpName %[[#PCS:]] "view"
; CHECK-NOT: OpName %{{.*}} "view.main.push"
; CHECK: %[[#PCS]] = OpVariable %{{[0-9]+}} PushConstant

@view.main.push = external hidden addrspace(13) externally_initialized global %struct.S, align 1, !spirv.Name !0

define void @main() #1 {
entry:
  %0 = call token @llvm.experimental.convergence.entry()
  %1 = alloca float, align 4
  %2 = load float, ptr addrspace(13) @view.main.push, align 1
  store float %2, ptr %1
  ret void
}

declare token @llvm.experimental.convergence.entry() #2

attributes #1 = { convergent noinline norecurse optnone "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
attributes #2 = { convergent nocallback nofree nosync nounwind willreturn memory(none) }

!0 = !{!"view"}
