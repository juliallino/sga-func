module Web.View.Enrollments.Edit where
import Web.View.Prelude

data EditView = EditView { enrollment :: Enrollment }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Edit Enrollment</h1>
        {renderForm enrollment}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Enrollments" EnrollmentsAction
                , breadcrumbText "Edit Enrollment"
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