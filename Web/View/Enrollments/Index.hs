module Web.View.Enrollments.Index where
import Web.View.Prelude

data IndexView = IndexView { enrollments :: [Enrollment] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>Matrículas<a href={pathTo NewEnrollmentAction} class="btn btn-primary ms-4">+ Nova matrícula</a></h1>
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>ID do estudante</th>
                        <th>ID do curso</th>
                        <th>Data da matrícula</th>
                        <th>Situação</th>
                        <th></th>
                        <th></th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>{forEach enrollments renderEnrollment}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Matrículas" EnrollmentsAction
                ]

renderEnrollment :: Enrollment -> Html
renderEnrollment enrollment = [hsx|
    <tr>
        <td>{enrollment.studentId}</td>
        <td>{enrollment.courseId}</td>
        <td>{enrollment.enrollmentDate}</td>
        <td>{enrollmentStatusLabel enrollment.status}</td>
        <td><a href={ShowEnrollmentAction enrollment.id}>Visualizar</a></td>
        <td><a href={EditEnrollmentAction enrollment.id} class="text-muted">Editar</a></td>
        <td><a href={DeleteEnrollmentAction enrollment.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este registro?">Excluir</a></td>
    </tr>
|]
