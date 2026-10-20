module Web.Controller.Subjects where

import Web.Controller.Prelude
import Web.View.Subjects.Index
import Web.View.Subjects.New
import Web.View.Subjects.Edit
import Web.View.Subjects.Show

instance Controller SubjectsController where
    action SubjectsAction = do
        requireLogin
        subjects <- visibleSubjects
        courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) subjects) |> fetch
        render IndexView { .. }

    action NewSubjectAction = do
        requireAdmin
        let subject = newRecord @Subject
        courses <- query @Course |> fetch
        render NewView { .. }

    action ShowSubjectAction { subjectId } = do
        requireLogin
        requireSubject subjectId
        subject <- fetchOr404 subjectId
        course <- fetchOr404 (Id subject.courseId :: Id Course)
        render ShowView { .. }

    action EditSubjectAction { subjectId } = do
        requireAdmin
        subject <- fetchOr404 subjectId
        courses <- query @Course |> fetch
        render EditView { .. }

    action CreateSubjectAction = do
        requireAdmin
        courses <- query @Course |> fetch
        subject <- validarSubject (buildSubject (newRecord @Subject))
        subject |> ifValid \case
            Left subject -> render NewView { .. }
            Right subject -> do
                _ <- createRecord subject
                setSuccessMessage "Disciplina cadastrada com sucesso."
                redirectTo SubjectsAction

    action UpdateSubjectAction { subjectId } = do
        requireAdmin
        subject <- fetchOr404 subjectId
        courses <- query @Course |> fetch
        subject <- validarSubject (buildSubject subject)
        subject |> ifValid \case
            Left subject -> render EditView { .. }
            Right subject -> do
                _ <- updateRecord subject
                setSuccessMessage "Disciplina atualizada com sucesso."
                redirectTo EditSubjectAction { .. }

    action DeleteSubjectAction { subjectId } = do
        requireAdmin
        subject <- fetchOr404 subjectId
        permissions <- query @TeacherSubject |> filterWhere (#subjectId, unpackId subjectId) |> fetchOneOrNothing
        if isJust permissions
            then setErrorMessage "Revogue as autorizações antes de excluir disciplina."
            else do
                deleteRecord subject
                setSuccessMessage "Registro excluído com sucesso."
        redirectTo SubjectsAction

buildSubject subject = subject
    |> fill @'["name", "code", "workload", "courseId"]
    |> validateField #name (withCustomErrorMessage "Informe o nome." nonEmpty)
    |> validateField #code (withCustomErrorMessage "Informe o código." nonEmpty)
    |> validateField #workload (withCustomErrorMessage "A carga horária deve ser maior que zero." (isGreaterThan 0))
    |> validarCursoObrigatorio

-- fill ignores absent parameters on update, so require the course explicitly.
validarCursoObrigatorio subject = case paramOrError @UUID "courseId" of
    Left ParamNotFoundException {} -> attachFailure #courseId "Selecione um curso." subject
    _ -> subject

validarSubject :: (?modelContext :: ModelContext) => Subject -> IO Subject
validarSubject subject
    | not (isValid subject) = pure subject
    | otherwise = do
        comCodigo <- withCustomErrorMessageIO "Este código de disciplina já está cadastrado" validateIsUnique #code subject
        course <- query @Course
            |> filterWhere (#id, Id subject.courseId)
            |> fetchOneOrNothing
        pure (if isNothing course
            then attachFailure #courseId "O curso informado não existe." comCodigo
            else comCodigo)
