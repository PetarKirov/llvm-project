; The module's `spirv.MemberNames` metadata names a struct's members.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-unknown-vulkan %s -o - -filetype=obj | spirv-val %}

; CHECK-DAG: OpName [[light:%[0-9]+]] "Light"
; CHECK-DAG: OpMemberName [[light]] 0 "gain"
; CHECK-DAG: OpMemberName [[light]] 1 "colour"
; CHECK-DAG: [[light]] = OpTypeStruct
; CHECK-NOT: OpMemberName [[light]] 2
%Light = type { float, <3 x float> }

@light = external hidden addrspace(2) global %Light

define float @gain() {
entry:
  %v = load %Light, ptr addrspace(2) @light
  %g = extractvalue %Light %v, 0
  ret float %g
}

!spirv.MemberNames = !{!0}
!0 = !{%Light poison, !"gain", !"colour"}
