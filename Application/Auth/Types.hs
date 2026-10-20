module Application.Auth.Types where
import IHP.Prelude
import Generated.Types
import IHP.LoginSupport.Types

type instance CurrentUserRecord = User
instance HasNewSessionUrl User where
    newSessionUrl _ = "/Login"
