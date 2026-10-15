module Web.View.Grades.Edit where
import Web.View.Prelude
import Web.View.Grades.Form (EnrollmentOption, renderForm)

data EditView = EditView
    { grade :: Grade
    , enrollmentOptions :: [EnrollmentOption]
    }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Editar nota</h1>
        {renderForm grade enrollmentOptions}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Notas" GradesAction
                , breadcrumbText "Editar nota"
                ]
