module Web.View.Grades.Show where
import Web.View.Prelude

data ShowView = ShowView { grade :: Grade }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}
        <h1>Detalhes da nota</h1>
        <dl>
            <dt>Matrícula</dt><dd>{grade.enrollmentId}</dd>
            <dt>Nome da avaliação</dt><dd>{grade.assessmentName}</dd>
            <dt>Nota</dt><dd>{grade.score}</dd>
            <dt>Peso</dt><dd>{grade.weight}</dd>
        </dl>

    |]
        where
            breadcrumb = renderBreadcrumb
                            [ breadcrumbLink "Notas" GradesAction
                            , breadcrumbText "Detalhes da nota"
                            ]
