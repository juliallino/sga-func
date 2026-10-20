module Web.View.Teachers.Index where
import Web.View.Prelude

data IndexView = IndexView { teachers :: [Teacher] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}

        <h1>Professores<a href={pathTo NewTeacherAction} class="btn btn-primary ms-4">+ Novo professor</a></h1>
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Nome</th>
                        <th>E-mail</th>
                        <th>Número de registro</th>
                        <th>Especialização</th>
                        <th></th>
                        <th></th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>{forEach teachers renderTeacher}</tbody>
            </table>
            
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Professores" TeachersAction
                ]

renderTeacher :: Teacher -> Html
renderTeacher teacher = [hsx|
    <tr>
        <td>{teacher.name}</td>
        <td>{teacher.email}</td>
        <td>{teacher.registrationNumber}</td>
        <td>{fromMaybe "Não informada" teacher.specialization}</td>
        <td><a href={ShowTeacherAction teacher.id}>Visualizar</a></td>
        <td><a href={EditTeacherAction teacher.id} class="text-muted">Editar</a></td>
        <td><a href={DeleteTeacherAction teacher.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este registro?">Excluir</a></td>
    </tr>
|]
