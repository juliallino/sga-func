module Web.View.Enrollments.Show where

import Web.View.Prelude
import qualified Application.Domain.Attendance as AttendanceDomain
import Web.View.Portal.Academic (renderAttendance)
import Web.View.ClassSessions.Form (formatDay)

data ShowView = ShowView
    { enrollment :: Enrollment
    , student :: Student
    , subject :: Subject
    , grades :: [Grade]
    , media :: Maybe Double
    , attendance :: AttendanceDomain.ResumoFrequencia
    , attendanceRows :: [(ClassSession, Bool)]
    , period :: Maybe AcademicPeriod
    }

instance View ShowView where
    html ShowView { .. } = [hsx|
        {breadcrumb}

        <h1>Detalhes da matrícula</h1>

        <dl>
            <dt>Estudante</dt>
            <dd>{student.name} · {student.enrollmentNumber}</dd>

            <dt>Disciplina</dt>
            <dd>{subject.name} · {subject.code}</dd>

            <dt>Período letivo</dt>
            <dd>{maybe "Sem período" (.name) period}</dd>

            <dt>Data da matrícula</dt>
            <dd>{enrollment.enrollmentDate}</dd>

            <dt>Situação</dt>
            <dd>{enrollmentStatusLabel enrollment.status}</dd>

            <dt>Quantidade de avaliações</dt>
            <dd>{length grades}</dd>

            <dt>Média ponderada</dt>
            <dd>{textoMedia}</dd>

            <dt>Frequência</dt>
            <dd>{renderAttendance attendance} · mínimo de {AttendanceDomain.frequenciaMinimaPercentual} % para aprovação</dd>
        </dl>

        <h2>Avaliações</h2>
        {when (null grades) noAssessments}
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr><th scope="col">Avaliação</th><th scope="col">Nota</th><th scope="col">Peso</th><th scope="col"><span class="visually-hidden">Ações</span></th><th scope="col"><span class="visually-hidden">Ações</span></th></tr>
                </thead>
                <tbody>{forEach grades renderAssessment}</tbody>
            </table>
        </div>
        <h2>Frequência</h2>
        {when (null attendanceRows) noAttendance}
        <div class="table-responsive">
            <table class="table">
                <thead><tr><th scope="col">Data da aula</th><th scope="col">Conteúdo</th><th scope="col">Presença</th></tr></thead>
                <tbody>{forEach attendanceRows renderAttendanceRow}</tbody>
            </table>
        </div>
        <div class="detail-actions">
            <a class="btn btn-outline-primary" href={EnrollmentsAction}>Voltar à listagem</a>
            {when isAdmin (editLink enrollment)}
        </div>
    |]
        where
            textoMedia = case media of
                Just valor -> show valor
                Nothing | null grades -> "Ainda não há avaliações"
                        | otherwise -> "Não foi possível calcular a média: verifique as notas e os pesos."

            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Matrículas" EnrollmentsAction
                , breadcrumbText "Detalhes da matrícula"
                ]

renderAssessment :: (?request :: Request) => Grade -> Html
renderAssessment grade = [hsx|
    <tr>
        <td>{grade.assessmentName}</td>
        <td>{grade.score}</td>
        <td>{grade.weight}</td>
        <td><a href={ShowGradeAction grade.id}>Visualizar</a></td>
        <td>{when canWriteGrades (editAssessment grade)}</td>
    </tr>
|]

renderAttendanceRow :: (ClassSession, Bool) -> Html
renderAttendanceRow (classSession, present) = [hsx|
    <tr><td>{formatDay classSession.classDate}</td><td>{fromMaybe "—" classSession.topic}</td><td>{if present then "Presente" else "Falta" :: Text}</td></tr>
|]

noAttendance :: Html
noAttendance = [hsx|<p>Nenhuma chamada registrada nesta matrícula.</p>|]

noAssessments :: Html
noAssessments = [hsx|<p>Nenhuma avaliação registrada nesta matrícula.</p>|]

editAssessment :: Grade -> Html
editAssessment grade = [hsx|<a href={EditGradeAction grade.id} class="text-muted">Editar</a>|]

editLink :: Enrollment -> Html
editLink enrollment = [hsx|<a class="btn btn-primary" href={EditEnrollmentAction enrollment.id}>Editar</a>|]
