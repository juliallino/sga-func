module Main where

import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.Hspec
import IHP.AuthSupport.Authentication (hashPassword, verifyPassword)
import qualified Network.HTTP.Types as HTTP
import qualified Network.Wai as Wai
import qualified Network.Wai.Test as WaiTest
import System.Environment (lookupEnv)
import Config
import Web.Types
import Web.FrontController ()
import Generated.Types
import Test.Hspec
import Control.Monad (replicateM_)
import qualified Data.List as List
import qualified Prelude

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]

main :: IO ()
main = do
    isolated <- lookupEnv "SGA_ISOLATED_CRUD_TEST"
    unless (isolated == Just "1") (error "Use python3 Test/run-crud-tests.py (isolated database required)")
    withMockContext WebApplication config \context -> do
      app <- initTestApplication context
      withContext (do
        hash <- hashPassword "auth-test-only-password"
        let createAccount email role = newRecord @User |> set #name "Conta de teste isolado" |> set #email email |> set #passwordHash hash |> set #role_ role |> createRecord
        admin <- createAccount "auth-admin@example.test" Roleadmin
        studentUser <- createAccount "auth-student@example.test" Rolestudent
        otherStudentUser <- createAccount "auth-other-student@example.test" Rolestudent
        teacherUser <- createAccount "auth-teacher@example.test" Roleteacher
        unlinkedUser <- createAccount "auth-unlinked@example.test" Rolestudent
        lockedUser <- createAccount "auth-lock@example.test" Roleadmin
        let createStudent user name number = newRecord @Student |> set #userId (Just (unpackId user.id)) |> set #name name |> set #email user.email |> set #enrollmentNumber number |> createRecord
        student <- createStudent studentUser "Estudante permitido AUTH" "AUTH-1"
        otherStudent <- createStudent otherStudentUser "Estudante privado AUTH" "AUTH-2"
        teacher <- newRecord @Teacher |> set #userId (Just (unpackId teacherUser.id)) |> set #name "Professor AUTH" |> set #email teacherUser.email |> set #registrationNumber "AUTH-T" |> createRecord
        course <- newRecord @Course |> set #name "Curso AUTH" |> set #code "AUTH-C" |> set #workload 60 |> createRecord
        let createSubject name code = newRecord @Subject |> set #name name |> set #code code |> set #workload 30 |> set #courseId (unpackId course.id) |> createRecord
        subject <- createSubject "Disciplina autorizada AUTH" "AUTH-S1"
        otherSubject <- createSubject "Disciplina privada AUTH" "AUTH-S2"
        permission <- newRecord @TeacherSubject |> set #teacherId (unpackId teacher.id) |> set #subjectId (unpackId subject.id) |> createRecord
        let createEnrollment student = newRecord @Enrollment |> set #studentId (unpackId student.id) |> set #courseId (unpackId course.id) |> createRecord
        enrollment <- createEnrollment student
        otherEnrollment <- createEnrollment otherStudent
        let createGrade enrollment name = newRecord @Grade |> set #enrollmentId (unpackId enrollment.id) |> set #assessmentName name |> set #score 8 |> set #weight 1 |> createRecord
        grade <- createGrade enrollment "Avaliação permitida AUTH"
        otherGrade <- createGrade otherEnrollment "Avaliação privada AUTH"
        hspec do
          describe "Autenticação e sessões IHP 1.6" do
            it "armazena hash verificável, diferente da senha" do
              hash `shouldNotBe` "auth-test-only-password"
              verifyPassword studentUser "auth-test-only-password" `shouldBe` True
              verifyPassword studentUser "senha incorreta" `shouldBe` False
            it "redireciona visitantes nas seis listagens privadas" do
              forEach ["/Students", "/Teachers", "/Courses", "/Subjects", "/Enrollments", "/Grades"] \path -> do
                response <- WaiTest.runSession (WaiTest.request (WaiTest.setPath Wai.defaultRequest path)) app
                WaiTest.simpleStatus response `shouldBe` HTTP.status302
            it "bloqueia visitante também em requisições diretas de escrita" do
              response <- callActionWithParams CreateGradeAction [("assessmentName", "invasao"), ("score", "10"), ("weight", "1"), ("enrollmentId", cs (show enrollment.id))]
              responseStatusShouldBe response HTTP.status302
            it "faz login, usa cookie e invalida o acesso após logout" do
              responses <- WaiTest.runSession (do
                login <- post "/Login" "email=auth-admin%40example.test&password=auth-test-only-password"
                private <- WaiTest.request (WaiTest.setPath Wai.defaultRequest "/Students")
                logout <- post "/Logout" ""
                denied <- WaiTest.request (WaiTest.setPath Wai.defaultRequest "/Students")
                pure (map WaiTest.simpleStatus [login,private,logout,denied])) app
              responses `shouldBe` [HTTP.status303, HTTP.status200, HTTP.status303, HTTP.status302]
            it "não autentica senha inválida" do
              response <- WaiTest.runSession (do
                _ <- post "/Login" "email=auth-admin%40example.test&password=errada"
                WaiTest.request (WaiTest.setPath Wai.defaultRequest "/Students")) app
              WaiTest.simpleStatus response `shouldBe` HTTP.status302
            it "bloqueia login após dez falhas, inclusive com a senha correta" do
              replicateM_ 10 do
                response <- callActionWithParams CreateSessionAction [("email", "auth-lock@example.test"), ("password", "incorreta")]
                responseStatusShouldBe response HTTP.status302
              locked <- fetch lockedUser.id
              locked.failedLoginAttempts `shouldBe` 10
              locked.lockedAt `shouldSatisfy` isJust
              response <- WaiTest.runSession (do
                _ <- post "/Login" "email=auth-lock%40example.test&password=auth-test-only-password"
                WaiTest.request (WaiTest.setPath Wai.defaultRequest "/Students")) app
              WaiTest.simpleStatus response `shouldBe` HTTP.status302
          describe "Admin" do
            it "mantém acesso às listagens e a registros de qualquer estudante" do
              withUser admin do
                forEach [StudentsAction] \action -> callAction action >>= (\response -> responseStatusShouldBe response HTTP.status200)
                callAction (ShowStudentAction otherStudent.id) >>= (\response -> responseStatusShouldBe response HTTP.status200)
                callAction (ShowGradeAction otherGrade.id) >>= (\response -> responseStatusShouldBe response HTTP.status200)
                response <- callAction SubjectsAction
                responseBodyShouldContain response "Disciplina autorizada AUTH"
                responseBodyShouldContain response "Disciplina privada AUTH"
          describe "Portal acadêmico por perfil" do
            it "mostra contagens reais do PostgreSQL apenas no dashboard Admin" do
              withUser admin do
                response <- callAction WelcomeAction
                responseStatusShouldBe response HTTP.status200
                students <- query @Student |> fetchCount
                teachers <- query @Teacher |> fetchCount
                courses <- query @Course |> fetchCount
                subjects <- query @Subject |> fetchCount
                enrollments <- query @Enrollment |> fetchCount
                forEach [("Estudantes", students), ("Professores", teachers), ("Cursos", courses), ("Disciplinas", subjects), ("Matrículas", enrollments)] \(label, total) ->
                  responseBodyShouldContain response ("aria-label=\"" <> label <> ": " <> cs (show total) <> "\"")
                responseBodyShouldContain response "href=\"/Users\""
                responseBodyShouldContain response "action=\"/Logout\""
            it "estudante possui menu próprio, perfil e médias sem expor terceiros" do
              withUser studentUser do
                response <- callAction WelcomeAction
                responseBodyShouldContain response "Minhas médias"
                responseBodyShouldNotContain response "href=\"/Users\""
                responseBodyShouldNotContain response "href=\"/Teachers\""
                responseBodyShouldNotContain response "Estudante privado AUTH"
                profile <- callAction MyProfileAction
                responseBodyShouldContain profile "Estudante permitido AUTH"
                averages <- callAction StudentAveragesAction
                responseBodyShouldContain averages "8.00"
                responseBodyShouldNotContain averages "Avaliação privada AUTH"
                callAction UsersAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction TeacherStudentsAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
            it "estudante não recebe links de criação, edição ou exclusão de avaliações" do
              withUser studentUser do
                response <- callAction GradesAction
                responseBodyShouldNotContain response "NewGrade"
                responseBodyShouldNotContain response "EditGrade"
                responseBodyShouldNotContain response "DeleteGrade"
                response <- callAction (ShowEnrollmentAction enrollment.id)
                responseBodyShouldNotContain response "EditGrade"
            it "professor tem menu próprio sem atalhos administrativos ou novas permissões" do
              withUser teacherUser do
                response <- callAction WelcomeAction
                responseBodyShouldContain response "Disciplinas sob minha responsabilidade"
                responseBodyShouldNotContain response "href=\"/Users\""
                response <- callAction SubjectsAction
                responseBodyShouldNotContain response "NewSubject"
                responseBodyShouldNotContain response "EditSubject"
                responseBodyShouldNotContain response "DeleteSubject"
                callAction StudentAveragesAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction UsersAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                availability <- callAction TeacherAssessmentsAction
                responseBodyShouldContain availability "indisponível"
            it "consulta administrativa de usuários nunca mostra hash de senha" do
              withUser admin do
                response <- callAction UsersAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "auth-admin@example.test"
                responseBodyShouldNotContain response (cs hash)
                responseBodyShouldNotContain response "auth-test-only-password"
          describe "Student" do
            it "lista somente seu cadastro, suas matrículas e suas notas" do
              withUser studentUser do
                response <- callAction StudentsAction
                responseBodyShouldContain response "Estudante permitido AUTH"
                responseBodyShouldNotContain response "Estudante privado AUTH"
                response <- callAction EnrollmentsAction
                responseBodyShouldContain response (show enrollment.id)
                responseBodyShouldNotContain response (show otherEnrollment.id)
                response <- callAction GradesAction
                responseBodyShouldContain response "Avaliação permitida AUTH"
                responseBodyShouldNotContain response "Avaliação privada AUTH"
            it "consulta a própria matrícula com avaliações e média" do
              withUser studentUser do
                response <- callAction (ShowEnrollmentAction enrollment.id)
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "Avaliação permitida AUTH"
                responseBodyShouldContain response "8.0"
                responseBodyShouldNotContain response "Avaliação privada AUTH"
            it "não acessa outro estudante, matrícula ou avaliação trocando UUID" do
              withUser studentUser do
                callAction (ShowStudentAction otherStudent.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callAction (ShowEnrollmentAction otherEnrollment.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callAction (ShowGradeAction otherGrade.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
            it "não modifica notas, mesmo enviando perfil administrativo" do
              withUser studentUser do
                forEach [CreateGradeAction, UpdateGradeAction grade.id, DeleteGradeAction grade.id] \action -> do
                  response <- callActionWithParams action [("role", "RoleAdmin"), ("score", "10"), ("enrollmentId", cs (show enrollment.id))]
                  responseStatusShouldBe response HTTP.status403
                saved <- fetch grade.id
                saved.score `shouldBe` 8
            it "nega acesso acadêmico a conta sem vínculo de estudante" do
              withUser unlinkedUser do
                callAction StudentsAction >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callAction GradesAction >>= (\r -> responseStatusShouldBe r HTTP.status404)
          describe "Teacher" do
            it "consulta somente disciplinas explicitamente autorizadas" do
              withUser teacherUser do
                response <- callAction SubjectsAction
                responseBodyShouldContain response "Disciplina autorizada AUTH"
                responseBodyShouldNotContain response "Disciplina privada AUTH"
                callAction (ShowSubjectAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status200)
                callAction (ShowSubjectAction otherSubject.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
            it "não obtém acesso a alunos ou notas legados pelo mesmo curso" do
              withUser teacherUser do
                callAction StudentsAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction (ShowGradeAction grade.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction NewGradeAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction (UpdateGradeAction grade.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction (EditSubjectAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
            it "protege exclusão de professor/disciplina com autorização" do
              withUser admin do
                callAction (DeleteTeacherAction teacher.id) >>= (\r -> responseStatusShouldBe r HTTP.status302)
                callAction (DeleteSubjectAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status302)
                fetchOneOrNothing teacher.id >>= (`shouldSatisfy` isJust)
                fetchOneOrNothing subject.id >>= (`shouldSatisfy` isJust)
            it "banco rejeita autorização duplicada e professor/disciplina inexistentes" do
              unsafeSqlExecDiscardResult "INSERT INTO teacher_subjects (teacher_id,subject_id) VALUES (?,?)" (unpackId teacher.id, unpackId subject.id) `shouldThrow` (\(err :: HasqlError) -> List.isInfixOf "23505" (Prelude.show err))
              unsafeSqlExecDiscardResult "INSERT INTO teacher_subjects (teacher_id,subject_id) VALUES ('00000000-0000-0000-0000-000000000001',?)" (Only (unpackId subject.id)) `shouldThrow` (\(err :: HasqlError) -> List.isInfixOf "23503" (Prelude.show err))
              unsafeSqlExecDiscardResult "INSERT INTO teacher_subjects (teacher_id,subject_id) VALUES (?,'00000000-0000-0000-0000-000000000001')" (Only (unpackId teacher.id)) `shouldThrow` (\(err :: HasqlError) -> List.isInfixOf "23503" (Prelude.show err))
            it "revogação bloqueia a requisição seguinte" do
              deleteRecord permission
              withUser teacherUser do
                response <- callAction SubjectsAction
                responseBodyShouldNotContain response "Disciplina autorizada AUTH"
                callAction (ShowSubjectAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
        ) context

post :: ByteString -> LByteString -> WaiTest.Session WaiTest.SResponse
post path body = WaiTest.srequest (WaiTest.SRequest ((WaiTest.setPath Wai.defaultRequest path)
    { Wai.requestMethod = "POST", Wai.requestHeaders = [(HTTP.hContentType, "application/x-www-form-urlencoded")] }) body)
