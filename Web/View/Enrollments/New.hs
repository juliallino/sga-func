module Web.View.Enrollments.New where

import Web.View.Prelude
import Web.View.Enrollments.Form (renderForm)

data NewView = NewView
    { enrollment :: Enrollment
    , students :: [Student]
    , courses :: [Course]
    }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>Nova matrícula</h1>
        {renderForm enrollment students courses}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Matrículas" EnrollmentsAction
                , breadcrumbText "Nova matrícula"
                ]
