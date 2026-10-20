module Web.View.Subjects.Show where
import Web.View.Prelude

data ShowView = ShowView { subject :: Subject, course :: Course }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}
        <h1>Detalhes da disciplina</h1>
        <dl>
            <dt>Nome</dt><dd>{subject.name}</dd>
            <dt>Código</dt><dd>{subject.code}</dd>
            <dt>Carga horária</dt><dd>{subject.workload}</dd>
            <dt>Curso</dt><dd>{courseDetail course}</dd>
        </dl>

    |]
        where
            breadcrumb = renderBreadcrumb
                            [ breadcrumbLink "Disciplinas" SubjectsAction
                            , breadcrumbText "Detalhes da disciplina"
                            ]

courseDetail :: (?request :: Request) => Course -> Html
courseDetail course
    | isAdmin = [hsx|<a href={ShowCourseAction course.id}>{course.name} - {course.code}</a>|]
    | otherwise = [hsx|{course.name} - {course.code}|]
