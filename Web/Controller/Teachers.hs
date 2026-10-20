module Web.Controller.Teachers where

import Web.Controller.Prelude
import Web.View.Teachers.Index
import Web.View.Teachers.New
import Web.View.Teachers.Edit
import Web.View.Teachers.Show

instance Controller TeachersController where
    action TeachersAction = do
        requireAdmin
        teachers <- query @Teacher |> fetch
        render IndexView { .. }

    action NewTeacherAction = do
        requireAdmin
        let teacher = newRecord
        render NewView { .. }

    action ShowTeacherAction { teacherId } = do
        requireAdmin
        teacher <- fetchOr404 teacherId
        render ShowView { .. }

    action EditTeacherAction { teacherId } = do
        requireAdmin
        teacher <- fetchOr404 teacherId
        render EditView { .. }

    action UpdateTeacherAction { teacherId } = do
        requireAdmin
        teacher <- fetchOr404 teacherId
        teacher <- validarTeacher (buildTeacher teacher)
        ifValid (\case
            Left teacher -> render EditView { .. }
            Right teacher -> do
                teacher <- teacher |> updateRecord
                setSuccessMessage "Professor atualizado com sucesso."
                redirectTo EditTeacherAction { teacherId }
            ) teacher

    action CreateTeacherAction = do
        requireAdmin
        let teacher = newRecord @Teacher
        teacher <- validarTeacher (buildTeacher teacher)
        ifValid (\case
            Left teacher -> render NewView { .. }
            Right teacher -> do
                teacher <- teacher |> createRecord
                setSuccessMessage "Professor cadastrado com sucesso."
                redirectTo TeachersAction
            ) teacher

    action DeleteTeacherAction { teacherId } = do
        requireAdmin
        teacher <- fetchOr404 teacherId
        permissions <- query @TeacherSubject |> filterWhere (#teacherId, unpackId teacherId) |> fetchOneOrNothing
        if isJust permissions
            then setErrorMessage "Revogue as autorizações antes de excluir professor."
            else do
                deleteRecord teacher
                setSuccessMessage "Registro excluído com sucesso."
        redirectTo TeachersAction

buildTeacher teacher = teacher
    |> fill @'["name", "email", "registrationNumber", "specialization"]
    |> validateField #name (withCustomErrorMessage "Informe o nome." nonEmpty)
    |> validateField #email (withCustomErrorMessage "Informe o e-mail." nonEmpty)
    |> validateField #email (withCustomErrorMessage "Informe um e-mail válido." isEmail)
    |> validateField #registrationNumber (withCustomErrorMessage "Informe o número de registro." nonEmpty)

validarTeacher :: (?modelContext :: ModelContext) => Teacher -> IO Teacher
validarTeacher teacher
    | not (isValid teacher) = pure teacher
    | otherwise = do
        comEmail <- withCustomErrorMessageIO "Este e-mail já está cadastrado" validateIsUnique #email teacher
        withCustomErrorMessageIO "Este número de registro já está cadastrado" validateIsUnique #registrationNumber comEmail
