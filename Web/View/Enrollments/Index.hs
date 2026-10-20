module Web.View.Enrollments.Index where
import Web.View.Prelude

data IndexView = IndexView { enrollments :: [Enrollment], students :: [Student], courses :: [Course] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>{if isStudent then "Minhas matrículas" else "Matrículas" :: Text}{when isAdmin (newEnrollmentLink)}</h1>
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Estudante</th>
                        <th>Curso</th>
                        <th>Data da matrícula</th>
                        <th>Situação</th>
                        <th></th>
                        <th></th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>{forEach enrollments (renderEnrollment students courses)}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Matrículas" EnrollmentsAction
                ]

renderEnrollment :: (?request :: Request) => [Student] -> [Course] -> Enrollment -> Html
renderEnrollment students courses enrollment = [hsx|
    <tr>
        <td>{maybe "Estudante indisponível" (.name) (find (\student -> unpackId student.id == enrollment.studentId) students)}</td>
        <td>{maybe "Curso indisponível" (.name) (find (\course -> unpackId course.id == enrollment.courseId) courses)}</td>
        <td>{enrollment.enrollmentDate}</td>
        <td><span class="status-badge">{enrollmentStatusLabel enrollment.status}</span></td>
        <td><a href={ShowEnrollmentAction enrollment.id}>Visualizar</a></td>
        <td>{when isAdmin (editEnrollmentLink enrollment)}</td>
        <td>{when isAdmin (deleteEnrollmentLink enrollment)}</td>
    </tr>
|]

newEnrollmentLink :: (?request :: Request) => Html
newEnrollmentLink = [hsx|<a href={pathTo NewEnrollmentAction} class="btn btn-primary ms-4">+ Nova matrícula</a>|]

editEnrollmentLink :: (?request :: Request) => Enrollment -> Html
editEnrollmentLink enrollment = [hsx|<a href={EditEnrollmentAction enrollment.id} class="text-muted">Editar</a>|]

deleteEnrollmentLink :: (?request :: Request) => Enrollment -> Html
deleteEnrollmentLink enrollment = [hsx|<a href={DeleteEnrollmentAction enrollment.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este registro?">Excluir</a>|]
