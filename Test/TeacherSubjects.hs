module Main where

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
import Generated.Types
import Test.Hspec

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]

main :: IO ()
main = do
    isolated <- lookupEnv "SGA_ISOLATED_CRUD_TEST"
    unless (isolated == Just "1") (error "Use the isolated CRUD test runner")
    withMockContext WebApplication config \context -> do
      app <- initTestApplication context
      withContext (do
        hash <- hashPassword "assignment-test-only"
        let account email role = newRecord @User |> set #name "Conta vínculos teste" |> set #email email |> set #passwordHash hash |> set #role_ role |> createRecord
        admin <- account "links-admin@example.test" Roleadmin
        teacherUser <- account "links-teacher@example.test" Roleteacher
        studentUser <- account "links-student@example.test" Rolestudent
        teacher <- newRecord @Teacher |> set #name "Professor vínculos" |> set #registrationNumber "LINK-T1" |> set #email teacherUser.email |> set #userId (Just (unpackId teacherUser.id)) |> createRecord
        student <- newRecord @Student |> set #name "Estudante vínculos" |> set #enrollmentNumber "LINK-S1" |> set #email studentUser.email |> set #userId (Just (unpackId studentUser.id)) |> createRecord
        course <- newRecord @Course |> set #name "Curso vínculos" |> set #code "LINK-C1" |> set #workload 60 |> createRecord
        let subject name code = newRecord @Subject |> set #name name |> set #code code |> set #courseId (unpackId course.id) |> set #workload 30 |> createRecord
        allowed <- subject "Disciplina concedida pelo Admin" "LINK-D1"
        private <- subject "Disciplina sem autorização" "LINK-D2"
        enrollment <- newRecord @Enrollment |> set #studentId (unpackId student.id) |> set #subjectId (unpackId allowed.id) |> createRecord
        grade <- newRecord @Grade |> set #enrollmentId (unpackId enrollment.id) |> set #assessmentName "Avaliação preservada vínculos" |> set #score 8 |> set #weight 2 |> createRecord
        let params = [("teacherId", cs (show teacher.id)), ("subjectId", cs (show allowed.id))]
        hspec do
          describe "Gestão Admin de vínculos professor–disciplina" do
            it "expõe a rota e formulário para Admin sem criar vínculos automaticamente" do
              response <- WaiTest.runSession (do
                _ <- sendRequest HTTP.methodPost "/Login" "email=links-admin%40example.test&password=assignment-test-only"
                sendRequest HTTP.methodGet "/TeacherSubjects" "") app
              WaiTest.simpleStatus response `shouldBe` HTTP.status200
              (cs (WaiTest.simpleBody response) :: Text) `shouldSatisfy` isInfixOf "action=\"/CreateTeacherSubject\""
              query @TeacherSubject |> filterWhere (#teacherId, unpackId teacher.id) |> fetchCount >>= (`shouldBe` 0)
            it "recusa visitantes nas ações de listar, criar e remover" do
              callAction TeacherSubjectsAction >>= (\r -> responseStatusShouldBe r HTTP.status302)
              callActionWithParams CreateTeacherSubjectAction params >>= (\r -> responseStatusShouldBe r HTTP.status302)
              callAction (DeleteTeacherSubjectAction (Id "00000000-0000-0000-0000-000000000001")) >>= (\r -> responseStatusShouldBe r HTTP.status302)
            it "recusa Teacher e Student mesmo por URLs diretas" do
              forEach [teacherUser, studentUser] \user -> withUser user do
                callAction TeacherSubjectsAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callActionWithParams CreateTeacherSubjectAction params >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction (DeleteTeacherSubjectAction (Id "00000000-0000-0000-0000-000000000001")) >>= (\r -> responseStatusShouldBe r HTTP.status403)
              query @TeacherSubject |> filterWhere (#teacherId, unpackId teacher.id) |> fetchCount >>= (`shouldBe` 0)
            it "rejeita dados ausentes, UUID inválido e referências inexistentes" do
              withUser admin do
                forEach [[], [("teacherId", "invalido"), ("subjectId", cs (show allowed.id))], [("teacherId", cs (show teacher.id)), ("subjectId", "00000000-0000-0000-0000-000000000001")], [("teacherId", "00000000-0000-0000-0000-000000000001"), ("subjectId", cs (show allowed.id))]] \invalid -> do
                  response <- callActionWithParams CreateTeacherSubjectAction invalid
                  responseStatusShouldBe response HTTP.status200
                query @TeacherSubject |> filterWhere (#teacherId, unpackId teacher.id) |> fetchCount >>= (`shouldBe` 0)
            it "cria apenas o vínculo explicitamente selecionado via POST e ignora campos extras" do
              response <- WaiTest.runSession (do
                _ <- sendRequest HTTP.methodPost "/Login" "email=links-admin%40example.test&password=assignment-test-only"
                let body = cs (HTTP.renderSimpleQuery False [("teacherId", cs (show teacher.id)), ("subjectId", cs (show allowed.id)), ("role", "RoleAdmin")])
                sendRequest HTTP.methodPost "/CreateTeacherSubject" body) app
              WaiTest.simpleStatus response `shouldBe` HTTP.status302
              query @TeacherSubject |> filterWhere (#teacherId, unpackId teacher.id) |> fetchCount >>= (`shouldBe` 1)
              withUser teacherUser do
                response <- callAction SubjectsAction
                responseBodyShouldContain response allowed.name
                responseBodyShouldNotContain response private.name
                callAction (ShowSubjectAction private.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
            it "recusa duplicidade preservando seletores e registros acadêmicos" do
              withUser admin do
                response <- callActionWithParams CreateTeacherSubjectAction params
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "Este professor já está vinculado"
                responseBodyShouldContain response "Professor vínculos"
                responseBodyShouldContain response "Disciplina concedida pelo Admin"
                query @TeacherSubject |> filterWhere (#teacherId, unpackId teacher.id) |> fetchCount >>= (`shouldBe` 1)
                response <- callAction TeacherSubjectsAction
                responseBodyShouldContain response "LINK-T1"
                responseBodyShouldContain response "LINK-D1"
                responseBodyShouldContain response "LINK-C1"
            it "o vínculo permite lançar notas da disciplina, mas estudante não escreve" do
              withUser teacherUser do
                callActionWithParams CreateGradeAction [("enrollmentId", cs (show enrollment.id)), ("assessmentName", "Nota autorizada"), ("score", "8"), ("weight", "2")] >>= (\r -> responseStatusShouldBe r HTTP.status302)
                callActionWithParams (UpdateGradeAction grade.id) [("score", "8")] >>= (\r -> responseStatusShouldBe r HTTP.status302)
                callAction (DeleteGradeAction grade.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
              withUser studentUser do
                callActionWithParams CreateGradeAction [("enrollmentId", cs (show enrollment.id)), ("score", "10")] >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callActionWithParams (UpdateGradeAction grade.id) [("score", "10")] >>= (\r -> responseStatusShouldBe r HTTP.status403)
                response <- callAction GradesAction
                responseBodyShouldContain response grade.assessmentName
              saved <- fetch grade.id
              saved.score `shouldBe` 8
            it "revoga via DELETE, bloqueia a requisição seguinte e preserva os dados" do
              permission <- query @TeacherSubject |> filterWhere (#teacherId, unpackId teacher.id) |> filterWhere (#subjectId, unpackId allowed.id) |> fetchOne
              -- GET must not revoke permission.
              _ <- WaiTest.runSession (do
                _ <- sendRequest HTTP.methodPost "/Login" "email=links-admin%40example.test&password=assignment-test-only"
                sendRequest HTTP.methodGet ("/DeleteTeacherSubject?teacherSubjectId=" <> cs (show permission.id)) "") app
              fetchOneOrNothing permission.id >>= (`shouldSatisfy` isJust)
              response <- WaiTest.runSession (do
                _ <- sendRequest HTTP.methodPost "/Login" "email=links-admin%40example.test&password=assignment-test-only"
                sendRequest HTTP.methodDelete ("/DeleteTeacherSubject?teacherSubjectId=" <> cs (show permission.id)) "") app
              WaiTest.simpleStatus response `shouldBe` HTTP.status302
              fetchOneOrNothing permission.id >>= (`shouldSatisfy` isNothing)
              withUser teacherUser do
                response <- callAction SubjectsAction
                responseBodyShouldNotContain response allowed.name
                callAction (ShowSubjectAction allowed.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callAction (TeacherSubjectAssessmentsAction allowed.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
              fetchOneOrNothing teacher.id >>= (`shouldSatisfy` isJust)
              fetchOneOrNothing allowed.id >>= (`shouldSatisfy` isJust)
              fetchOneOrNothing enrollment.id >>= (`shouldSatisfy` isJust)
              saved <- fetch grade.id
              saved.score `shouldBe` 8
              saved.weight `shouldBe` 2
              withUser admin do
                callAction (DeleteTeacherSubjectAction permission.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
        ) context

sendRequest :: HTTP.Method -> ByteString -> LByteString -> WaiTest.Session WaiTest.SResponse
sendRequest method path body = WaiTest.srequest (WaiTest.SRequest ((WaiTest.setPath Wai.defaultRequest path)
    { Wai.requestMethod = method, Wai.requestHeaders = [(HTTP.hContentType, "application/x-www-form-urlencoded")] }) body)
