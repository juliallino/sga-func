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
import qualified Data.ByteString.Lazy as LBS
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
        unlinkedTeacher <- createAccount "auth-unlinked-teacher@example.test" Roleteacher
        emptyStudentUser <- createAccount "auth-empty@example.test" Rolestudent
        lockedUser <- createAccount "auth-lock@example.test" Roleadmin
        let createStudent user name number = newRecord @Student |> set #userId (Just (unpackId user.id)) |> set #name name |> set #email user.email |> set #enrollmentNumber number |> createRecord
        student <- createStudent studentUser "Estudante permitido AUTH" "AUTH-1"
        _ <- createStudent emptyStudentUser "Estudante sem matrículas" "AUTH-EMPTY"
        otherStudent <- createStudent otherStudentUser "Estudante privado AUTH" "AUTH-2"
        teacher <- newRecord @Teacher |> set #userId (Just (unpackId teacherUser.id)) |> set #name "Professor AUTH" |> set #email teacherUser.email |> set #registrationNumber "AUTH-T" |> createRecord
        course <- newRecord @Course |> set #name "Curso AUTH" |> set #code "AUTH-C" |> set #workload 60 |> createRecord
        let createSubject name code = newRecord @Subject |> set #name name |> set #code code |> set #workload 30 |> set #courseId (unpackId course.id) |> createRecord
        subject <- createSubject "Disciplina autorizada AUTH" "AUTH-S1"
        otherSubject <- createSubject "Disciplina privada AUTH" "AUTH-S2"
        permission <- newRecord @TeacherSubject |> set #teacherId (unpackId teacher.id) |> set #subjectId (unpackId subject.id) |> createRecord
        let createEnrollment student subject = newRecord @Enrollment |> set #studentId (unpackId student.id) |> set #subjectId (unpackId subject.id) |> createRecord
        enrollment <- createEnrollment student subject
        otherEnrollment <- createEnrollment otherStudent otherSubject
        let createGrade enrollment name = newRecord @Grade |> set #enrollmentId (unpackId enrollment.id) |> set #assessmentName name |> set #score 8 |> set #weight 1 |> createRecord
        grade <- createGrade enrollment "Avaliação permitida AUTH"
        otherGrade <- createGrade otherEnrollment "Avaliação privada AUTH"
        hspec do
          describe "Autenticação e sessões IHP 1.6" do
            it "armazena hash verificável, diferente da senha" do
              (hash /= "auth-test-only-password") `shouldBe` True
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
            it "redireciona cada perfil ao próprio dashboard e encerra sua sessão" do
              forEach [("email=auth-admin%40example.test&password=auth-test-only-password", "/"), ("email=auth-teacher%40example.test&password=auth-test-only-password", "/TeacherDashboard"), ("email=auth-student%40example.test&password=auth-test-only-password", "/StudentDashboard")] \(credentials, dashboard) -> do
                (login, home, logout, denied) <- WaiTest.runSession (do
                  -- A stored private return URL must not override the role portal.
                  _ <- WaiTest.request (WaiTest.setPath Wai.defaultRequest "/Courses")
                  login <- post "/Login" credentials
                  home <- WaiTest.request (WaiTest.setPath Wai.defaultRequest dashboard)
                  logout <- post "/Logout" ""
                  denied <- WaiTest.request (WaiTest.setPath Wai.defaultRequest dashboard)
                  pure (login, home, logout, denied)) app
                WaiTest.simpleStatus login `shouldBe` HTTP.status303
                lookup HTTP.hLocation (WaiTest.simpleHeaders login) `shouldBe` Just ("http://localhost" <> dashboard)
                WaiTest.simpleStatus home `shouldBe` HTTP.status200
                WaiTest.simpleStatus logout `shouldBe` HTTP.status303
                lookup HTTP.hLocation (WaiTest.simpleHeaders logout) `shouldBe` Just "http://localhost/Login"
                WaiTest.simpleStatus denied `shouldBe` HTTP.status302
            it "protege todas as páginas dos portais contra visitantes" do
              forEach ["/", "/TeacherDashboard", "/TeacherProfile", "/TeacherStudents", "/TeacherAssessments", "/TeacherGradeEntry", "/StudentDashboard", "/MyProfile", "/MySubjects", "/MyAverages"] \path -> do
                response <- WaiTest.runSession (WaiTest.request (WaiTest.setPath Wai.defaultRequest path)) app
                WaiTest.simpleStatus response `shouldBe` HTTP.status302
            it "nega URLs administrativas e escrita de notas aos dois perfis acadêmicos" do
              forEach ["email=auth-student%40example.test&password=auth-test-only-password"] \credentials -> do
                responses <- WaiTest.runSession (do
                  _ <- post "/Login" credentials
                  reads <- forM ["/Users", "/Teachers", "/Courses", "/NewStudent", "/NewTeacher", "/NewCourse", "/NewSubject", "/NewEnrollment", "/NewGrade", "/EditGrade?gradeId=" <> cs (show grade.id)] \path ->
                    WaiTest.request (WaiTest.setPath Wai.defaultRequest path)
                  creates <- post "/CreateGrade" ("assessmentName=Invasao&score=10&weight=99&enrollmentId=" <> cs (show enrollment.id))
                  updates <- post ("/UpdateGrade?gradeId=" <> cs (show grade.id)) "score=10&weight=99"
                  pure (reads <> [creates, updates])) app
                map WaiTest.simpleStatus responses `shouldBe` replicate 12 HTTP.status403
              saved <- fetch grade.id
              saved.score `shouldBe` grade.score
              saved.weight `shouldBe` grade.weight
            it "contas sem vínculo recebem orientação sem dados acadêmicos" do
              forEach [("email=auth-unlinked%40example.test&password=auth-test-only-password", "/StudentDashboard"), ("email=auth-unlinked-teacher%40example.test&password=auth-test-only-password", "/TeacherDashboard")] \(credentials, dashboard) -> do
                (response, logout) <- WaiTest.runSession (do
                  _ <- post "/Login" credentials
                  response <- WaiTest.request (WaiTest.setPath Wai.defaultRequest dashboard)
                  logout <- post "/Logout" ""
                  pure (response, logout)) app
                WaiTest.simpleStatus response `shouldBe` HTTP.status404
                WaiTest.simpleBody response `shouldSatisfy` List.isInfixOf "Vínculo acadêmico pendente" . cs
                WaiTest.simpleBody response `shouldSatisfy` not . List.isInfixOf "Avaliação permitida AUTH" . cs
                WaiTest.simpleStatus logout `shouldBe` HTTP.status303
              withUser unlinkedTeacher do
                response <- callAction SubjectsAction
                responseStatusShouldBe response HTTP.status404
                responseBodyShouldContain response "Solicite à administração"
            it "estudante não acessa dados de terceiros por URLs reais" do
              responses <- WaiTest.runSession (do
                _ <- post "/Login" "email=auth-student%40example.test&password=auth-test-only-password"
                forM ["/ShowStudent?studentId=" <> cs (show otherStudent.id), "/ShowEnrollment?enrollmentId=" <> cs (show otherEnrollment.id), "/ShowGrade?gradeId=" <> cs (show otherGrade.id)] \path ->
                  WaiTest.request (WaiTest.setPath Wai.defaultRequest path)) app
              map WaiTest.simpleStatus responses `shouldBe` replicate 3 HTTP.status404
            it "formulários exibem validação e confirmação de atualização na sessão Admin" do
              (invalid, updated, confirmation) <- WaiTest.runSession (do
                _ <- post "/Login" "email=auth-admin%40example.test&password=auth-test-only-password"
                invalid <- post "/CreateGrade" ("assessmentName=&score=11&weight=0&enrollmentId=" <> cs (show enrollment.id))
                let body = cs (HTTP.renderSimpleQuery False [("assessmentName", cs grade.assessmentName), ("score", "8"), ("weight", "1"), ("enrollmentId", cs (show enrollment.id))])
                updated <- post ("/UpdateGrade?gradeId=" <> cs (show grade.id)) body
                confirmation <- WaiTest.request (WaiTest.setPath Wai.defaultRequest ("/EditGrade?gradeId=" <> cs (show grade.id)))
                pure (invalid, updated, confirmation)) app
              WaiTest.simpleStatus invalid `shouldBe` HTTP.status200
              forEach ["Informe o nome da avaliação", "A nota deve estar entre 0 e 10", "O peso deve permanecer positivo"] \message ->
                WaiTest.simpleBody invalid `shouldSatisfy` List.isInfixOf message . cs
              WaiTest.simpleStatus updated `shouldBe` HTTP.status302
              WaiTest.simpleBody confirmation `shouldSatisfy` List.isInfixOf "Nota atualizada com sucesso" . cs
            it "não autentica senha inválida" do
              response <- WaiTest.runSession (do
                _ <- post "/Login" "email=auth-admin%40example.test&password=errada"
                WaiTest.request (WaiTest.setPath Wai.defaultRequest "/Students")) app
              WaiTest.simpleStatus response `shouldBe` HTTP.status302
            it "não autentica uma conta inexistente" do
              response <- WaiTest.runSession (do
                _ <- post "/Login" "email=missing%40example.test&password=security-test-only"
                WaiTest.request (WaiTest.setPath Wai.defaultRequest "/Students")) app
              WaiTest.simpleStatus response `shouldBe` HTTP.status302
            it "mantém HttpOnly e SameSite no cookie de autenticação" do
              response <- WaiTest.runSession
                (post "/Login" "email=auth-admin%40example.test&password=auth-test-only-password") app
              let cookies = [value | (name, value) <- WaiTest.simpleHeaders response, name == "Set-Cookie"]
              (not (null cookies)) `shouldBe` True
              (any (List.isInfixOf "HttpOnly" . cs) cookies) `shouldBe` True
              (any (List.isInfixOf "SameSite=Lax" . cs) cookies) `shouldBe` True
            it "não renderiza hashes na listagem administrativa" do
              response <- WaiTest.runSession (do
                _ <- post "/Login" "email=auth-admin%40example.test&password=auth-test-only-password"
                WaiTest.request (WaiTest.setPath Wai.defaultRequest "/Users")) app
              WaiTest.simpleStatus response `shouldBe` HTTP.status200
              (List.isInfixOf (cs hash :: String) (cs (WaiTest.simpleBody response))) `shouldBe` False
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
          describe "Sprint 4: interfaces SSR" do
            it "exporta amostras SSR quando solicitado para inspeção visual" do
              target <- lookupEnv "SGA_INTERFACE_SNAPSHOTS"
              case target of
                Nothing -> pure ()
                Just directory -> do
                  forEach [("admin.html", "auth-admin", "/"), ("form.html", "auth-admin", "/NewStudent"), ("teacher.html", "auth-teacher", "/TeacherStudents"), ("student.html", "auth-student", "/StudentDashboard")] \(filename, account, path) -> do
                    response <- WaiTest.runSession (do
                      _ <- post "/Login" ("email=" <> account <> "%40example.test&password=auth-test-only-password")
                      WaiTest.request (WaiTest.setPath Wai.defaultRequest path)) app
                    WaiTest.simpleStatus response `shouldBe` HTTP.status200
                    LBS.writeFile (directory <> "/" <> filename) (WaiTest.simpleBody response)
            it "renderiza listagens, formulários e detalhes administrativos" do
              responses <- WaiTest.runSession (do
                _ <- post "/Login" "email=auth-admin%40example.test&password=auth-test-only-password"
                forM ["/", "/Students", "/Teachers", "/Courses", "/Subjects", "/Enrollments", "/Grades", "/Users", "/TeacherSubjects", "/NewStudent", "/NewTeacher", "/NewCourse", "/NewSubject", "/NewEnrollment", "/NewGrade", "/EditStudent?studentId=" <> cs (show student.id), "/EditTeacher?teacherId=" <> cs (show teacher.id), "/EditCourse?courseId=" <> cs (show course.id), "/EditSubject?subjectId=" <> cs (show subject.id), "/EditEnrollment?enrollmentId=" <> cs (show enrollment.id), "/EditGrade?gradeId=" <> cs (show grade.id), "/ShowStudent?studentId=" <> cs (show student.id), "/ShowTeacher?teacherId=" <> cs (show teacher.id), "/ShowCourse?courseId=" <> cs (show course.id), "/ShowSubject?subjectId=" <> cs (show subject.id), "/ShowEnrollment?enrollmentId=" <> cs (show enrollment.id), "/ShowGrade?gradeId=" <> cs (show grade.id)] \path ->
                  WaiTest.request (WaiTest.setPath Wai.defaultRequest path)) app
              forEach responses \response -> do
                WaiTest.simpleStatus response `shouldBe` HTTP.status200
                forEach ["lang=\"pt-BR\"", "id=\"main-content\"", "aria-controls=\"portal-sidebar\"", "name=\"viewport\""] \fragment ->
                  WaiTest.simpleBody response `shouldSatisfy` List.isInfixOf fragment . cs
            it "mantém telas docentes distintas sem divulgar estudantes e avaliações legados" do
              withUser teacherUser do
                forEach [(TeacherStudentsAction, "Meus estudantes"), (TeacherAssessmentsAction, "Consulta de avaliações"), (TeacherGradeEntryAction, "Lançamento de notas")] \(action, title) -> do
                  response <- callAction action
                  responseStatusShouldBe response HTTP.status200
                  responseBodyShouldContain response ("<h1>" <> title <> "</h1>")
                  responseBodyShouldContain response "Disciplina autorizada AUTH"
                  responseBodyShouldNotContain response "Disciplina privada AUTH"
                  responseBodyShouldNotContain response "Estudante permitido AUTH"
                  responseBodyShouldNotContain response "Avaliação permitida AUTH"
              withUser studentUser do
                callAction TeacherGradeEntryAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
              withUser admin do
                callAction TeacherGradeEntryAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
            it "detalhes próprios mostram contexto acadêmico sem ações administrativas" do
              withUser studentUser do
                response <- callAction (ShowGradeAction grade.id)
                responseBodyShouldContain response "Estudante permitido AUTH"
                responseBodyShouldContain response "Curso AUTH"
                responseBodyShouldNotContain response "Estudante privado AUTH"
                responseBodyShouldNotContain response "EditGrade"
                profile <- callAction MyProfileAction
                responseBodyShouldContain profile "Voltar ao início"
                responseBodyShouldNotContain profile "href=\"/Students\""
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
                home <- callAction WelcomeAction
                responseStatusShouldBe home HTTP.status302
                response <- callAction StudentDashboardAction
                responseBodyShouldContain response "Minhas médias"
                responseBodyShouldContain response "AUTH-1"
                responseBodyShouldContain response "8.00"
                responseBodyShouldNotContain response "AUTH-2"
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
                home <- callAction WelcomeAction
                responseStatusShouldBe home HTTP.status302
                response <- callAction TeacherDashboardAction
                responseBodyShouldContain response "Disciplinas sob minha responsabilidade"
                responseBodyShouldContain response "Professor AUTH"
                responseBodyShouldContain response "Estudantes matriculados"
                responseBodyShouldContain response "Avaliações cadastradas"
                responseBodyShouldContain response "Disciplinas"
                responseBodyShouldNotContain response "Estudante permitido AUTH"
                profile <- callAction TeacherProfileAction
                responseBodyShouldContain profile "AUTH-T"
                responseBodyShouldNotContain response "href=\"/Users\""
                response <- callAction SubjectsAction
                responseBodyShouldNotContain response "NewSubject"
                responseBodyShouldNotContain response "EditSubject"
                responseBodyShouldNotContain response "DeleteSubject"
                callAction StudentDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction StudentAveragesAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction UsersAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                availability <- callAction TeacherAssessmentsAction
                responseBodyShouldContain availability "Disciplina autorizada AUTH"
            it "dashboard e perfil docente recusam outros perfis e visitantes" do
              withUser studentUser do
                callAction TeacherDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction TeacherProfileAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
              withUser admin do
                callAction TeacherDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
              response <- callAction TeacherDashboardAction
              responseStatusShouldBe response HTTP.status302
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
          describe "Consultas acadêmicas do estudante" do
            it "exibe cursos reais sem inferir disciplinas do curso" do
              withUser studentUser do
                response <- callAction StudentSubjectsAction
                responseBodyShouldContain response "Disciplina autorizada AUTH"
                responseBodyShouldContain response "AUTH-S1"
                responseBodyShouldContain response "30 h"
                responseBodyShouldContain response "Situação da matrícula"
                responseBodyShouldContain response "Disciplina autorizada AUTH"
                responseBodyShouldNotContain response "Disciplina privada AUTH"
                responseBodyShouldNotContain response "AUTH-2"
            it "agrupa notas próprias por matrícula e explicita o escopo das médias" do
              withUser studentUser do
                notes <- callAction GradesAction
                responseBodyShouldContain notes "Disciplina autorizada AUTH"
                responseBodyShouldContain notes "Avaliação permitida AUTH"
                responseBodyShouldNotContain notes "Avaliação privada AUTH"
                averages <- callAction StudentAveragesAction
                responseBodyShouldContain averages "8.00"
                responseBodyShouldContain averages "Médias ponderadas por matrícula em disciplina"
            it "trata estudante sem matrículas ou avaliações" do
              withUser emptyStudentUser do
                forEach [StudentSubjectsAction, StudentAveragesAction] \action -> do
                  response <- callAction action
                  responseBodyShouldContain response "Você ainda não possui matrículas"
                notes <- callAction GradesAction
                responseBodyShouldContain notes "Você ainda não possui matrículas"
                responseBodyShouldNotContain notes "Avaliação permitida AUTH"
                responseBodyShouldNotContain notes "Avaliação privada AUTH"
            it "nega edição direta de notas, pesos e matrículas" do
              withUser studentUser do
                callAction (EditGradeAction grade.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callActionWithParams (UpdateGradeAction grade.id) [("score", "10"), ("weight", "99")] >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction (EditEnrollmentAction enrollment.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callActionWithParams (UpdateEnrollmentAction enrollment.id) [("status", "completed")] >>= (\r -> responseStatusShouldBe r HTTP.status403)
                unchanged <- fetch grade.id
                unchanged.score `shouldBe` grade.score
                unchanged.weight `shouldBe` grade.weight
                unchangedEnrollment <- fetch enrollment.id
                unchangedEnrollment.status `shouldBe` enrollment.status
            it "protege disciplinas e médias contra visitantes e contas sem vínculo" do
              forEach [StudentSubjectsAction, StudentAveragesAction] \action -> do
                callAction action >>= (\r -> responseStatusShouldBe r HTTP.status302)
                withUser unlinkedUser do
                  callAction action >>= (\r -> responseStatusShouldBe r HTTP.status404)
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
                callAction (ShowGradeAction otherGrade.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callAction NewGradeAction >>= (\r -> responseStatusShouldBe r HTTP.status200)
                callAction (UpdateGradeAction otherGrade.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction (EditSubjectAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
            it "protege exclusão de professor/disciplina com autorização" do
              withUser admin do
                callAction (DeleteTeacherAction teacher.id) >>= (\r -> responseStatusShouldBe r HTTP.status302)
                callAction (DeleteSubjectAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status302)
                fetchOneOrNothing teacher.id >>= (`shouldSatisfy` isJust)
                fetchOneOrNothing subject.id >>= (`shouldSatisfy` isJust)
            it "seleção de disciplina verifica autorização em ambos os fluxos" do
              withUser teacherUser do
                response <- callAction SubjectsAction
                responseBodyShouldContain response "Estudantes matriculados"
                responseBodyShouldContain response "Estudantes matriculados"
                responseBodyShouldNotContain response "Disciplina privada AUTH"
                callAction (TeacherSubjectStudentsAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status200)
                callAction (TeacherSubjectAssessmentsAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status302)
                callAction (TeacherSubjectStudentsAction otherSubject.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callAction (TeacherSubjectAssessmentsAction otherSubject.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
              withUser studentUser do
                callAction (TeacherSubjectStudentsAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
            it "dashboard estudantil rejeita visitantes, Admin e contas sem vínculo" do
              callAction StudentDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status302)
              withUser admin do
                callAction StudentDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
              withUser unlinkedUser do
                callAction StudentDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status404)
            it "banco rejeita autorização duplicada e professor/disciplina inexistentes" do
              unsafeSqlExecDiscardResult "INSERT INTO teacher_subjects (teacher_id,subject_id) VALUES (?,?)" (unpackId teacher.id, unpackId subject.id) `shouldThrow` (\(err :: HasqlError) -> List.isInfixOf "23505" (Prelude.show err))
              unsafeSqlExecDiscardResult "INSERT INTO teacher_subjects (teacher_id,subject_id) VALUES ('00000000-0000-0000-0000-000000000001',?)" (Only (unpackId subject.id)) `shouldThrow` (\(err :: HasqlError) -> List.isInfixOf "23503" (Prelude.show err))
              unsafeSqlExecDiscardResult "INSERT INTO teacher_subjects (teacher_id,subject_id) VALUES (?,'00000000-0000-0000-0000-000000000001')" (Only (unpackId teacher.id)) `shouldThrow` (\(err :: HasqlError) -> List.isInfixOf "23503" (Prelude.show err))
            it "revogação bloqueia a requisição seguinte" do
              deleteRecord permission
              withUser teacherUser do
                dashboard <- callAction TeacherDashboardAction
                responseBodyShouldContain dashboard "Você ainda não possui disciplinas atribuídas"
                response <- callAction SubjectsAction
                responseBodyShouldNotContain response "Disciplina autorizada AUTH"
                callAction (ShowSubjectAction subject.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
        ) context

post :: ByteString -> LByteString -> WaiTest.Session WaiTest.SResponse
post path body = WaiTest.srequest (WaiTest.SRequest ((WaiTest.setPath Wai.defaultRequest path)
    { Wai.requestMethod = "POST", Wai.requestHeaders = [(HTTP.hContentType, "application/x-www-form-urlencoded")] }) body)
