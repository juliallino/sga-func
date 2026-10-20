module Web.View.Students.Show where
import Web.View.Prelude

data ShowView = ShowView { student :: Student }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}
        <h1>{if isStudent then "Meu perfil" else "Detalhes do estudante" :: Text}</h1>
        <dl>
            <dt>Nome</dt><dd>{student.name}</dd>
            <dt>E-mail</dt><dd>{student.email}</dd>
            <dt>Número de matrícula</dt><dd>{student.enrollmentNumber}</dd>
        </dl>

    |]
        where
            breadcrumb = renderBreadcrumb
                            [ breadcrumbLink "Estudantes" StudentsAction
                            , breadcrumbText "Detalhes do estudante"
                            ]
