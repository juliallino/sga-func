module Web.View.Enrollments.Edit where
import Web.View.Prelude
import Web.View.Enrollments.Form (renderForm)

data EditView = EditView
    { enrollment :: Enrollment
    , students :: [Student]
    , subjects :: [Subject]
    }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Editar matrícula</h1>
        {renderForm enrollment students subjects}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Matrículas" EnrollmentsAction
                , breadcrumbText "Editar matrícula"
                ]
