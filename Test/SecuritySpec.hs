{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
module Test.SecuritySpec (spec) where

import Prelude
import Test.Hspec
import Control.Exception (bracket)
import "crypton" Crypto.Random (getRandomBytes)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as Base64
import qualified Data.ByteString.Char8 as Char8
import qualified Data.Text as Text
import Data.Bits (xor)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import IHP.AuthSupport.Authentication (hashPassword, verifyPassword')
import Application.Security.FieldEncryption

newKey :: IO EncryptionKey
newKey = do
    bytes <- getRandomBytes 32 :: IO BS.ByteString
    either (\_ -> fail "Falha ao preparar chave efêmera") pure (keyFromBytes bytes)

withKeyEnv :: Maybe String -> IO a -> IO a
withKeyEnv value action = bracket (lookupEnv name) restore (\_ -> restore value >> action)
    where
        name = "SGA_FIELD_ENCRYPTION_KEY"
        restore Nothing = unsetEnv name
        restore (Just encoded) = setEnv name encoded

spec :: Spec
spec = do
    describe "Segurança: hash nativo IHP 1.6" $ do
        it "usa hash verificável com salt e custo, sem registrar valores secretos" $ do
            first <- hashPassword "security-test-only"
            second <- hashPassword "security-test-only"
            (first /= "security-test-only") `shouldBe` True
            (first /= second) `shouldBe` True
            Text.isPrefixOf "sha256|17|" first `shouldBe` True
            verifyPassword' first "security-test-only" `shouldBe` True
            verifyPassword' first "incorreta" `shouldBe` False
    describe "AES-256-GCM: demonstração isolada" $ do
        it "recupera somente o conteúdo autenticado, inclusive vazio" $ do
            key <- newKey
            mapM_ (\plaintext -> do
                encrypted <- encryptField key "demo:observacao:1" plaintext
                case encrypted of
                    Left _ -> expectationFailure "Falha ao criptografar demonstração"
                    Right envelope -> do
                        (envelope /= plaintext) `shouldBe` True
                        decryptField key "demo:observacao:1" envelope `shouldBe` Right plaintext)
                ["Observação acadêmica fictícia", ""]
        it "gera um novo nonce para cada operação" $ do
            key <- newKey
            first <- encryptField key "demo" "ficticio"
            second <- encryptField key "demo" "ficticio"
            (first /= second) `shouldBe` True
        it "rejeita chave errada e contexto trocado" $ do
            key <- newKey
            otherKey <- newKey
            encrypted <- encryptField key "demo:1" "ficticio"
            case encrypted of
                Left _ -> expectationFailure "Falha na preparação"
                Right envelope -> do
                    decryptField otherKey "demo:1" envelope `shouldBe` Left AuthenticationFailed
                    decryptField key "demo:2" envelope `shouldBe` Left AuthenticationFailed
        it "rejeita adulteração do nonce, tag e conteúdo" $ do
            key <- newKey
            encrypted <- encryptField key "demo" "ficticio"
            case encrypted of
                Left _ -> expectationFailure "Falha na preparação"
                Right envelope -> mapM_ (\position ->
                    let altered = BS.take position envelope
                            <> BS.singleton (BS.index envelope position `xor` 1)
                            <> BS.drop (position + 1) envelope
                    in decryptField key "demo" altered `shouldBe` Left AuthenticationFailed)
                    [4, 16, 32]
        it "rejeita envelopes truncados e versões desconhecidas" $ do
            key <- newKey
            mapM_ (\envelope -> decryptField key "demo" envelope `shouldBe` Left InvalidEnvelope)
                ["", "SGA1", "SGA1" <> BS.replicate 27 0, "SGA2" <> BS.replicate 28 0]
        it "exige chave de 32 bytes sem expor seu conteúdo" $
            mapM_ (\size -> either (== InvalidEncryptionKey) (const False)
                (keyFromBytes (BS.replicate size 0)) `shouldBe` True) [0, 16, 24, 31, 33]
        it "falha de forma fechada sem variável ou com Base64 inválida" $ do
            withKeyEnv Nothing $ do
                result <- loadEncryptionKey
                either (== MissingEncryptionKey) (const False) result `shouldBe` True
            mapM_ (\encoded -> withKeyEnv (Just encoded) $ do
                result <- loadEncryptionKey
                either (== InvalidEncryptionKey) (const False) result `shouldBe` True) ["invalid!", "YWJj"]
        it "carrega a chave do ambiente e permite round-trip" $ do
            bytes <- getRandomBytes 32 :: IO BS.ByteString
            withKeyEnv (Just (Char8.unpack (Base64.encode bytes))) $ do
                result <- loadEncryptionKey
                case result of
                    Left _ -> expectationFailure "Falha ao carregar chave efêmera"
                    Right key -> do
                        encrypted <- encryptField key "demo" "ficticio"
                        (encrypted >>= decryptField key "demo") `shouldBe` Right "ficticio"
