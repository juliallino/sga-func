module Web.View.Portal.Academic where

import Web.View.Prelude
import qualified Application.Domain.Academic as Academic
import qualified Application.Domain.Attendance as AttendanceDomain
import Web.View.Dashboard.Report (averageText)

data MetricValue = MetricValue { metricTitle :: Text, metricText :: Text, metricDescription :: Text }

renderMetric :: MetricValue -> Html
renderMetric value = [hsx|
    <div class="metric-card" aria-label={value.metricTitle <> ": " <> value.metricText}>
        <span class="metric-value">{value.metricText}</span><span class="metric-label">{value.metricTitle}</span><span class="metric-link">{value.metricDescription}</span>
    </div>
|]

optionalCount :: Maybe Int -> Text
optionalCount = maybe "—" show

standingText :: Academic.AcademicStanding -> Text
standingText Academic.NoAverage = "Média indisponível"
standingText Academic.PolicyPending = "Critério de aprovação não configurado"
standingText Academic.InProgress = "Em andamento"
standingText Academic.Approved = "Aprovado"
standingText Academic.Insufficient = "Desempenho insuficiente"
standingText Academic.AttendanceBelowMinimum = "Frequência abaixo de 75 %"
standingText Academic.FailedAttendance = "Reprovado por frequência"

renderStanding :: Academic.AcademicStanding -> Html
renderStanding value = [hsx|<span class="status-badge">{standingText value}</span>|]

approvalNotice :: Html
approvalNotice = case Academic.validPolicy Academic.approvalPolicy of
    Nothing -> [hsx|<p class="portal-notice" role="status">Critério de aprovação não configurado. As médias atuais não determinam aprovação ou reprovação; os indicadores de classificação ficam indisponíveis.</p>|]
    Just _ -> mempty

-- Ex.: "80.0 % (8 de 10 aulas)", com destaque quando abaixo do mínimo.
renderAttendance :: AttendanceDomain.ResumoFrequencia -> Html
renderAttendance resumo = case AttendanceDomain.classificarFrequencia resumo of
    AttendanceDomain.FrequenciaAbaixoDoMinimo -> [hsx|<span class="attendance-low">{AttendanceDomain.textoFrequencia resumo}</span>|]
    _ -> [hsx|<span>{AttendanceDomain.textoFrequencia resumo}</span>|]

attendanceNotice :: Html
attendanceNotice = [hsx|<p class="portal-notice" role="status">Frequência mínima para aprovação: {AttendanceDomain.frequenciaMinimaPercentual} % das aulas com chamada registrada. Abaixo disso a matrícula concluída é reprovada por frequência, qualquer que seja a média.</p>|]

renderCourseAverage :: (Course, Maybe Double) -> Html
renderCourseAverage (course, value) = [hsx|
    <div class="metric-card"><span class="metric-value">{maybe "—" (averageText . Just) value}</span><span class="metric-label">Média geral · {course.name}</span><span class="metric-link">Disponível quando todas as disciplinas do curso têm média. Contribuição igual por disciplina.</span></div>
|]

gradeEntryUrl :: Id Subject -> Maybe (Id Enrollment) -> Text
gradeEntryUrl subjectId enrollmentId = pathTo NewGradeAction <> "?subjectId=" <> show subjectId
    <> maybe "" (\value -> "&enrollmentId=" <> show value) enrollmentId
