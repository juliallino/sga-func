{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
-- Isolated authenticated-encryption demonstration. No database dependencies.
module Application.Security.FieldEncryption
    ( EncryptionKey, EncryptionError (..), keyFromBytes, loadEncryptionKey
    , encryptField, decryptField
    ) where

import Prelude
import "crypton" Crypto.Cipher.AES (AES256)
import "crypton" Crypto.Cipher.Types
    ( AEADMode (AEAD_GCM), AuthTag (..), cipherInit, aeadInit
    , aeadSimpleEncrypt, aeadSimpleDecrypt )
import "crypton" Crypto.Error (CryptoFailable (..))
import "crypton" Crypto.Random (getRandomBytes)
import Data.ByteArray (convert)
import qualified Data.ByteString as BS
import Data.ByteString (ByteString)
import qualified Data.ByteString.Base64 as Base64
import qualified Data.ByteString.Char8 as Char8
import System.Environment (lookupEnv)

-- No Show instance or exported constructor: do not log keys or cipher state.
newtype EncryptionKey = EncryptionKey AES256

data EncryptionError
    = MissingEncryptionKey | InvalidEncryptionKey | InvalidEnvelope
    | AuthenticationFailed | CipherInitializationFailed
    deriving (Eq, Show)

keyFromBytes :: ByteString -> Either EncryptionError EncryptionKey
keyFromBytes bytes
    | BS.length bytes /= 32 = Left InvalidEncryptionKey
    | otherwise = case cipherInit bytes of
        CryptoFailed _ -> Left InvalidEncryptionKey
        CryptoPassed cipher -> Right (EncryptionKey cipher)

-- Base64-encoded 32 random bytes; no hardcoded fallback or key logging.
loadEncryptionKey :: IO (Either EncryptionError EncryptionKey)
loadEncryptionKey = do
    encoded <- lookupEnv "SGA_FIELD_ENCRYPTION_KEY"
    pure $ case encoded of
        Nothing -> Left MissingEncryptionKey
        Just value -> case Base64.decode (Char8.pack value) of
            Left _ -> Left InvalidEncryptionKey
            Right bytes -> keyFromBytes bytes

-- Envelope v1: magic (4) | random nonce (12) | auth tag (16) | ciphertext.
-- context is authenticated, not encrypted; bind it to field + record identity
-- if this demonstration is ever integrated after a separate data review.
magic :: ByteString
magic = "SGA1"

encryptField :: EncryptionKey -> ByteString -> ByteString -> IO (Either EncryptionError ByteString)
encryptField (EncryptionKey cipher) context plaintext = do
    nonce <- getRandomBytes 12 :: IO ByteString
    pure $ case aeadInit AEAD_GCM cipher nonce of
        CryptoFailed _ -> Left CipherInitializationFailed
        CryptoPassed aead ->
            let (tag, ciphertext) = aeadSimpleEncrypt aead (magic <> context) plaintext 16
            in Right (magic <> nonce <> convert tag <> ciphertext)

decryptField :: EncryptionKey -> ByteString -> ByteString -> Either EncryptionError ByteString
decryptField (EncryptionKey cipher) context envelope
    | BS.length envelope < 32 || BS.take 4 envelope /= magic = Left InvalidEnvelope
    | otherwise = case aeadInit AEAD_GCM cipher nonce of
        CryptoFailed _ -> Left CipherInitializationFailed
        CryptoPassed aead -> maybe (Left AuthenticationFailed) Right
            (aeadSimpleDecrypt aead (magic <> context) ciphertext (AuthTag (convert tag)))
    where
        nonce = BS.take 12 (BS.drop 4 envelope)
        tag = BS.take 16 (BS.drop 16 envelope)
        ciphertext = BS.drop 32 envelope
