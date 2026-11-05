module Web.View.Dashboard.Report where

import Web.View.Prelude
import qualified Application.Domain.Dashboard as D
import Numeric (showFFloat)
import qualified Data.Text as Text

data AcademicReport = AcademicReport
    { filters :: D.DashboardFilters
    , filterError :: Maybe Text
    , reportCourses :: [(Text, Text)]
    , reportSubjects :: [(Text, Text)]
    , results :: [D.AcademicResult]
    , reportRanking :: [D.RankingGroup]
    }

renderReport :: AcademicReport -> Text -> Html
renderReport report actionUrl = [hsx|
    <section class="dashboard-section" aria-labelledby="academic-report">
        <div class="section-heading"><h2 id="academic-report">Resultados por matrícula em disciplina</h2></div>
        <p class="page-description">Médias ponderadas das avaliações registradas. Os filtros abaixo se aplicam a esta consulta; os cards apresentam os totais do portal.</p>
        {renderFilters report actionUrl}
        {forEach report.filterError renderError}
        <p class="page-description">{length report.results} matrículas encontradas · {D.validAverageCount report.results} com média válida · {D.assessmentCount report.results} avaliações. A classificação geral exige médias disponíveis em todas as disciplinas.</p>
        {when (null report.results) (emptyState "grades" "Nenhum resultado disponível" "Revise os filtros. Matrículas sem avaliações não têm média; escolha uma disciplina disponível.")}
        <div class="table-responsive"><table class="table">
            <thead><tr><th scope="col">Estudante</th><th scope="col">Curso</th><th scope="col">Disciplina</th><th scope="col">Situação</th><th scope="col">Avaliações</th><th scope="col">Média ponderada</th><th scope="col">Acesso</th></tr></thead>
            <tbody>{forEach report.results renderResult}</tbody>
        </table></div>
    </section>
|]

renderFilters :: AcademicReport -> Text -> Html
renderFilters report actionUrl = [hsx|
    <form method="GET" action={actionUrl} class="dashboard-filters" aria-label="Filtros acadêmicos">
        <div><label class="form-label" for="filter-name">Nome do estudante</label><input id="filter-name" class="form-control" type="search" name="studentName" value={D.filterName report.filters}/></div>
        <div><label class="form-label" for="filter-course">Curso</label><select id="filter-course" class="form-select" name="courseId"><option value="">Todos os cursos disponíveis</option>{forEach report.reportCourses (renderOption (D.filterCourse report.filters))}</select></div>
        <div><label class="form-label" for="filter-subject">Disciplina</label><select id="filter-subject" class="form-select" name="subjectId"><option value="">Todas as disciplinas disponíveis</option>{forEach report.reportSubjects (renderOption (D.filterSubject report.filters))}</select></div>
        <div><label class="form-label" for="filter-status">Situação da matrícula</label><select id="filter-status" class="form-select" name="status"><option value="">Todas as situações</option>{forEach [("active", "Ativa"), ("suspended", "Suspensa"), ("completed", "Concluída")] (renderOption (D.filterStatus report.filters))}</select></div>
        <div><label class="form-label" for="filter-minimum">Média mínima</label><input id="filter-minimum" class="form-control" type="number" min="0" max="10" step="any" name="minimum" value={D.filterMinimum report.filters}/></div>
        <div><label class="form-label" for="filter-maximum">Média máxima</label><input id="filter-maximum" class="form-control" type="number" min="0" max="10" step="any" name="maximum" value={D.filterMaximum report.filters}/></div>
        <div class="form-actions"><button class="btn btn-primary" type="submit">Aplicar filtros</button><a class="btn btn-outline-secondary" href={actionUrl}>Limpar filtros</a></div>
    </form>
|]

renderOption :: Text -> (Text, Text) -> Html
renderOption selectedValue (value, label) = [hsx|<option value={value} selected={value == selectedValue}>{label}</option>|]

renderError :: Text -> Html
renderError message = [hsx|<div class="alert alert-danger" role="alert">{message}</div>|]

renderResult :: D.AcademicResult -> Html
renderResult result = [hsx|
    <tr><td>{D.resultStudentName result}</td><td>{D.resultCourseName result}</td><td>{D.resultSubjectName result}</td><td>{statusText (D.resultStatus result)}</td><td>{length (D.resultAssessments result)}</td><td>{averageText (D.resultAverage result)}</td><td><a href={"/ShowEnrollment?enrollmentId=" <> D.resultEnrollmentId result}>Ver avaliações</a></td></tr>
|]

averageText :: Maybe Double -> Text
averageText Nothing = "Sem média válida"
averageText (Just value) = cs (showFFloat (Just 2) value "")

statusText :: Text -> Text
statusText "active" = "Ativa"
statusText "suspended" = "Suspensa"
statusText "completed" = "Concluída"
statusText _ = "Situação indisponível"

renderRanking :: AcademicReport -> Html
renderRanking report = [hsx|
    <section class="dashboard-section" aria-labelledby="demo-ranking">
        <div class="section-heading"><h2 id="demo-ranking">Ranking por disciplina</h2></div>
        <p class="portal-notice">Médias ponderadas por disciplina. Ausência de avaliação não é nota zero; empates recebem a mesma posição. Filtros não renumeram a posição no grupo.</p>
        <a href={AcademicRankingsAction}>Consultar rankings por disciplina e geral</a>
        {when (null report.reportRanking) (emptyState "grades" "Sem estudantes comparáveis para o ranking" "Não há médias disponíveis para as disciplinas e filtros selecionados.")}
        {forEach report.reportRanking renderRankingGroup}
    </section>
|]

renderRankingGroup :: D.RankingGroup -> Html
renderRankingGroup group = [hsx|
    <section class="dashboard-section">
        <h3>{D.rankingCourse group} · {D.rankingSubject group}</h3>
        <div class="table-responsive"><table class="table"><thead><tr><th scope="col">Posição no grupo</th><th scope="col">Estudante</th><th scope="col">Curso</th><th scope="col">Disciplina</th><th scope="col">Média ponderada</th></tr></thead><tbody>{forEach (D.rankingEntries group) renderRankingEntry}</tbody></table></div>
    </section>
|]
    where planLabel = Text.intercalate "; " (map (\(name, weight) -> name <> " (peso " <> show weight <> ")") (D.rankingPlan group))

renderRankingEntry :: D.RankingEntry -> Html
renderRankingEntry entry = [hsx|
    <tr><td>{D.rankingPosition entry}</td><td>{D.resultStudentName result}</td><td>{D.resultCourseName result}</td><td>{D.resultSubjectName result}</td><td>{averageText (D.resultAverage result)}</td></tr>
|]
    where result = D.rankingResult entry

renderDisciplineFilters :: AcademicReport -> Text -> Html
renderDisciplineFilters report actionUrl = [hsx|
    <form method="GET" action={actionUrl} class="dashboard-filters" aria-label="Filtrar disciplinas autorizadas">
        <div><label class="form-label" for="teacher-course">Curso</label><select id="teacher-course" class="form-select" name="courseId"><option value="">Todos os cursos autorizados</option>{forEach report.reportCourses (renderOption (D.filterCourse report.filters))}</select></div>
        <div><label class="form-label" for="teacher-subject">Disciplina</label><select id="teacher-subject" class="form-select" name="subjectId"><option value="">Todas as disciplinas autorizadas</option>{forEach report.reportSubjects (renderOption (D.filterSubject report.filters))}</select></div>
        <div class="form-actions"><button class="btn btn-primary" type="submit">Aplicar filtros</button><a class="btn btn-outline-secondary" href={actionUrl}>Limpar filtros</a></div>
    </form>
    {forEach report.filterError renderError}
|]
