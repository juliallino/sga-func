module Web.View.StudentPortal.Dashboard where
import Web.View.Prelude
import Web.View.Dashboard.Report (AcademicReport, renderReport)
import Web.View.Static.Welcome (AverageSummary, metric, quick, renderAverage)

data DashboardView = DashboardView { student :: Student, summaries :: [AverageSummary], assessmentCount :: Int, academicReport :: AcademicReport }

instance View DashboardView where
    html DashboardView { .. } = [hsx|
        <div class="page-heading"><div><p class="eyebrow">Portal do Estudante</p><h1>Olá, {student.name}.</h1><p class="page-description">Matrícula: {student.enrollmentNumber}</p></div><span class="semester-label">SGA · Minha vida acadêmica</span></div>
        <div class="metrics-grid teacher-metrics">
            <div class="metric-card"><span class="metric-icon">{moduleIcon "subjects"}</span><span class="metric-value">{length summaries}</span><span class="metric-label">Disciplinas matriculadas</span><span class="metric-link">Disciplinas vinculadas</span></div>
            {metric "enrollments" "Minhas matrículas em disciplinas" (length summaries) (pathTo EnrollmentsAction)}
            {metric "grades" "Minhas avaliações" assessmentCount (pathTo GradesAction)}
        </div>
        <section aria-labelledby="student-results"><div class="section-heading"><h2 id="student-results">Resultados das minhas matrículas</h2></div>
            {when (null summaries) emptyEnrollments}
            {when (assessmentCount == 0) emptyGrades}
            {renderReport academicReport (pathTo StudentDashboardAction)}
        </section>
        <div class="section-heading"><h2>Acesso rápido</h2></div><div class="quick-grid">
            {quick "subjects" "Minhas disciplinas" "Consulte a disponibilidade dos seus vínculos." (pathTo StudentSubjectsAction)}
            {quick "grades" "Minhas notas" "Consulte suas avaliações cadastradas." (pathTo GradesAction)}
            {quick "dashboard" "Minhas médias" "Acompanhe suas médias ponderadas." (pathTo StudentAveragesAction)}
            {quick "users" "Meu perfil" "Consulte seus dados acadêmicos." (pathTo MyProfileAction)}
        </div>
    |]

emptyEnrollments :: Html
emptyEnrollments = [hsx|<p class="portal-notice">Você ainda não possui matrículas cadastradas.</p>|]

emptyGrades :: Html
emptyGrades = [hsx|<p class="portal-notice">Você ainda não possui notas cadastradas.</p>|]
