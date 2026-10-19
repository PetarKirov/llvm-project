; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; An entry point's interface lists the global variables its call tree uses,
; not every global of the module: a vertex stage's integer input in the
; fragment entry's interface would need a Flat decoration it cannot have.

; CHECK-DAG: OpEntryPoint Vertex %[[VS:[0-9]+]] "vs" %[[VIDX:[0-9]+]] %[[OUT:[0-9]+]]{{$}}
; CHECK-DAG: OpEntryPoint Fragment %[[FS:[0-9]+]] "fs" %[[SHARED:[0-9]+]] %[[IN:[0-9]+]] %[[COLOR:[0-9]+]]{{$}}
; CHECK-DAG: OpName %[[VIDX]] "vidx"
; CHECK-DAG: OpName %[[OUT]] "out"
; CHECK-DAG: OpName %[[IN]] "in"
; CHECK-DAG: OpName %[[COLOR]] "color"
; CHECK-DAG: OpName %[[SHARED]] "shared"

@vidx = external hidden thread_local addrspace(7) externally_initialized constant i32, !spirv.Decorations !1
@out = external hidden thread_local addrspace(8) global <4 x float>, !spirv.Decorations !3
@in = external hidden thread_local addrspace(7) externally_initialized constant <4 x float>, !spirv.Decorations !3
@color = external hidden thread_local addrspace(8) global <4 x float>, !spirv.Decorations !3
@shared = internal addrspace(10) global float 0.0

define void @vs() #0 {
entry:
  %i = load i32, ptr addrspace(7) @vidx
  %f = sitofp i32 %i to float
  %v = insertelement <4 x float> zeroinitializer, float %f, i32 0
  store <4 x float> %v, ptr addrspace(8) @out
  ret void
}

; The fragment entry reaches @shared only through a helper.
define internal spir_func float @helper() {
entry:
  %s = load float, ptr addrspace(10) @shared
  ret float %s
}

define void @fs() #1 {
entry:
  %c = load <4 x float>, ptr addrspace(7) @in
  %s = call spir_func float @helper()
  %v = insertelement <4 x float> %c, float %s, i32 3
  store <4 x float> %v, ptr addrspace(8) @color
  ret void
}

attributes #0 = { "hlsl.shader"="vertex" }
attributes #1 = { "hlsl.shader"="pixel" }

!0 = !{i32 11, i32 42}
!1 = !{!0}
!2 = !{i32 30, i32 0}
!3 = !{!2}
