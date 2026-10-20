module Web.View.Teachers.Edit where
import Web.View.Prelude
import Web.View.Teachers.Form (renderForm)

data EditView = EditView { teacher :: Teacher }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Editar professor</h1>
        {renderForm teacher}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Professores" TeachersAction
                , breadcrumbText "Editar professor"
                ]

