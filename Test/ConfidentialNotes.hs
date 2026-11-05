module Main where
import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.Hspec
import IHP.Controller.Response (EarlyReturnException (..))
import IHP.AuthSupport.Authentication (hashPassword)
import Test.Hspec
import Config
import Generated.Types
import Web.Types
import Web.FrontController ()
import Application.Security.ConfidentialNote
import qualified Application.Helper.ConfidentialNote as Notes
import qualified Network.HTTP.Types as HTTP
import qualified Network.Wai as Wai
import qualified Network.Wai.Test as WT
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Text as T
import qualified Data.Text.Encoding as UTF8
import qualified System.Environment as Env
import Control.Exception (bracket, try)
import Control.Monad (void)
import Data.Bits (xor)
import Data.Aeson (object, (.=), encode)
import "crypton" Crypto.Random (getRandomBytes)

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]

withConfig active keys action = bracket
    ((,) <$> Env.lookupEnv "SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID" <*> Env.lookupEnv "SGA_FIELD_ENCRYPTION_KEYS")
    (\(a,k) -> restore "SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID" a >> restore "SGA_FIELD_ENCRYPTION_KEYS" k)
    (\_ -> restore "SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID" active >> restore "SGA_FIELD_ENCRYPTION_KEYS" keys >> action)
    where restore name = maybe (Env.unsetEnv name) (Env.setEnv name)

main :: IO ()
main = do
    marker <- Env.lookupEnv "SGA_ISOLATED_CRUD_TEST"
    url <- Env.lookupEnv "DATABASE_URL"
    unless (marker == Just "1" && maybe False (T.isInfixOf "host=/tmp/sga-crud-test-" . T.pack) url) (error "Isolated database required")
    raw1 <- getRandomBytes 32 :: IO BS.ByteString
    raw2 <- getRandomBytes 32 :: IO BS.ByteString
    let b64 = UTF8.decodeUtf8 . B64.encode
    let json1 = cs (LBS.toStrict (encode (object ["k1" .= b64 raw1])))
    let json2 = cs (LBS.toStrict (encode (object ["k1" .= b64 raw2])))
    let rotated = cs (LBS.toStrict (encode (object ["k1" .= b64 raw1,"k2" .= b64 raw2])))
    withConfig (Just "k1") (Just json1) $ withMockContext WebApplication config \context -> do
      app <- initTestApplication context
      withContext (do
        password <- b64 <$> (getRandomBytes 24 :: IO BS.ByteString)
        hash <- hashPassword password
        let account name email role = newRecord @User |> set #name name |> set #email email |> set #role_ role |> set #passwordHash hash |> createRecord
        admin <- account "Admin AES" "aes-admin@example.test" Roleadmin
        studentUser <- account "Aluno AES" "aes-student@example.test" Rolestudent
        teacherUser <- account "Docente AES" "aes-teacher@example.test" Roleteacher
        student <- newRecord @Student |> set #userId (Just (unpackId studentUser.id)) |> set #name "Estudante AES fictício" |> set #email studentUser.email |> set #enrollmentNumber "AES-1" |> createRecord
        _ <- newRecord @Teacher |> set #userId (Just (unpackId teacherUser.id)) |> set #name "Docente AES" |> set #email teacherUser.email |> set #registrationNumber "AES-T" |> createRecord
        let note = "Atendimento administrativo fictício <script>não executar</script>"
        let stored = do
              rows <- unsafeSqlQuery "SELECT confidential_note_encrypted FROM students WHERE id = ?" (Only (unpackId student.id)) :: IO [Only (Maybe Text)]
              case rows of [Only value] -> pure value; _ -> error "Fixture ausente"
        let post path values = WT.srequest (WT.SRequest ((WT.setPath Wai.defaultRequest path) {Wai.requestMethod="POST",Wai.requestHeaders=[(HTTP.hContentType,"application/x-www-form-urlencoded")]}) (cs (HTTP.renderSimpleQuery False values)))
        let login user = post "/Login" [("email",cs user.email),("password",UTF8.encodeUtf8 password)]
        let page = "/StudentConfidentialNote?studentId=" <> cs (show student.id)
        let save = "/SaveStudentConfidentialNote?studentId=" <> cs (show student.id)
        let remove = "/RemoveStudentConfidentialNote?studentId=" <> cs (show student.id)
        let getAs user = WT.runSession (login user >> WT.request (WT.setPath Wai.defaultRequest page)) app
        let postAs user path values = WT.runSession (login user >> post path values) app
        snapshots <- Env.lookupEnv "SGA_AES_SNAPSHOTS"
        let exportPage name response = forEach snapshots (\directory -> LBS.writeFile (directory <> "/" <> name <> ".html") (WT.simpleBody response))
        hspec do
          describe "AES persistido: fluxo administrativo e autorização" do
            it "NULL funciona sem chave e não mostra o campo no perfil Student" do
              stored >>= (`shouldBe` Nothing)
              withConfig Nothing Nothing do
                response <- getAs admin
                WT.simpleStatus response `shouldBe` HTTP.status200
                exportPage "aes-empty" response
              withUser studentUser do
                response <- callAction MyProfileAction
                responseBodyShouldNotContain response "StudentConfidentialNote"
            it "Admin cadastra por HTTP; PostgreSQL contém envelope, nunca texto claro" do
              response <- postAs admin save [("note",UTF8.encodeUtf8 note)]
              WT.simpleStatus response `shouldBe` HTTP.status302
              value <- stored
              (maybe False (T.isPrefixOf "SGAF1.k1.") value) `shouldBe` True
              (maybe False (not . T.isInfixOf note) value) `shouldBe` True
              forEach value \envelope -> do
                let payload = fromMaybe "" (last (T.splitOn "." envelope))
                case B64.decode (UTF8.encodeUtf8 payload) of
                    Left _ -> expectationFailure "Envelope inválido"
                    Right bytes -> do
                        (not (UTF8.encodeUtf8 note `BS.isInfixOf` bytes)) `shouldBe` True
                        (BS.drop 32 bytes /= UTF8.encodeUtf8 note) `shouldBe` True
            it "nova requisição Admin recupera e escapa o texto; cache não armazena" do
              response <- getAs admin
              WT.simpleStatus response `shouldBe` HTTP.status200
              exportPage "aes-note" response
              lookup HTTP.hCacheControl (WT.simpleHeaders response) `shouldBe` Just "no-store"
              ("&lt;script&gt;" `isInfixOf` cs (WT.simpleBody response) :: Bool) `shouldBe` True
              ("<script>não executar</script>" `isInfixOf` cs (WT.simpleBody response) :: Bool) `shouldBe` False
            it "Teacher e Student não leem, salvam ou removem por URL direta" do
              before <- stored
              forEach [teacherUser,studentUser] \user -> do
                response <- getAs user
                WT.simpleStatus response `shouldBe` HTTP.status403
                forEach [save,remove] \path -> do
                  response <- postAs user path [("note","proibida")]
                  WT.simpleStatus response `shouldBe` HTTP.status403
                  (not (T.isInfixOf note (cs (WT.simpleBody response)))) `shouldBe` True
              stored >>= (`shouldBe` before)
            it "camada de dados também exige Admin para leitura e escrita" do
              forEach [teacherUser,studentUser] \user -> withUser user do
                let capture work = do
                      response <- try work :: IO (Either EarlyReturnException ())
                      case response of Left _ -> pure (); Right _ -> expectationFailure "Acesso indevido na camada de dados"
                capture (void (Notes.readNote student.id))
                capture (void (Notes.saveNote student.id "proibida"))
                capture (void (Notes.removeNote student.id))
            it "visitante é redirecionado e não altera o campo" do
              before <- stored
              forEach [page,save,remove] \path -> do
                response <- WT.runSession (if path==page then WT.request (WT.setPath Wai.defaultRequest path) else post path [("note","proibida")]) app
                WT.simpleStatus response `shouldBe` HTTP.status302
              stored >>= (`shouldBe` before)
            it "chave ausente ou incorreta falha sem revelar ou sobrescrever conteúdo" do
              before <- stored
              forEach [(Nothing,Nothing),(Just "k1",Just json2)] \(active,keys) -> withConfig active keys do
                response <- getAs admin
                WT.simpleStatus response `shouldBe` HTTP.status503
                forEach [save,remove] \path -> do
                  response <- postAs admin path [("note",UTF8.encodeUtf8 "não sobrescrever")]
                  WT.simpleStatus response `shouldBe` HTTP.status503
                  (not (T.isInfixOf note (cs (WT.simpleBody response)))) `shouldBe` True
              stored >>= (`shouldBe` before)
            it "limite inválido não reflete observação na resposta e preserva envelope" do
              before <- stored
              response <- postAs admin save [("note",UTF8.encodeUtf8 (T.replicate 2001 "X"))]
              WT.simpleStatus response `shouldBe` HTTP.status400
              (not ("XXXXXXXX" `isInfixOf` cs (WT.simpleBody response))) `shouldBe` True
              stored >>= (`shouldBe` before)
            it "UTF-8 inválido e parâmetro ausente não expõem dados" do
              before <- stored
              forEach [[("note",BS.pack [255,254])],[]] \values -> do
                response <- postAs admin save values
                WT.simpleStatus response `shouldBe` HTTP.status400
              stored >>= (`shouldBe` before)
            it "Admin edita; mesmo conteúdo novamente usa outro nonce" do
              before <- stored
              response <- postAs admin save [("note",UTF8.encodeUtf8 "Observação fictícia editada")]
              WT.simpleStatus response `shouldBe` HTTP.status302
              after <- stored
              (after /= before) `shouldBe` True
              response <- postAs admin save [("note",UTF8.encodeUtf8 "Observação fictícia editada")]
              WT.simpleStatus response `shouldBe` HTTP.status302
              stored >>= (\value -> (value /= after) `shouldBe` True)
            it "rotação mantém chave antiga legível e grava com chave ativa nova" do
              withConfig (Just "k2") (Just rotated) do
                getAs admin >>= (\response -> WT.simpleStatus response `shouldBe` HTTP.status200)
                postAs admin save [("note",UTF8.encodeUtf8 "Observação fictícia com chave nova")] >>= (\response -> WT.simpleStatus response `shouldBe` HTTP.status302)
                stored >>= (\value -> maybe False (T.isPrefixOf "SGAF1.k2.") value `shouldBe` True)
                getAs admin >>= (\response -> WT.simpleStatus response `shouldBe` HTTP.status200)
              -- Restore a k1 envelope to exercise subsequent corruption tests.
              withConfig (Just "k1") (Just rotated) do
                postAs admin save [("note",UTF8.encodeUtf8 "Observação fictícia restaurada")] >>= (\response -> WT.simpleStatus response `shouldBe` HTTP.status302)
            it "troca de estudante e adulteração da tag são rejeitadas sem perda" do
              original <- stored
              forEach original \envelope -> do
                other <- newRecord @Student |> set #name "Outro AES" |> set #email "aes-other@example.test" |> set #enrollmentNumber "AES-2" |> createRecord
                keys <- loadNoteKeys >>= either (const (fail "configuração de teste")) pure
                openNote keys (show other.id) envelope `shouldBe` Left InvalidStoredNote
                let altered = case T.splitOn "." envelope of
                      [v,k,p] -> case B64.decode (UTF8.encodeUtf8 p) of
                          Right bytes -> v <> "." <> k <> "." <> UTF8.decodeUtf8 (B64.encode
                              (BS.take 16 bytes <> BS.singleton (BS.index bytes 16 `xor` 1) <> BS.drop 17 bytes))
                          Left _ -> "invalid"
                      _ -> "invalid"
                unsafeSqlExecDiscardResult "UPDATE students SET confidential_note_encrypted = ? WHERE id = ?" (altered,unpackId student.id)
                response <- getAs admin
                WT.simpleStatus response `shouldBe` HTTP.status503
                response <- postAs admin save [("note",UTF8.encodeUtf8 "não sobrescrever")]
                WT.simpleStatus response `shouldBe` HTTP.status503
                stored >>= (`shouldBe` Just altered)
                unsafeSqlExecDiscardResult "UPDATE students SET confidential_note_encrypted = ? WHERE id = ?" (envelope,unpackId student.id)
            it "CRUD comum não apaga ciphertext; Admin remove por HTTP e NULL é persistido" do
              before <- stored
              withUser admin do
                response <- callActionWithParams (UpdateStudentAction student.id) [("name",UTF8.encodeUtf8 "Estudante AES editado"),("email","aes-student@example.test"),("enrollmentNumber","AES-1"),("confidentialNoteEncrypted","tentativa de sobrescrever")]
                responseStatusShouldBe response HTTP.status302
              stored >>= (`shouldBe` before)
              response <- postAs admin remove []
              WT.simpleStatus response `shouldBe` HTTP.status302
              stored >>= (`shouldBe` Nothing)
              getAs admin >>= (\r -> WT.simpleStatus r `shouldBe` HTTP.status200)
            it "login e dashboards continuam disponíveis sem configuração AES" do
              withConfig Nothing Nothing do
                forEach [(admin,"/"),(teacherUser,"/TeacherDashboard"),(studentUser,"/StudentDashboard")] \(user,path) -> do
                  response <- WT.runSession (login user >> WT.request (WT.setPath Wai.defaultRequest path)) app
                  WT.simpleStatus response `shouldBe` HTTP.status200
        ) context
