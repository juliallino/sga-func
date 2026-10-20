module Web.View.Subjects.Form (renderForm) where
import Web.View.Prelude

renderForm :: Subject -> [Course] -> Html
renderForm subject courses = formFor subject [hsx|
    {(textField #name) { fieldLabel = "Nome" }}
    {(textField #code) { fieldLabel = "Código" }}
    {(numberField #workload) { fieldLabel = "Carga horária", additionalAttributes = [("min", "1")] }}
    {(selectField #courseId courses) { fieldLabel = "Curso", placeholder = "Selecione um curso", required = True }}
    {when (null courses) noCourses}
    {submitButton { label = "Salvar" }}
|]

noCourses :: Html
noCourses = [hsx|
    <p>Nenhum curso cadastrado. <a href={NewCourseAction}>Cadastrar curso</a></p>
|]
