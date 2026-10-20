module Web.View.Teachers.New where
import Web.View.Prelude
import Web.View.Teachers.Form (renderForm)

data NewView = NewView { teacher :: Teacher }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>Novo professor</h1>
        {renderForm teacher}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Professores" TeachersAction
                , breadcrumbText "Novo professor"
                ]

