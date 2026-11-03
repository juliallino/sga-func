module Web.View.StudentPortal.Academic where

import Web.View.Prelude
import Application.Helper.Portal (StudentEnrollment (..), enrollmentStanding)
import Web.View.Dashboard.Report (averageText)
import Web.View.Portal.Academic (renderStanding, approvalNotice)
import qualified Data.Text as Text

data SubjectsView = SubjectsView { rows :: [StudentEnrollment] }
instance View SubjectsView where
    html SubjectsView { .. } = [hsx|
        <p class="eyebrow">Portal do Aluno</p><h1>Minhas disciplinas</h1>
        <p class="page-description">Disciplinas em que estou matriculado, seus docentes e resultados atuais.</p>
        {when (null rows) emptyEnrollments}
        <div class="table-responsive"><table class="table"><caption class="visually-hidden">Minhas disciplinas e médias atuais</caption><thead><tr><th scope="col">Disciplina</th><th scope="col">Código</th><th scope="col">Carga horária</th><th scope="col">Curso</th><th scope="col">Professor responsável</th><th scope="col">Situação da matrícula</th><th scope="col">Média atual</th><th scope="col">Situação acadêmica</th><th scope="col">Acesso</th></tr></thead><tbody>{forEach rows renderEnrollment}</tbody></table></div>
        {approvalNotice}
    |]

renderEnrollment :: StudentEnrollment -> Html
renderEnrollment row = [hsx|
    <tr><td>{row.rowSubject.name}</td><td>{row.rowSubject.code}</td><td>{row.rowSubject.workload} h</td><td>{maybe "Curso indisponível" (.name) row.rowCourse}</td><td>{teacherNames}</td><td>{enrollmentStatusLabel row.rowEnrollment.status}</td><td>{averageText row.rowAverage}</td><td>{renderStanding (enrollmentStanding row.rowEnrollment row.rowAverage)}</td><td><a href={ShowEnrollmentAction row.rowEnrollment.id}>Consultar matrícula</a></td></tr>
|]
    where teacherNames = if null row.rowTeachers then "Professor não atribuído" else Text.intercalate ", " (map (.name) row.rowTeachers)

data NotesView = NotesView { rows :: [StudentEnrollment] }
instance View NotesView where
    html NotesView { .. } = [hsx|
        <p class="eyebrow">Portal do Aluno</p><h1>Minhas notas</h1>
        <p class="page-description">Médias ponderadas calculadas com as notas e os pesos registrados. Resultados atuais podem ser parciais.</p>
        {when (null rows) emptyEnrollments}
        {forEach rows renderNotes}
        {approvalNotice}
    |]

renderNotes :: StudentEnrollment -> Html
renderNotes row = [hsx|
    <section class="dashboard-section">
        <div class="section-heading"><h2>{row.rowSubject.name}</h2><span>{enrollmentStatusLabel row.rowEnrollment.status}</span></div>
        <div class="academic-result"><strong>Média ponderada: {averageText row.rowAverage}</strong>{renderStanding (enrollmentStanding row.rowEnrollment row.rowAverage)}</div>
        {when (null row.rowGrades) emptyNotes}
        <div class="table-responsive"><table class="table"><caption class="visually-hidden">Avaliações de {row.rowSubject.name}</caption><thead><tr><th scope="col">Nome da avaliação</th><th scope="col">Nota obtida</th><th scope="col">Peso</th><th scope="col">Acesso</th></tr></thead><tbody>{forEach row.rowGrades renderNote}</tbody></table></div>
        <a class="btn btn-outline-primary" href={ShowEnrollmentAction row.rowEnrollment.id}>Consultar matrícula e avaliações</a>
    </section>
|]

renderNote :: Grade -> Html
renderNote grade = [hsx|<tr><td>{grade.assessmentName}</td><td>{grade.score}</td><td>{grade.weight}</td><td><a href={ShowGradeAction grade.id}>Consultar avaliação</a></td></tr>|]

emptyEnrollments :: Html
emptyEnrollments = emptyState "enrollments" "Você ainda não possui matrículas cadastradas." "Suas matrículas serão exibidas aqui após o cadastro pela administração."

emptyNotes :: Html
emptyNotes = emptyState "grades" "Sem avaliações nesta matrícula." "As notas serão exibidas após o registro das avaliações."
