//===- TargetLoweringObjectFileTest.cpp -----------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Target/TargetLoweringObjectFile.h"
#include "llvm/AsmParser/Parser.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/BinaryFormat/Wasm.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/MCSectionWasm.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Target/TargetMachine.h"
#include "gtest/gtest.h"

using namespace llvm;

namespace {

// One TargetMachine lowers two modules in turn, as a compiler that emits one
// object per module does. A global the first module names in llvm.used must
// not stay retained once the object file lowering is initialized for the
// second module.
class TLOFUsedTest : public testing::Test {
protected:
  static constexpr const char *UsedIR = R"(
@a = global i32 1
@llvm.used = appending global [1 x ptr] [ptr @a], section "llvm.metadata"
)";

  static void SetUpTestCase() {
    InitializeAllTargetInfos();
    InitializeAllTargets();
    InitializeAllTargetMCs();
  }

  std::unique_ptr<TargetMachine> createTM(StringRef TripleName) {
    Triple TT(TripleName);
    std::string Error;
    const Target *T = TargetRegistry::lookupTarget(TT, Error);
    if (!T)
      return nullptr;
    return std::unique_ptr<TargetMachine>(
        T->createTargetMachine(TT, "", "", TargetOptions(), std::nullopt));
  }

  std::unique_ptr<Module> parse(StringRef IR, const TargetMachine &TM) {
    SMDiagnostic Err;
    std::unique_ptr<Module> M = parseAssemblyString(IR, Err, Ctx);
    if (M) {
      M->setTargetTriple(TM.getTargetTriple());
      M->setDataLayout(TM.createDataLayout());
    }
    return M;
  }

  std::unique_ptr<MCContext> createMC(const TargetMachine &TM) {
    auto MC = std::make_unique<MCContext>(
        TM.getTargetTriple(), TM.getMCAsmInfo(), TM.getMCRegisterInfo(),
        TM.getMCSubtargetInfo());
    MC->setObjectFileInfo(TM.getObjFileLowering());
    return MC;
  }

  // Lowers the first module, then initializes the lowering for the second,
  // and returns the section the first module's used global gets, before and
  // after.
  std::pair<MCSection *, MCSection *> sectionsOfUsedGlobal(TargetMachine &TM) {
    std::unique_ptr<Module> A = parse(UsedIR, TM);
    std::unique_ptr<Module> B = parse("@b = global i32 2\n", TM);
    EXPECT_TRUE(A && B);
    if (!A || !B)
      return {nullptr, nullptr};

    TargetLoweringObjectFile &TLOF = *TM.getObjFileLowering();
    const GlobalVariable *GA = A->getNamedGlobal("a");

    std::unique_ptr<MCContext> MCA = createMC(TM);
    TLOF.initialize(*MCA, TM, *A);
    MCSection *Before = TLOF.SectionForGlobal(GA, TM);

    std::unique_ptr<MCContext> MCB = createMC(TM);
    TLOF.initialize(*MCB, TM, *B);
    MCSection *After = TLOF.SectionForGlobal(GA, TM);
    return {Before, After};
  }

  LLVMContext Ctx;
};

TEST_F(TLOFUsedTest, ELF) {
  std::unique_ptr<TargetMachine> TM = createTM("x86_64-unknown-linux-gnu");
  if (!TM)
    GTEST_SKIP() << "X86 target not built";
  auto [Before, After] = sectionsOfUsedGlobal(*TM);
  ASSERT_TRUE(Before && After);
  EXPECT_TRUE(static_cast<MCSectionELF *>(Before)->getFlags() &
              ELF::SHF_GNU_RETAIN);
  EXPECT_FALSE(static_cast<MCSectionELF *>(After)->getFlags() &
               ELF::SHF_GNU_RETAIN);
}

TEST_F(TLOFUsedTest, Wasm) {
  std::unique_ptr<TargetMachine> TM = createTM("wasm32-unknown-wasi");
  if (!TM)
    GTEST_SKIP() << "WebAssembly target not built";
  auto [Before, After] = sectionsOfUsedGlobal(*TM);
  ASSERT_TRUE(Before && After);
  EXPECT_TRUE(static_cast<MCSectionWasm *>(Before)->getSegmentFlags() &
              wasm::WASM_SEG_FLAG_RETAIN);
  EXPECT_FALSE(static_cast<MCSectionWasm *>(After)->getSegmentFlags() &
               wasm::WASM_SEG_FLAG_RETAIN);
}

} // namespace
