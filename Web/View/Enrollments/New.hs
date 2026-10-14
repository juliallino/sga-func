module Web.View.Enrollments.New where
import Web.View.Prelude

data NewView = NewView { enrollment :: Enrollment }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>New Enrollment</h1>
        {renderForm enrollment}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Enrollments" EnrollmentsAction
                , breadcrumbText "New Enrollment"
                ]

renderForm :: Enrollment -> Html
renderForm enrollment = formFor enrollment [hsx|
    {- studentId needs to be a selectField -}
        {(textField #studentId)}
    {- courseId needs to be a selectField -}
        {(textField #courseId)}
    {(dateField #enrollmentDate)}
    {(textField #status)}
    {submitButton}

|]