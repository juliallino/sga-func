module Web.View.Courses.Index where
import Web.View.Prelude

data IndexView = IndexView { courses :: [Course] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>Index<a href={pathTo NewCourseAction} class="btn btn-primary ms-4">+ New</a></h1>
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Code</th>
                        <th>Workload</th>
                        <th></th>
                        <th></th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>{forEach courses renderCourse}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Courses" CoursesAction
                ]

renderCourse :: Course -> Html
renderCourse course = [hsx|
    <tr>
        <td>{course.name}</td>
        <td>{course.code}</td>
        <td>{course.workload}</td>
        <td><a href={ShowCourseAction course.id}>Show</a></td>
        <td><a href={EditCourseAction course.id} class="text-muted">Edit</a></td>
        <td><a href={DeleteCourseAction course.id} class="js-delete text-muted">Delete</a></td>
    </tr>
|]