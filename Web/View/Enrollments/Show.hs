module Web.View.Enrollments.Show where

import Web.View.Prelude

data ShowView = ShowView
    { enrollment :: Enrollment
    , student :: Student
    , course :: Course
    , grades :: [Grade]
    , media :: Maybe Double
    }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}

        <h1>Detalhes da matrícula</h1>

        <dl>
            <dt>Estudante</dt>
            <dd>{student.name} · {student.enrollmentNumber}</dd>

            <dt>Curso</dt>
            <dd>{course.name} · {course.code}</dd>

            <dt>Data da matrícula</dt>
            <dd>{enrollment.enrollmentDate}</dd>

            <dt>Situação</dt>
            <dd>{enrollmentStatusLabel enrollment.status}</dd>

            <dt>Quantidade de avaliações</dt>
            <dd>{length grades}</dd>

            <dt>Média ponderada</dt>
            <dd>{textoMedia}</dd>
        </dl>

        <h2>Avaliações</h2>
        {when (null grades) noAssessments}
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr><th>Avaliação</th><th>Nota</th><th>Peso</th><th></th><th></th></tr>
                </thead>
                <tbody>{forEach grades renderAssessment}</tbody>
            </table>
        </div>
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

renderAssessment :: (?request :: Request) => Grade -> Html
renderAssessment grade = [hsx|
    <tr>
        <td>{grade.assessmentName}</td>
        <td>{grade.score}</td>
        <td>{grade.weight}</td>
        <td><a href={ShowGradeAction grade.id}>Visualizar</a></td>
        <td>{when isAdmin (editAssessment grade)}</td>
    </tr>
|]

noAssessments :: Html
noAssessments = [hsx|<p>Nenhuma avaliação registrada nesta matrícula.</p>|]

editAssessment :: Grade -> Html
editAssessment grade = [hsx|<a href={EditGradeAction grade.id} class="text-muted">Editar</a>|]
