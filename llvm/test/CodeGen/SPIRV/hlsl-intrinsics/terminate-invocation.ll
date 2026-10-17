; `llvm.spv.terminate.invocation` ends the invocation, as GLSL's `discard`
; does: OpTerminateInvocation where SPIR-V 1.6 or SPV_KHR_terminate_invocation
; provides it, and OpKill (with the same meaning) before that. Unlike
; `llvm.spv.discard`, it never demotes to a helper invocation, and nothing
; after it in its block is emitted.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - | FileCheck %s --check-prefixes=CHECK,TERMINATE --implicit-check-not=OpExtension --implicit-check-not=OpDemoteToHelperInvocation
; RUN: llc -verify-machineinstrs -O0 -spirv-ext=+SPV_KHR_terminate_invocation -mtriple=spirv1.5-unknown-vulkan1.2-compute %s -o - | FileCheck %s --check-prefixes=CHECK,TERMINATE,EXTENSION
; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv1.5-unknown-vulkan1.2-compute %s -o - | FileCheck %s --check-prefixes=CHECK,KILL --implicit-check-not=OpTerminateInvocation
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}
; RUN: %if spirv-tools %{ llc -O0 -spirv-ext=+SPV_KHR_terminate_invocation -mtriple=spirv1.5-unknown-vulkan1.2-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.2 %}
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.5-unknown-vulkan1.2-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.2 %}

; EXTENSION: OpExtension "SPV_KHR_terminate_invocation"

; CHECK-LABEL: ; -- Begin function kill
; CHECK:       OpBranchConditional %[[#]] %[[#yes:]] %[[#no:]]
; CHECK:       %[[#yes]] = OpLabel
; TERMINATE-NEXT: OpTerminateInvocation
; KILL-NEXT:   OpKill
; CHECK-NEXT:  %[[#no]] = OpLabel

@g = internal addrspace(10) global float 0.0

define internal void @kill(float %x) {
entry:
  %c = fcmp olt float %x, 0.000000e+00
  br i1 %c, label %yes, label %no

yes:
  call void @llvm.spv.terminate.invocation()
  store volatile float 1.0, ptr addrspace(10) @g, align 4
  br label %no

no:
  ret void
}

define void @main() #0 {
entry:
  %x = load volatile float, ptr addrspace(10) @g, align 4
  call void @kill(float %x)
  ret void
}

declare void @llvm.spv.terminate.invocation()

attributes #0 = { "hlsl.shader"="pixel" }
