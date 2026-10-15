module Web.Controller.Grades where

import Web.Controller.Prelude
import Web.View.Grades.Form (EnrollmentOption, buildEnrollmentOptions)
import Web.View.Grades.Index
import Web.View.Grades.New
import Web.View.Grades.Edit
import Web.View.Grades.Show

instance Controller GradesController where
    action GradesAction = do
        grades <- query @Grade |> fetch
        render IndexView { .. }

    action NewGradeAction = do
        let grade = newRecord
        enrollmentOptions <- loadEnrollmentOptions
        render NewView { .. }

    action ShowGradeAction { gradeId } = do
        grade <- fetchOr404 gradeId
        render ShowView { .. }

    action EditGradeAction { gradeId } = do
        grade <- fetchOr404 gradeId
        enrollmentOptions <- loadEnrollmentOptions
        render EditView { .. }

    action UpdateGradeAction { gradeId } = do
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
        grade <- fetchOr404 gradeId
        deleteRecord grade
        setSuccessMessage "Nota excluída com sucesso."
        redirectTo GradesAction

buildGrade grade = grade
    |> fill @'["enrollmentId", "assessmentName", "score", "weight"]
    |> validateField #assessmentName (withCustomErrorMessage "Informe o nome da avaliação." nonEmpty)
    |> validateField #score (withCustomErrorMessage "A nota deve estar entre 0 e 10." (isInRange (0, 10)))
    |> validateField #weight (withCustomErrorMessage "O peso deve ser maior que zero." (isGreaterThan 0))

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
