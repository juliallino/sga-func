module Application.Helper.Portal where

import IHP.ControllerPrelude
import Generated.Types
import qualified Application.Domain.Grade as GradeDomain
import qualified Application.Domain.Academic as Academic
import qualified Application.Domain.Attendance as AttendanceDomain

-- Inputs must already be authorized by visibleEnrollments/visibleGrades.
-- Views receive these projections and never query data or calculate averages.
data StudentEnrollment = StudentEnrollment
    { rowEnrollment :: Enrollment
    , rowSubject :: Subject
    , rowCourse :: Maybe Course
    , rowTeachers :: [Teacher]
    , rowGrades :: [Grade]
    , rowAverage :: Maybe Double
    , rowAttendance :: AttendanceDomain.ResumoFrequencia
    }

averageGrades :: [Grade] -> Maybe Double
averageGrades grades = GradeDomain.mediaDaMatricula (map (\g -> (realToFrac g.score, realToFrac g.weight)) grades)

studentEnrollmentRows :: (?modelContext :: ModelContext) => [Enrollment] -> [Subject] -> [Grade] -> IO [StudentEnrollment]
studentEnrollmentRows enrollments subjects grades = do
    courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) subjects) |> fetch
    permissions <- query @TeacherSubject |> filterWhereIn (#subjectId, map (unpackId . (.id)) subjects) |> fetch
    teachers <- query @Teacher |> filterWhereIn (#id, map (Id . (.teacherId)) permissions) |> fetch
    attendances <- enrollmentAttendances enrollments
    pure (mapMaybe (project courses permissions teachers attendances) enrollments)
    where
        project courses permissions teachers attendances enrollment = do
            subject <- find (\s -> unpackId s.id == enrollment.subjectId) subjects
            let assessments = filter (\g -> g.enrollmentId == unpackId enrollment.id) grades
            let assignedIds = map (.teacherId) (filter (\p -> p.subjectId == enrollment.subjectId) permissions)
            pure StudentEnrollment
                { rowEnrollment = enrollment
                , rowSubject = subject
                , rowCourse = find (\c -> unpackId c.id == subject.courseId) courses
                , rowTeachers = filter (\t -> unpackId t.id `elem` assignedIds) teachers
                , rowGrades = assessments
                , rowAverage = averageGrades assessments
                , rowAttendance = attendanceSummary attendances enrollment
                }

-- Same complete-course rule as the existing general ranking: every subject in
-- the course must have a valid enrollment average. Never average across courses.
studentCourseAverages :: (?modelContext :: ModelContext) => [StudentEnrollment] -> IO [(Course, Maybe Double)]
studentCourseAverages rows = do
    let courses = nubBy (\a b -> a.id == b.id) (mapMaybe (.rowCourse) rows)
    subjects <- query @Subject |> filterWhereIn (#courseId, map (unpackId . (.id)) courses) |> fetch
    pure (map (summarize subjects) courses)
    where
        summarize subjects course =
            let curriculum = filter (\s -> s.courseId == unpackId course.id) subjects
                averages = map (\s -> find (\r -> r.rowSubject.id == s.id) rows >>= (.rowAverage)) curriculum
            in (course, Academic.mediaGeralCompleta (length curriculum) averages)

data SubjectPerformance = SubjectPerformance
    { performanceSubject :: Subject
    , performanceEnrollmentCount :: Int
    , performanceSummary :: Academic.Performance
    , performanceAttendanceBelowMinimum :: Int
    }

subjectPerformance :: [Enrollment] -> [Grade] -> [Attendance] -> Subject -> SubjectPerformance
subjectPerformance enrollments grades attendances subject = SubjectPerformance subject (length selected)
    (Academic.performanceWithAttendance Academic.approvalPolicy (map result selected))
    (Academic.attendanceBelowMinimumCount (map (AttendanceDomain.classificarFrequencia . attendanceSummary attendances) selected))
    where
        selected = filter (\e -> e.subjectId == unpackId subject.id) enrollments
        result enrollment =
            ( enrollment.status == Completed
            , AttendanceDomain.classificarFrequencia (attendanceSummary attendances enrollment)
            , averageGrades (filter (\g -> g.enrollmentId == unpackId enrollment.id) grades)
            )

-- A situação acadêmica considera a média e a frequência mínima de 75 %.
enrollmentStanding :: Enrollment -> AttendanceDomain.ResumoFrequencia -> Maybe Double -> Academic.AcademicStanding
enrollmentStanding enrollment attendance = Academic.classifyEnrollment Academic.approvalPolicy
    (enrollment.status == Completed) (AttendanceDomain.classificarFrequencia attendance)

-- Inputs must already be authorized: presences are read only for these enrollments.
enrollmentAttendances :: (?modelContext :: ModelContext) => [Enrollment] -> IO [Attendance]
enrollmentAttendances enrollments = query @Attendance
    |> filterWhereIn (#enrollmentId, map (unpackId . (.id)) enrollments)
    |> fetch

attendanceSummary :: [Attendance] -> Enrollment -> AttendanceDomain.ResumoFrequencia
attendanceSummary attendances enrollment = AttendanceDomain.resumirFrequencia
    [entry.present | entry <- attendances, entry.enrollmentId == unpackId enrollment.id]
