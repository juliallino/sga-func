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

            <dt>Status</dt>
            <dd>{enrollment.status}</dd>

            <dt>Quantidade de avaliações</dt>
            <dd>{length grades}</dd>

            <dt>Média ponderada</dt>
            <dd>{textoMedia}</dd>
        </dl>
    |]
        where
            textoMedia = case media of
                Just valor -> show valor
                Nothing -> "Ainda não há avaliações"

            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Enrollments" EnrollmentsAction
                , breadcrumbText "Detalhes da matrícula"
                ]