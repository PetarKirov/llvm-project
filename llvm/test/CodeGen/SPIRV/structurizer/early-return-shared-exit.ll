; Early returns from nested conditions all land in one block, the function's
; exit, which so has four predecessors: `if (x < 0 || y < 0) return 0;
; if (x > 1 && y > 1) return 1; return 0.5;` as an optimiser leaves it. Each
; selection needs its own merge block; none may leave another's construct
; except through its merge.

; RUN: llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv1.6-unknown-vulkan1.3-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; CHECK-LABEL: ; -- Begin function mask
; CHECK:      OpSelectionMerge %[[#exit:]] None
; CHECK-NEXT: OpBranchConditional %[[#]] %[[#]] %[[#a:]]
; CHECK:      %[[#a]] = OpLabel
; CHECK:      OpSelectionMerge %[[#amerge:]] None
; CHECK-NEXT: OpBranchConditional %[[#]] %[[#]] %[[#b:]]
; CHECK:      %[[#b]] = OpLabel
; CHECK:      OpSelectionMerge %[[#bmerge:]] None
; CHECK:      %[[#bmerge]] = OpLabel
; CHECK-NOT:  OpLabel
; CHECK:      OpBranch %[[#amerge]]
; CHECK:      %[[#amerge]] = OpLabel
; CHECK-NOT:  OpLabel
; CHECK:      OpBranch %[[#exit]]
; CHECK:      %[[#exit]] = OpLabel
; CHECK:      OpReturnValue

@in = internal addrspace(10) global <2 x float> zeroinitializer
@out = internal addrspace(10) global float 0.0

define internal float @mask(<2 x float> %p) {
entry:
  %x = extractelement <2 x float> %p, i64 0
  %c0 = fcmp olt float %x, 0.000000e+00
  br i1 %c0, label %exit, label %oror

oror:
  %y = extractelement <2 x float> %p, i64 1
  %c1 = fcmp olt float %y, 0.000000e+00
  br i1 %c1, label %exit, label %endif

endif:
  %c2 = fcmp ogt float %x, 1.000000e+00
  br i1 %c2, label %andand, label %exit

andand:
  %c3 = fcmp ogt float %y, 1.000000e+00
  %s = select i1 %c3, float 1.000000e+00, float 5.000000e-01
  br label %exit

exit:
  %r = phi float [ 0.000000e+00, %oror ], [ 0.000000e+00, %entry ], [ 5.000000e-01, %endif ], [ %s, %andand ]
  ret float %r
}

define void @main() #0 {
entry:
  %p = load <2 x float>, ptr addrspace(10) @in, align 8
  %r = call float @mask(<2 x float> %p)
  store float %r, ptr addrspace(10) @out, align 4
  ret void
}

attributes #0 = { "hlsl.shader"="pixel" }
