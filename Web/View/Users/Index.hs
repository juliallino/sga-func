module Web.View.Users.Index where
import Web.View.Prelude

data IndexView = IndexView { users :: [User] }
instance View IndexView where
    html IndexView { .. } = [hsx|
        <p class="eyebrow">Administração</p><h1>Usuários</h1>
        <p class="page-description">Contas cadastradas e perfis de acesso ao portal.</p>
        <div class="table-responsive"><table class="table"><thead><tr><th>Nome</th><th>E-mail</th><th>Perfil</th></tr></thead><tbody>{forEach users renderUser}</tbody></table></div>
    |]
renderUser :: User -> Html
renderUser user = [hsx|<tr><td>{user.name}</td><td>{user.email}</td><td><span class="status-badge">{roleLabel user.role_}</span></td></tr>|]
