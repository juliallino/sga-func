module Web.View.ClassSessions.Subjects where

import Web.View.Prelude

-- Disciplinas em que a conta pode registrar chamadas (Admin: todas;
-- professor: somente as autorizadas em teacher_subjects).
data SubjectsView = SubjectsView
    { subjects :: [Subject]
    , courses :: [Course]
    , sessionCounts :: [(UUID, Int)]
    }

instance View SubjectsView where
    html SubjectsView { .. } = [hsx|
        {breadcrumb}
        <h1>Chamada e frequência</h1>
        <p class="page-description">Selecione a disciplina para registrar a chamada de uma aula ou consultar a frequência dos estudantes. A frequência mínima para aprovação é de 75 % das aulas.</p>
        {when (null subjects) (emptyState "subjects" "Nenhuma disciplina disponível" "As disciplinas autorizadas para sua conta aparecerão aqui.")}
        <div class="table-responsive"><table class="table"><caption class="visually-hidden">Disciplinas para chamada</caption>
            <thead><tr><th scope="col">Disciplina</th><th scope="col">Código</th><th scope="col">Curso</th><th scope="col">Aulas com chamada</th><th scope="col">Acesso</th></tr></thead>
            <tbody>{forEach subjects (renderSubject courses sessionCounts)}</tbody>
        </table></div>
    |]
        where
            breadcrumb = renderBreadcrumb [ breadcrumbText "Frequência" ]

renderSubject :: [Course] -> [(UUID, Int)] -> Subject -> Html
renderSubject courses sessionCounts subject = [hsx|
    <tr><td>{subject.name}</td><td>{subject.code}</td><td>{courseName}</td><td>{sessionCount}</td><td><a href={ClassSessionsAction subject.id}>Abrir chamadas</a> · <a href={NewClassSessionAction subject.id}>Nova chamada</a></td></tr>
|]
    where
        courseName = maybe "Curso indisponível" (.name) (find (\course -> unpackId course.id == subject.courseId) courses)
        sessionCount = maybe 0 snd (find (\(subjectUuid, _) -> subjectUuid == unpackId subject.id) sessionCounts)
