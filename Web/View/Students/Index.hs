module Web.View.Students.Index where
import Web.View.Prelude

data IndexView = IndexView { students :: [Student] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>Index<a href={pathTo NewStudentAction} class="btn btn-primary ms-4">+ New</a></h1>
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Enrollment Number</th>
                        <th></th>
                        <th></th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>{forEach students renderStudent}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Students" StudentsAction
                ]

renderStudent :: Student -> Html
renderStudent student = [hsx|
    <tr>
        <td>{student.name}</td>
        <td>{student.email}</td>
        <td>{student.enrollmentNumber}</td>
        <td><a href={ShowStudentAction student.id}>Show</a></td>
        <td><a href={EditStudentAction student.id} class="text-muted">Edit</a></td>
        <td><a href={DeleteStudentAction student.id} class="js-delete text-muted">Delete</a></td>
    </tr>
|]