module Web.View.Enrollments.Index where
import Web.View.Prelude

data IndexView = IndexView { enrollments :: [Enrollment] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>Index<a href={pathTo NewEnrollmentAction} class="btn btn-primary ms-4">+ New</a></h1>
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Student Id</th>
                        <th>Course Id</th>
                        <th>Enrollment Date</th>
                        <th>Status</th>
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
                [ breadcrumbLink "Enrollments" EnrollmentsAction
                ]

renderEnrollment :: Enrollment -> Html
renderEnrollment enrollment = [hsx|
    <tr>
        <td>{enrollment.studentId}</td>
        <td>{enrollment.courseId}</td>
        <td>{enrollment.enrollmentDate}</td>
        <td>{enrollment.status}</td>
        <td><a href={ShowEnrollmentAction enrollment.id}>Show</a></td>
        <td><a href={EditEnrollmentAction enrollment.id} class="text-muted">Edit</a></td>
        <td><a href={DeleteEnrollmentAction enrollment.id} class="js-delete text-muted">Delete</a></td>
    </tr>
|]