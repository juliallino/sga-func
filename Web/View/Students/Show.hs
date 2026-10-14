module Web.View.Students.Show where
import Web.View.Prelude

data ShowView = ShowView { student :: Student }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}
        <h1>Show Student</h1>
        <dl>
            <dt>Name</dt><dd>{student.name}</dd>
            <dt>Email</dt><dd>{student.email}</dd>
            <dt>Enrollment Number</dt><dd>{student.enrollmentNumber}</dd>
        </dl>

    |]
        where
            breadcrumb = renderBreadcrumb
                            [ breadcrumbLink "Students" StudentsAction
                            , breadcrumbText "Show Student"
                            ]