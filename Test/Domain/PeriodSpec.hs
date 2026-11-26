{-# LANGUAGE OverloadedStrings #-}
module Test.Domain.PeriodSpec (spec) where

import Prelude
import Test.Hspec
import Data.Time.Calendar (fromGregorian)
import Application.Domain.Period

spec :: Spec
spec = do
    describe "Períodos letivos" $ do
        it "aceita apenas ano.semestre (1 ou 2), ignorando espaços" $ do
            validarNomePeriodo " 2026.1 " `shouldBe` Right "2026.1"
            validarNomePeriodo "2026.2" `shouldBe` Right "2026.2"
            mapM_ (\nome -> validarNomePeriodo nome `shouldSatisfy` either (const True) (const False))
                ["2026", "2026.3", "26.1", "2026/1", "2026.1.1", "abcd.1", ""]
        it "exige término depois do início e início no ano do período" $ do
            validarDatasPeriodo "2026.1" (fromGregorian 2026 2 2) (fromGregorian 2026 6 30) `shouldBe` Right ()
            validarDatasPeriodo "2026.1" (fromGregorian 2026 6 30) (fromGregorian 2026 6 30)
                `shouldBe` Left "A data de término deve ser posterior à data de início."
            validarDatasPeriodo "2026.2" (fromGregorian 2025 8 1) (fromGregorian 2025 12 15)
                `shouldBe` Left "A data de início deve estar no ano do período."
        it "detecta sobreposição de datas, inclusive no mesmo dia" $ do
            let primeiro = (fromGregorian 2026 2 2, fromGregorian 2026 6 30)
            periodosSobrepostos primeiro (fromGregorian 2026 8 3, fromGregorian 2026 12 18) `shouldBe` False
            periodosSobrepostos primeiro (fromGregorian 2026 6 30, fromGregorian 2026 12 18) `shouldBe` True
            periodosSobrepostos primeiro (fromGregorian 2026 3 1, fromGregorian 2026 4 1) `shouldBe` True
        it "sugere o período em andamento, senão o último iniciado" $ do
            let periodos =
                    [ ("2026.1" :: String, (fromGregorian 2026 2 2, fromGregorian 2026 6 30))
                    , ("2026.2", (fromGregorian 2026 8 3, fromGregorian 2026 12 18))
                    ]
            periodoAtual (fromGregorian 2026 11 26) periodos `shouldBe` Just "2026.2"
            periodoAtual (fromGregorian 2026 7 15) periodos `shouldBe` Just "2026.1"
            periodoAtual (fromGregorian 2025 12 1) periodos `shouldBe` Nothing
