module Web.Controller.StudentConfidentialNotes where
import Web.Controller.Prelude
import qualified Application.Helper.ConfidentialNote as Notes
import Application.Security.ConfidentialNote (NoteError (..))
import Web.View.StudentConfidentialNotes.Show
import qualified Data.Text.Encoding as UTF8
import qualified Network.Wai as Wai
import qualified Network.HTTP.Types as HTTP

instance Controller StudentConfidentialNotesController where
    action StudentConfidentialNoteAction { studentId } = do
        requireAdmin
        privateResponse
        student <- fetchOr404 studentId
        outcome <- Notes.readNote studentId
        case outcome of
            Left _ -> unavailable
            Right note -> render ShowView { .. }
    action SaveStudentConfidentialNoteAction { studentId } = do
        requireAdmin
        privateResponse
        -- Do not use partial param parsing: error messages must never quote input.
        let raw = paramOrNothing @ByteString "note"
        case raw >>= either (const Nothing) Just . UTF8.decodeUtf8' of
            Nothing -> invalidInput
            Just input -> do
                outcome <- Notes.saveNote studentId input
                case outcome of
                    Right () -> redirectTo StudentConfidentialNoteAction { .. }
                    Left InvalidNoteInput -> invalidInput
                    Left _ -> unavailable
    action RemoveStudentConfidentialNoteAction { studentId } = do
        requireAdmin
        privateResponse
        result <- Notes.removeNote studentId
        case result of
            Right () -> redirectTo StudentConfidentialNoteAction { .. }
            Left _ -> unavailable

privateResponse :: (?request :: Request) => IO ()
privateResponse = do
    setHeader ("Cache-Control", "no-store")
    setHeader ("Referrer-Policy", "no-referrer")

-- Constant bodies exclude plaintext, envelope, configuration and exceptions.
invalidInput :: (?request :: Request, ?respond :: Respond) => IO a
invalidInput = earlyReturn (respondWith (Wai.responseLBS HTTP.status400 [(HTTP.hContentType,"text/plain; charset=utf-8"),(HTTP.hCacheControl,"no-store")] "Informe uma observação de até 2000 caracteres."))
unavailable :: (?request :: Request, ?respond :: Respond) => IO a
unavailable = earlyReturn (respondWith (Wai.responseLBS HTTP.status503 [(HTTP.hContentType,"text/plain; charset=utf-8"),(HTTP.hCacheControl,"no-store")] "Observação confidencial indisponível. Nenhum conteúdo foi alterado."))
