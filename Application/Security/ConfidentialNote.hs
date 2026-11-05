{-# LANGUAGE OverloadedStrings #-}
module Application.Security.ConfidentialNote
    ( NoteError (..), NoteKeys, loadNoteKeys, parseNoteKeys, sealNote, openNote ) where
import Prelude
import Application.Security.FieldEncryption
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as UTF8
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as Base64
import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Aeson.Parser (jsonNoDup')
import Data.Attoparsec.ByteString (parseOnly, endOfInput)
import Data.Char (isAscii, isAlphaNum)
import Data.List (lookup)
import System.Environment (lookupEnv)

-- No Show instances for keys or plaintext-bearing values.
data NoteKeys = NoteKeys Text [(Text, EncryptionKey)]
data NoteError = NoteUnavailable | InvalidStoredNote | InvalidNoteInput | NoteStorageFailure
    deriving (Eq, Show)

validId :: Text -> Bool
validId value = not (Text.null value) && Text.length value <= 64
    && Text.all (\c -> isAscii c && (isAlphaNum c || c == '_' || c == '-')) value

parseNoteKeys :: Text -> Text -> Either NoteError NoteKeys
parseNoteKeys active encoded = do
    if validId active && Text.length encoded <= 16384 then Right () else Left NoteUnavailable
    value <- either (const (Left NoteUnavailable)) Right
        (parseOnly (jsonNoDup' <* endOfInput) (UTF8.encodeUtf8 encoded))
    pairs <- case value of
        Object fields | KeyMap.size fields > 0 && KeyMap.size fields <= 16 ->
            traverse parseKey (KeyMap.toList fields)
        _ -> Left NoteUnavailable
    case lookup active pairs of
        Nothing -> Left NoteUnavailable
        Just _ -> Right (NoteKeys active pairs)
    where
        parseKey (name, String base64) | validId (Key.toText name) = do
            bytes <- either (const (Left NoteUnavailable)) Right (Base64.decode (UTF8.encodeUtf8 base64))
            key <- either (const (Left NoteUnavailable)) Right (keyFromBytes bytes)
            Right (Key.toText name, key)
        parseKey _ = Left NoteUnavailable

loadNoteKeys :: IO (Either NoteError NoteKeys)
loadNoteKeys = do
    active <- lookupEnv "SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID"
    keys <- lookupEnv "SGA_FIELD_ENCRYPTION_KEYS"
    pure $ case (active, keys) of
        (Just name, Just values) -> parseNoteKeys (Text.pack name) (Text.pack values)
        _ -> Left NoteUnavailable

-- Metadata is non-secret and authenticated; callers supply a canonical UUID.
context :: Text -> Text -> BS.ByteString
context student keyId = UTF8.encodeUtf8
    ("SGA:students:" <> student <> ":confidential_note_encrypted:SGAF1:" <> keyId)

sealNote :: NoteKeys -> Text -> Text -> IO (Either NoteError Text)
sealNote (NoteKeys active keys) student plaintext = case lookup active keys of
    Nothing -> pure (Left NoteUnavailable)
    Just key -> do
        encrypted <- encryptField key (context student active) (UTF8.encodeUtf8 plaintext)
        pure $ case encrypted of
            Left _ -> Left NoteUnavailable
            Right envelope -> Right ("SGAF1." <> active <> "." <> UTF8.decodeUtf8 (Base64.encode envelope))

openNote :: NoteKeys -> Text -> Text -> Either NoteError Text
openNote (NoteKeys _ keys) student stored
    | Text.length stored > 12000 = Left InvalidStoredNote
    | otherwise = case Text.splitOn "." stored of
        ["SGAF1", keyId, payload] | validId keyId -> do
            key <- maybe (Left NoteUnavailable) Right (lookup keyId keys)
            envelope <- either (const (Left InvalidStoredNote)) Right (Base64.decode (UTF8.encodeUtf8 payload))
            plaintext <- either (const (Left InvalidStoredNote)) Right (decryptField key (context student keyId) envelope)
            either (const (Left InvalidStoredNote)) Right (UTF8.decodeUtf8' plaintext)
        _ -> Left InvalidStoredNote
