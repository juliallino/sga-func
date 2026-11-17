{-# LANGUAGE OverloadedStrings #-}
module Test.Domain.AttendanceSpec (spec) where

import Prelude
import Test.Hspec
import Application.Domain.Attendance
import Application.Domain.Academic

spec :: Spec
spec = do
    describe "Frequência por chamada" $ do
        it "conta presenças, aulas e faltas" $ do
            let resumo = resumirFrequencia [True, False, True, True]
            resumo `shouldBe` ResumoFrequencia 3 4
            faltas resumo `shouldBe` 1
            frequencia resumo `shouldBe` Just 75
        it "não transforma ausência de chamadas em 0 %" $ do
            frequencia (resumirFrequencia []) `shouldBe` Nothing
            classificarFrequencia (resumirFrequencia []) `shouldBe` SemAulasRegistradas
            textoFrequencia (resumirFrequencia []) `shouldBe` "Sem chamadas registradas"
        it "aceita exatamente 75 % e recusa abaixo disso" $ do
            classificarFrequencia (ResumoFrequencia 3 4) `shouldBe` FrequenciaRegular
            classificarFrequencia (ResumoFrequencia 15 20) `shouldBe` FrequenciaRegular
            classificarFrequencia (ResumoFrequencia 74 100) `shouldBe` FrequenciaAbaixoDoMinimo
            classificarFrequencia (ResumoFrequencia 2 3) `shouldBe` FrequenciaAbaixoDoMinimo
            frequenciaSuficiente (ResumoFrequencia 0 4) `shouldBe` False
        it "recusa contagens impossíveis" $ do
            frequencia (ResumoFrequencia 5 4) `shouldBe` Nothing
            frequenciaSuficiente (ResumoFrequencia 5 4) `shouldBe` False
            classificarFrequencia (ResumoFrequencia (-1) 4) `shouldBe` SemAulasRegistradas
        it "formata o percentual com uma casa decimal" $ do
            textoFrequencia (ResumoFrequencia 3 4) `shouldBe` "75.0 % (3 de 4 aulas)"
            textoFrequencia (ResumoFrequencia 2 3) `shouldBe` "66.7 % (2 de 3 aulas)"

    describe "Frequência mínima como requisito de aprovação" $ do
        let rule = Just (ApprovalPolicy 6 True)
        it "reprova por frequência a matrícula concluída abaixo de 75 %, mesmo com média alta" $ do
            classifyEnrollment rule True FrequenciaAbaixoDoMinimo (Just 10) `shouldBe` FailedAttendance
            classifyEnrollment Nothing True FrequenciaAbaixoDoMinimo Nothing `shouldBe` FailedAttendance
        it "sinaliza a matrícula em andamento abaixo de 75 % sem reprovar" $
            classifyEnrollment rule False FrequenciaAbaixoDoMinimo (Just 9) `shouldBe` AttendanceBelowMinimum
        it "com frequência regular ou sem chamadas, vale a classificação pela média" $ do
            classifyEnrollment rule True FrequenciaRegular (Just 7) `shouldBe` Approved
            classifyEnrollment rule True FrequenciaRegular (Just 5) `shouldBe` Insufficient
            classifyEnrollment rule True SemAulasRegistradas (Just 7) `shouldBe` Approved
            classifyEnrollment Nothing True FrequenciaRegular (Just 7) `shouldBe` PolicyPending
        it "não conta como aprovado quem está abaixo da frequência mínima" $ do
            performanceWithAttendance rule
                [ (True, FrequenciaRegular, Just 8)
                , (True, FrequenciaAbaixoDoMinimo, Just 9)
                , (True, FrequenciaRegular, Just 4)
                , (False, SemAulasRegistradas, Nothing)
                ]
                `shouldBe` Performance (Just 7) 3 1 (Just 1) (Just 1) (Just 3)
            attendanceBelowMinimumCount [FrequenciaRegular, FrequenciaAbaixoDoMinimo, SemAulasRegistradas]
                `shouldBe` 1
