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
import IHP.AuthSupport.Authentication (hashPassword)

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]

main :: IO ()
main = do
    isolated <- lookupEnv "SGA_ISOLATED_CRUD_TEST"
    unless (isolated == Just "1") (error "Use python3 Test/run-crud-tests.py (isolated database required)")
    withMockContext WebApplication config \context -> do
      app <- initTestApplication context
      admin <- withContext createCrudAdmin context
      withContext (hspec do
        describe "Rotas HTTP" do
            it "resolve as seis listagens via GET" $ withUser admin do
                forEach ["/Students", "/Courses", "/Enrollments", "/Grades", "/Teachers", "/Subjects"] \path -> do
                    response <- getAsAdmin app path
                    WaiTest.simpleStatus response `shouldBe` HTTP.status200
            it "retorna 404 para registros inexistentes nos seis CRUDs" $ withUser admin do
                forEach ["/ShowStudent?studentId=", "/ShowCourse?courseId=", "/ShowEnrollment?enrollmentId=", "/ShowGrade?gradeId=", "/ShowTeacher?teacherId=", "/ShowSubject?subjectId="] \path -> do
                    response <- getAsAdmin app (path <> "00000000-0000-0000-0000-000000000001")
                    WaiTest.simpleStatus response `shouldBe` HTTP.status404
        describe "Navegação e disciplina sem cursos" do
            it "exibe os novos menus e orienta cadastrar um curso" $ withUser admin do
                response <- callAction NewSubjectAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "Nenhum curso cadastrado"
                responseBodyShouldContain response "href=\"/Teachers\""
                responseBodyShouldContain response "href=\"/Subjects\""
        describe "CRUD de estudantes" do
            it "explica a ausência de opções quando não há cadastros" $ withUser admin do
                response <- callAction NewEnrollmentAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "Nenhum estudante cadastrado"
                responseBodyShouldContain response "Nenhum curso cadastrado"
                gradeResponse <- callAction NewGradeAction
                responseBodyShouldContain gradeResponse "Nenhuma matrícula cadastrada"
            it "cria um estudante" $ withUser admin do
                response <- callActionWithParams CreateStudentAction studentParams
                responseStatusShouldBe response HTTP.status302
                students <- query @Student |> fetch
                length students `shouldBe` 1
            it "lista, visualiza e abre a edição" $ withUser admin do
                student <- query @Student |> fetchOne
                forEach [StudentsAction, ShowStudentAction student.id, EditStudentAction student.id] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "Aluno de teste"
            it "rejeita campos obrigatórios vazios e e-mail inválido" $ withUser admin do
                response <- callActionWithParams CreateStudentAction [("name", ""), ("email", "invalido"), ("enrollmentNumber", "")]
                responseStatusShouldBe response HTTP.status200
                students <- query @Student |> fetch
                length students `shouldBe` 1
            it "rejeita e-mail e matrícula duplicados" $ withUser admin do
                response <- callActionWithParams CreateStudentAction studentParams
                responseStatusShouldBe response HTTP.status200
                students <- query @Student |> fetch
                length students `shouldBe` 1
            it "edita sem acusar duplicidade do próprio registro" $ withUser admin do
                student <- query @Student |> fetchOne
                response <- callActionWithParams (UpdateStudentAction student.id) studentParams
                responseStatusShouldBe response HTTP.status302
        describe "CRUD de cursos" do
            it "cria um curso" $ withUser admin do
                response <- callActionWithParams CreateCourseAction courseParams
                responseStatusShouldBe response HTTP.status302
                courses <- query @Course |> fetch
                length courses `shouldBe` 1
            it "lista, visualiza e abre a edição" $ withUser admin do
                course <- query @Course |> fetchOne
                forEach [CoursesAction, ShowCourseAction course.id, EditCourseAction course.id] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
            it "rejeita código duplicado e carga horária zero" $ withUser admin do
                forEach [courseParams, [("name", "Outro"), ("code", "OUTRO"), ("workload", "0")]] \params -> do
                    response <- callActionWithParams CreateCourseAction params
                    responseStatusShouldBe response HTTP.status200
                courses <- query @Course |> fetch
                length courses `shouldBe` 1
            it "edita o curso" $ withUser admin do
                course <- query @Course |> fetchOne
                response <- callActionWithParams (UpdateCourseAction course.id) courseParams
                responseStatusShouldBe response HTTP.status302
        describe "CRUD de professores" do
            it "cria professor sem especialização e sem vincular usuário" $ withUser admin do
                response <- callActionWithParams CreateTeacherAction teacherParams
                responseStatusShouldBe response HTTP.status302
                teacher <- query @Teacher |> fetchOne
                teacher.userId `shouldBe` Nothing
                teacher.specialization `shouldBe` Nothing
            it "lista, visualiza e abre edição e novo cadastro" $ withUser admin do
                teacher <- query @Teacher |> fetchOne
                forEach [TeachersAction, ShowTeacherAction teacher.id, EditTeacherAction teacher.id, NewTeacherAction] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
            it "rejeita campos obrigatórios e e-mail inválido sem gravar" $ withUser admin do
                forEach [("name", ""), ("email", ""), ("email", "invalido"), ("registrationNumber", "")] \(field, value) -> do
                    response <- callActionWithParams CreateTeacherAction ((field, value) : filter ((/= field) . fst) teacherParams)
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "Informe"
                query @Teacher |> fetch >>= (\rows -> length rows `shouldBe` 1)
            it "rejeita e-mail e registro duplicados separadamente" $ withUser admin do
                forEach [[("registrationNumber", "OUTRO")], [("email", "outro@example.test")]] \changes -> do
                    let params = changes <> filter (\(field, _) -> not (field `elem` map fst changes)) teacherParams
                    response <- callActionWithParams CreateTeacherAction params
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "já está cadastrado"
                query @Teacher |> fetch >>= (\rows -> length rows `shouldBe` 1)
            it "edita sem acusar duplicidade do próprio professor e salva especialização" $ withUser admin do
                teacher <- query @Teacher |> fetchOne
                response <- callActionWithParams (UpdateTeacherAction teacher.id) (("specialization", "Haskell") : teacherParams)
                responseStatusShouldBe response HTTP.status302
                updated <- fetch teacher.id
                updated.specialization `shouldBe` Just "Haskell"
                invalid <- callActionWithParams (UpdateTeacherAction teacher.id) (("email", "invalido") : filter ((/= "email") . fst) teacherParams)
                responseStatusShouldBe invalid HTTP.status200
                unchanged <- fetch teacher.id
                unchanged.email `shouldBe` teacher.email
            it "exclui professor sem apagar a conta associada" $ withUser admin do
                teacher <- query @Teacher |> fetchOne
                user <- newRecord @User |> set #name "Conta teste" |> set #email "teacher-user@example.test" |> set #passwordHash "hash-apenas-banco-isolado" |> set #role_ Roleteacher |> createRecord
                _ <- teacher |> set #userId (Just (unpackId user.id)) |> updateRecord
                response <- callAction (DeleteTeacherAction teacher.id)
                responseStatusShouldBe response HTTP.status302
                fetchOneOrNothing teacher.id >>= (`shouldSatisfy` isNothing)
                fetchOneOrNothing user.id >>= (`shouldSatisfy` isJust)
        describe "CRUD de disciplinas" do
            it "cadastra disciplina com curso existente" $ withUser admin do
                course <- query @Course |> fetchOne
                response <- callActionWithParams CreateSubjectAction (subjectParams course)
                responseStatusShouldBe response HTTP.status302
                subject <- query @Subject |> fetchOne
                subject.courseId `shouldBe` unpackId course.id
            it "lista e mostra nome do curso, e abre formulários" $ withUser admin do
                subject <- query @Subject |> fetchOne
                forEach [SubjectsAction, ShowSubjectAction subject.id, EditSubjectAction subject.id, NewSubjectAction] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "Curso de teste"
                response <- callAction (EditSubjectAction subject.id)
                responseBodyShouldContain response "selected"
            it "rejeita campos vazios, código repetido, carga inválida e curso inválido" $ withUser admin do
                course <- query @Course |> fetchOne
                let valid = subjectParams course
                forEach [("name", ""), ("code", ""), ("workload", "0"), ("workload", "-1"), ("workload", "abc"), ("courseId", ""), ("courseId", "invalido"), ("courseId", "00000000-0000-0000-0000-000000000001")] \(field, value) -> do
                    response <- callActionWithParams CreateSubjectAction ((field, value) : filter ((/= field) . fst) valid)
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "Curso de teste"
                duplicate <- callActionWithParams CreateSubjectAction valid
                responseStatusShouldBe duplicate HTTP.status200
                responseBodyShouldContain duplicate "Este código de disciplina já está cadastrado"
                query @Subject |> fetch >>= (\rows -> length rows `shouldBe` 1)
            it "exige curso mesmo quando o parâmetro está ausente na edição" $ withUser admin do
                subject <- query @Subject |> fetchOne
                course <- query @Course |> fetchOne
                let params = filter ((/= "courseId") . fst) (subjectParams course)
                forEach [CreateSubjectAction, UpdateSubjectAction subject.id] \action -> do
                    response <- callActionWithParams action params
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "Selecione um curso."
                updated <- fetch subject.id
                updated.courseId `shouldBe` subject.courseId
            it "edita sem acusar duplicidade própria e preserva curso após erro" $ withUser admin do
                subject <- query @Subject |> fetchOne
                course <- query @Course |> fetchOne
                response <- callActionWithParams (UpdateSubjectAction subject.id) (subjectParams course)
                responseStatusShouldBe response HTTP.status302
                invalid <- callActionWithParams (UpdateSubjectAction subject.id) (("workload", "0") : filter ((/= "workload") . fst) (subjectParams course))
                responseStatusShouldBe invalid HTTP.status200
                responseBodyShouldContain invalid "selected"
                updated <- fetch subject.id
                updated.workload `shouldBe` 60
            it "impede excluir curso com disciplina mesmo sem matrículas" $ withUser admin do
                course <- query @Course |> fetchOne
                response <- callAction (DeleteCourseAction course.id)
                responseStatusShouldBe response HTTP.status302
                fetchOneOrNothing course.id >>= (`shouldSatisfy` isJust)
                unsafeSqlExecDiscardResult "DELETE FROM courses" () `shouldThrow` anyException
            it "exclui disciplina preservando seu curso" $ withUser admin do
                subject <- query @Subject |> fetchOne
                course <- query @Course |> fetchOne
                response <- callAction (DeleteSubjectAction subject.id)
                responseStatusShouldBe response HTTP.status302
                fetchOneOrNothing subject.id >>= (`shouldSatisfy` isNothing)
                fetchOneOrNothing course.id >>= (`shouldSatisfy` isJust)
        describe "CRUD de matrículas" do
            it "inclui alunos e cursos cadastrados nas opções de nova matrícula" $ withUser admin do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                response <- callAction NewEnrollmentAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response ("value=\"" <> show student.id <> "\"")
                responseBodyShouldContain response ("value=\"" <> show course.id <> "\"")
                responseBodyShouldContain response "Aluno de teste"
                responseBodyShouldContain response "Curso de teste"
            it "cria uma matrícula sem data e usa o dia atual do PostgreSQL" $ withUser admin do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                response <- callActionWithParams CreateEnrollmentAction (enrollmentParams student course)
                responseStatusShouldBe response HTTP.status302
                enrollment <- query @Enrollment |> fetchOne
                [Only today] <- sqlQuery "SELECT CURRENT_DATE" ()
                enrollment.enrollmentDate `shouldBe` today
            it "ignora data enviada na criação" $ withUser admin do
                student <- query @Student |> fetchOne
                course <- newRecord @Course |> set #name "Curso data automática" |> set #code "AUTO-DATE" |> set #workload 60 |> createRecord
                response <- callActionWithParams CreateEnrollmentAction (("enrollmentDate", "2000-01-01") : enrollmentParams student course)
                responseStatusShouldBe response HTTP.status302
                enrollment <- query @Enrollment |> filterWhere (#courseId, unpackId course.id) |> fetchOne
                [Only today] <- sqlQuery "SELECT CURRENT_DATE" ()
                enrollment.enrollmentDate `shouldBe` today
                _ <- callAction (DeleteEnrollmentAction enrollment.id)
                _ <- callAction (DeleteCourseAction course.id)
                pure ()
            it "não oferece campo editável de data nos formulários" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                forEach [NewEnrollmentAction, EditEnrollmentAction enrollment.id] \action -> do
                    response <- callAction action
                    responseBodyShouldNotContain response "name=\"enrollmentDate\""
                    responseBodyShouldNotContain response "type=\"date\""
                response <- callAction (EditEnrollmentAction enrollment.id)
                responseBodyShouldContain response (show enrollment.enrollmentDate)
            it "lista, visualiza e abre a edição" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                forEach [EnrollmentsAction, ShowEnrollmentAction enrollment.id, EditEnrollmentAction enrollment.id] \action -> do
                    response <- callAction action
                    responseStatusShouldBe response HTTP.status200
                response <- callAction (EditEnrollmentAction enrollment.id)
                responseBodyShouldContain response "Aluno de teste"
                responseBodyShouldContain response "Curso de teste"
                responseBodyShouldContain response "selected"
            it "explica quando a matrícula não possui avaliações" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                response <- callAction (ShowEnrollmentAction enrollment.id)
                responseBodyShouldContain response "Ainda não há avaliações"
                responseBodyShouldContain response "Nenhuma avaliação registrada nesta matrícula."
                responseBodyShouldNotContain response "Não foi possível calcular"
            it "impede duplicidade e preserva seletores após erro" $ withUser admin do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                response <- callActionWithParams CreateEnrollmentAction (enrollmentParams student course)
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response "já está matriculado"
                responseBodyShouldContain response "selected"
                enrollments <- query @Enrollment |> fetch
                length enrollments `shouldBe` 1
            it "rejeita estudante/curso inexistentes e status inválido" $ withUser admin do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                let valid = enrollmentParams student course
                forEach [("studentId", "00000000-0000-0000-0000-000000000001"), ("courseId", "00000000-0000-0000-0000-000000000001"), ("status", "pending")] \(field, value) -> do
                    response <- callActionWithParams CreateEnrollmentAction ((field, value) : filter ((/= field) . fst) valid)
                    responseStatusShouldBe response HTTP.status200
                enrollments <- query @Enrollment |> fetch
                length enrollments `shouldBe` 1
            it "edita a própria matrícula sem acusar duplicidade" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                response <- callActionWithParams (UpdateEnrollmentAction enrollment.id) (enrollmentParams student course)
                responseStatusShouldBe response HTTP.status302
            it "preserva a data original ao editar, mesmo com data adulterada ou inválida" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                let originalDate = fromGregorian 2001 2 3
                -- Simulate a historical enrollment in the isolated database.
                _ <- enrollment |> set #enrollmentDate originalDate |> updateRecord
                forEach ["2099-12-31", "data-invalida"] \date -> do
                    response <- callActionWithParams (UpdateEnrollmentAction enrollment.id) (("enrollmentDate", date) : enrollmentParams student course)
                    responseStatusShouldBe response HTTP.status302
                    updated <- fetch enrollment.id
                    updated.enrollmentDate `shouldBe` originalDate
        describe "CRUD de notas e dependências" do
            it "oferece a matrícula com aluno e curso no seletor de notas" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                response <- callAction NewGradeAction
                responseStatusShouldBe response HTTP.status200
                responseBodyShouldContain response ("value=\"" <> show enrollment.id <> "\"")
                responseBodyShouldContain response "Aluno de teste"
                responseBodyShouldContain response "Curso de teste"
                responseBodyShouldContain response "Selecione uma matrícula"
            it "cria duas avaliações com notas decimais" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                forEach [("P1", "7.5", "1"), ("P2", "9", "3")] \(name, score, weight) -> do
                    response <- callActionWithParams CreateGradeAction (gradeParams enrollment name score weight)
                    responseStatusShouldBe response HTTP.status302
            it "lista, visualiza e abre a edição" $ withUser admin do
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
            it "exibe as avaliações da matrícula e a média ponderada" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                response <- callAction (ShowEnrollmentAction enrollment.id)
                responseBodyShouldContain response "8.625"
                responseBodyShouldContain response "P1"
                responseBodyShouldContain response "P2"
                grades <- query @Grade |> fetch
                forEach grades \grade -> do
                    responseBodyShouldContain response (cs (pathTo (ShowGradeAction grade.id)))
                    responseBodyShouldContain response (cs (pathTo (EditGradeAction grade.id)))
            it "rejeita nome vazio, nota fora do intervalo, peso zero e matrícula inexistente" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                let valid = gradeParams enrollment "P3" "8" "1"
                forEach [("assessmentName", ""), ("score", "11"), ("score", "-1"), ("score", "1e309"), ("weight", "0"), ("weight", "-1"), ("weight", "1e309"), ("enrollmentId", "00000000-0000-0000-0000-000000000001")] \(field, value) -> do
                    response <- callActionWithParams CreateGradeAction ((field, value) : filter ((/= field) . fst) valid)
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "Aluno de teste"
                    responseBodyShouldContain response "Curso de teste"
                    when (field /= "enrollmentId") do
                        responseBodyShouldContain response "selected"
                grades <- query @Grade |> fetch
                length grades `shouldBe` 2
            it "edita uma nota" $ withUser admin do
                grade <- query @Grade |> fetchOne
                enrollment <- query @Enrollment |> fetchOne
                response <- callActionWithParams (UpdateGradeAction grade.id) (gradeParams enrollment "Revisada" "8" "1")
                responseStatusShouldBe response HTTP.status302
                updated <- fetch grade.id
                updated.assessmentName `shouldBe` "Revisada"
            it "rejeita nota inválida no banco e preserva a avaliação" $ withUser admin do
                grade <- query @Grade |> fetchOne
                enrollment <- query @Enrollment |> fetchOne
                (grade |> set #score 11 |> updateRecord) `shouldThrow` anyException
                updated <- fetch grade.id
                updated.score `shouldBe` grade.score
                response <- callAction (ShowEnrollmentAction enrollment.id)
                responseBodyShouldNotContain response "Não foi possível calcular"
                responseBodyShouldNotContain response "Ainda não há avaliações"
            it "rejeita pesos incompatíveis com NUMERIC(5,2) sem erro de servidor" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                forEach ["0.001", "1000"] \weight -> do
                    response <- callActionWithParams CreateGradeAction (gradeParams enrollment "Limite do peso" "8" weight)
                    responseStatusShouldBe response HTTP.status200
                    responseBodyShouldContain response "peso"
                grades <- query @Grade |> fetch
                length grades `shouldBe` 2
            it "preserva o arredondamento de pesos que o PostgreSQL já consegue armazenar" $ withUser admin do
                enrollment <- query @Enrollment |> fetchOne
                forEach [("0.005", 0.01), ("999.994", 999.99)] \(weight, expected) -> do
                    response <- callActionWithParams CreateGradeAction (gradeParams enrollment "Peso arredondado" "8" weight)
                    responseStatusShouldBe response HTTP.status302
                    grade <- query @Grade |> filterWhere (#assessmentName, "Peso arredondado") |> fetchOne
                    grade.weight `shouldBe` expected
                    _ <- callAction (DeleteGradeAction grade.id)
                    pure ()
        describe "Integridade PostgreSQL no banco isolado" do
            it "rejeita pesos nulos, negativos e NaN mesmo sem passar pelo controller" $ withUser admin do
                forEach ["0", "-1", "'NaN'::numeric"] \weight -> do
                    unsafeSqlExecDiscardResult ("UPDATE grades SET weight = " <> weight) ()
                        `shouldThrow` anyException
            it "rejeita matrícula duplicada mesmo sem passar pelo controller" $ withUser admin do
                unsafeSqlExecDiscardResult "INSERT INTO enrollments (student_id, course_id) SELECT student_id, course_id FROM enrollments LIMIT 1" ()
                    `shouldThrow` anyException
            it "rejeita estudante inexistente" $ withUser admin do
                unsafeSqlExecDiscardResult "INSERT INTO enrollments (student_id, course_id) SELECT '00000000-0000-0000-0000-000000000001'::uuid, id FROM courses LIMIT 1" ()
                    `shouldThrow` anyException
            it "rejeita curso inexistente" $ withUser admin do
                unsafeSqlExecDiscardResult "INSERT INTO enrollments (student_id, course_id) SELECT id, '00000000-0000-0000-0000-000000000001'::uuid FROM students LIMIT 1" ()
                    `shouldThrow` anyException
            it "rejeita nota com matrícula inexistente" $ withUser admin do
                unsafeSqlExecDiscardResult "INSERT INTO grades (enrollment_id, assessment_name, score, weight) VALUES ('00000000-0000-0000-0000-000000000001', 'Orfa', 8, 1)" ()
                    `shouldThrow` anyException
        describe "Exclusões" do
            it "preserva estudante, curso e matrícula com dependências" $ withUser admin do
                student <- query @Student |> fetchOne
                course <- query @Course |> fetchOne
                enrollment <- query @Enrollment |> fetchOne
                _ <- callAction (DeleteStudentAction student.id)
                _ <- callAction (DeleteCourseAction course.id)
                _ <- callAction (DeleteEnrollmentAction enrollment.id)
                fetchOneOrNothing student.id >>= (`shouldSatisfy` isJust)
                fetchOneOrNothing course.id >>= (`shouldSatisfy` isJust)
                fetchOneOrNothing enrollment.id >>= (`shouldSatisfy` isJust)
            it "exclui notas, depois matrícula, estudante e curso de teste" $ withUser admin do
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
enrollmentParams student course = [("studentId", cs (show student.id)), ("courseId", cs (show course.id)), ("status", "active")]
gradeParams :: Enrollment -> ByteString -> ByteString -> ByteString -> [(ByteString, ByteString)]
gradeParams enrollment name score weight = [("enrollmentId", cs (show enrollment.id)), ("assessmentName", name), ("score", score), ("weight", weight)]

teacherParams :: [(ByteString, ByteString)]
teacherParams = [("name", "Professor de teste"), ("email", "teacher@example.test"), ("registrationNumber", "PROF-001")]

subjectParams :: Course -> [(ByteString, ByteString)]
subjectParams course = [("name", "Disciplina de teste"), ("code", "SUB-001"), ("workload", "60"), ("courseId", cs (show course.id))]

-- Real login/cookie flow for route resolution tests; credentials exist only
-- in the temporary database created by run-crud-tests.py.
getAsAdmin :: Wai.Application -> ByteString -> IO WaiTest.SResponse
getAsAdmin app path = WaiTest.runSession (do
    _ <- WaiTest.srequest (WaiTest.SRequest ((WaiTest.setPath Wai.defaultRequest "/Login")
        { Wai.requestMethod = "POST", Wai.requestHeaders = [(HTTP.hContentType, "application/x-www-form-urlencoded")] })
        "email=crud-admin%40example.test&password=crud-admin-test-only")
    WaiTest.request (WaiTest.setPath Wai.defaultRequest path)
    ) app

createCrudAdmin :: (?modelContext :: ModelContext) => IO User
createCrudAdmin = do
    passwordHash <- hashPassword "crud-admin-test-only"
    newRecord @User |> set #name "Admin teste isolado" |> set #email "crud-admin@example.test" |> set #passwordHash passwordHash |> set #role_ Roleadmin |> createRecord
