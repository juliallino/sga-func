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
    maybe (earlyReturn renderNotFound) pure student

myTeacher :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO Teacher
myTeacher = do
    requireLogin
    unless ((currentUser @User).role_ == Roleteacher) forbidden
    teacher <- query @Teacher |> filterWhere (#userId, Just (unpackId (currentUser @User).id)) |> fetchOneOrNothing
    maybe (earlyReturn renderNotFound) pure teacher

visibleStudents :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [Student]
visibleStudents = do
    requireLogin
    if (currentUser @User).role_ == Roleadmin
        then query @Student |> fetch
        else do
            student <- myStudent
            pure [student]

requireStudent :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => Id Student -> IO ()
requireStudent studentId = do
    requireLogin
    unless ((currentUser @User).role_ == Roleadmin) do
        student <- myStudent
        unless (student.id == studentId) (earlyReturn renderNotFound)

visibleEnrollments :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [Enrollment]
visibleEnrollments = do
    requireLogin
    if (currentUser @User).role_ == Roleadmin
        then query @Enrollment |> fetch
        else do
            student <- myStudent
            query @Enrollment |> filterWhere (#studentId, unpackId student.id) |> fetch

requireEnrollment :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => Enrollment -> IO ()
requireEnrollment enrollment = requireStudent (Id enrollment.studentId :: Id Student)

visibleGrades :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [Grade]
visibleGrades = do
    enrollments <- visibleEnrollments
    query @Grade |> filterWhereIn (#enrollmentId, map (unpackId . (.id)) enrollments) |> fetch

requireGrade :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => Grade -> IO ()
requireGrade grade = do
    requireLogin
    enrollment <- fetchOneOrNothing (Id grade.enrollmentId :: Id Enrollment)
    case enrollment of
        Nothing -> earlyReturn renderNotFound
        Just enrollment -> requireEnrollment enrollment

visibleSubjects :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [Subject]
visibleSubjects = do
    requireLogin
    if (currentUser @User).role_ == Roleadmin
        then query @Subject |> fetch
        else do
            teacher <- myTeacher
            permissions <- query @TeacherSubject |> filterWhere (#teacherId, unpackId teacher.id) |> fetch
            query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) permissions) |> fetch

requireSubject :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => Id Subject -> IO ()
requireSubject subjectId = do
    subjects <- visibleSubjects
    unless (any (\subject -> subject.id == subjectId) subjects) (earlyReturn renderNotFound)

-- Enrollment has no subject_id yet. No teacher is allowed to read or write
-- legacy grades by inferring a permission from the course. All grade writes
-- remain Admin-only until the separately approved enrollment migration exists.
