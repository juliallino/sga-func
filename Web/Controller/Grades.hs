module Web.Controller.Grades where

import Web.Controller.Prelude
import qualified Application.Domain.Grade as GradeDomain
import Web.View.Grades.Form (EnrollmentOption, buildEnrollmentOptions)
import Web.View.Grades.Index
import Web.View.Grades.New
import Web.View.Grades.Edit
import Web.View.Grades.Show

instance Controller GradesController where
    action GradesAction = do
        requireLogin
        grades <- visibleGrades
        enrollments <- visibleEnrollments
        students <- query @Student |> filterWhereIn (#id, map (Id . (.studentId)) enrollments) |> fetch
        courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) enrollments) |> fetch
        let enrollmentOptions = buildEnrollmentOptions enrollments students courses
        render IndexView { .. }

    action NewGradeAction = do
        requireAdmin
        let grade = newRecord
        enrollmentOptions <- loadEnrollmentOptions
        render NewView { .. }

    action ShowGradeAction { gradeId } = do
        requireLogin
        grade <- fetchOr404 gradeId
        requireGrade grade
        render ShowView { .. }

    action EditGradeAction { gradeId } = do
        requireAdmin
        grade <- fetchOr404 gradeId
        enrollmentOptions <- loadEnrollmentOptions
        render EditView { .. }

    action UpdateGradeAction { gradeId } = do
        requireAdmin
        grade <- fetchOr404 gradeId
        enrollmentOptions <- loadEnrollmentOptions
        grade
            |> buildGrade
            |> ifValid \case
                Left grade -> render EditView { .. }
                Right grade -> do
                    matriculaValida <- validarMatricula grade
                    if not matriculaValida
                        then do
                            setErrorMessage "A matrícula informada não existe."
                            render EditView { .. }
                        else do
                            grade <- grade |> updateRecord
                            setSuccessMessage "Nota atualizada com sucesso."
                            redirectTo EditGradeAction { .. }

    action CreateGradeAction = do
        requireAdmin
        let grade = newRecord @Grade
        enrollmentOptions <- loadEnrollmentOptions
        grade
            |> buildGrade
            |> ifValid \case
                Left grade -> render NewView { .. }
                Right grade -> do
                    matriculaValida <- validarMatricula grade
                    if not matriculaValida
                        then do
                            setErrorMessage "A matrícula informada não existe."
                            render NewView { .. }
                        else do
                            grade <- grade |> createRecord
                            setSuccessMessage "Nota cadastrada com sucesso."
                            redirectTo GradesAction

    action DeleteGradeAction { gradeId } = do
        requireAdmin
        grade <- fetchOr404 gradeId
        deleteRecord grade
        setSuccessMessage "Nota excluída com sucesso."
        redirectTo GradesAction

buildGrade grade = grade
    |> fill @'["enrollmentId", "assessmentName", "score", "weight"]
    |> validateField #assessmentName (withCustomErrorMessage "Informe o nome da avaliação." nonEmpty)
    |> validateField #score (withCustomErrorMessage "A nota deve estar entre 0 e 10." (isTrue . GradeDomain.notaValida . realToFrac))
    |> validateField #weight (withCustomErrorMessage "O peso deve ser maior que zero." (isTrue . GradeDomain.pesoValido . realToFrac))
    |> validateField #weight validarPrecisaoPeso

validarMatricula :: (?modelContext :: ModelContext) => Grade -> IO Bool
validarMatricula grade = do
    resultado <- query @Enrollment
        |> filterWhere (#id, Id grade.enrollmentId)
        |> fetchOneOrNothing

    pure (isJust resultado)


loadEnrollmentOptions :: (?modelContext :: ModelContext) => IO [EnrollmentOption]
loadEnrollmentOptions = do
    enrollments <- query @Enrollment |> fetch
    students <- query @Student |> fetch
    courses <- query @Course |> fetch
    pure (buildEnrollmentOptions enrollments students courses)

-- NUMERIC(5,2) rounds before checking constraints. A positive input such as
-- 0.001 becomes zero; 1000 overflows. Match PostgreSQL's positive rounding
-- without changing inputs that it can already store (e.g. 0.005 -> 0.01).
validarPrecisaoPeso :: RealFrac value => value -> ValidatorResult
validarPrecisaoPeso value
    | cents >= 1 && cents <= 99999 = Success
    | otherwise = Failure "O peso deve permanecer positivo após arredondamento para duas casas e não exceder 999,99."
    where cents = floor (value * 100 + 0.5) :: Integer
