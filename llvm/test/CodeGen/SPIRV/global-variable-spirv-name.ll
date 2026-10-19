; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-library %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A shader's interface is named by its source, and one name can denote several
; variables: a vertex stage's output and the fragment input it feeds, in one
; module. LLVM gives each global a unique name, so a frontend states the SPIR-V
; name in `spirv.Name` metadata, and OpName takes it.

; CHECK-DAG: OpName %[[OUT:[0-9]+]] "colour"
; CHECK-DAG: OpName %[[IN:[0-9]+]] "colour"
; CHECK-DAG: OpName %[[PLAIN:[0-9]+]] "plain"
; CHECK-DAG: %[[OUT]] = OpVariable %{{[0-9]+}} Output
; CHECK-DAG: %[[IN]] = OpVariable %{{[0-9]+}} Input
; CHECK-NOT: OpName {{.*}} "colour.vertex.out"

@colour.vertex.out = external hidden thread_local addrspace(8) global <4 x float>, !spirv.Name !0, !spirv.Decorations !2
@colour = external hidden thread_local addrspace(7) externally_initialized constant <4 x float>, !spirv.Name !0, !spirv.Decorations !2
@plain = external hidden thread_local addrspace(8) global <4 x float>, !spirv.Decorations !4

define void @vs() #0 {
entry:
  store <4 x float> zeroinitializer, ptr addrspace(8) @colour.vertex.out
  ret void
}

define void @fs() #1 {
entry:
  %c = load <4 x float>, ptr addrspace(7) @colour
  store <4 x float> %c, ptr addrspace(8) @plain
  ret void
}

attributes #0 = { "hlsl.shader"="vertex" }
attributes #1 = { "hlsl.shader"="pixel" }

!0 = !{!"colour"}
!1 = !{i32 30, i32 0}
!2 = !{!1}
!3 = !{i32 30, i32 0}
!4 = !{!3}
