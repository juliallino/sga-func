module Web.View.TeacherPortal.Students where
import Web.View.Prelude

data IndexView = IndexView { subject :: Subject, enrollments :: [Enrollment], students :: [Student] }
instance View IndexView where
    html IndexView { .. } = [hsx|
        <p class="eyebrow">Portal do Professor</p><h1>Estudantes · {subject.name}</h1>
        <a class="btn btn-primary" href={TeacherSubjectAssessmentsAction subject.id}>Consultar e lançar avaliações</a>
        <div class="table-responsive"><table class="table"><thead><tr><th>Estudante</th><th>Registro</th><th>Situação</th><th></th></tr></thead>
        <tbody>{forEach enrollments (renderEnrollment students)}</tbody></table></div>
    |]
renderEnrollment :: [Student] -> Enrollment -> Html
renderEnrollment students enrollment = [hsx|
    <tr><td>{maybe "Estudante indisponível" (.name) student}</td><td>{maybe "—" (.enrollmentNumber) student}</td><td>{enrollmentStatusLabel enrollment.status}</td><td><a href={ShowEnrollmentAction enrollment.id}>Avaliações e média</a></td></tr>
|]
    where student = find (\value -> unpackId value.id == enrollment.studentId) students
