module Web.Controller.Students where

import Web.Controller.Prelude
import Web.View.Students.Index
import Web.View.Students.New
import Web.View.Students.Edit
import Web.View.Students.Show

instance Controller StudentsController where
    action StudentsAction = do
        students <- query @Student |> fetch
        render IndexView { .. }

    action NewStudentAction = do
        let student = newRecord
        render NewView { .. }

    action ShowStudentAction { studentId } = do
        student <- fetchOr404 studentId
        render ShowView { .. }

    action EditStudentAction { studentId } = do
        student <- fetchOr404 studentId
        render EditView { .. }

    action UpdateStudentAction { studentId } = do
        student <- fetchOr404 studentId
        let studentValidado = buildStudent student
        studentComEmailValidado <-
            withCustomErrorMessageIO
                "Este e-mail já está cadastrado"
                validateIsUnique
                #email
                studentValidado
        studentComMatriculaValidada <-
            withCustomErrorMessageIO
                "Este número de matrícula já está cadastrado"
                validateIsUnique
                #enrollmentNumber
                studentComEmailValidado
        ifValid (\case
            Left student -> render EditView { .. }
            Right student -> do
                student <- student |> updateRecord
                setSuccessMessage "Estudante atualizado com sucesso."
                redirectTo EditStudentAction { studentId }
            ) studentComMatriculaValidada

    action CreateStudentAction = do
        let student = newRecord @Student
        let studentValidado = buildStudent student

        studentComEmailValidado <-
            withCustomErrorMessageIO
                "Este e-mail já está cadastrado"
                validateIsUnique
                #email
                studentValidado

        studentComMatriculaValidada <-
            withCustomErrorMessageIO
                "Este número de matrícula já está cadastrado"
                validateIsUnique
                #enrollmentNumber
                studentComEmailValidado

        ifValid (\case
            Left student -> render NewView { .. }
            Right student -> do
                student <- student |> createRecord
                setSuccessMessage "Estudante cadastrado com sucesso."
                redirectTo StudentsAction
            ) studentComMatriculaValidada

    action DeleteStudentAction { studentId } = do
        student <- fetchOr404 studentId
        dependencias <- query @Enrollment
            |> filterWhere (#studentId, unpackId studentId)
            |> fetchOneOrNothing
        if isJust dependencias
            then setErrorMessage "Não é possível excluir um estudante com matrículas."
            else do
                deleteRecord student
                setSuccessMessage "Estudante excluído com sucesso."
        redirectTo StudentsAction

buildStudent student = student
    |> fill @'["name", "email", "enrollmentNumber"]
    |> validateField #name (withCustomErrorMessage "Informe o nome." nonEmpty)
    |> validateField #email (withCustomErrorMessage "Informe o e-mail." nonEmpty)
    |> validateField #email (withCustomErrorMessage "Informe um e-mail válido." isEmail)
    |> validateField #enrollmentNumber (withCustomErrorMessage "Informe o número de matrícula." nonEmpty)
