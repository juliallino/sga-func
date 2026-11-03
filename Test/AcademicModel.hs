module Main where
import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.Hspec
import IHP.AuthSupport.Authentication (hashPassword)
import Config
import Generated.Types
import Web.Types
import Web.FrontController ()
import qualified Network.HTTP.Types as HTTP
import Test.Hspec
import System.Environment (lookupEnv)

main :: IO ()
main = do
    isolated <- lookupEnv "SGA_ISOLATED_CRUD_TEST"
    unless (isolated == Just "1") (error "Use the isolated test runner")
    runSuite

runSuite :: IO ()
runSuite = withMockContext WebApplication config \context -> withContext (do
    hash <- hashPassword "academic-test-only"
    let account email role = newRecord @User |> set #name "Conta academic" |> set #email email |> set #passwordHash hash |> set #role_ role |> createRecord
    admin <- account "v2-admin@example.test" Roleadmin
    teacherUser <- account "v2-teacher@example.test" Roleteacher
    teacher <- newRecord @Teacher |> set #name "Professor V2" |> set #email teacherUser.email |> set #registrationNumber "V2-T1" |> set #userId (Just (unpackId teacherUser.id)) |> createRecord
    course <- newRecord @Course |> set #name "Curso Academic V2" |> set #code "V2-C1" |> set #workload 60 |> createRecord
    let subject name code = newRecord @Subject |> set #name name |> set #code code |> set #workload 60 |> set #courseId (unpackId course.id) |> createRecord
    a <- subject "Disciplina A V2" "V2-A"
    b <- subject "Disciplina B privada V2" "V2-B"
    permission <- newRecord @TeacherSubject |> set #teacherId (unpackId teacher.id) |> set #subjectId (unpackId a.id) |> createRecord
    u1 <- account "v2-student1@example.test" Rolestudent
    u2 <- account "v2-student2@example.test" Rolestudent
    u3 <- account "v2-student3@example.test" Rolestudent
    oldUser <- account "v2-old-unlinked@example.test" Rolestudent
    let student user name registration = newRecord @Student |> set #name name |> set #email user.email |> set #enrollmentNumber registration |> set #userId (Just (unpackId user.id)) |> createRecord
    s1 <- student u1 "Estudante V2 permitido" "V2-001"
    s2 <- student u2 "Estudante V2 empate" "V2-002"
    s3 <- student u3 "Estudante V2 privado" "V2-003"
    let enroll s d = newRecord @Enrollment |> set #studentId (unpackId s.id) |> set #subjectId (unpackId d.id) |> createRecord
    e1a <- enroll s1 a
    e1b <- enroll s1 b
    e2a <- enroll s2 a
    e2b <- enroll s2 b
    e3b <- enroll s3 b
    let mark e = newRecord @Grade |> set #enrollmentId (unpackId e.id) |> set #assessmentName "Avaliação V2" |> set #score 8 |> set #weight 2 |> createRecord
    g1a <- mark e1a
    g1b <- mark e1b
    _ <- mark e2a
    _ <- mark e2b
    let gradeParams e = [("enrollmentId",cs (show e.id)),("assessmentName","AV teste autorizacao"),("score","8"),("weight","2")]
    hspec do
      describe "Modelo por disciplina e autorização V2" do
        it "permite duas disciplinas do mesmo curso sem duplicar o par" do
          query @Enrollment |> filterWhere (#studentId,unpackId s1.id) |> fetchCount >>= (`shouldBe` 2)
          (enroll s1 a) `shouldThrow` anyException
        it "exige disciplina existente e não aceita matrícula sem disciplina" do
          unsafeSqlExecDiscardResult "INSERT INTO enrollments(student_id) VALUES (?)" (Only (unpackId s1.id)) `shouldThrow` anyException
          unsafeSqlExecDiscardResult "INSERT INTO enrollments(student_id,subject_id) VALUES (?,'00000000-0000-0000-0000-000000000001')" (Only (unpackId s1.id)) `shouldThrow` anyException
        it "professor consulta estudantes apenas da disciplina autorizada" do
          withUser teacherUser do
            response <- callAction (TeacherSubjectStudentsAction a.id)
            responseStatusShouldBe response HTTP.status200
            responseBodyShouldContain response s1.name
            responseBodyShouldNotContain response s3.name
            callAction (TeacherSubjectStudentsAction b.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
        it "professor lança e edita sua nota, sem permissão de excluir" do
          withUser teacherUser do
            callActionWithParams CreateGradeAction (gradeParams e1a) >>= (\r -> responseStatusShouldBe r HTTP.status302)
            callActionWithParams (UpdateGradeAction g1a.id) [("score","9")] >>= (\r -> responseStatusShouldBe r HTTP.status302)
            saved <- fetch g1a.id
            saved.score `shouldBe` 9
            callActionWithParams (UpdateGradeAction g1a.id) [("score","8")] >>= (\r -> responseStatusShouldBe r HTTP.status302)
            callAction (DeleteGradeAction g1a.id) >>= (\r -> responseStatusShouldBe r HTTP.status403)
        it "professor não grava nem edita notas de outra disciplina" do
          before <- query @Grade |> fetchCount
          withUser teacherUser do
            callActionWithParams CreateGradeAction (gradeParams e1b) >>= (\r -> responseStatusShouldBe r HTTP.status403)
            callActionWithParams (UpdateGradeAction g1b.id) [("score","10")] >>= (\r -> responseStatusShouldBe r HTTP.status403)
            callAction (ShowGradeAction g1b.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
          query @Grade |> fetchCount >>= (`shouldBe` before)
          saved <- fetch g1b.id
          saved.score `shouldBe` 8
        it "trocar enrollmentId na edição não transfere avaliação" do
          withUser teacherUser do
            callActionWithParams (UpdateGradeAction g1a.id) [("enrollmentId",cs (show e1b.id)),("score","10")] >>= (\r -> responseStatusShouldBe r HTTP.status403)
          saved <- fetch g1a.id
          saved.enrollmentId `shouldBe` unpackId e1a.id
          saved.score `shouldBe` 8
        it "Student não escreve e não visualiza terceiros" do
          withUser u1 do
            callActionWithParams CreateGradeAction (gradeParams e1a) >>= (\r -> responseStatusShouldBe r HTTP.status403)
            callActionWithParams (UpdateGradeAction g1a.id) [("score","10")] >>= (\r -> responseStatusShouldBe r HTTP.status403)
            callAction (ShowEnrollmentAction e2a.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
            response <- callAction GradesAction
            responseBodyShouldNotContain response s2.name
        it "conta antiga sem vínculo não é ligada aos novos estudantes" do
          withUser oldUser do
            callAction StudentDashboardAction >>= (\r -> responseStatusShouldBe r HTTP.status404)
            callAction GradesAction >>= (\r -> responseStatusShouldBe r HTTP.status404)
            callAction AcademicRankingsAction >>= (\r -> responseStatusShouldBe r HTTP.status404)
        it "ranking por disciplina tem empates e geral exige todas as médias" do
          withUser admin do
            response <- callAction AcademicRankingsAction
            responseStatusShouldBe response HTTP.status200
            responseBodyShouldContain response s1.name
            responseBodyShouldContain response s2.name
            responseBodyShouldNotContain response s3.name
            responseBodyShouldContain response "Geral · Curso Academic V2"
            responseBodyShouldContain response "8.00"
          rows <- unsafeSqlQuery "WITH a AS (SELECT e.student_id,SUM(g.score*g.weight)/SUM(g.weight) AS avg FROM enrollments e JOIN grades g ON g.enrollment_id=e.id WHERE e.subject_id=? GROUP BY e.student_id) SELECT RANK() OVER (ORDER BY avg DESC)::bigint FROM a" (Only (unpackId a.id)) :: IO [Only Int64]
          rows `shouldBe` [Only 1,Only 1]
        it "professor não recebe ranking geral nem disciplina não autorizada" do
          withUser teacherUser do
            response <- callAction AcademicRankingsAction
            responseBodyShouldContain response a.name
            responseBodyShouldNotContain response b.name
            responseBodyShouldNotContain response "Geral ·"
            responseBodyShouldNotContain response s3.name
        it "ranking Student expõe somente sua própria posição" do
          withUser u1 do
            response <- callAction AcademicRankingsAction
            responseBodyShouldContain response s1.name
            responseBodyShouldNotContain response s2.name
            responseBodyShouldNotContain response s3.name
          withUser u3 do
            response <- callAction AcademicRankingsAction
            responseBodyShouldContain response "Sem média disponível"
            responseBodyShouldNotContain response s1.name
        it "revogação impede novas gravações e mantém notas existentes" do
          withUser admin do
            callAction (DeleteTeacherSubjectAction permission.id) >>= (\r -> responseStatusShouldBe r HTTP.status302)
          withUser teacherUser do
            callActionWithParams CreateGradeAction (gradeParams e1a) >>= (\r -> responseStatusShouldBe r HTTP.status403)
            callActionWithParams (UpdateGradeAction g1a.id) [("score","10")] >>= (\r -> responseStatusShouldBe r HTTP.status403)
            callAction (ShowGradeAction g1a.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
          saved <- fetch g1a.id
          saved.score `shouldBe` 8
        it "não apaga disciplina com matrícula" do
          withUser admin do
            callAction (DeleteSubjectAction b.id) >>= (\r -> responseStatusShouldBe r HTTP.status302)
          fetchOneOrNothing b.id >>= (`shouldSatisfy` isJust)
    ) context
