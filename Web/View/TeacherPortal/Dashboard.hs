module Web.View.TeacherPortal.Dashboard where

import Web.View.Prelude
import Web.View.Static.Welcome (metric, quick)
import Web.View.Dashboard.Report (AcademicReport, renderDisciplineFilters, averageText)
import Application.Helper.Portal (SubjectPerformance (..))
import qualified Application.Domain.Academic as Academic
import Web.View.Portal.Academic

data DashboardView = DashboardView { teacher :: Teacher, subjectCount :: Int, studentCount :: Int, assessmentCount :: Int, subjects :: [Subject], courses :: [Course], academicReport :: AcademicReport, enrollments :: [Enrollment], performances :: [SubjectPerformance] }

instance View DashboardView where
    html DashboardView { .. } = [hsx|
        <div class="page-heading">
            <div><p class="eyebrow">Portal do Professor</p><h1>Olá, {teacher.name}.</h1><p class="page-description">Acompanhe suas disciplinas e sua rotina acadêmica.</p></div>
            <span class="semester-label">SGA · Área docente</span>
        </div>
        <section class="dashboard-section" aria-labelledby="teacher-overview">
            <div class="section-heading"><h2 id="teacher-overview">Visão geral</h2><span>Somente suas disciplinas autorizadas</span></div>
            <div class="metrics-grid teacher-metrics">
                {metric "subjects" "Disciplinas sob minha responsabilidade" subjectCount (pathTo SubjectsAction)}
                {metric "students" "Estudantes matriculados" studentCount (pathTo TeacherStudentsAction)}
                {metric "grades" "Avaliações cadastradas" assessmentCount (pathTo TeacherAssessmentsAction)}
            </div>
        </section>
        {when (subjectCount == 0) emptyAssignments}
        <section class="dashboard-section" aria-labelledby="authorized-disciplines">
            <h2 id="authorized-disciplines">Disciplinas autorizadas</h2>
            {renderDisciplineFilters academicReport (pathTo TeacherDashboardAction)}
            <p class="page-description">Selecione uma disciplina para consultar estudantes, avaliações, médias e ranking.</p>
            {when (null subjects) (emptyState "subjects" "Nenhuma disciplina encontrada" "Revise os filtros ou solicite à administração a atribuição de disciplinas.")}
            <div class="table-responsive"><table class="table"><thead><tr><th scope="col">Disciplina</th><th scope="col">Curso</th><th scope="col">Estudantes</th><th scope="col">Médias e ranking por disciplina</th></tr></thead><tbody>{forEach subjects (renderAuthorizedSubject courses enrollments)}</tbody></table></div>
        </section>
        <section class="dashboard-section" aria-labelledby="teacher-performance">
            <div class="section-heading"><h2 id="teacher-performance">Resumo do desempenho acadêmico</h2><a href={AcademicRankingsAction}>Consultar rankings das disciplinas</a></div>
            <p class="page-description">Média atual da turma por disciplina: média simples das médias ponderadas disponíveis. Matrículas sem média ficam fora desse cálculo. Não representa fechamento oficial.</p>
            {approvalNotice}
            <div class="table-responsive"><table class="table"><caption class="visually-hidden">Desempenho por disciplina autorizada</caption><thead><tr><th scope="col">Disciplina</th><th scope="col">Matriculados</th><th scope="col">Média atual da turma</th><th scope="col">Com média</th><th scope="col">Sem média</th><th scope="col">Aprovados</th><th scope="col">Desempenho insuficiente</th></tr></thead><tbody>{forEach performances renderPerformance}</tbody></table></div>
        </section>
        <section aria-labelledby="teacher-shortcuts">
            <div class="section-heading"><h2 id="teacher-shortcuts">Acesso rápido</h2><span>Sua rotina acadêmica</span></div>
            <div class="quick-grid">
                {quick "subjects" "Minhas disciplinas" "Consulte as disciplinas atribuídas a você." (pathTo SubjectsAction)}
                {quick "students" "Meus estudantes" "Consulte seus estudantes." (pathTo TeacherStudentsAction)}
                {quick "grades" "Lançar notas" "Consulte suas avaliações." (pathTo TeacherGradeEntryAction)}
                {quick "enrollments" "Avaliações" "Consulte a disponibilidade das avaliações por disciplina." (pathTo TeacherAssessmentsAction)}
                {quick "users" "Meu perfil" "Consulte seus dados de professor." (pathTo TeacherProfileAction)}
            </div>
        </section>
    |]

emptyAssignments :: Html
emptyAssignments = [hsx|<div class="portal-notice" role="status"><p>Você ainda não possui disciplinas atribuídas. Solicite à administração a atribuição das disciplinas sob sua responsabilidade.</p></div>|]

unavailableMetric :: Text -> Text -> Text -> Html
unavailableMetric icon label explanation = [hsx|
    <div class="metric-card"><span class="metric-icon">{moduleIcon icon}</span><span class="metric-value" aria-label="Indisponível">—</span><span class="metric-label">{label}</span><span class="metric-link">{explanation}</span></div>
|]

data ProfileView = ProfileView { teacher :: Teacher }

instance View ProfileView where
    html ProfileView { .. } = [hsx|
        <p class="eyebrow">Portal do Professor</p><h1>Meu perfil</h1>
        <div class="table-responsive"><table class="table"><tbody>
            <tr><th scope="row">Nome</th><td>{teacher.name}</td></tr>
            <tr><th scope="row">E-mail</th><td>{teacher.email}</td></tr>
            <tr><th scope="row">Registro</th><td>{teacher.registrationNumber}</td></tr>
            <tr><th scope="row">Especialização</th><td>{fromMaybe "Não informada" teacher.specialization}</td></tr>
        </tbody></table></div>
        <a class="btn btn-outline-primary" href={TeacherDashboardAction}>Voltar ao início</a>
    |]

renderAuthorizedSubject :: [Course] -> [Enrollment] -> Subject -> Html
renderAuthorizedSubject courses enrollments subject = [hsx|
    <tr><td><a href={ShowSubjectAction subject.id}>{subject.name} · {subject.code}</a></td><td>{courseName}</td><td><a href={TeacherSubjectStudentsAction subject.id}>{length (filter (\e -> e.subjectId == unpackId subject.id) enrollments)} estudantes</a></td><td><a href={AcademicRankingsAction}>Médias e ranking</a> · <a href={TeacherSubjectAssessmentsAction subject.id}>Avaliações</a></td></tr>
|]
    where courseName = maybe "Curso indisponível" (.name) (find (\course -> unpackId course.id == subject.courseId) courses)

renderPerformance :: SubjectPerformance -> Html
renderPerformance row = [hsx|
    <tr><td><a href={TeacherSubjectStudentsAction row.performanceSubject.id}>{row.performanceSubject.name}</a></td><td>{row.performanceEnrollmentCount}</td><td>{averageText summary.currentClassAverage}</td><td>{summary.availableAverages}</td><td>{summary.missingAverages}</td><td>{optionalCount summary.approvedCount}</td><td>{optionalCount summary.insufficientCount}</td></tr>
|]
    where
        summary :: Academic.Performance
        summary = row.performanceSummary
