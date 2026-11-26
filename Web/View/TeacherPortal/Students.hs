module Web.View.TeacherPortal.Students where

import Web.View.Prelude
import Application.Helper.Portal (enrollmentStanding)
import qualified Application.Domain.Attendance as AttendanceDomain
import qualified Application.Domain.Academic as Academic
import Web.View.Dashboard.Report (averageText)
import Web.View.Portal.Academic

data IndexView = IndexView
    { subject :: Subject, students :: [Student], results :: [(Enrollment, AttendanceDomain.ResumoFrequencia, Maybe Double)]
    , performance :: Academic.Performance, attendanceBelowMinimum :: Int
    , periods :: [AcademicPeriod]
    }
instance View IndexView where
    html IndexView { .. } = [hsx|
        <p class="eyebrow">Portal do Professor</p><h1>Estudantes · {subject.name}</h1>
        <div class="detail-actions"><a class="btn btn-outline-primary" href={TeacherStudentsAction}>Voltar às disciplinas</a><a class="btn btn-primary" href={TeacherSubjectAssessmentsAction subject.id}>Consultar avaliações</a><a class="btn btn-outline-primary" href={gradeEntryUrl subject.id Nothing}>Lançar avaliação</a><a class="btn btn-outline-primary" href={ClassSessionsAction subject.id}>Chamadas e frequência</a></div>
        <div class="metrics-grid teacher-metrics">
            {renderMetric (MetricValue "Média atual da turma" (maybe "—" (averageText . Just) performance.currentClassAverage) "Somente matrículas com média disponível")}
            {renderMetric (MetricValue "Aprovados" (optionalCount performance.approvedCount) "Matrículas concluídas com média e frequência mínimas")}
            {renderMetric (MetricValue "Reprovados por nota" (optionalCount performance.insufficientCount) "Matrículas concluídas com média abaixo de 5.0")}
            {renderMetric (MetricValue "Frequência abaixo de 75 %" (show attendanceBelowMinimum) "Matrículas com chamada registrada")}
        </div>
        {approvalNotice}
        {attendanceNotice}
        {when (null results) (emptyState "students" "Nenhum estudante matriculado" "Os estudantes aparecerão após a matrícula nesta disciplina pela administração.")}
        <div class="table-responsive"><table class="table"><caption class="visually-hidden">Estudantes matriculados em {subject.name}</caption><thead><tr><th scope="col">Nome</th><th scope="col">Número de matrícula</th><th scope="col">E-mail</th><th scope="col">Período</th><th scope="col">Média atual</th><th scope="col">Frequência</th><th scope="col">Situação acadêmica</th><th scope="col">Situação da matrícula</th><th scope="col">Acesso</th></tr></thead>
        <tbody>{forEach results (renderEnrollment subject students periods)}</tbody></table></div>
    |]

renderEnrollment :: Subject -> [Student] -> [AcademicPeriod] -> (Enrollment, AttendanceDomain.ResumoFrequencia, Maybe Double) -> Html
renderEnrollment subject students periods (enrollment, attendance, average) = [hsx|
    <tr><td>{maybe "Estudante indisponível" (.name) student}</td><td>{maybe "—" (.enrollmentNumber) student}</td><td>{maybe "—" (.email) student}</td><td>{maybe "Sem período" (.name) period}</td><td>{averageText average}</td><td>{renderAttendance attendance}</td><td>{renderStanding (enrollmentStanding enrollment attendance average)}</td><td>{enrollmentStatusLabel enrollment.status}</td><td><a href={ShowEnrollmentAction enrollment.id}>Avaliações e média</a><br/><a href={gradeEntryUrl subject.id (Just enrollment.id)}>Lançar nota</a></td></tr>
|]
    where
        student = find (\value -> unpackId value.id == enrollment.studentId) students
        period = find (\value -> Just (unpackId value.id) == enrollment.academicPeriodId) periods
