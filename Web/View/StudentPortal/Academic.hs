module Web.View.StudentPortal.Academic where
import Web.View.Prelude

data SubjectsView = SubjectsView { enrollments :: [Enrollment], subjects :: [Subject] }
instance View SubjectsView where
    html SubjectsView { .. } = [hsx|
        <p class="eyebrow">Portal do Estudante</p><h1>Minhas disciplinas</h1>
        {when (null enrollments) emptyEnrollments}
        <h2>Meus disciplinas matriculados</h2>
        <div class="table-responsive"><table class="table"><thead><tr><th scope="col">Disciplina</th><th scope="col">Código do disciplina</th><th scope="col">Carga horária do disciplina</th><th scope="col">Situação da matrícula</th><th scope="col"><span class="visually-hidden">Ações</span></th></tr></thead><tbody>{forEach enrollments (renderEnrollment subjects)}</tbody></table></div>
    |]

renderEnrollment :: [Subject] -> Enrollment -> Html
renderEnrollment subjects enrollment = [hsx|
    <tr><td>{maybe "Disciplina indisponível" (.name) subject}</td><td>{maybe "—" (.code) subject}</td><td>{maybe "—" (\value -> show value.workload <> " h") subject}</td><td>{enrollmentStatusLabel enrollment.status}</td><td><a href={ShowEnrollmentAction enrollment.id}>Consultar matrícula</a></td></tr>
|]
    where subject = find (\value -> unpackId value.id == enrollment.subjectId) subjects

data NotesView = NotesView { enrollments :: [Enrollment], subjects :: [Subject], grades :: [Grade] }
instance View NotesView where
    html NotesView { .. } = [hsx|
        <p class="eyebrow">Portal do Estudante</p><h1>Minhas notas</h1>
        {when (null enrollments) emptyEnrollments}
        {forEach enrollments (renderNotes subjects grades)}
    |]

renderNotes :: [Subject] -> [Grade] -> Enrollment -> Html
renderNotes subjects grades enrollment = [hsx|
    <section class="dashboard-section">
        <div class="section-heading"><h2>{subjectName}</h2><span>{enrollmentStatusLabel enrollment.status}</span></div>
        {when (null assessments) emptyNotes}
        <div class="table-responsive"><table class="table"><thead><tr><th scope="col">Nome da avaliação</th><th scope="col">Nota</th><th scope="col">Peso</th><th scope="col"><span class="visually-hidden">Ações</span></th></tr></thead><tbody>{forEach assessments renderNote}</tbody></table></div>
        <a class="btn btn-outline-primary" href={ShowEnrollmentAction enrollment.id}>Consultar avaliações e média</a>
    </section>
|]
    where
        subjectName = maybe "Disciplina indisponível" (.name) (find (\subject -> unpackId subject.id == enrollment.subjectId) subjects)
        assessments = filter (\grade -> grade.enrollmentId == unpackId enrollment.id) grades

renderNote :: Grade -> Html
renderNote grade = [hsx|<tr><td>{grade.assessmentName}</td><td>{grade.score}</td><td>{grade.weight}</td><td><a href={ShowGradeAction grade.id}>Consultar avaliação</a></td></tr>|]

emptyEnrollments :: Html
emptyEnrollments = emptyState "enrollments" "Você ainda não possui matrículas cadastradas." "Suas matrículas serão exibidas aqui após o cadastro pela administração."

emptyNotes :: Html
emptyNotes = emptyState "grades" "Sem avaliações nesta matrícula." "As notas serão exibidas após o registro das avaliações."
