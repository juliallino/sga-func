module Main where

import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.Hspec
import IHP.AuthSupport.Authentication (hashPassword)
import "crypton" Crypto.Random (getRandomBytes)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as Base64
import Test.Hspec
import qualified Network.HTTP.Types as HTTP
import qualified Network.Wai as Wai
import qualified Network.Wai.Test as WT
import qualified Data.List as List
import qualified Data.Text as Text
import qualified Data.ByteString.Lazy as LBS
import qualified System.Environment as Env
import Config
import Generated.Types
import Web.Types
import Web.FrontController ()

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]

main :: IO ()
main = do
    marker <- Env.lookupEnv "SGA_ISOLATED_CRUD_TEST"
    url <- Env.lookupEnv "DATABASE_URL"
    unless (marker == Just "1" && maybe False (List.isInfixOf "host=/tmp/sga-crud-test-") url) (error "Use o executor de testes isolado")
    withMockContext WebApplication config \context -> do
      app <- initTestApplication context
      withContext (do
        password <- cs . Base64.encode <$> (getRandomBytes 24 :: IO BS.ByteString)
        hash <- hashPassword password
        let account name email role = newRecord @User |> set #name name |> set #email email |> set #role_ role |> set #passwordHash hash |> createRecord
        admin <- account "Admin Portal" "portal-admin@example.test" Roleadmin
        studentUser <- account "Aluno Portal A" "portal-a@example.test" Rolestudent
        otherUser <- account "Aluno Portal B" "portal-b@example.test" Rolestudent
        emptyUser <- account "Aluno Portal sem matrícula" "portal-empty@example.test" Rolestudent
        teacherUser <- account "Docente Portal A" "portal-teacher@example.test" Roleteacher
        otherTeacherUser <- account "Docente Portal B" "portal-teacher-b@example.test" Roleteacher
        emptyTeacherUser <- account "Docente Portal sem vínculo" "portal-teacher-empty@example.test" Roleteacher
        let student user registration = newRecord @Student |> set #userId (Just (unpackId user.id)) |> set #name user.name |> set #email user.email |> set #enrollmentNumber registration |> createRecord
        own <- student studentUser "PORTAL-S1"
        other <- student otherUser "PORTAL-S2"
        _ <- student emptyUser "PORTAL-S-EMPTY"
        let teacher user registration = newRecord @Teacher |> set #userId (Just (unpackId user.id)) |> set #name user.name |> set #email user.email |> set #registrationNumber registration |> createRecord
        t1 <- teacher teacherUser "PORTAL-T1"
        t2 <- teacher otherTeacherUser "PORTAL-T2"
        _ <- teacher emptyTeacherUser "PORTAL-T-EMPTY"
        course <- newRecord @Course |> set #name "Curso Portal" |> set #code "PORTAL-C1" |> set #workload 120 |> createRecord
        privateCourse <- newRecord @Course |> set #name "Curso externo Portal" |> set #code "PORTAL-C2" |> set #workload 120 |> createRecord
        let subject course title code = newRecord @Subject |> set #courseId (unpackId course.id) |> set #name title |> set #code code |> set #workload 60 |> createRecord
        s1 <- subject course "Disciplina Portal A" "PORTAL-A"
        s2 <- subject course "Disciplina Portal B" "PORTAL-B"
        s3 <- subject privateCourse "Disciplina externa Portal" "PORTAL-X"
        s4 <- subject privateCourse "Disciplina sem docente Portal" "PORTAL-NONE"
        permission <- newRecord @TeacherSubject |> set #teacherId (unpackId t1.id) |> set #subjectId (unpackId s1.id) |> createRecord
        forEach [s2,s3] \s -> do
            _ <- newRecord @TeacherSubject |> set #teacherId (unpackId t2.id) |> set #subjectId (unpackId s.id) |> createRecord
            pure ()
        let enroll student subject = newRecord @Enrollment |> set #studentId (unpackId student.id) |> set #subjectId (unpackId subject.id) |> createRecord
        ownA <- enroll own s1
        ownB <- enroll own s2
        otherA <- enroll other s1
        otherX <- enroll other s3
        _ <- enroll other s4
        let assess enrollment title score weight = newRecord @Grade |> set #enrollmentId (unpackId enrollment.id) |> set #assessmentName title |> set #score score |> set #weight weight |> createRecord
        grade <- assess ownA "Avaliação própria Portal 1" 7 1
        _ <- assess ownA "Avaliação própria Portal 2" 9 3
        _ <- assess ownB "Avaliação própria Portal B" 9 1
        _ <- assess otherA "Avaliação do colega Portal" 6 1
        privateGrade <- assess otherX "Avaliação externa Portal" 4 1
        let post path body = WT.srequest (WT.SRequest ((WT.setPath Wai.defaultRequest path) {Wai.requestMethod="POST",Wai.requestHeaders=[(HTTP.hContentType,"application/x-www-form-urlencoded")]}) body)
        let login email = post "/Login" (cs (HTTP.renderSimpleQuery False [("email",cs email),("password",cs password)]))
        let asUser user path = WT.runSession (login user.email >> WT.request (WT.setPath Wai.defaultRequest path)) app
        let gradeParams :: Enrollment -> Text -> Text -> Text -> [(ByteString, ByteString)]
            gradeParams enrollment title score weight = [("enrollmentId",cs (show enrollment.id)),("assessmentName",cs title),("score",cs score),("weight",cs weight)]
        let countGrades = query @Grade |> fetchCount
        hspec do
          describe "Portais SSR: dados próprios e cálculos" do
            it "redireciona o login para o painel próprio dos três perfis" do
              forEach [(admin,"/"),(teacherUser,"/TeacherDashboard"),(studentUser,"/StudentDashboard")] \(user,destination) -> do
                response <- WT.runSession (login user.email) app
                WT.simpleStatus response `shouldBe` HTTP.status303
                lookup HTTP.hLocation (WT.simpleHeaders response) `shouldBe` Just ("http://localhost" <> destination)
            it "aluno vê matrícula, média geral completa e seus resultados sem dados de colegas" do
              withUser studentUser do
                response <- callAction StudentDashboardAction
                forEach [own.name,"PORTAL-S1","Média geral","8.75","Disciplinas aprovadas","Disciplinas pendentes","Critério de aprovação não configurado"] (responseBodyShouldContain response)
                forEach [other.name,"Avaliação externa Portal",privateCourse.name] (responseBodyShouldNotContain response)
            it "disciplinas do aluno mostram curso, códigos, docentes, situação e médias" do
              withUser studentUser do
                response <- callAction StudentSubjectsAction
                forEach [s1.name,s2.name,s1.code,course.name,t1.name,t2.name,"8.50","9.00","Ativa"] (responseBodyShouldContain response)
                forEach [s3.name,s4.name,other.email,"NewEnrollment"] (responseBodyShouldNotContain response)
            it "notas mostram cada avaliação, peso e média calculada no domínio" do
              withUser studentUser do
                response <- callAction GradesAction
                forEach ["Minhas notas","Avaliação própria Portal 1","Avaliação própria Portal 2","Média ponderada: 8.50","Peso"] (responseBodyShouldContain response)
                forEach ["Avaliação do colega Portal","Avaliação externa Portal","NewGrade","EditGrade"] (responseBodyShouldNotContain response)
            it "curso incompleto, ausência de avaliações e docente ausente não viram zero" do
              withUser otherUser do
                response <- callAction StudentDashboardAction
                responseBodyShouldNotContain response "Média geral: 0"
                responseBodyShouldContain response "Média geral"
                response <- callAction StudentSubjectsAction
                responseBodyShouldContain response "Professor não atribuído"
                responseBodyShouldContain response "Sem média válida"
              withUser emptyUser do
                response <- callAction StudentDashboardAction
                responseBodyShouldContain response "Você ainda não possui matrículas"
                responseBodyShouldNotContain response own.name
            it "professor sem matrículas recebe orientação sem atalhos administrativos" do
              withUser emptyTeacherUser do
                response <- callAction NewGradeAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "Nenhuma matrícula disponível"
                responseBodyShouldNotContain response "href=\"/NewEnrollment\""
            it "perfil do aluno é somente leitura" do
              withUser studentUser do
                response <- callAction MyProfileAction
                forEach [own.name,own.email,own.enrollmentNumber] (responseBodyShouldContain response)
                responseBodyShouldNotContain response "EditStudent"
            it "professor vê resumo por disciplina sem média global entre turmas" do
              withUser teacherUser do
                response <- callAction TeacherDashboardAction
                forEach [t1.name,"Resumo do desempenho acadêmico","Média atual da turma","7.25",s1.name,"Desempenho insuficiente"] (responseBodyShouldContain response)
                forEach [s2.name,s3.name,privateCourse.name,otherTeacherUser.email] (responseBodyShouldNotContain response)
            it "professor consulta somente seus matriculados, com e-mail e média" do
              withUser teacherUser do
                response <- callAction (TeacherSubjectStudentsAction s1.id)
                forEach [own.name,other.name,own.email,other.email,"8.50","6.00","Lançar nota","Voltar às disciplinas"] (responseBodyShouldContain response)
                response <- callAction SubjectsAction
                responseBodyShouldContain response s1.code
                responseBodyShouldNotContain response s2.code
              withUser emptyTeacherUser do
                response <- callAction TeacherDashboardAction
                responseBodyShouldContain response "Nenhuma disciplina"
                responseBodyShouldNotContain response own.email
            it "mantém disciplina e matrícula selecionadas no formulário de lançamento" do
              response <- asUser teacherUser ("/NewGrade?subjectId=" <> cs (show s1.id) <> "&enrollmentId=" <> cs (show otherA.id))
              WT.simpleStatus response `shouldBe` HTTP.status200
              WT.simpleBody response `shouldSatisfy` (List.isInfixOf ("value=\"" <> cs (show otherA.id) <> "\" selected") . cs)
              WT.simpleBody response `shouldSatisfy` (not . List.isInfixOf (Text.unpack (show otherX.id)) . cs)
              listing <- asUser teacherUser ("/Grades?subjectId=" <> cs (show s1.id))
              WT.simpleBody listing `shouldSatisfy` (List.isInfixOf ("/NewGrade?subjectId=" <> cs (show s1.id)) . cs)
          describe "URLs e escritas protegidas no servidor" do
            it "bloqueia perfis cruzados e escritas administrativas mesmo por URL direta" do
              withUser studentUser do
                forEach [TeacherDashboardAction,TeacherStudentsAction,TeacherAssessmentsAction,TeacherGradeEntryAction,TeacherProfileAction] (\action -> callAction action >>= (\r -> responseStatusShouldBe r HTTP.status403))
                callAction (ShowStudentAction other.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callAction (ShowEnrollmentAction otherA.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callAction (ShowGradeAction privateGrade.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                callActionWithParams CreateEnrollmentAction [("studentId",cs (show own.id)),("subjectId",cs (show s3.id))] >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callActionWithParams CreateGradeAction (gradeParams ownA "Proibida Student" "8" "1") >>= (\r -> responseStatusShouldBe r HTTP.status403)
              withUser teacherUser do
                forEach [StudentDashboardAction,MyProfileAction,StudentSubjectsAction,StudentAveragesAction] (\action -> callAction action >>= (\r -> responseStatusShouldBe r HTTP.status403))
                callAction (TeacherSubjectStudentsAction s3.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
              withUser admin do
                callAction TeacherDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction StudentDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
            it "recusa disciplina/matrícula externas e UUID inválido nos parâmetros de contexto" do
              forEach ["/NewGrade?subjectId=invalid", "/NewGrade?enrollmentId=invalid", "/Grades?subjectId=invalid", "/NewGrade?subjectId=" <> cs (show s3.id),"/NewGrade?subjectId=" <> cs (show s1.id) <> "&enrollmentId=" <> cs (show otherX.id)] \path -> do
                response <- asUser teacherUser path
                WT.simpleStatus response `shouldBe` HTTP.status404
            it "professor cadastra e edita avaliações autorizadas somente no banco isolado" do
              withUser teacherUser do
                response <- callActionWithParams CreateGradeAction (gradeParams otherA "Avaliação isolada Portal" "7.25" "2")
                responseStatusShouldBe response HTTP.status302
                saved <- query @Grade |> filterWhere (#assessmentName,"Avaliação isolada Portal") |> fetchOne
                response <- callActionWithParams (UpdateGradeAction saved.id) (gradeParams otherA "Avaliação isolada Portal editada" "8.25" "3")
                responseStatusShouldBe response HTTP.status302
                updated <- fetch saved.id
                (realToFrac updated.score :: Double) `shouldBe` 8.25
                (realToFrac updated.weight :: Double) `shouldBe` 3
            it "recusa notas/pesos inválidos e escritas fora da disciplina sem modificar registros" do
              before <- countGrades
              withUser teacherUser do
                response <- callActionWithParams CreateGradeAction (gradeParams ownA "Inválida Portal" "11" "0")
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "invalid-feedback"
                callActionWithParams CreateGradeAction (gradeParams otherX "Proibida Teacher" "8" "1") >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callActionWithParams (UpdateGradeAction privateGrade.id) (gradeParams otherX "Proibida Teacher" "8" "1") >>= (\r -> responseStatusShouldBe r HTTP.status403)
              countGrades >>= (`shouldBe` before)
              current <- fetch privateGrade.id
              (realToFrac current.score :: Double) `shouldBe` 4
            it "dashboard administrativo e CRUDs continuam acessíveis ao Admin" do
              withUser admin do
                response <- callAction WelcomeAction
                forEach ["Visão geral","Estudantes","Professores","Avaliações"] (responseBodyShouldContain response)
                callAction UsersAction >>= (\r -> responseStatusShouldBe r HTTP.status200)
                callAction SubjectsAction >>= (\r -> responseStatusShouldBe r HTTP.status200)
            it "exporta amostras SSR fictícias para inspeção responsiva sem usar o banco atual" do
              target <- Env.lookupEnv "SGA_PORTAL_SNAPSHOTS"
              forEach target \directory -> forEach
                [("admin",admin,"/"),("student",studentUser,"/StudentDashboard"),("student-subjects",studentUser,"/MySubjects"),("student-notes",studentUser,"/Grades"),("student-profile",studentUser,"/MyProfile"),("teacher",teacherUser,"/TeacherDashboard"),("teacher-subjects",teacherUser,"/Subjects"),("teacher-students",teacherUser,"/TeacherSubjectStudents?subjectId=" <> cs (show s1.id)),("grade-form",teacherUser,"/NewGrade?subjectId=" <> cs (show s1.id)),("grade-edit",teacherUser,"/EditGrade?gradeId=" <> cs (show grade.id)),("empty-student",emptyUser,"/StudentDashboard"),("empty-teacher",emptyTeacherUser,"/TeacherDashboard")]
                \(filename,user,path) -> do
                  response <- asUser user path
                  WT.simpleStatus response `shouldBe` HTTP.status200
                  LBS.writeFile (directory <> "/" <> filename <> ".html") (WT.simpleBody response)
        ) context
