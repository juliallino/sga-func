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
        student <- fetch studentId
        render ShowView { .. }

    action EditStudentAction { studentId } = do
        student <- fetch studentId
        render EditView { .. }

    action UpdateStudentAction { studentId } = do
        student <- fetch studentId
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
                setSuccessMessage "Student updated"
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
                setSuccessMessage "Student created"
                redirectTo StudentsAction
            ) studentComMatriculaValidada

    action DeleteStudentAction { studentId } = do
        student <- fetch studentId
        deleteRecord student
        setSuccessMessage "Student deleted"
        redirectTo StudentsAction

buildStudent student = student
    |> fill @'["name", "email", "enrollmentNumber"]
    |> validateField #name nonEmpty
    |> validateField #email nonEmpty
    |> validateField #email isEmail
    |> validateField #enrollmentNumber nonEmpty
