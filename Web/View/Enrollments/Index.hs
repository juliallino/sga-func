module Web.View.Enrollments.Index where
import Web.View.Prelude

data IndexView = IndexView { enrollments :: [Enrollment], students :: [Student], subjects :: [Subject], periods :: [AcademicPeriod] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>{if isStudent then "Minhas matrículas" else "Matrículas" :: Text}{when isAdmin (newEnrollmentLink)}</h1>
        {when (null enrollments) (emptyState "enrollments" "Nenhuma matrícula encontrada" "As matrículas disponíveis para sua conta serão exibidas aqui.")}
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th scope="col">Estudante</th>
                        <th scope="col">Disciplina</th>
                        <th scope="col">Período</th>
                        <th scope="col">Data da matrícula</th>
                        <th scope="col">Situação</th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                    </tr>
                </thead>
                <tbody>{forEach enrollments (renderEnrollment students subjects periods)}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Matrículas" EnrollmentsAction
                ]

renderEnrollment :: (?request :: Request) => [Student] -> [Subject] -> [AcademicPeriod] -> Enrollment -> Html
renderEnrollment students subjects periods enrollment = [hsx|
    <tr>
        <td>{maybe "Estudante indisponível" (.name) (find (\student -> unpackId student.id == enrollment.studentId) students)}</td>
        <td>{maybe "Disciplina indisponível" (.name) (find (\subject -> unpackId subject.id == enrollment.subjectId) subjects)}</td>
        <td>{maybe "Sem período" (.name) (find (\period -> Just (unpackId period.id) == enrollment.academicPeriodId) periods)}</td>
        <td>{enrollment.enrollmentDate}</td>
        <td><span class="status-badge">{enrollmentStatusLabel enrollment.status}</span></td>
        <td><a href={ShowEnrollmentAction enrollment.id}>Visualizar</a></td>
        <td>{when isAdmin (editEnrollmentLink enrollment)}</td>
        <td>{when (isAdmin && enrollment.status /= Inactive) (deactivateEnrollmentButton enrollment)}</td>
        <td>{when isAdmin (deleteEnrollmentLink enrollment)}</td>
    </tr>
|]

newEnrollmentLink :: (?request :: Request) => Html
newEnrollmentLink = [hsx|<a href={pathTo NewEnrollmentAction} class="btn btn-primary ms-4">+ Nova matrícula</a>|]

editEnrollmentLink :: (?request :: Request) => Enrollment -> Html
editEnrollmentLink enrollment = [hsx|<a href={EditEnrollmentAction enrollment.id} class="text-muted">Editar</a>|]

-- POST simples (sem JavaScript): desativar é reversível pela edição.
deactivateEnrollmentButton :: (?request :: Request) => Enrollment -> Html
deactivateEnrollmentButton enrollment = [hsx|
    <form method="POST" action={DeactivateEnrollmentAction enrollment.id} class="d-inline">
        <button type="submit" class="btn btn-link p-0 text-muted align-baseline">Desativar</button>
    </form>
|]

deleteEnrollmentLink :: (?request :: Request) => Enrollment -> Html
deleteEnrollmentLink enrollment = [hsx|<a href={DeleteEnrollmentAction enrollment.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este registro?">Excluir</a>|]
