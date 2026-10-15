module Web.View.Grades.Index where
import Web.View.Prelude

data IndexView = IndexView { grades :: [Grade] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>Notas<a href={pathTo NewGradeAction} class="btn btn-primary ms-4">+ Nova nota</a></h1>
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Matrícula</th>
                        <th>Nome da avaliação</th>
                        <th>Nota</th>
                        <th>Peso</th>
                        <th></th>
                        <th></th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>{forEach grades renderGrade}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Notas" GradesAction
                ]

renderGrade :: Grade -> Html
renderGrade grade = [hsx|
    <tr>
        <td>{grade.enrollmentId}</td>
        <td>{grade.assessmentName}</td>
        <td>{grade.score}</td>
        <td>{grade.weight}</td>
        <td><a href={ShowGradeAction grade.id}>Visualizar</a></td>
        <td><a href={EditGradeAction grade.id} class="text-muted">Editar</a></td>
        <td><a href={DeleteGradeAction grade.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este registro?">Excluir</a></td>
    </tr>
|]
