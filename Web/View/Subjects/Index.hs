module Web.View.Subjects.Index where
import Web.View.Prelude

data IndexView = IndexView { subjects :: [Subject], courses :: [Course] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>Disciplinas{when isAdmin (newSubjectLink)}</h1>
        {when (null subjects) (emptyState "subjects" "Nenhuma disciplina cadastrada" "Cadastre uma disciplina vinculada a um curso.")}
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th scope="col">Nome</th>
                        <th scope="col">Código</th>
                        <th scope="col">Carga horária</th>
                        <th scope="col">Curso</th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                    </tr>
                </thead>
                <tbody>{forEach subjects (renderSubject courses)}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Disciplinas" SubjectsAction
                ]

renderSubject :: (?request :: Request) => [Course] -> Subject -> Html
renderSubject courses subject = [hsx|
    <tr>
        <td>{subject.name}</td>
        <td>{subject.code}</td>
        <td>{subject.workload}</td>
        <td>{maybe "Curso indisponível" (\course -> course.name <> " - " <> course.code) (find (\course -> unpackId course.id == subject.courseId) courses)}</td>
        <td><a href={ShowSubjectAction subject.id}>Visualizar</a></td>
        <td>{when isAdmin (editSubjectLink subject)}</td>
        <td>{when isAdmin (deleteSubjectLink subject)}</td>
    </tr>
|]

newSubjectLink :: (?request :: Request) => Html
newSubjectLink = [hsx|<a href={pathTo NewSubjectAction} class="btn btn-primary ms-4">+ Nova disciplina</a>|]

editSubjectLink :: (?request :: Request) => Subject -> Html
editSubjectLink subject = [hsx|<a href={EditSubjectAction subject.id} class="text-muted">Editar</a>|]

deleteSubjectLink :: (?request :: Request) => Subject -> Html
deleteSubjectLink subject = [hsx|<a href={DeleteSubjectAction subject.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este registro?">Excluir</a>|]
