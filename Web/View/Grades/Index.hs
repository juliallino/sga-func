module Web.View.Grades.Index where
import Web.View.Prelude
import Web.View.Grades.Form (EnrollmentOption (..))

data IndexView = IndexView { grades :: [Grade], enrollmentOptions :: [EnrollmentOption] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>{if isStudent then "Minhas notas" else "Avaliações" :: Text}{when canWriteGrades (newGradeLink)}</h1>
        {when (null grades) (emptyState "grades" "Nenhuma avaliação encontrada" "As avaliações disponíveis para sua conta serão exibidas aqui.")}
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th scope="col">Matrícula</th>
                        <th scope="col">Nome da avaliação</th>
                        <th scope="col">Nota</th>
                        <th scope="col">Peso</th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                    </tr>
                </thead>
                <tbody>{forEach grades (renderGrade enrollmentOptions)}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Notas" GradesAction
                ]

renderGrade :: (?request :: Request) => [EnrollmentOption] -> Grade -> Html
renderGrade enrollmentOptions grade = [hsx|
    <tr>
        <td>{maybe "Matrícula indisponível" (.optionLabel) (find (\option -> option.optionId == grade.enrollmentId) enrollmentOptions)}</td>
        <td>{grade.assessmentName}</td>
        <td>{grade.score}</td>
        <td>{grade.weight}</td>
        <td><a href={ShowGradeAction grade.id}>Visualizar</a></td>
        <td>{when canWriteGrades (editGradeLink grade)}</td>
        <td>{when isAdmin (deleteGradeLink grade)}</td>
    </tr>
|]

newGradeLink :: (?request :: Request) => Html
newGradeLink = [hsx|<a href={pathTo NewGradeAction} class="btn btn-primary ms-4">+ Nova nota</a>|]

editGradeLink :: (?request :: Request) => Grade -> Html
editGradeLink grade = [hsx|<a href={EditGradeAction grade.id} class="text-muted">Editar</a>|]

deleteGradeLink :: (?request :: Request) => Grade -> Html
deleteGradeLink grade = [hsx|<a href={DeleteGradeAction grade.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este registro?">Excluir</a>|]
