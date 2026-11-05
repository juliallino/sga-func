module Web.View.TeacherSubjects.Index where

import Web.View.Prelude

data IndexView = IndexView
    { teacherSubject :: TeacherSubject
    , teacherSubjects :: [TeacherSubject]
    , teachers :: [Teacher]
    , subjects :: [Subject]
    , courses :: [Course]
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <p class="eyebrow">Administração</p><h1>Vínculos professor–disciplina</h1>
        <p class="page-description">Conceda e revogue explicitamente o acesso às disciplinas.</p>
        <section aria-labelledby="new-assignment">
            <h2 id="new-assignment">Novo vínculo</h2>
            {renderForm teacherSubject teachers subjects}
            {when (null teachers) noTeachers}
            {when (null subjects) noSubjects}
        </section>
        <section aria-labelledby="assignments">
            <h2 id="assignments">Vínculos cadastrados</h2>
            {when (null teacherSubjects) noAssignments}
            <div class="table-responsive"><table class="table">
                <thead><tr><th scope="col">Professor</th><th scope="col">Disciplina</th><th scope="col">Curso</th><th scope="col">Ação</th></tr></thead>
                <tbody>{forEach teacherSubjects (renderAssignment teachers subjects courses)}</tbody>
            </table></div>
        </section>
    |]

renderAssignment :: [Teacher] -> [Subject] -> [Course] -> TeacherSubject -> Html
renderAssignment teachers subjects courses assignment = [hsx|
    <tr>
        <td>{maybe "Professor indisponível" (\teacher -> teacher.name <> " — " <> teacher.registrationNumber) teacher}</td>
        <td>{maybe "Disciplina indisponível" (\subject -> subject.name <> " — " <> subject.code) subject}</td>
        <td>{maybe "Curso indisponível" (\course -> course.name <> " — " <> course.code) course}</td>
        <td><a href={DeleteTeacherSubjectAction assignment.id} class="js-delete text-danger" data-confirm="Revogar o acesso deste professor à disciplina?">Remover vínculo</a></td>
    </tr>
|]
    where
        teacher = find (\value -> unpackId value.id == assignment.teacherId) teachers
        subject = find (\value -> unpackId value.id == assignment.subjectId) subjects
        course = subject >>= \value -> find (\item -> unpackId item.id == value.courseId) courses

renderForm :: TeacherSubject -> [Teacher] -> [Subject] -> Html
renderForm teacherSubject teachers subjects = formFor teacherSubject [hsx|
    {(selectField #teacherId teachers) { fieldLabel = "Professor", placeholder = "Selecione um professor", required = True }}
    {(selectField #subjectId subjects) { fieldLabel = "Disciplina", placeholder = "Selecione uma disciplina", required = True }}
    {submitButton { label = "Vincular professor" }}
|]

noTeachers, noSubjects, noAssignments :: Html
noTeachers = [hsx|<p>Cadastre um professor para criar vínculos.</p>|]
noSubjects = [hsx|<p>Cadastre uma disciplina para criar vínculos.</p>|]
noAssignments = [hsx|<p>Nenhum vínculo cadastrado.</p>|]
