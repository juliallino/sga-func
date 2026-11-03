module Web.Controller.Sessions where
import Web.Controller.Prelude
import IHP.AuthSupport.Controller.Sessions
import Web.View.Sessions.New ()

instance SessionsControllerConfig User where
    afterLoginRedirectPath = "/"
    afterLogoutRedirectPath = "/Login"
    -- Native IHP login checks credentials and lock state before this hook.
    -- Replace any stored return URL so every login reaches its own portal.
    beforeLogin user = setSession "IHP.LoginSupport.redirectAfterLogin" (case user.role_ of
        Roleadmin -> "/" :: Text
        Roleteacher -> "/TeacherDashboard"
        Rolestudent -> "/StudentDashboard")

instance Controller SessionsController where
    action NewSessionAction = newSessionAction @User
    action CreateSessionAction = createSessionAction @User
    action DeleteSessionAction = do
        deleteSession "IHP.LoginSupport.redirectAfterLogin"
        deleteSessionAction @User
