module Web.View.Enrollments.Form (renderForm) where

import Web.View.Prelude

-- relationSupport is disabled, so foreign-key fields use UUID values.
instance CanSelect Student where
    type SelectValue Student = UUID
    selectLabel student = student.name <> " - Matrícula " <> student.enrollmentNumber
    selectValue student = unpackId student.id

instance CanSelect Course where
    type SelectValue Course = UUID
    selectLabel course = course.name <> " - " <> course.code
    selectValue course = unpackId course.id

renderForm :: Enrollment -> [Student] -> [Course] -> Html
renderForm enrollment students courses = formFor enrollment [hsx|
    {(selectField #studentId students)
        { fieldLabel = "Estudante", placeholder = "Selecione um estudante", required = True }}
    {when (null students) noStudents}
    {(selectField #courseId courses)
        { fieldLabel = "Curso", placeholder = "Selecione um curso", required = True }}
    {when (null courses) noCourses}
    {(dateField #enrollmentDate) { fieldLabel = "Data da matrícula" }}
    {(selectField #status [Active, Suspended, Completed]) { fieldLabel = "Situação", fieldValue = inputValue enrollment.status, placeholder = "Selecione uma situação" }}
    {submitButton { label = "Salvar" }}
|]

noStudents :: Html
noStudents = [hsx|
    <p>Nenhum estudante cadastrado. <a href={NewStudentAction}>Cadastrar estudante</a></p>
|]

noCourses :: Html
noCourses = [hsx|
    <p>Nenhum curso cadastrado. <a href={NewCourseAction}>Cadastrar curso</a></p>
|]
