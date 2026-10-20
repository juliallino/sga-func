module Config where

import IHP.Prelude
import IHP.FrameworkConfig
import IHP.LoginSupport.Middleware (authMiddleware)
import Application.Auth.Types ()
import Generated.Types

config :: ConfigBuilder
config = do
    -- See https://ihp.digitallyinduced.com/Guide/config.html
    -- for what you can do here
    option $ AuthMiddleware (authMiddleware @User)
