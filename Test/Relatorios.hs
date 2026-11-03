module Main where

-- Integração da Sprint 4: relatórios/dashboard (HTML e JSON). Roda no banco temporário criado por
-- python3 Test/run-crud-tests.py, depois das demais suítes; os dados usam o
-- prefixo REL para não colidir com elas.

import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.Hspec
import IHP.AuthSupport.Authentication (hashPassword)
import qualified Network.HTTP.Types as HTTP
import qualified Network.Wai as Wai
import qualified Network.Wai.Test as WaiTest
import System.Environment (lookupEnv)
import Config
import Web.Types
import Web.FrontController ()
import Web.Controller.Reports ()
import Generated.Types
import Test.Hspec

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]

main :: IO ()
main = do
    isolated <- lookupEnv "SGA_ISOLATED_CRUD_TEST"
    unless (isolated == Just "1") (error "Use python3 Test/run-crud-tests.py (isolated database required)")
    withMockContext WebApplication config \context -> do
      app <- initTestApplication context
      withContext (do
        hash <- hashPassword "rel-test-only-password"
        let createAccount email role = newRecord @User |> set #name "Conta de relatório" |> set #email email |> set #passwordHash hash |> set #role_ role |> createRecord
        admin <- createAccount "rel-admin@example.test" Roleadmin
        studentUser <- createAccount "rel-student@example.test" Rolestudent
        cursoA <- newRecord @Course |> set #name "Curso REL A" |> set #code "REL-A" |> set #workload 60 |> createRecord
        cursoB <- newRecord @Course |> set #name "Curso REL B" |> set #code "REL-B" |> set #workload 60 |> createRecord
        let createStudent name email number = newRecord @Student |> set #name name |> set #email email |> set #enrollmentNumber number |> createRecord
        alfa <- createStudent "Aluna Alfa REL" "rel-alfa@example.test" "REL-1"
        beta <- createStudent "Aluno Beta REL" "rel-beta@example.test" "REL-2"
        gama <- createStudent "Aluna Gama REL" "rel-gama@example.test" "REL-3"
        let createEnrollment student course = newRecord @Enrollment |> set #studentId (unpackId student.id) |> set #courseId (unpackId course.id) |> createRecord
        enrollmentAlfa <- createEnrollment alfa cursoA
        enrollmentBeta <- createEnrollment beta cursoA
        enrollmentGama <- createEnrollment gama cursoB
        let createGrade enrollment score = newRecord @Grade |> set #enrollmentId (unpackId enrollment.id) |> set #assessmentName "Avaliação REL" |> set #score score |> set #weight 1 |> createRecord
        _ <- createGrade enrollmentAlfa 9
        _ <- createGrade enrollmentBeta 7
        _ <- createGrade enrollmentGama 10
        hspec do
          describe "Relatórios e dashboard (Sprint 4)" do
            it "redireciona visitantes para o login" do
              forEach ["/Reports", "/ReportsData"] \path -> do
                response <- WaiTest.runSession (WaiTest.request (WaiTest.setPath Wai.defaultRequest path)) app
                WaiTest.simpleStatus response `shouldBe` HTTP.status302
            it "nega o relatório a quem não é Admin" do
              withUser studentUser do
                forEach [DashboardAction, DashboardDataAction] \action -> do
                  response <- callAction action
                  responseStatusShouldBe response HTTP.status403
            it "entrega o JSON com resumo, ranking, cursos e distribuição" do
              withUser admin do
                response <- callAction DashboardDataAction
                responseStatusShouldBe response HTTP.status200
                forEach ["\"resumo\"", "\"ranking\"", "\"porCurso\"", "\"distribuicao\"", "Aluna Alfa REL", "Curso REL A"] \trecho ->
                  responseBodyShouldContain response trecho
            it "filtra por curso" do
              withUser admin do
                response <- callActionWithParams DashboardDataAction [("courseId", cs (show cursoB.id))]
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "Aluna Gama REL"
                responseBodyShouldNotContain response "Aluna Alfa REL"
                responseBodyShouldNotContain response "Aluno Beta REL"
            it "filtra por média mínima" do
              withUser admin do
                response <- callActionWithParams DashboardDataAction [("courseId", cs (show cursoA.id)), ("minAverage", "8")]
                responseBodyShouldContain response "Aluna Alfa REL"
                responseBodyShouldNotContain response "Aluno Beta REL"
            it "limita o ranking ao parâmetro top" do
              withUser admin do
                response <- callActionWithParams DashboardDataAction [("courseId", cs (show cursoA.id)), ("top", "1")]
                responseBodyShouldContain response "Aluna Alfa REL"
                responseBodyShouldNotContain response "Aluno Beta REL"
            it "rejeita filtros inválidos no servidor com 422 e lista os campos" do
              withUser admin do
                response <- callActionWithParams DashboardDataAction [("minAverage", "abc"), ("top", "0"), ("status", "zzz")]
                responseStatusShouldBe response (HTTP.mkStatus 422 "Unprocessable Entity")
                forEach ["minAverage", "top", "status"] \campo ->
                  responseBodyShouldContain response campo
            it "renderiza o dashboard HTML com filtros e ranking" do
              withUser admin do
                response <- callAction DashboardAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "Relatórios de desempenho"
                responseBodyShouldContain response "name=\"minAverage\""
                responseBodyShouldContain response "Aluna Alfa REL"
            it "mostra o erro de validação no HTML sem derrubar a página" do
              withUser admin do
                response <- callActionWithParams DashboardAction [("minAverage", "99")]
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "A média mínima deve ser um número entre 0 e 10."
            it "oferece o dashboard no menu do Admin" do
              withUser admin do
                response <- callAction WelcomeAction
                responseBodyShouldContain response "href=\"/Reports\""
        ) context
