module Main where
import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.AuthSupport.Authentication (hashPassword)
import qualified Network.Wai.Handler.Warp as Warp
import qualified System.Environment as Env
import Config
import Generated.Types
import Web.Types
import Web.FrontController ()

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]
main :: IO ()
main = do
    url <- Env.getEnv "DATABASE_URL"
    unless ("host=/tmp/sga-aes-demo-" `isInfixOf` cs url) (error "Isolated demonstration database required")
    password <- cs <$> Env.getEnv "SGA_AES_DEMO_PASSWORD"
    withMockContext WebApplication config \context -> do
      withContext (do
        count <- query @User |> fetchCount
        when (count == 0) do
            hash <- hashPassword password
            let account name email role = newRecord @User |> set #name name |> set #email email |> set #passwordHash hash |> set #role_ role |> createRecord
            _ <- account "Admin fictício AES" "admin-aes@example.test" Roleadmin
            studentUser <- account "Aluno fictício AES" "student-aes@example.test" Rolestudent
            teacherUser <- account "Docente fictício AES" "teacher-aes@example.test" Roleteacher
            _ <- newRecord @Student |> set #userId (Just (unpackId studentUser.id)) |> set #name studentUser.name |> set #email studentUser.email |> set #enrollmentNumber "AES-DEMO" |> createRecord
            _ <- newRecord @Teacher |> set #userId (Just (unpackId teacherUser.id)) |> set #name teacherUser.name |> set #email teacherUser.email |> set #registrationNumber "AES-DEMO-T" |> createRecord
            pure ()
        ) context
      app <- initTestApplication context
      putStrLn "Demonstração pronta em http://127.0.0.1:8107/Login (somente dados fictícios)."
      Warp.runSettings (Warp.setHost "127.0.0.1" (Warp.setPort 8107 Warp.defaultSettings)) app
