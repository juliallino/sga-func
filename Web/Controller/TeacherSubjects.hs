module Web.Controller.TeacherSubjects where

import Web.Controller.Prelude
import Web.View.TeacherSubjects.Index

instance Controller TeacherSubjectsController where
    action TeacherSubjectsAction = do
        requireAdmin
        let teacherSubject = newRecord @TeacherSubject
        renderAssignments teacherSubject

    action CreateTeacherSubjectAction = do
        requireAdmin
        teacherSubject <- validarVinculo (newRecord @TeacherSubject |> fill @'["teacherId", "subjectId"])
        teacherSubject |> ifValid \case
            Left teacherSubject -> renderAssignments teacherSubject
            Right teacherSubject -> do
                -- PostgreSQL's unique constraint also protects concurrent submissions.
                -- Bind parameters; only the two explicitly selected references are inserted.
                inserted <- unsafeSqlQuery
                    "INSERT INTO teacher_subjects (teacher_id, subject_id) VALUES (?, ?) ON CONFLICT (teacher_id, subject_id) DO NOTHING RETURNING id"
                    (teacherSubject.teacherId, teacherSubject.subjectId) :: IO [Only UUID]
                if null inserted
                    then renderAssignments (attachFailure #subjectId "Este professor já está vinculado a esta disciplina." teacherSubject)
                    else do
                        setSuccessMessage "Professor vinculado à disciplina com sucesso."
                        redirectTo TeacherSubjectsAction

    action DeleteTeacherSubjectAction { teacherSubjectId } = do
        requireAdmin
        teacherSubject <- fetchOr404 teacherSubjectId
        -- Revoke only the permission. Keep teacher, subject, enrollment and grades.
        deleteRecord teacherSubject
        setSuccessMessage "Vínculo removido. A autorização foi revogada."
        redirectTo TeacherSubjectsAction

renderAssignments teacherSubject = do
    teacherSubjects <- query @TeacherSubject |> fetch
    teachers <- query @Teacher |> orderByAsc #name |> fetch
    subjects <- query @Subject |> orderByAsc #name |> fetch
    courses <- query @Course |> fetch
    render IndexView { .. }

-- Parsing is IHP's responsibility. Database checks happen only after it succeeds.
validarVinculo :: (?modelContext :: ModelContext) => TeacherSubject -> IO TeacherSubject
validarVinculo teacherSubject
    | not (isValid teacherSubject) = pure teacherSubject
    | otherwise = do
        teacher <- fetchOneOrNothing (Id teacherSubject.teacherId :: Id Teacher)
        subject <- fetchOneOrNothing (Id teacherSubject.subjectId :: Id Subject)
        existing <- query @TeacherSubject
            |> filterWhere (#teacherId, teacherSubject.teacherId)
            |> filterWhere (#subjectId, teacherSubject.subjectId)
            |> fetchOneOrNothing
        let withTeacher = if isNothing teacher
                then attachFailure #teacherId "O professor informado não existe." teacherSubject
                else teacherSubject
        let withSubject = if isNothing subject
                then attachFailure #subjectId "A disciplina informada não existe." withTeacher
                else withTeacher
        pure (if isJust existing
            then attachFailure #subjectId "Este professor já está vinculado a esta disciplina." withSubject
            else withSubject)
