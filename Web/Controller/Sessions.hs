module Web.Controller.Sessions where
import Web.Controller.Prelude
import IHP.AuthSupport.Controller.Sessions
import Web.View.Sessions.New ()

instance SessionsControllerConfig User where
    afterLoginRedirectPath = "/"
    afterLogoutRedirectPath = "/Login"

instance Controller SessionsController where
    action NewSessionAction = newSessionAction @User
    action CreateSessionAction = createSessionAction @User
    action DeleteSessionAction = deleteSessionAction @User
