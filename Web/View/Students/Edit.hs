module Web.View.Students.Edit where
import Web.View.Prelude

data EditView = EditView { student :: Student }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Edit Student</h1>
        {renderForm student}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Students" StudentsAction
                , breadcrumbText "Edit Student"
                ]

renderForm :: Student -> Html
renderForm student = formFor student [hsx|
    {(textField #name)}
    {(textField #email)}
    {(textField #enrollmentNumber)}
    {submitButton}

|]