module Web.View.StudentPortal.Dashboard where

import Web.View.Prelude
import Web.View.Dashboard.Report (AcademicReport, renderReport)
import Web.View.Static.Welcome (metric, quick)
import Application.Helper.Portal (StudentEnrollment)
import qualified Application.Domain.Academic as Academic
import Web.View.Portal.Academic

data DashboardView = DashboardView
    { student :: Student, rows :: [StudentEnrollment], assessmentCount :: Int
    , academicReport :: AcademicReport, courseAverages :: [(Course, Maybe Double)]
    , studentPerformance :: Academic.Performance
    }

instance View DashboardView where
    html DashboardView { .. } = [hsx|
        <div class="page-heading"><div><p class="eyebrow">Portal do Aluno</p><h1>Olá, {student.name}.</h1><p class="page-description">Matrícula: {student.enrollmentNumber}</p></div><span class="semester-label">SGA · Minha vida acadêmica</span></div>
        <section class="dashboard-section" aria-labelledby="student-overview">
            <div class="section-heading"><h2 id="student-overview">Minha vida acadêmica</h2><span>Somente seus registros</span></div>
            <div class="metrics-grid">
                {metric "subjects" "Disciplinas matriculadas" (length rows) (pathTo StudentSubjectsAction)}
                {metric "grades" "Minhas avaliações" assessmentCount (pathTo GradesAction)}
                {forEach courseAverages renderCourseAverage}
                {renderMetric (MetricValue "Disciplinas aprovadas" (optionalCount studentPerformance.approvedCount) "Conforme critério acadêmico configurado")}
                {renderMetric (MetricValue "Disciplinas pendentes" (optionalCount studentPerformance.pendingCount) "Ainda não classificadas como aprovadas")}
                {renderMetric (MetricValue "Sem média disponível" (show studentPerformance.missingAverages) "Ausência não equivale a nota zero")}
            </div>
            {approvalNotice}
        </section>
        <section aria-labelledby="student-results"><div class="section-heading"><h2 id="student-results">Resultados das minhas matrículas</h2></div>
            {when (null rows) (emptyState "enrollments" "Você ainda não possui matrículas cadastradas." "Suas disciplinas aparecerão após a matrícula pela administração.")}
            {when (assessmentCount == 0) (emptyState "grades" "Nenhuma avaliação recebida" "As médias estarão disponíveis após o lançamento das avaliações.")}
            {renderReport academicReport (pathTo StudentDashboardAction)}
        </section>
        <div class="section-heading"><h2>Acesso rápido</h2></div><div class="quick-grid">
            {quick "subjects" "Minhas disciplinas" "Consulte curso, professores e médias atuais." (pathTo StudentSubjectsAction)}
            {quick "grades" "Minhas notas" "Confira avaliações, notas e pesos." (pathTo GradesAction)}
            {quick "dashboard" "Minhas médias" "Acompanhe suas médias ponderadas." (pathTo StudentAveragesAction)}
            {quick "users" "Meu perfil" "Consulte nome, e-mail e matrícula." (pathTo MyProfileAction)}
        </div>
    |]
