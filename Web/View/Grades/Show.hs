module Web.View.Grades.Show where
import Web.View.Prelude

data ShowView = ShowView { grade :: Grade, enrollment :: Enrollment, student :: Student, course :: Course, subject :: Subject }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}
        <h1>Detalhes da nota</h1>
        <dl>
            <dt>Estudante</dt><dd>{student.name} · {student.enrollmentNumber}</dd>
            <dt>Disciplina</dt><dd>{subject.name} · {subject.code}</dd>
            <dt>Curso</dt><dd>{course.name} · {course.code}</dd>
            <dt>Matrícula</dt><dd><a href={ShowEnrollmentAction enrollment.id}>Consultar matrícula</a></dd>
            <dt>Nome da avaliação</dt><dd>{grade.assessmentName}</dd>
            <dt>Nota</dt><dd>{grade.score}</dd>
            <dt>Peso</dt><dd>{grade.weight}</dd>
        </dl>

        <div class="detail-actions">
            <a class="btn btn-outline-primary" href={GradesAction}>Voltar à listagem</a>
            {when canWriteGrades (editLink grade)}
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                            [ breadcrumbLink "Notas" GradesAction
                            , breadcrumbText "Detalhes da nota"
                            ]

editLink :: Grade -> Html
editLink grade = [hsx|<a class="btn btn-primary" href={EditGradeAction grade.id}>Editar</a>|]
