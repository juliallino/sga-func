{-# LANGUAGE OverloadedStrings #-}
module Test.Domain.DashboardSpec where

import Prelude
import Test.Hspec
import Application.Domain.Dashboard

spec :: Spec
spec = do
    describe "Dashboard: médias e agregações puras" do
        it "reutiliza a média ponderada, sem calcular uma média geral" do
            resultAverage weighted `shouldBe` Just 8.5
        it "não transforma ausência ou dados inválidos em zero" do
            resultAverage (sample "1" "Ana" []) `shouldBe` Nothing
            resultAverage (sample "1" "Ana" [("A", 11, 1)]) `shouldBe` Nothing
            resultAverage (sample "1" "Ana" [("A", 8, 0)]) `shouldBe` Nothing
        it "conta matrículas com média válida e avaliações, inclusive listas vazias" do
            validAverageCount [weighted, sample "2" "Bia" []] `shouldBe` 1
            assessmentCount [weighted, sample "2" "Bia" []] `shouldBe` 2
            validAverageCount [] `shouldBe` 0
            assessmentCount [] `shouldBe` 0
    describe "Dashboard: filtros combinados" do
        it "combina nome sem diferenciar caixa, curso e situação" do
            filterResults (emptyFilters {filterName = " ANA ", filterCourse = "course-1", filterStatus = "active"}) [weighted, other] `shouldBe` Right [weighted]
        it "aplica limites inclusivos e exclui médias ausentes" do
            filterResults (emptyFilters {filterMinimum = "8.5", filterMaximum = "8.5"}) [weighted, other, sample "3" "Sem nota" []] `shouldBe` Right [weighted]
        it "rejeita intervalos invertidos, fora da escala, NaN e entradas inválidas" do
            map (parseBounds . (\value -> emptyFilters {filterMinimum = value})) ["-1", "11", "NaN", "Infinity", "abc", "8' OR 1=1"] `shouldSatisfy` all isLeft
            parseBounds (emptyFilters {filterMinimum = "9", filterMaximum = "8"}) `shouldSatisfy` isLeft
        it "não infere uma disciplina pelo curso nem interpreta SQL no nome" do
            filterResults (emptyFilters {filterSubject = "subject-2"}) [weighted] `shouldBe` Right []
            filterResults (emptyFilters {filterSubject = "subject-1"}) [weighted] `shouldBe` Right [weighted]
            filterResults (emptyFilters {filterName = "' OR 1=1 --"}) [weighted] `shouldBe` Right []
        it "trata lista vazia e filtro sem correspondência" do
            filterResults emptyFilters [] `shouldBe` Right []
            filterResults (emptyFilters {filterCourse = "other"}) [weighted] `shouldBe` Right []
    describe "Ranking demonstrativo por grupos comparáveis" do
        it "ordena por média decrescente e preserva posição ao filtrar" do
            let groups = rankingGroups [other, weighted]
            map (map (resultStudentName . rankingResult) . rankingEntries) groups `shouldBe` [["Ana", "Bia"]]
            map (map rankingPosition . rankingEntries) (visibleRankingGroups [other] groups) `shouldBe` [[2]]
        it "desempata por nome e ID de forma independente da ordem de entrada" do
            let ana = sample "a" "Ana" [("A", 8, 1)]
            let ana2 = sample "b" "Ana" [("A", 8, 1)]
            let bia = sample "c" "Bia" [("A", 8, 1)]
            rankingGroups [bia, ana2, ana] `shouldBe` rankingGroups [ana, bia, ana2]
            map (map (resultStudentId . rankingResult) . rankingEntries) (rankingGroups [bia, ana2, ana]) `shouldBe` [["a", "b", "c"]]
        it "separa cursos e admite planos e situações distintos na mesma disciplina" do
            length (rankingGroups [weighted, other {resultCourseId = "different"}]) `shouldBe` 2
            length (rankingGroups [weighted, other {resultStatus = "suspended"}]) `shouldBe` 1
            length (rankingGroups [weighted, sample "2" "Bia" [("A", 8, 1)]]) `shouldBe` 1
            length (rankingGroups [sample "1" "Ana" [("A", 8, 1)], sample "2" "Bia" [("A", 9, 2)]]) `shouldBe` 1
        it "normaliza nomes de avaliações e ignora sua ordem" do
            let a = sample "1" "Ana" [(" AV1 ", 8, 1), ("AV2", 9, 3)]
            let b = sample "2" "Bia" [("av2", 7, 3), ("av1", 9, 1)]
            length (rankingGroups [a,b]) `shouldBe` 1
        it "exclui ausência e vínculo disciplinar desconhecido e preserva empates" do
            rankingGroups [] `shouldBe` []
            map (map rankingPosition . rankingEntries) (rankingGroups [weighted]) `shouldBe` [[1]]
            map (map rankingPosition . rankingEntries) (rankingGroups [weighted, sample "2" "Sem nota" []]) `shouldBe` [[1]]
            map (map rankingPosition . rankingEntries) (rankingGroups [sample "1" "A" [("AV",8,1),("av",9,1)], sample "2" "B" [("AV",8,1),("av",9,1)]]) `shouldBe` [[1,1]]
            rankingGroups [weighted {resultSubjectId = ""}] `shouldBe` []
    where
        isLeft (Left _) = True
        isLeft _ = False
        weighted = sample "1" "Ana" [("A",7,1),("B",9,3)]
        other = sample "2" "Bia" [("A",8,1),("B",8,3)]

sample student name = makeSubjectResult ("enrollment-" <> student) student name "course-1" "Curso" "subject-1" "Disciplina" "active"
