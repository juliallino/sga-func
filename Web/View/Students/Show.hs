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

        <div class="detail-actions">
            <a class="btn btn-outline-primary" href={if isStudent then pathTo StudentDashboardAction else pathTo StudentsAction}>{if isStudent then "Voltar ao início" else "Voltar à listagem" :: Text}</a>
            {when isAdmin (editLink student)}
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                            [ if isStudent then breadcrumbLink "Início" StudentDashboardAction else breadcrumbLink "Estudantes" StudentsAction
                            , breadcrumbText "Detalhes do estudante"
                            ]

editLink :: Student -> Html
editLink student = [hsx|<a class="btn btn-primary" href={EditStudentAction student.id}>Editar</a>|]
