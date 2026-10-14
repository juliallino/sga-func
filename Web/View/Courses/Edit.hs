module Web.View.Courses.Edit where
import Web.View.Prelude

data EditView = EditView { course :: Course }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Edit Course</h1>
        {renderForm course}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Courses" CoursesAction
                , breadcrumbText "Edit Course"
                ]

renderForm :: Course -> Html
renderForm course = formFor course [hsx|
    {(textField #name)}
    {(textField #code)}
    {(numberField #workload)}
    {submitButton}

|]