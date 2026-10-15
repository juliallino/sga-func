module Web.Controller.Grades where

import Web.Controller.Prelude
import qualified Application.Domain.Grade as GradeDomain
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
        render NewView { .. }

    action ShowGradeAction { gradeId } = do
        grade <- fetch gradeId
        render ShowView { .. }

    action EditGradeAction { gradeId } = do
        grade <- fetch gradeId
        render EditView { .. }

    action UpdateGradeAction { gradeId } = do
        grade <- fetch gradeId
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
                            setSuccessMessage "Grade updated"
                            redirectTo EditGradeAction { .. }

    action CreateGradeAction = do
        let grade = newRecord @Grade
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
                            setSuccessMessage "Grade created"
                            redirectTo GradesAction

    action DeleteGradeAction { gradeId } = do
        grade <- fetch gradeId
        deleteRecord grade
        setSuccessMessage "Grade deleted"
        redirectTo GradesAction

buildGrade grade = grade
    |> fill @'["enrollmentId", "assessmentName", "score", "weight"]
    |> validateField #assessmentName nonEmpty
    |> validateField #score (isInRange (0, 10))
    |> validateField #weight (isGreaterThan 0)

validarMatricula :: (?modelContext :: ModelContext) => Grade -> IO Bool
validarMatricula grade = do
    resultado <- query @Enrollment
        |> filterWhere (#id, Id grade.enrollmentId)
        |> fetchOneOrNothing

    pure (isJust resultado)