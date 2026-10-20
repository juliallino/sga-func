module Web.Controller.Users where
import Web.Controller.Prelude
import Web.View.Users.Index

instance Controller UsersController where
    action UsersAction = do
        requireAdmin
        users <- query @User |> fetch
        render IndexView { .. }
    action _ = do
        requireAdmin
        earlyReturn renderNotFound
