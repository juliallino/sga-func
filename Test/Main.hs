module Main where

import Test.Hspec
import IHP.Prelude
import qualified Test.Domain.GradeSpec as GradeSpec
import qualified Test.Domain.DashboardSpec as DashboardSpec
import qualified Test.Domain.MonadsSpec as MonadsSpec
import qualified Test.Domain.FunctorsLazySpec as FunctorsLazySpec
import qualified Test.Domain.EnrollmentCPSSpec as EnrollmentCPSSpec
import qualified Test.SecuritySpec as SecuritySpec
import qualified Test.Domain.AcademicSpec as AcademicSpec

-- Import your test specs here:
-- import Test.MySpec

main :: IO ()
main = hspec do
    GradeSpec.spec
    DashboardSpec.spec
    MonadsSpec.spec
    FunctorsLazySpec.spec
    EnrollmentCPSSpec.spec
    SecuritySpec.spec
    AcademicSpec.spec
    describe "Example" do
        it "should pass" do
            1 + 1 `shouldBe` (2 :: Int)
