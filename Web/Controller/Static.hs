module Web.Controller.Static where
import Web.Controller.Prelude
import IHP.LoginSupport.Helper.Controller (currentUser)
import Web.View.Static.Welcome
import qualified Web.View.Students.Show as Student
import qualified Application.Domain.Grade as GradeDomain
import qualified Web.View.TeacherPortal.Dashboard as TeacherPortal
import qualified Web.View.StudentPortal.Dashboard as StudentPortal
import qualified Web.View.StudentPortal.Academic as StudentAcademic
import qualified Web.View.TeacherPortal.Subjects as TeacherSubjects
import qualified Web.View.TeacherPortal.Students as TeacherStudents
import qualified Web.Controller.Rankings as Rankings
import qualified Application.Domain.Dashboard as D
import Web.View.Dashboard.Report (AcademicReport (..))
import qualified Data.Text as Text
import Text.Read (readMaybe)

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
                assessments <- query @Grade |> fetchCount
                pure (AdminOverview students teachers courses subjects enrollments assessments)
            Rolestudent -> do
                _ <- myStudent
                earlyReturn (redirectTo StudentDashboardAction)
            Roleteacher -> do
                _ <- myTeacher
                earlyReturn (redirectTo TeacherDashboardAction)
        academicReport <- loadAcademicReport
        render WelcomeView { .. }

    action StudentDashboardAction = do
        student <- myStudent
        enrollments <- visibleEnrollments
        grades <- visibleGrades
        subjects <- query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) enrollments) |> fetch
        let summaries = map (summarize subjects grades) enrollments
        let assessmentCount = length grades
        academicReport <- loadAcademicReport
        render StudentPortal.DashboardView { .. }

    action TeacherSubjectStudentsAction { subjectId } = do
        _ <- myTeacher
        requireSubject subjectId
        subject <- fetchOr404 subjectId
        enrollments <- query @Enrollment |> filterWhere (#subjectId, unpackId subjectId) |> fetch
        students <- query @Student |> filterWhereIn (#id, map (Id . (.studentId)) enrollments) |> fetch
        render TeacherStudents.IndexView { .. }

    action TeacherSubjectAssessmentsAction { subjectId } = do
        _ <- myTeacher
        requireSubject subjectId
        redirectToPath ("/Grades?subjectId=" <> cs (show subjectId))

    action AcademicRankingsAction = Rankings.renderRankings

    action TeacherDashboardAction = do
        teacher <- myTeacher
        authorizedSubjects <- visibleSubjects
        enrollments <- visibleEnrollments
        grades <- visibleGrades
        courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) authorizedSubjects) |> fetch
        let studentCount = length (nub (map (.studentId) enrollments))
        let assessmentCount = length grades
        let subjectCount = length authorizedSubjects
        let dashboardFilters = readDashboardFilters
        let error = validateDashboardFilters dashboardFilters
        let subjects = if isJust error then [] else filter (matchesSubject dashboardFilters) authorizedSubjects
        let academicReport = AcademicReport dashboardFilters error
                (map (\course -> (show course.id,course.name)) courses)
                (map (\subject -> (show subject.id,subject.name)) authorizedSubjects) [] []
        render TeacherPortal.DashboardView { .. }

    action TeacherProfileAction = do
        teacher <- myTeacher
        render TeacherPortal.ProfileView { .. }

    action MyProfileAction = do
        student <- myStudent
        render Student.ShowView { .. }

    action StudentSubjectsAction = do
        _ <- myStudent
        enrollments <- visibleEnrollments
        subjects <- query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) enrollments) |> fetch
        render StudentAcademic.SubjectsView { .. }

    action StudentAveragesAction = do
        _ <- myStudent
        enrollments <- visibleEnrollments
        grades <- visibleGrades
        subjects <- query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) enrollments) |> fetch
        let summaries = map (summarize subjects grades) enrollments
        render AveragesView { .. }

    action TeacherStudentsAction = teacherWorkspace TeacherSubjects.Students
    action TeacherAssessmentsAction = teacherWorkspace TeacherSubjects.Assessments
    action TeacherGradeEntryAction = teacherWorkspace TeacherSubjects.GradeEntry

teacherWorkspace mode = do
    _ <- myTeacher
    subjects <- visibleSubjects
    enrollments <- visibleEnrollments
    courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) subjects) |> fetch
    render TeacherSubjects.WorkspaceView { .. }

summarize :: [Subject] -> [Grade] -> Enrollment -> AverageSummary
summarize subjects grades enrollment = AverageSummary
    { enrollment = enrollment
    , subjectName = maybe "Disciplina indisponível" (.name) (find (\subject -> unpackId subject.id == enrollment.subjectId) subjects)
    , average = GradeDomain.mediaDaMatricula (map (\grade -> (realToFrac grade.score, realToFrac grade.weight)) assessments)
    , assessmentCount = length assessments
    }
    where assessments = filter (\grade -> grade.enrollmentId == unpackId enrollment.id) grades

-- Authorized data is projected before applying pure search/filter operations.
loadAcademicReport :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO AcademicReport
loadAcademicReport = do
    requireLogin
    enrollments <- visibleEnrollments
    grades <- visibleGrades
    students <- query @Student |> filterWhereIn (#id,map (Id . (.studentId)) enrollments) |> fetch
    subjects <- visibleSubjects
    courses <- query @Course |> filterWhereIn (#id,map (Id . (.courseId)) subjects) |> fetch
    let filters = readDashboardFilters
    let allResults = mapMaybe (projectResult students courses subjects grades) enrollments
    let outcome = case validateDashboardFilters filters of
            Just message -> Left message
            Nothing -> D.filterResults filters allResults
    let results = either (const []) (\values -> values) outcome
    let filterError = either Just (const Nothing) outcome
    let reportCourses = map (\course -> (show course.id,course.name)) courses
    let reportSubjects = map (\subject -> (show subject.id,subject.name)) subjects
    let reportRanking = if (currentUser @User).role_ == Roleadmin
            then D.visibleRankingGroups results (D.rankingGroups allResults)
            else []
    pure AcademicReport { .. }

projectResult :: [Student] -> [Course] -> [Subject] -> [Grade] -> Enrollment -> Maybe D.AcademicResult
projectResult students courses subjects grades enrollment = do
    student <- find (\value -> unpackId value.id==enrollment.studentId) students
    subject <- find (\value -> unpackId value.id==enrollment.subjectId) subjects
    course <- find (\value -> unpackId value.id==subject.courseId) courses
    let assessments = map (\grade -> (grade.assessmentName,realToFrac grade.score,realToFrac grade.weight))
            (filter (\grade -> grade.enrollmentId==unpackId enrollment.id) grades)
    pure (D.makeSubjectResult (show enrollment.id) (show student.id) student.name (show course.id) course.name (show subject.id) subject.name (statusValue enrollment.status) assessments)

readDashboardFilters :: (?request :: Request) => D.DashboardFilters
readDashboardFilters = D.DashboardFilters
    (value "studentName") (value "courseId") (value "subjectId")
    (value "status") (value "minimum") (value "maximum")
    where value name = Text.strip (fromMaybe "" (paramOrNothing @Text name))

validateDashboardFilters :: D.DashboardFilters -> Maybe Text
validateDashboardFilters filters
    | any invalidId [D.filterCourse filters, D.filterSubject filters] = Just "Selecione um curso e uma disciplina válidos."
    | D.filterStatus filters `notElem` ["", "active", "suspended", "completed"] = Just "Selecione uma situação de matrícula válida."
    | otherwise = either Just (const Nothing) (D.parseBounds filters)
    where invalidId raw = not (Text.null raw) && isNothing (readMaybe (cs raw) :: Maybe UUID)

matchesSubject :: D.DashboardFilters -> Subject -> Bool
matchesSubject filters subject =
    (Text.null (D.filterCourse filters) || D.filterCourse filters == show subject.courseId)
    && (Text.null (D.filterSubject filters) || D.filterSubject filters == show subject.id)

statusValue :: EnrollmentStatus -> Text
statusValue Active = "active"
statusValue Suspended = "suspended"
statusValue Completed = "completed"
