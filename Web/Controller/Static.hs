module Web.Controller.Static where
import Web.Controller.Prelude
import IHP.LoginSupport.Helper.Controller (currentUser)
import Web.View.Static.Welcome
import qualified Web.View.Students.Show as Student
import qualified Application.Domain.Grade as GradeDomain

instance Controller StaticController where
    action WelcomeAction = do
        requireLogin
        let user = currentUser @User
        overview <- case user.role_ of
            Roleadmin -> do
                students <- query @Student |> fetchCount
                teachers <- query @Teacher |> fetchCount
                courses <- query @Course |> fetchCount
                subjects <- query @Subject |> fetchCount
                enrollments <- query @Enrollment |> fetchCount
                pure (AdminOverview students teachers courses subjects enrollments)
            Rolestudent -> do
                _ <- myStudent
                enrollments <- visibleEnrollments
                grades <- visibleGrades
                pure (StudentOverview (length enrollments) (length grades))
            Roleteacher -> do
                _ <- myTeacher
                subjects <- visibleSubjects
                pure (TeacherOverview (length subjects))
        render WelcomeView { .. }

    action MyProfileAction = do
        student <- myStudent
        render Student.ShowView { .. }

    action StudentSubjectsAction = do
        _ <- myStudent
        render NoticeView
            { title = "Minhas disciplinas"
            , message = "Suas matrículas atuais estão organizadas por curso. Consulte seus vínculos e avaliações em Minhas matrículas. As disciplinas serão exibidas aqui quando estiverem associadas à sua matrícula."
            }

    action StudentAveragesAction = do
        _ <- myStudent
        enrollments <- visibleEnrollments
        grades <- visibleGrades
        courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) enrollments) |> fetch
        let summaries = map (summarize courses grades) enrollments
        render AveragesView { .. }

    action TeacherStudentsAction = do
        _ <- myTeacher
        render NoticeView
            { title = "Estudantes vinculados"
            , message = "A consulta de estudantes será disponibilizada quando suas matrículas estiverem vinculadas às disciplinas sob sua responsabilidade."
            }

    action TeacherAssessmentsAction = do
        _ <- myTeacher
        render NoticeView
            { title = "Lançamento de avaliações"
            , message = "O lançamento está indisponível para matrículas sem disciplina vinculada. Consulte a administração para regularizar os vínculos acadêmicos."
            }

summarize :: [Course] -> [Grade] -> Enrollment -> AverageSummary
summarize courses grades enrollment = AverageSummary
    { enrollment = enrollment
    , courseName = maybe "Curso indisponível" (.name) (find (\course -> unpackId course.id == enrollment.courseId) courses)
    , average = GradeDomain.mediaDaMatricula (map (\grade -> (realToFrac grade.score, realToFrac grade.weight)) assessments)
    , assessmentCount = length assessments
    }
    where assessments = filter (\grade -> grade.enrollmentId == unpackId enrollment.id) grades
