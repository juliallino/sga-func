{-# LANGUAGE OverloadedStrings #-}
module Application.Domain.ConfidentialNote (validateNote) where
import Prelude
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as UTF8
import qualified Data.ByteString as BS

-- No request, database or secret; empty input explicitly removes the note.
validateNote :: Text -> Either () (Maybe Text)
validateNote input
    | Text.length input > 2000 || BS.length (UTF8.encodeUtf8 input) > 8000 = Left ()
    | Text.null clean = Right Nothing
    | otherwise = Right (Just clean)
    where clean = Text.strip input
