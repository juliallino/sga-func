module Web.View.Layout (defaultLayout, Html) where

import IHP.ViewPrelude
import IHP.Environment
import Generated.Types
import Web.Types
import Web.Routes
import Application.Helper.View
import qualified Network.Wai as Wai
import qualified Data.Text as Text

defaultLayout :: (?request :: Request) => Html -> Html
defaultLayout inner = [hsx|
<!DOCTYPE html>
<html lang="pt-BR">
    <head>
        {metaTags}
        {stylesheets}
        {scripts}
        <title>{pageTitleOrDefault "SGA — Portal Acadêmico"}</title>
    </head>
    <body>
        <a class="skip-link" href="#main-content">Pular para o conteúdo</a>
        {renderPortal inner}
    </body>
</html>
|]

renderPortal :: (?request :: Request) => Html -> Html
renderPortal inner = case currentUserOrNothing @User of
    Nothing -> [hsx|
        <div class="login-page">
            <div class="login-brand"><span class="brand-mark">{moduleIcon "students"}</span><span><strong>SGA</strong><small>Portal Acadêmico</small></span></div>
            <main id="main-content" class="login-card">{renderFlashMessages}{inner}</main>
            <p class="login-footer">Sistema de Gestão Acadêmica</p>
        </div>
    |]
    Just user -> [hsx|
        <div class="portal-shell">
            <header class="portal-header">
                <a class="portal-brand" href={WelcomeAction}><span class="brand-mark">{moduleIcon "students"}</span><span><strong>SGA</strong><small>Portal Acadêmico</small></span></a>
                <div class="header-user"><span class="avatar" aria-hidden="true">{initial user.name}</span><span class="user-info"><strong>{user.name}</strong><small>{roleLabel user.role_}</small></span></div>
                <button class="menu-toggle" type="button" aria-expanded="false" aria-controls="portal-sidebar" aria-label="Abrir menu">☰</button>
            </header>
            <aside class="portal-sidebar" id="portal-sidebar">
                <div class="sidebar-label">{roleLabel user.role_}</div>
                <nav aria-label="Navegação principal">{roleMenu user.role_}</nav>
                <form method="POST" action={DeleteSessionAction} class="logout-form"><button class="sidebar-link logout-button" type="submit">{moduleIcon "logout"}<span>Sair</span></button></form>
                <div class="sidebar-footer"><span class="connection-dot"></span> Ambiente acadêmico</div>
            </aside>
            <div class="menu-backdrop" hidden="hidden"></div>
            <main id="main-content" class="portal-main"><div class="portal-content">{renderFlashMessages}{inner}</div><footer class="portal-footer">SGA · Sistema de Gestão Acadêmica</footer></main>
        </div>
    |]

initial :: Text -> Text
initial name = if null name then "?" else Text.toUpper (Text.take 1 name)

roleMenu :: (?request :: Request) => UserRole -> Html
roleMenu Roleadmin = [hsx|
    {navItem "dashboard" "Dashboard" (pathTo WelcomeAction)}
    {navItem "students" "Estudantes" (pathTo StudentsAction)}
    {navItem "teachers" "Professores" (pathTo TeachersAction)}
    {navItem "courses" "Cursos" (pathTo CoursesAction)}
    {navItem "subjects" "Disciplinas" (pathTo SubjectsAction)}
    {navItem "enrollments" "Matrículas" (pathTo EnrollmentsAction)}
    {navItem "grades" "Avaliações" (pathTo GradesAction)}
    {navItem "users" "Usuários" (pathTo UsersAction)}
|]
roleMenu Rolestudent = [hsx|
    {navItem "dashboard" "Meu portal" (pathTo WelcomeAction)}
    {navItem "users" "Meu perfil" (pathTo MyProfileAction)}
    {navItem "subjects" "Minhas disciplinas" (pathTo StudentSubjectsAction)}
    {navItem "enrollments" "Minhas matrículas" (pathTo EnrollmentsAction)}
    {navItem "grades" "Minhas notas" (pathTo GradesAction)}
    {navItem "dashboard" "Minhas médias" (pathTo StudentAveragesAction)}
|]
roleMenu Roleteacher = [hsx|
    {navItem "dashboard" "Meu portal" (pathTo WelcomeAction)}
    {navItem "subjects" "Minhas disciplinas" (pathTo SubjectsAction)}
    {navItem "students" "Estudantes vinculados" (pathTo TeacherStudentsAction)}
    {navItem "grades" "Lançar avaliações" (pathTo TeacherAssessmentsAction)}
|]

navItem :: (?request :: Request) => Text -> Text -> Text -> Html
navItem icon label url = [hsx|
    <a class={classes [("sidebar-link", True), ("is-active", active)]} href={url} aria-current={if active then "page" else "false" :: Text}>{moduleIcon icon}<span>{label}</span></a>
|]
    where active = cs (Wai.rawPathInfo ?request) == url

-- The 'assetPath' function used below appends a `?v=SOME_VERSION` to the static assets in production
-- This is useful to avoid users having old CSS and JS files in their browser cache once a new version is deployed
-- See https://ihp.digitallyinduced.com/Guide/assets.html for more details

stylesheets :: Html
stylesheets = [hsx|
        <link rel="stylesheet" href={assetPath "/vendor/bootstrap-5.3.8/bootstrap.min.css"}/>
        <link rel="stylesheet" href={assetPath "/vendor/flatpickr.min.css"}/>
        <link rel="stylesheet" href={assetPath "/app.css"}/>
    |]

scripts :: Html
scripts = [hsx|
        {when isDevelopment devScripts}
        <script src={assetPath "/vendor/jquery-4.0.0.slim.min.js"}></script>
        <script src={assetPath "/vendor/timeago.js"}></script>
        <script src={assetPath "/vendor/popper-2.11.6.min.js"}></script>
        <script src={assetPath "/vendor/bootstrap-5.3.8/bootstrap.min.js"}></script>
        <script src={assetPath "/vendor/flatpickr.js"}></script>
        <script src={assetPath "/vendor/morphdom-umd.min.js"}></script>
        <script src={assetPath "/vendor/turbolinks.js"}></script>
        <script src={assetPath "/vendor/turbolinksInstantClick.js"}></script>
        <script src={assetPath "/vendor/turbolinksMorphdom.js"}></script>
        <script src={assetPath "/helpers.js"}></script>
        <script src={assetPath "/ihp-auto-refresh.js"}></script>
        <script src={assetPath "/app.js"}></script>
    |]

devScripts :: Html
devScripts = [hsx|
        <script id="livereload-script" src={assetPath "/livereload.js"} data-ws={liveReloadWebsocketUrl}></script>
    |]

metaTags :: Html
metaTags = [hsx|
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"/>
    <meta property="og:title" content="SGA — Sistema de Gestão Acadêmica"/>
    <meta property="og:type" content="website"/>
    <meta property="og:url" content="Portal acadêmico SGA"/>
    <meta property="og:description" content="Portal acadêmico SGA"/>
    {autoRefreshMeta}
|]
