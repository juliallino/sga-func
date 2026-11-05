module Application.Helper.ConfidentialNote (readNote, saveNote, removeNote) where
import IHP.ControllerPrelude
import Data.Traversable (traverse)
import Generated.Types
import Application.Helper.Auth (requireAdmin)
import Application.Domain.ConfidentialNote (validateNote)
import Application.Security.ConfidentialNote
import qualified Control.Exception as Exception

-- Guard every public data operation; never trust a controller-provided role.
-- Database errors are reduced to a constant error, never sent to IHP's debugger.
noteStorage action = do
    result <- Exception.try @HasqlError action
    pure (either (const (Left NoteStorageFailure)) (\value -> value) result)

readNote :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext)
    => Id Student -> IO (Either NoteError (Maybe Text))
readNote studentId = do
    requireAdmin
    noteStorage do
        rows <- unsafeSqlQuery "SELECT confidential_note_encrypted FROM students WHERE id = ?"
            (Only (unpackId studentId)) :: IO [Only (Maybe Text)]
        case rows of
            [Only Nothing] -> pure (Right Nothing)
            [Only (Just envelope)] -> do
                configured <- loadNoteKeys
                pure (configured >>= \keys -> Just <$> openNote keys (show studentId) envelope)
            _ -> earlyReturn renderNotFound

saveNote :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext)
    => Id Student -> Text -> IO (Either NoteError ())
saveNote studentId input = do
    requireAdmin
    case validateNote input of
        Left _ -> pure (Left InvalidNoteInput)
        Right Nothing -> removeNote studentId
        Right (Just plaintext) -> noteStorage $ withTransaction do
            rows <- unsafeSqlQuery "SELECT confidential_note_encrypted FROM students WHERE id = ? FOR UPDATE"
                (Only (unpackId studentId)) :: IO [Only (Maybe Text)]
            case rows of
                [Only previous] -> do
                    configured <- loadNoteKeys
                    case configured of
                        Left err -> pure (Left err)
                        Right keys -> case traverse (openNote keys (show studentId)) previous of
                            Left err -> pure (Left err)
                            Right _ -> do
                                sealed <- sealNote keys (show studentId) plaintext
                                case sealed of
                                    Left err -> pure (Left err)
                                    Right envelope -> do
                                        unsafeSqlExecDiscardResult "UPDATE students SET confidential_note_encrypted = ? WHERE id = ?"
                                            (envelope, unpackId studentId)
                                        pure (Right ())
                _ -> earlyReturn renderNotFound

removeNote :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext)
    => Id Student -> IO (Either NoteError ())
removeNote studentId = do
    requireAdmin
    -- Removal also authenticates an existing envelope: wrong/missing keys never
    -- silently destroy data. This is independent of the ordinary student CRUD.
    noteStorage $ withTransaction do
        rows <- unsafeSqlQuery "SELECT id FROM students WHERE id = ? FOR UPDATE"
            (Only (unpackId studentId)) :: IO [Only UUID]
        when (null rows) (earlyReturn renderNotFound)
        previous <- readNote studentId
        case previous of
            Left err -> pure (Left err)
            Right _ -> do
                unsafeSqlExecDiscardResult "UPDATE students SET confidential_note_encrypted = NULL WHERE id = ?"
                    (Only (unpackId studentId))
                pure (Right ())
