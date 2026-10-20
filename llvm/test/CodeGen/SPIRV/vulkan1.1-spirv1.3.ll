; Vulkan 1.1 consumes SPIR-V up to 1.3: a module for it is SPIR-V 1.3, and its
; entry point lists only its Input and Output variables, as SPIR-V before 1.4
; requires.

; RUN: llc -O0 -mtriple=spirv1.3-unknown-vulkan1.1-compute %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.3-unknown-vulkan1.1-compute %s -o - -filetype=obj | spirv-dis | FileCheck %s --check-prefix=VERSION %}
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.3-unknown-vulkan1.1-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.1 %}

; VERSION: ; Version: 1.3
; CHECK-DAG: OpCapability Shader
; CHECK-DAG: OpEntryPoint GLCompute %[[MAIN:[0-9]+]] "main"{{$}}

define void @main() #0 {
entry:
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
