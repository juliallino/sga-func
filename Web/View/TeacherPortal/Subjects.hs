module Web.View.TeacherPortal.Subjects where
import Web.View.Prelude
import Web.View.Portal.Academic (gradeEntryUrl)

data IndexView = IndexView { subjects :: [Subject], courses :: [Course], enrollments :: [Enrollment] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <p class="eyebrow">Portal do Professor</p><h1>Minhas disciplinas</h1>
        <p class="page-description">Somente disciplinas explicitamente atribuídas a você.</p>
        {when (null subjects) emptySubjects}
        <div class="table-responsive"><table class="table"><caption class="visually-hidden">Disciplinas autorizadas ao professor</caption><thead><tr><th scope="col">Nome</th><th scope="col">Código</th><th scope="col">Curso</th><th scope="col">Carga horária</th><th scope="col">Estudantes matriculados</th><th scope="col">Acesso</th></tr></thead><tbody>{forEach subjects (renderSubject courses enrollments)}</tbody></table></div>
    |]

emptySubjects :: Html
emptySubjects = emptyState "subjects" "Nenhuma disciplina atribuída" "Solicite à administração a atribuição das disciplinas sob sua responsabilidade."

renderSubject :: [Course] -> [Enrollment] -> Subject -> Html
renderSubject courses enrollments subject = [hsx|
    <tr><td><a href={ShowSubjectAction subject.id}>{subject.name}</a></td><td>{subject.code}</td><td>{courseName}</td><td>{subject.workload} h</td><td>{length (filter (\e -> e.subjectId == unpackId subject.id) enrollments)}</td><td><a href={TeacherSubjectStudentsAction subject.id}>Meus estudantes</a><br/><a href={TeacherSubjectAssessmentsAction subject.id}>Consultar avaliações</a> · <a href={gradeEntryUrl subject.id Nothing}>Lançar notas</a></td></tr>
|]
    where courseName = maybe "Curso indisponível" (.name) (find (\course -> unpackId course.id == subject.courseId) courses)

-- Each workspace uses only the subjects authorized by the controller.
data WorkspaceMode = Students | Assessments | GradeEntry deriving (Eq)
data WorkspaceView = WorkspaceView { subjects :: [Subject], courses :: [Course], mode :: WorkspaceMode }

instance View WorkspaceView where
    html WorkspaceView { .. } = [hsx|
        <div class="page-heading"><div><p class="eyebrow">Portal do Professor</p><h1>{workspaceTitle mode}</h1><p class="page-description">Selecione uma das suas disciplinas autorizadas.</p></div><a class="btn btn-outline-primary" href={SubjectsAction}>Minhas disciplinas</a></div>
        <div class="portal-notice" role="status">{moduleIcon "enrollments"}<p>{workspaceNotice mode}</p></div>
        {when (null subjects) (emptyState "subjects" "Nenhuma disciplina atribuída" "Solicite à administração a atribuição das disciplinas sob sua responsabilidade.")}
        <div class="table-responsive"><table class="table"><caption class="visually-hidden">Disciplinas autorizadas ao professor</caption>
            <thead><tr><th scope="col">Disciplina</th><th scope="col">Código</th><th scope="col">Curso</th><th scope="col">Situação</th><th scope="col">Acesso</th></tr></thead>
            <tbody>{forEach subjects (renderWorkspaceSubject courses mode)}</tbody>
        </table></div>
    |]

workspaceTitle :: WorkspaceMode -> Text
workspaceTitle Students = "Meus estudantes"
workspaceTitle Assessments = "Consulta de avaliações"
workspaceTitle GradeEntry = "Lançamento de notas"

workspaceNotice :: WorkspaceMode -> Text
workspaceNotice Students = "Consulte estudantes somente nas disciplinas autorizadas."
workspaceNotice Assessments = "Consulte as avaliações das disciplinas autorizadas."
workspaceNotice GradeEntry = "Lance e edite avaliações somente nas suas disciplinas autorizadas."

renderWorkspaceSubject :: [Course] -> WorkspaceMode -> Subject -> Html
renderWorkspaceSubject courses mode subject = [hsx|
    <tr><td>{subject.name}</td><td>{subject.code}</td><td>{courseName}</td><td><span class="status-badge">Disciplina autorizada</span></td><td><a href={workspaceUrl mode subject}>Acessar disciplina</a></td></tr>
|]
    where courseName = maybe "Curso indisponível" (.name) (find (\course -> unpackId course.id == subject.courseId) courses)

workspaceUrl :: WorkspaceMode -> Subject -> Text
workspaceUrl Students subject = pathTo (TeacherSubjectStudentsAction subject.id)
workspaceUrl Assessments subject = pathTo (TeacherSubjectAssessmentsAction subject.id)
workspaceUrl GradeEntry subject = gradeEntryUrl subject.id Nothing
