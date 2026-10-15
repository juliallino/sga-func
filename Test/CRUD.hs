module Main where

import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.Hspec
import qualified Network.HTTP.Types as HTTP
import qualified Network.Wai as Wai
import qualified Network.Wai.Test as WaiTest
import System.Environment (lookupEnv)
import Config
import Web.Types
import Web.FrontController ()
import Web.Controller.Students ()
import Web.Controller.Courses ()
import Web.Controller.Enrollments ()
import Web.Controller.Grades ()
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
      withContext (hspec do
        describe "Rotas HTTP" do
            it "resolve as quatro listagens via GET" do
                forEach ["/Students", "/Courses", "/Enrollments", "/Grades"] \path -> do
                    response <- WaiTest.runSession (WaiTest.request (WaiTest.setPath Wai.defaultRequest path)) app
                    WaiTest.simpleStatus response `shouldBe` HTTP.status200
            it "retorna 404 para registros inexistentes nos quatro CRUDs" do
                forEach ["/ShowStudent?studentId=", "/ShowCourse?courseId=", "/ShowEnrollment?enrollmentId=", "/ShowGrade?gradeId="] \path -> do
                    response <- WaiTest.runSession (WaiTest.request (WaiTest.setPath Wai.defaultRequest (path <> "00000000-0000-0000-0000-000000000001"))) app
                    WaiTest.simpleStatus response `shouldBe` HTTP.status404
        describe "CRUD de estudantes" do
            it "explica a ausência de opções quando não há cadastros" do
                response <- callAction NewEnrollmentAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "Nenhum estudante cadastrado"
                responseBodyShouldContain response "Nenhum curso cadastrado"
                gradeResponse <- callAction NewGradeAction
                responseBodyShouldContain gradeResponse "Nenhuma matrícula cadastrada"
            it "cria um estudante" do
                response <- callActionWithParams CreateStudentAction studentParams
                responseStatusShouldBe response HTTP.status302
                students <- query @Student |> fetch
                length students `shouldBe` 1
            it "lista, visualiza e abre a edição" do
                student <- query @Student |> fetchOne
                forEach [StudentsAction, ShowStudentAction student.id, EditStudentAction student.id] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "Aluno de teste"
            it "rejeita campos obrigatórios vazios e e-mail inválido" do
                response <- callActionWithParams CreateStudentAction [("name", ""), ("email", "invalido"), ("enrollmentNumber", "")]
                responseStatusShouldBe response HTTP.status200
                students <- query @Student |> fetch
                length students `shouldBe` 1
            it "rejeita e-mail e matrícula duplicados" do
                response <- callActionWithParams CreateStudentAction studentParams
                responseStatusShouldBe response HTTP.status200
                students <- query @Student |> fetch
                length students `shouldBe` 1
            it "edita sem acusar duplicidade do próprio registro" do
                student <- query @Student |> fetchOne
                response <- callActionWithParams (UpdateStudentAction student.id) studentParams
                responseStatusShouldBe response HTTP.status302
        describe "CRUD de cursos" do
            it "cria um curso" do
                response <- callActionWithParams CreateCourseAction courseParams
                responseStatusShouldBe response HTTP.status302
                courses <- query @Course |> fetch
                length courses `shouldBe` 1
            it "lista, visualiza e abre a edição" do
                course <- query @Course |> fetchOne
                forEach [CoursesAction, ShowCourseAction course.id, EditCourseAction course.id] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
            it "rejeita código duplicado e carga horária zero" do
                forEach [courseParams, [("name", "Outro"), ("code", "OUTRO"), ("workload", "0")]] \params -> do
                    response <- callActionWithParams CreateCourseAction params
                    responseStatusShouldBe response HTTP.status200
                courses <- query @Course |> fetch
                length courses `shouldBe` 1
            it "edita o curso" do
                course <- query @Course |> fetchOne
                response <- callActionWithParams (UpdateCourseAction course.id) courseParams
                responseStatusShouldBe response HTTP.status302
        describe "CRUD de matrículas" do
            it "inclui alunos e cursos cadastrados nas opções de nova matrícula" do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                response <- callAction NewEnrollmentAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response ("value=\"" <> show student.id <> "\"")
                responseBodyShouldContain response ("value=\"" <> show course.id <> "\"")
                responseBodyShouldContain response "Aluno de teste"
                responseBodyShouldContain response "Curso de teste"
            it "cria uma matrícula" do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                response <- callActionWithParams CreateEnrollmentAction (enrollmentParams student course)
                responseStatusShouldBe response HTTP.status302
            it "lista, visualiza e abre a edição" do
                enrollment <- query @Enrollment |> fetchOne
                forEach [EnrollmentsAction, ShowEnrollmentAction enrollment.id, EditEnrollmentAction enrollment.id] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
                response <- callAction (EditEnrollmentAction enrollment.id)
                responseBodyShouldContain response "Aluno de teste"
                responseBodyShouldContain response "Curso de teste"
                responseBodyShouldContain response "selected"
            it "impede duplicidade e preserva seletores após erro" do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                response <- callActionWithParams CreateEnrollmentAction (enrollmentParams student course)
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "já está matriculado"
                responseBodyShouldContain response "selected"
                enrollments <- query @Enrollment |> fetch
                length enrollments `shouldBe` 1
            it "rejeita estudante/curso inexistentes, data inválida e status inválido" do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                let valid = enrollmentParams student course
                forEach [("studentId", "00000000-0000-0000-0000-000000000001"), ("courseId", "00000000-0000-0000-0000-000000000001"), ("enrollmentDate", "2025-02-29"), ("status", "pending")] \(field, value) -> do
                    response <- callActionWithParams CreateEnrollmentAction ((field, value) : filter ((/= field) . fst) valid)
                    responseStatusShouldBe response HTTP.status200
                enrollments <- query @Enrollment |> fetch
                length enrollments `shouldBe` 1
            it "edita a própria matrícula sem acusar duplicidade" do
                enrollment <- query @Enrollment |> fetchOne
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                response <- callActionWithParams (UpdateEnrollmentAction enrollment.id) (enrollmentParams student course)
                responseStatusShouldBe response HTTP.status302
        describe "CRUD de notas e dependências" do
            it "oferece a matrícula com aluno e curso no seletor de notas" do
                enrollment <- query @Enrollment |> fetchOne
                response <- callAction NewGradeAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response ("value=\"" <> show enrollment.id <> "\"")
                responseBodyShouldContain response "Aluno de teste"
                responseBodyShouldContain response "Curso de teste"
                responseBodyShouldContain response "Selecione uma matrícula"
            it "cria duas avaliações com notas decimais" do
                enrollment <- query @Enrollment |> fetchOne
                forEach [("P1", "7.5", "1"), ("P2", "9", "3")] \(name, score, weight) -> do
                    response <- callActionWithParams CreateGradeAction (gradeParams enrollment name score weight)
                    responseStatusShouldBe response HTTP.status302
            it "lista, visualiza e abre a edição" do
                grade <- query @Grade |> fetchOne
                forEach [GradesAction, ShowGradeAction grade.id, EditGradeAction grade.id] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
                response <- callAction NewGradeAction
                responseBodyShouldContain response "step=\"0.01\""
                editResponse <- callAction (EditGradeAction grade.id)
                responseBodyShouldContain editResponse "Aluno de teste"
                responseBodyShouldContain editResponse "Curso de teste"
                responseBodyShouldContain editResponse "selected"
            it "exibe a média ponderada" do
                enrollment <- query @Enrollment |> fetchOne
                response <- callAction (ShowEnrollmentAction enrollment.id)
                responseBodyShouldContain response "8.625"
            it "rejeita nome vazio, nota fora do intervalo, peso zero e matrícula inexistente" do
                enrollment <- query @Enrollment |> fetchOne
                let valid = gradeParams enrollment "P3" "8" "1"
                forEach [("assessmentName", ""), ("score", "11"), ("score", "-1"), ("weight", "0"), ("enrollmentId", "00000000-0000-0000-0000-000000000001")] \(field, value) -> do
                    response <- callActionWithParams CreateGradeAction ((field, value) : filter ((/= field) . fst) valid)
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "Aluno de teste"
                    responseBodyShouldContain response "Curso de teste"
                    when (field /= "enrollmentId") do
                        responseBodyShouldContain response "selected"
                grades <- query @Grade |> fetch
                length grades `shouldBe` 2
            it "edita uma nota" do
                grade <- query @Grade |> fetchOne
                enrollment <- query @Enrollment |> fetchOne
                response <- callActionWithParams (UpdateGradeAction grade.id) (gradeParams enrollment "Revisada" "8" "1")
                responseStatusShouldBe response HTTP.status302
                updated <- fetch grade.id
                updated.assessmentName `shouldBe` "Revisada"
            it "distingue avaliações inválidas de ausência de avaliações" do
                grade <- query @Grade |> fetchOne
                enrollment <- query @Enrollment |> fetchOne
                _ <- grade |> set #score 11 |> updateRecord
                response <- callAction (ShowEnrollmentAction enrollment.id)
                responseBodyShouldContain response "Não foi possível calcular"
                responseBodyShouldNotContain response "Ainda não há avaliações"
                _ <- grade |> set #score 8 |> updateRecord
                pure ()
        describe "Integridade PostgreSQL no banco isolado" do
            it "rejeita matrícula duplicada mesmo sem passar pelo controller" do
                unsafeSqlExecDiscardResult "INSERT INTO enrollments (student_id, course_id) SELECT student_id, course_id FROM enrollments LIMIT 1" ()
                    `shouldThrow` anyException
            it "rejeita estudante inexistente" do
                unsafeSqlExecDiscardResult "INSERT INTO enrollments (student_id, course_id) SELECT '00000000-0000-0000-0000-000000000001'::uuid, id FROM courses LIMIT 1" ()
                    `shouldThrow` anyException
            it "rejeita curso inexistente" do
                unsafeSqlExecDiscardResult "INSERT INTO enrollments (student_id, course_id) SELECT id, '00000000-0000-0000-0000-000000000001'::uuid FROM students LIMIT 1" ()
                    `shouldThrow` anyException
            it "rejeita nota com matrícula inexistente" do
                unsafeSqlExecDiscardResult "INSERT INTO grades (enrollment_id, assessment_name, score, weight) VALUES ('00000000-0000-0000-0000-000000000001', 'Orfa', 8, 1)" ()
                    `shouldThrow` anyException
        describe "Exclusões" do
            it "preserva estudante, curso e matrícula com dependências" do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                enrollment <- query @Enrollment |> fetchOne
                _ <- callAction (DeleteStudentAction student.id)
                _ <- callAction (DeleteCourseAction course.id)
                _ <- callAction (DeleteEnrollmentAction enrollment.id)
                fetchOneOrNothing student.id >>= (`shouldSatisfy` isJust)
                fetchOneOrNothing course.id >>= (`shouldSatisfy` isJust)
                fetchOneOrNothing enrollment.id >>= (`shouldSatisfy` isJust)
            it "exclui notas, depois matrícula, estudante e curso de teste" do
                grades <- query @Grade |> fetch
                forEach grades \grade -> do
                    response <- callAction (DeleteGradeAction grade.id)
                    responseStatusShouldBe response HTTP.status302
                enrollment <- query @Enrollment |> fetchOne
                _ <- callAction (DeleteEnrollmentAction enrollment.id)
                student <- query @Student |> fetchOne
                _ <- callAction (DeleteStudentAction student.id)
                course <- query @Course |> fetchOne
                _ <- callAction (DeleteCourseAction course.id)
                query @Grade |> fetch >>= (\rows -> length rows `shouldBe` 0)
                query @Enrollment |> fetch >>= (\rows -> length rows `shouldBe` 0)
                query @Student |> fetch >>= (\rows -> length rows `shouldBe` 0)
                query @Course |> fetch >>= (\rows -> length rows `shouldBe` 0)
        ) context

studentParams :: [(ByteString, ByteString)]
studentParams = [("name", "Aluno de teste"), ("email", "crud@example.test"), ("enrollmentNumber", "CRUD-001")]
courseParams :: [(ByteString, ByteString)]
courseParams = [("name", "Curso de teste"), ("code", "CRUD"), ("workload", "60")]
enrollmentParams :: Student -> Course -> [(ByteString, ByteString)]
enrollmentParams student course = [("studentId", cs (show student.id)), ("courseId", cs (show course.id)), ("enrollmentDate", "2026-10-14"), ("status", "active")]
gradeParams :: Enrollment -> ByteString -> ByteString -> ByteString -> [(ByteString, ByteString)]
gradeParams enrollment name score weight = [("enrollmentId", cs (show enrollment.id)), ("assessmentName", name), ("score", score), ("weight", weight)]
