module Web.View.ClassSessions.Index where

import Web.View.Prelude
import qualified Application.Domain.Attendance as AttendanceDomain
import Web.View.ClassSessions.Form (RosterEntry (..), formatDay)
import Web.View.Portal.Academic (renderAttendance, attendanceNotice)

data IndexView = IndexView
    { subject :: Subject
    , sessionRows :: [(ClassSession, Int, Int)]
    , studentRows :: [(RosterEntry, AttendanceDomain.ResumoFrequencia)]
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}
        <div class="page-heading"><div><h1>Frequência · {subject.name}</h1><p class="page-description">{subject.code} · {length sessionRows} aulas com chamada registrada</p></div><a class="btn btn-primary" href={NewClassSessionAction subject.id}>+ Nova chamada</a></div>
        {attendanceNotice}

        <section class="dashboard-section" aria-labelledby="attendance-students">
            <div class="section-heading"><h2 id="attendance-students">Frequência por estudante</h2></div>
            {when (null studentRows) (emptyState "students" "Nenhum estudante matriculado" "Os estudantes aparecerão após a matrícula nesta disciplina.")}
            <div class="table-responsive"><table class="table"><caption class="visually-hidden">Frequência dos estudantes em {subject.name}</caption>
                <thead><tr><th scope="col">Estudante</th><th scope="col">Número de matrícula</th><th scope="col">Situação da matrícula</th><th scope="col">Presenças</th><th scope="col">Faltas</th><th scope="col">Frequência</th><th scope="col">Requisito de 75 %</th></tr></thead>
                <tbody>{forEach studentRows renderStudent}</tbody>
            </table></div>
        </section>

        <section class="dashboard-section" aria-labelledby="attendance-sessions">
            <div class="section-heading"><h2 id="attendance-sessions">Aulas registradas</h2></div>
            {when (null sessionRows) (emptyState "attendance" "Nenhuma chamada registrada" "Registre a chamada de cada aula para calcular a frequência.")}
            <div class="table-responsive"><table class="table"><caption class="visually-hidden">Chamadas de {subject.name}</caption>
                <thead><tr><th scope="col">Data</th><th scope="col">Conteúdo</th><th scope="col">Presentes</th><th scope="col"><span class="visually-hidden">Ações</span></th><th scope="col"><span class="visually-hidden">Ações</span></th></tr></thead>
                <tbody>{forEach sessionRows renderSession}</tbody>
            </table></div>
        </section>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Frequência" ClassSessionSubjectsAction
                , breadcrumbText [hsx|{subject.name}|]
                ]

renderStudent :: (RosterEntry, AttendanceDomain.ResumoFrequencia) -> Html
renderStudent (entry, resumo) = [hsx|
    <tr>
        <td>{maybe "Estudante indisponível" (.name) entry.rosterStudent}</td>
        <td>{maybe "—" (.enrollmentNumber) entry.rosterStudent}</td>
        <td>{enrollmentStatusLabel entry.rosterEnrollment.status}</td>
        <td>{AttendanceDomain.presencas resumo}</td>
        <td>{AttendanceDomain.faltas resumo}</td>
        <td>{renderAttendance resumo}</td>
        <td><span class="status-badge">{requirementText (AttendanceDomain.classificarFrequencia resumo)}</span></td>
    </tr>
|]

requirementText :: AttendanceDomain.SituacaoFrequencia -> Text
requirementText AttendanceDomain.SemAulasRegistradas = "Sem chamadas"
requirementText AttendanceDomain.FrequenciaRegular = "Atendido"
requirementText AttendanceDomain.FrequenciaAbaixoDoMinimo = "Abaixo de 75 %"

renderSession :: (?request :: Request) => (ClassSession, Int, Int) -> Html
renderSession (classSession, present, total) = [hsx|
    <tr>
        <td>{formatDay classSession.classDate}</td>
        <td>{fromMaybe "—" classSession.topic}</td>
        <td>{present} de {total}</td>
        <td><a href={EditClassSessionAction classSession.id}>Editar chamada</a></td>
        <td><a href={DeleteClassSessionAction classSession.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir esta chamada? As presenças e faltas desta aula serão removidas.">Excluir</a></td>
    </tr>
|]
