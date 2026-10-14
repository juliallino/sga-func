module Web.View.Courses.Show where
import Web.View.Prelude

data ShowView = ShowView { course :: Course }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}
        <h1>Show Course</h1>
        <dl>
            <dt>Name</dt><dd>{course.name}</dd>
            <dt>Code</dt><dd>{course.code}</dd>
            <dt>Workload</dt><dd>{course.workload}</dd>
        </dl>

    |]
        where
            breadcrumb = renderBreadcrumb
                            [ breadcrumbLink "Courses" CoursesAction
                            , breadcrumbText "Show Course"
                            ]