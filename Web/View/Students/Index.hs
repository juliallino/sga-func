module Web.View.Students.Index where
import Web.View.Prelude

data IndexView = IndexView { students :: [Student] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>Estudantes{when isAdmin (newStudentLink)}</h1>
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Nome</th>
                        <th>E-mail</th>
                        <th>Número de matrícula</th>
                        <th></th>
                        <th></th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>{forEach students renderStudent}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Estudantes" StudentsAction
                ]

renderStudent :: (?request :: Request) => Student -> Html
renderStudent student = [hsx|
    <tr>
        <td>{student.name}</td>
        <td>{student.email}</td>
        <td>{student.enrollmentNumber}</td>
        <td><a href={ShowStudentAction student.id}>Visualizar</a></td>
        <td>{when isAdmin (editStudentLink student)}</td>
        <td>{when isAdmin (deleteStudentLink student)}</td>
    </tr>
|]

newStudentLink :: (?request :: Request) => Html
newStudentLink = [hsx|<a href={pathTo NewStudentAction} class="btn btn-primary ms-4">+ Novo estudante</a>|]

editStudentLink :: (?request :: Request) => Student -> Html
editStudentLink student = [hsx|<a href={EditStudentAction student.id} class="text-muted">Editar</a>|]

deleteStudentLink :: (?request :: Request) => Student -> Html
deleteStudentLink student = [hsx|<a href={DeleteStudentAction student.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este registro?">Excluir</a>|]
