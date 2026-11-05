module Application.Helper.Auth where

import IHP.ControllerPrelude
import IHP.LoginSupport.Helper.Controller
import Application.Auth.Types ()
import Generated.Types
import qualified Network.Wai as Wai
import qualified Network.HTTP.Types as HTTP

-- Explicit contexts are required: implicit parameters cannot be inferred
-- reliably for top-level constrained values under the monomorphism restriction.
requireLogin :: (?request :: Request, ?respond :: Respond) => IO ()
requireLogin = ensureIsUser @User

forbidden :: (?request :: Request, ?respond :: Respond) => IO a
forbidden = earlyReturn (respondWith (Wai.responseLBS HTTP.status403 [(HTTP.hContentType, "text/plain; charset=utf-8")] "Acesso não autorizado."))

requireAdmin :: (?request :: Request, ?respond :: Respond) => IO ()
requireAdmin = do
    requireLogin
    unless ((currentUser @User).role_ == Roleadmin) forbidden

-- Linked profiles are resolved on every request. Unlinked accounts have no
-- academic access; matching email never grants identity or permission.
myStudent :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO Student
myStudent = do
    requireLogin
    unless ((currentUser @User).role_ == Rolestudent) forbidden
    student <- query @Student |> filterWhere (#userId, Just (unpackId (currentUser @User).id)) |> fetchOneOrNothing
    maybe missingAcademicProfile pure student

myTeacher :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO Teacher
myTeacher = do
    requireLogin
    unless ((currentUser @User).role_ == Roleteacher) forbidden
    teacher <- query @Teacher |> filterWhere (#userId, Just (unpackId (currentUser @User).id)) |> fetchOneOrNothing
    maybe missingAcademicProfile pure teacher

-- A missing academic identity never grants access, even if emails match.
-- Keep the response independent of portal views to avoid a dependency cycle.
missingAcademicProfile :: (?request :: Request, ?respond :: Respond) => IO a
missingAcademicProfile = earlyReturn (respondWith (Wai.responseLBS HTTP.status404
    [(HTTP.hContentType, "text/html; charset=utf-8"), (HTTP.hCacheControl, "no-store")]
    (cs ("<!doctype html><html lang=\"pt-BR\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>SGA — Vínculo acadêmico pendente</title></head><body><main><h1>Vínculo acadêmico pendente</h1><p>Sua conta ainda não está vinculada a um cadastro de estudante ou professor. Solicite à administração a regularização do vínculo para acessar o portal.</p><form method=\"POST\" action=\"/Logout\"><button type=\"submit\">Sair</button></form></main></body></html>" :: Text))))


-- Every role resolves its academic identity server-side on each request.
visibleStudents :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [Student]
visibleStudents = do
    requireLogin
    case (currentUser @User).role_ of
        Roleadmin -> query @Student |> fetch
        Rolestudent -> do
            student <- myStudent
            pure [student]
        Roleteacher -> forbidden

requireStudent :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => Id Student -> IO ()
requireStudent studentId = do
    requireLogin
    case (currentUser @User).role_ of
        Roleadmin -> pure ()
        Rolestudent -> do
            student <- myStudent
            unless (student.id == studentId) (earlyReturn renderNotFound)
        Roleteacher -> forbidden

visibleEnrollments :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [Enrollment]
visibleEnrollments = do
    requireLogin
    case (currentUser @User).role_ of
        Roleadmin -> query @Enrollment |> fetch
        Rolestudent -> do
            student <- myStudent
            query @Enrollment |> filterWhere (#studentId, unpackId student.id) |> fetch
        Roleteacher -> do
            subjects <- visibleSubjects
            query @Enrollment |> filterWhereIn (#subjectId, map (unpackId . (.id)) subjects) |> fetch

requireEnrollment :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => Enrollment -> IO ()
requireEnrollment enrollment = do
    requireLogin
    case (currentUser @User).role_ of
        Roleadmin -> pure ()
        Rolestudent -> requireStudent (Id enrollment.studentId)
        Roleteacher -> requireSubject (Id enrollment.subjectId)

visibleGrades :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [Grade]
visibleGrades = do
    enrollments <- visibleEnrollments
    query @Grade |> filterWhereIn (#enrollmentId, map (unpackId . (.id)) enrollments) |> fetch

requireGrade :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => Grade -> IO ()
requireGrade grade = do
    requireLogin
    enrollment <- fetchOneOrNothing (Id grade.enrollmentId :: Id Enrollment)
    maybe (earlyReturn renderNotFound) requireEnrollment enrollment

visibleSubjects :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [Subject]
visibleSubjects = do
    requireLogin
    case (currentUser @User).role_ of
        Roleadmin -> query @Subject |> fetch
        Roleteacher -> do
            teacher <- myTeacher
            permissions <- query @TeacherSubject |> filterWhere (#teacherId, unpackId teacher.id) |> fetch
            query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) permissions) |> fetch
        Rolestudent -> do
            student <- myStudent
            enrollments <- query @Enrollment |> filterWhere (#studentId, unpackId student.id) |> fetch
            query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) enrollments) |> fetch

requireSubject :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => Id Subject -> IO ()
requireSubject subjectId = do
    subjects <- visibleSubjects
    unless (any (\subject -> subject.id == subjectId) subjects) (earlyReturn renderNotFound)

requireGradeWriter :: (?request :: Request, ?respond :: Respond) => IO ()
requireGradeWriter = do
    requireLogin
    unless ((currentUser @User).role_ `elem` [Roleadmin, Roleteacher]) forbidden

-- Must be used inside the write transaction. The enrollment row and permission
-- row stay locked until commit, so a concurrent revocation cannot be ignored.
requireEnrollmentWrite :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => UUID -> IO ()
requireEnrollmentWrite enrollmentId = do
    requireGradeWriter
    rows <- unsafeSqlQuery "SELECT subject_id FROM enrollments WHERE id = ? FOR SHARE" (Only enrollmentId) :: IO [Only UUID]
    subjectId <- case rows of
        [Only value] -> pure value
        _ -> earlyReturn renderNotFound
    when ((currentUser @User).role_ == Roleteacher) do
        teacher <- myTeacher
        permission <- unsafeSqlQuery "SELECT id FROM teacher_subjects WHERE teacher_id = ? AND subject_id = ? FOR SHARE"
            (unpackId teacher.id, subjectId) :: IO [Only UUID]
        when (null permission) forbidden
