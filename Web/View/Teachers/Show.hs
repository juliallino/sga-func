module Web.View.Teachers.Show where
import Web.View.Prelude

data ShowView = ShowView { teacher :: Teacher }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}
        <h1>Detalhes do professor</h1>
        <dl>
            <dt>Nome</dt><dd>{teacher.name}</dd>
            <dt>E-mail</dt><dd>{teacher.email}</dd>
            <dt>Número de registro</dt><dd>{teacher.registrationNumber}</dd>
            <dt>Especialização</dt><dd>{fromMaybe "Não informada" teacher.specialization}</dd>
        </dl>

    |]
        where
            breadcrumb = renderBreadcrumb
                            [ breadcrumbLink "Professores" TeachersAction
                            , breadcrumbText "Detalhes do professor"
                            ]
