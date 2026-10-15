module Web.View.Grades.New where
import Web.View.Prelude
import Web.View.Grades.Form (EnrollmentOption, renderForm)

data NewView = NewView
    { grade :: Grade
    , enrollmentOptions :: [EnrollmentOption]
    }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>Nova nota</h1>
        {renderForm grade enrollmentOptions}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Notas" GradesAction
                , breadcrumbText "Nova nota"
                ]
