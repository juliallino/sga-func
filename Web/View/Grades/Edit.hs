module Web.View.Grades.Edit where
import Web.View.Prelude

data EditView = EditView { grade :: Grade }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Edit Grade</h1>
        {renderForm grade}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Grades" GradesAction
                , breadcrumbText "Edit Grade"
                ]

renderForm :: Grade -> Html
renderForm grade = formFor grade [hsx|
    {- enrollmentId needs to be a selectField -}
        {(textField #enrollmentId)}
    {(textField #assessmentName)}
    {(numberField #score)}
    {(numberField #weight)}
    {submitButton}

|]