module Web.View.Courses.Edit where
import Web.View.Prelude

data EditView = EditView { course :: Course }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Editar curso</h1>
        {renderForm course}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Cursos" CoursesAction
                , breadcrumbText "Editar curso"
                ]

renderForm :: Course -> Html
renderForm course = formFor course [hsx|
    {(textField #name) { fieldLabel = "Nome" }}
    {(textField #code) { fieldLabel = "Código" }}
    {(numberField #workload) { fieldLabel = "Carga horária" }}
    {submitButton { label = "Salvar" }}

|]
