module Web.View.Courses.New where
import Web.View.Prelude

data NewView = NewView { course :: Course }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>New Course</h1>
        {renderForm course}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Courses" CoursesAction
                , breadcrumbText "New Course"
                ]

renderForm :: Course -> Html
renderForm course = formFor course [hsx|
    {(textField #name)}
    {(textField #code)}
    {(numberField #workload)}
    {submitButton}

|]