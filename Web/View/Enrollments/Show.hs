module Web.View.Enrollments.Show where

import Web.View.Prelude

data ShowView = ShowView
    { enrollment :: Enrollment
    , grades :: [Grade]
    , media :: Maybe Double
    }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}

        <h1>Detalhes da matrícula</h1>

        <dl>
            <dt>ID do estudante</dt>
            <dd>{enrollment.studentId}</dd>

            <dt>ID do curso</dt>
            <dd>{enrollment.courseId}</dd>

            <dt>Data da matrícula</dt>
            <dd>{enrollment.enrollmentDate}</dd>

            <dt>Situação</dt>
            <dd>{enrollmentStatusLabel enrollment.status}</dd>

            <dt>Quantidade de avaliações</dt>
            <dd>{length grades}</dd>

            <dt>Média ponderada</dt>
            <dd>{textoMedia}</dd>
        </dl>
    |]
        where
            textoMedia = case media of
                Just valor -> show valor
                Nothing | null grades -> "Ainda não há avaliações"
                        | otherwise -> "Não foi possível calcular a média: verifique as notas e os pesos."

            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Matrículas" EnrollmentsAction
                , breadcrumbText "Detalhes da matrícula"
                ]
