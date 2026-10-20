module Web.View.Static.Welcome where
import Web.View.Prelude
import Numeric (showFFloat)

data PortalOverview
    = AdminOverview Int Int Int Int Int
    | StudentOverview Int Int
    | TeacherOverview Int

data WelcomeView = WelcomeView { user :: User, overview :: PortalOverview }

instance View WelcomeView where
    html WelcomeView { .. } = [hsx|
        <div class="page-heading"><div><p class="eyebrow">{roleLabel user.role_}</p><h1>Olá, {user.name}.</h1><p class="page-description">Bem-vindo ao seu Portal Acadêmico.</p></div><span class="semester-label">SGA · Vida acadêmica</span></div>
        {renderOverview overview}
    |]

renderOverview :: PortalOverview -> Html
renderOverview (AdminOverview students teachers courses subjects enrollments) = [hsx|
    <section class="dashboard-section" aria-labelledby="overview-title">
        <div class="section-heading"><h2 id="overview-title">Visão geral</h2><span>Cadastros acadêmicos</span></div>
        <div class="metrics-grid">
            {metric "students" "Estudantes" students (pathTo StudentsAction)}
            {metric "teachers" "Professores" teachers (pathTo TeachersAction)}
            {metric "courses" "Cursos" courses (pathTo CoursesAction)}
            {metric "subjects" "Disciplinas" subjects (pathTo SubjectsAction)}
            {metric "enrollments" "Matrículas" enrollments (pathTo EnrollmentsAction)}
        </div>
    </section>
    <div class="section-heading"><h2>Acesso rápido</h2><span>Organize a rotina acadêmica</span></div>
    <div class="quick-grid">
        {quick "students" "Cadastrar estudante" "Comece pelo cadastro acadêmico do estudante." (pathTo NewStudentAction)}
        {quick "enrollments" "Nova matrícula" "Gerencie os vínculos dos estudantes." (pathTo NewEnrollmentAction)}
        {quick "grades" "Avaliações" "Registre notas e acompanhe os resultados." (pathTo GradesAction)}
    </div>
|]
renderOverview (StudentOverview enrollments grades) = [hsx|
    <div class="metrics-grid metrics-grid-small">
        {metric "enrollments" "Minhas matrículas" enrollments (pathTo EnrollmentsAction)}
        {metric "grades" "Minhas avaliações" grades (pathTo GradesAction)}
    </div>
    <div class="section-heading"><h2>Minha vida acadêmica</h2></div>
    <div class="quick-grid">
        {quick "users" "Meu perfil" "Consulte seus dados acadêmicos." (pathTo MyProfileAction)}
        {quick "subjects" "Minhas disciplinas" "Acompanhe seus vínculos acadêmicos." (pathTo StudentSubjectsAction)}
        {quick "grades" "Minhas médias" "Veja os resultados das suas avaliações." (pathTo StudentAveragesAction)}
    </div>
|]
renderOverview (TeacherOverview subjects) = [hsx|
    <div class="metrics-grid metrics-grid-small">{metric "subjects" "Disciplinas sob minha responsabilidade" subjects (pathTo SubjectsAction)}</div>
    <div class="section-heading"><h2>Área do professor</h2></div>
    <div class="quick-grid">
        {quick "subjects" "Minhas disciplinas" "Consulte as disciplinas atribuídas a você." (pathTo SubjectsAction)}
        {quick "students" "Estudantes vinculados" "Consulte a disponibilidade dos vínculos acadêmicos." (pathTo TeacherStudentsAction)}
        {quick "grades" "Lançar avaliações" "Confira a disponibilidade para lançamento." (pathTo TeacherAssessmentsAction)}
    </div>
|]

metric :: Text -> Text -> Int -> Text -> Html
metric icon label total url = [hsx|
    <a class="metric-card" href={url} aria-label={label <> ": " <> show total}><span class="metric-icon">{moduleIcon icon}</span><span class="metric-value">{total}</span><span class="metric-label">{label}</span><span class="metric-link">Consultar <span aria-hidden="true">→</span></span></a>
|]

quick :: Text -> Text -> Text -> Text -> Html
quick icon title description url = [hsx|
    <a class="quick-card" href={url}><span class="quick-icon">{moduleIcon icon}</span><h3>{title}</h3><p>{description}</p><span class="quick-arrow" aria-hidden="true">↗</span></a>
|]

data NoticeView = NoticeView { title :: Text, message :: Text }
instance View NoticeView where
    html NoticeView { .. } = [hsx|
        <p class="eyebrow">Portal acadêmico</p><h1>{title}</h1>
        <div class="portal-notice">{moduleIcon "subjects"}<p>{message}</p></div>
        <a class="btn btn-outline-primary" href={WelcomeAction}>Voltar ao início</a>
    |]

data AverageSummary = AverageSummary
    { enrollment :: Enrollment, courseName :: Text, average :: Maybe Double, assessmentCount :: Int }
data AveragesView = AveragesView { summaries :: [AverageSummary] }
instance View AveragesView where
    html AveragesView { .. } = [hsx|
        <p class="eyebrow">Resultados acadêmicos</p><h1>Minhas médias</h1>
        <p class="page-description">Médias ponderadas das avaliações registradas nas suas matrículas.</p>
        {when (null summaries) emptyAverages}
        <div class="table-responsive"><table class="table"><thead><tr><th>Curso da matrícula</th><th>Situação</th><th>Avaliações</th><th>Média ponderada</th><th></th></tr></thead><tbody>{forEach summaries renderAverage}</tbody></table></div>
    |]
renderAverage :: AverageSummary -> Html
renderAverage summary = [hsx|
    <tr><td>{summary.courseName}</td><td><span class="status-badge">{enrollmentStatusLabel summary.enrollment.status}</span></td><td>{summary.assessmentCount}</td><td>{averageText summary}</td><td><a href={ShowEnrollmentAction summary.enrollment.id}>Ver avaliações</a></td></tr>
|]
averageText :: AverageSummary -> Text
averageText summary = case summary.average of
    Just value -> cs (showFFloat (Just 2) value "")
    Nothing | summary.assessmentCount == 0 -> "Sem avaliações"
            | otherwise -> "Avaliações inválidas"
emptyAverages :: Html
emptyAverages = [hsx|<p class="portal-notice">Você ainda não possui matrículas.</p>|]
