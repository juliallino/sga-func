module Web.View.Students.New where
import Web.View.Prelude

data NewView = NewView { student :: Student }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>New Student</h1>
        {renderForm student}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Students" StudentsAction
                , breadcrumbText "New Student"
                ]

renderForm :: Student -> Html
renderForm student = formFor student [hsx|
    {(textField #name)}
    {(textField #email)}
    {(textField #enrollmentNumber)}
    {submitButton}

|]