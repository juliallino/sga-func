module Main where

import Test.Hspec
import IHP.Prelude

import qualified Test.Domain.GradeSpec as GradeSpec
import qualified Test.Domain.ErroSpec as ErroSpec
import qualified Test.Domain.ValidationSpec as ValidationSpec
import qualified Test.Domain.ReportSpec as ReportSpec

main :: IO ()
main = hspec do
    GradeSpec.spec
    ErroSpec.spec
    ValidationSpec.spec
    ReportSpec.spec

    describe "Example" do
        it "should pass" do
            1 + 1 `shouldBe` (2 :: Int)
