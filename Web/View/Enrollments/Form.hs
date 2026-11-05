module Web.View.Enrollments.Form (renderForm) where

import Web.View.Prelude

-- relationSupport is disabled, so foreign-key fields use UUID values.
instance CanSelect Student where
    type SelectValue Student = UUID
    selectLabel student = student.name <> " - Matrícula " <> student.enrollmentNumber
    selectValue student = unpackId student.id

renderForm :: Enrollment -> [Student] -> [Subject] -> Html
renderForm enrollment students subjects = formFor enrollment [hsx|
    {(selectField #studentId students)
        { fieldLabel = "Estudante", placeholder = "Selecione um estudante", required = True }}
    {when (null students) noStudents}
    {(selectField #subjectId subjects)
        { fieldLabel = "Disciplina", placeholder = "Selecione um disciplina", required = True }}
    {when (null subjects) noSubjects}
    <div class="mb-3">
        <span class="form-label">Data da matrícula</span>
        <p class="form-text">{if isNew enrollment then "Definida automaticamente no cadastro." else show enrollment.enrollmentDate}</p>
    </div>
    {(selectField #status [Active, Suspended, Completed]) { fieldLabel = "Situação", fieldValue = inputValue enrollment.status, placeholder = "Selecione uma situação" }}
    {formActions (submitButton { label = "Salvar" }) (pathTo EnrollmentsAction)}
|]

noStudents :: Html
noStudents = [hsx|
    <p>Nenhum estudante cadastrado. <a href={NewStudentAction}>Cadastrar estudante</a></p>
|]

noSubjects :: Html
noSubjects = [hsx|
    <p>Nenhuma disciplina cadastrada. <a href={NewSubjectAction}>Cadastrar disciplina</a></p>
|]
