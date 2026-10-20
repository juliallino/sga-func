module Web.View.Sessions.New where
import Web.View.Prelude
import IHP.AuthSupport.View.Sessions.New

instance View (NewView User) where
    html _ = [hsx|
        <p class="eyebrow">Sua vida acadêmica em um só lugar</p>
        <h1>Acesse seu portal</h1>
        <p class="page-description">Entre com o e-mail e a senha da sua conta.</p>
        <form method="POST" action={CreateSessionAction}>
            <div class="mb-3"><label class="form-label" for="email">E-mail</label><input class="form-control" type="email" id="email" name="email" required="required" autocomplete="username"/></div>
            <div class="mb-3"><label class="form-label" for="password">Senha</label><input class="form-control" type="password" id="password" name="password" required="required" autocomplete="current-password"/></div>
            <button class="btn btn-primary w-100" type="submit">Entrar</button>
        </form>
    |]
