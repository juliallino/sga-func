module Main where

import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.Hspec
import IHP.AuthSupport.Authentication (hashPassword)
import qualified Network.HTTP.Types as HTTP
import qualified Network.Wai as Wai
import qualified Network.Wai.Test as WT
import qualified Data.List as List
import System.Environment (lookupEnv)
import Config
import Web.Types
import Web.FrontController ()
import Generated.Types
import Test.Hspec

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]

main :: IO ()
main = do
    isolated <- lookupEnv "SGA_ISOLATED_CRUD_TEST"
    unless (isolated == Just "1") (error "Use Test/run-crud-tests.py: isolated database required")
    withMockContext WebApplication config \context -> do
      app <- initTestApplication context
      withContext (do
        hash <- hashPassword "dashboard-test-only"
        let account email role = newRecord @User |> set #name "Dashboard test" |> set #email email |> set #passwordHash hash |> set #role_ role |> createRecord
        admin <- account "dash-admin@example.test" Roleadmin
        studentUser <- account "dash-student@example.test" Rolestudent
        otherUser <- account "dash-other@example.test" Rolestudent
        teacherUser <- account "dash-teacher@example.test" Roleteacher
        let makeStudent user name number = newRecord @Student |> set #userId (Just (unpackId user.id)) |> set #name name |> set #email user.email |> set #enrollmentNumber number |> createRecord
        student <- makeStudent studentUser "Ana Dashboard" "DASH-1"
        other <- makeStudent otherUser "Bia Privada Dashboard" "DASH-2"
        teacher <- newRecord @Teacher |> set #userId (Just (unpackId teacherUser.id)) |> set #name "Docente Dashboard" |> set #email teacherUser.email |> set #registrationNumber "DASH-T" |> createRecord
        course <- newRecord @Course |> set #name "Curso Dashboard" |> set #code "DASH-C" |> set #workload 60 |> createRecord
        foreignCourse <- newRecord @Course |> set #name "Curso privado Dashboard" |> set #code "DASH-PRIVATE" |> set #workload 60 |> createRecord
        let makeSubject target name code = newRecord @Subject |> set #name name |> set #code code |> set #courseId (unpackId target.id) |> set #workload 30 |> createRecord
        subject <- makeSubject course "Disciplina autorizada Dashboard" "DASH-S1"
        privateSubject <- makeSubject course "Disciplina privada Dashboard" "DASH-S2"
        foreignSubject <- makeSubject foreignCourse "Disciplina de outro curso Dashboard" "DASH-S3"
        permission <- newRecord @TeacherSubject |> set #teacherId (unpackId teacher.id) |> set #subjectId (unpackId subject.id) |> createRecord
        let enroll person target = newRecord @Enrollment |> set #studentId (unpackId person.id) |> set #subjectId (unpackId target.id) |> createRecord
        first <- enroll student subject
        second <- enroll other subject
        _ <- enroll other foreignSubject
        let assess enrollment name score weight = newRecord @Grade |> set #enrollmentId (unpackId enrollment.id) |> set #assessmentName name |> set #score score |> set #weight weight |> createRecord
        _ <- assess first "AV1 dashboard" 7 1
        _ <- assess first "AV2 dashboard" 9 3
        _ <- assess second "AV1 dashboard" 7 1
        _ <- assess second "AV2 dashboard" 7 3
        hspec do
          describe "Dashboard Sprint 4: dados reais e isolamento" do
            it "conta seis entidades usando o PostgreSQL" do
              withUser admin do
                response <- callAction WelcomeAction
                totals <- sequence [query @Student |> fetchCount, query @Teacher |> fetchCount, query @Course |> fetchCount, query @Subject |> fetchCount, query @Enrollment |> fetchCount, query @Grade |> fetchCount]
                forEach (zip ["Estudantes", "Professores", "Cursos", "Disciplinas", "Matrículas", "Avaliações"] totals) \(label,total) ->
                  responseBodyShouldContain response ("aria-label=\"" <> label <> ": " <> show total <> "\"")
            it "renderiza médias e ranking demonstrativo dos grupos comparáveis para Admin" do
              withUser admin do
                response <- callAction WelcomeAction
                responseStatusShouldBe response HTTP.status200
                forEach ["Ranking por disciplina", "8.50", "7.00", "Ana Dashboard", "Bia Privada Dashboard"] (responseBodyShouldContain response)
            it "aplica filtros HTTP combinados e preserva a posição no ranking" do
              response <- getAs app "dash-admin" ("/?studentName=Bia&courseId=" <> cs (show course.id) <> "&status=active&minimum=7&maximum=7")
              WT.simpleStatus response `shouldBe` HTTP.status200
              forEach ["Bia Privada Dashboard", "1 matrículas encontradas", "<td>2</td>"] \fragment ->
                WT.simpleBody response `shouldSatisfy` List.isInfixOf fragment . cs
              WT.simpleBody response `shouldSatisfy` not . List.isInfixOf "Ana Dashboard" . cs
            it "não amplia consulta com filtros inválidos" do
              forEach [("/?courseId=invalid", "Selecione um curso"), ("/?minimum=NaN", "Informe médias válidas"), ("/?minimum=9&maximum=8", "menor ou igual"), ("/?status=other", "situação de matrícula válida"), ("/?studentName=%27%20OR%201%3D1%20--", "0 matrículas encontradas")] \(path, message) -> do
                response <- getAs app "dash-admin" path
                WT.simpleStatus response `shouldBe` HTTP.status200
                WT.simpleBody response `shouldSatisfy` List.isInfixOf message . cs
                WT.simpleBody response `shouldSatisfy` not . List.isInfixOf "Ana Dashboard" . cs
            it "estudante recebe somente resultados e opções próprios, sem ranking" do
              withUser studentUser do
                response <- callAction StudentDashboardAction
                forEach ["Ana Dashboard", "8.50", "Curso Dashboard"] (responseBodyShouldContain response)
                forEach ["Bia Privada Dashboard", "Curso privado Dashboard", "Disciplina privada Dashboard", "Ranking demonstrativo"] (responseBodyShouldNotContain response)
              response <- getAs app "dash-student" ("/StudentDashboard?courseId=" <> cs (show foreignCourse.id))
              WT.simpleBody response `shouldSatisfy` List.isInfixOf "0 matrículas encontradas" . cs
              WT.simpleBody response `shouldSatisfy` not . List.isInfixOf "Bia Privada Dashboard" . cs
            it "professor filtra só disciplinas autorizadas sem acessar matrículas do curso" do
              withUser teacherUser do
                response <- callAction TeacherDashboardAction
                responseBodyShouldContain response "Disciplina autorizada Dashboard"
                forEach ["Disciplina privada Dashboard", "Disciplina de outro curso Dashboard", "Ana Dashboard", "Bia Privada Dashboard", "8.50"] (responseBodyShouldNotContain response)
              response <- getAs app "dash-teacher" ("/TeacherDashboard?subjectId=" <> cs (show privateSubject.id))
              WT.simpleBody response `shouldSatisfy` List.isInfixOf "Nenhuma disciplina encontrada" . cs
              WT.simpleBody response `shouldSatisfy` not . List.isInfixOf "Disciplina privada Dashboard" . cs
            it "filtrar não contorna autenticação ou perfil" do
              response <- WT.runSession (WT.request (WT.setPath Wai.defaultRequest "/?minimum=0")) app
              WT.simpleStatus response `shouldBe` HTTP.status302
              withUser teacherUser do
                callAction StudentDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
              withUser studentUser do
                callAction TeacherDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
            it "revogação remove imediatamente disciplinas e opções do docente" do
              deleteRecord permission
              withUser teacherUser do
                response <- callAction TeacherDashboardAction
                responseBodyShouldNotContain response "Disciplina autorizada Dashboard"
                responseBodyShouldContain response "Nenhuma disciplina encontrada"
        ) context

getAs app account path = WT.runSession (do
    _ <- WT.srequest (WT.SRequest ((WT.setPath Wai.defaultRequest "/Login")
        {Wai.requestMethod = "POST", Wai.requestHeaders = [(HTTP.hContentType, "application/x-www-form-urlencoded")]})
        ("email=" <> account <> "%40example.test&password=dashboard-test-only"))
    WT.request (WT.setPath Wai.defaultRequest path)) app
