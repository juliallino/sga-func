module Web.Controller.Enrollments where

import Web.Controller.Prelude
import qualified Application.Domain.Grade as GradeDomain
import Web.View.Enrollments.Index
import Web.View.Enrollments.New
import Web.View.Enrollments.Edit
import Web.View.Enrollments.Show

instance Controller EnrollmentsController where
    action EnrollmentsAction = do
        enrollments <- query @Enrollment |> fetch
        render IndexView { .. }

    action NewEnrollmentAction = do
        let enrollment = newRecord
        students <- query @Student |> fetch
        courses <- query @Course |> fetch
        render NewView { .. }

    action ShowEnrollmentAction { enrollmentId } = do
        enrollment <- fetchOr404 enrollmentId
        grades <- query @Grade
            |> filterWhere (#enrollmentId, unpackId enrollmentId)
            |> fetch
        let media = calcularMediaEnrollment grades
        render ShowView { .. }
        
    action EditEnrollmentAction { enrollmentId } = do
        enrollment <- fetchOr404 enrollmentId
        students <- query @Student |> fetch
        courses <- query @Course |> fetch
        render EditView { .. }

    action UpdateEnrollmentAction { enrollmentId } = do
        enrollment <- fetchOr404 enrollmentId
        students <- query @Student |> fetch
        courses <- query @Course |> fetch
        enrollment <- validarEnrollment (buildEnrollment enrollment)
        enrollment |> ifValid \case
            Left enrollment -> render EditView { .. }
            Right enrollment -> do
                enrollment <- enrollment |> updateRecord
                setSuccessMessage "Matrícula atualizada com sucesso."
                redirectTo EditEnrollmentAction { .. }

    action CreateEnrollmentAction = do
        let enrollment = newRecord @Enrollment
        students <- query @Student |> fetch
        courses <- query @Course |> fetch
        enrollment <- validarEnrollment (buildEnrollment enrollment)
        enrollment |> ifValid \case
            Left enrollment -> render NewView { .. }
            Right enrollment -> do
                enrollment <- enrollment |> createRecord
                setSuccessMessage "Matrícula cadastrada com sucesso."
                redirectTo EnrollmentsAction

    action DeleteEnrollmentAction { enrollmentId } = do
        enrollment <- fetchOr404 enrollmentId
        dependencias <- query @Grade
            |> filterWhere (#enrollmentId, unpackId enrollmentId)
            |> fetchOneOrNothing
        if isJust dependencias
            then setErrorMessage "Não é possível excluir uma matrícula com notas."
            else do
                deleteRecord enrollment
                setSuccessMessage "Matrícula excluída com sucesso."
        redirectTo EnrollmentsAction

buildEnrollment enrollment = enrollment
    |> fill @'["studentId", "courseId", "enrollmentDate", "status"]
    |> validarDataMatricula

-- fill reports malformed dates, but silently ignores missing parameters.
validarDataMatricula enrollment =
    case paramOrError @Day "enrollmentDate" of
        Left ParamNotFoundException {} ->
            attachFailure #enrollmentDate "Informe uma data de matrícula válida." enrollment
        _ -> enrollment

-- Do not query references until UUID, date and enum parsing has succeeded.
validarEnrollment :: (?modelContext :: ModelContext) => Enrollment -> IO Enrollment
validarEnrollment enrollment
    | not (isValid enrollment) = pure enrollment
    | otherwise = do
        student <- query @Student
            |> filterWhere (#id, Id enrollment.studentId)
            |> fetchOneOrNothing
        course <- query @Course
            |> filterWhere (#id, Id enrollment.courseId)
            |> fetchOneOrNothing
        duplicada <- matriculaDuplicada enrollment
        let comEstudante = if isNothing student
                then attachFailure #studentId "O estudante informado não existe." enrollment
                else enrollment
        let comCurso = if isNothing course
                then attachFailure #courseId "O curso informado não existe." comEstudante
                else comEstudante
        pure (if duplicada
            then attachFailure #courseId "Este aluno já está matriculado nesta disciplina." comCurso
            else comCurso)

calcularMediaEnrollment :: [Grade] -> Maybe Double
calcularMediaEnrollment grades =
    GradeDomain.mediaDaMatricula
        (map (\grade -> (realToFrac grade.score, realToFrac grade.weight)) grades)

matriculaDuplicada :: (?modelContext :: ModelContext) => Enrollment -> IO Bool
matriculaDuplicada enrollment = do
    matriculas <- query @Enrollment
        |> filterWhere (#studentId, enrollment.studentId)
        |> filterWhere (#courseId, enrollment.courseId)
        |> fetch

    pure (any (\matricula -> matricula.id /= enrollment.id) matriculas)
