module Web.View.Grades.New where
import Web.View.Prelude

data NewView = NewView { grade :: Grade }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>New Grade</h1>
        {renderForm grade}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Grades" GradesAction
                , breadcrumbText "New Grade"
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