{-# LANGUAGE PackageImports #-}
{-# LANGUAGE OverloadedStrings #-}
module Test.Domain.ConfidentialNoteSpec (spec) where
import Prelude
import Test.Hspec
import Application.Domain.ConfidentialNote
import Application.Security.ConfidentialNote
import qualified Data.Text as T
import qualified Data.Text.Encoding as UTF8
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Lazy as LBS
import Data.Aeson (object, (.=), encode)
import "crypton" Crypto.Random (getRandomBytes)

spec :: Spec
spec = do
    describe "Observação confidencial: validação e envelope" $ do
        it "limita o texto e permite remoção explícita" $ do
            validateNote "  " `shouldBe` Right Nothing
            validateNote " fictício " `shouldBe` Right (Just "fictício")
            validateNote (T.replicate 2001 "x") `shouldBe` Left ()
        it "rejeita configuração ausente, inválida e IDs duplicados" $ do
            mapM_ (\raw -> either (== NoteUnavailable) (const False) (parseNoteKeys "k1" raw) `shouldBe` True)
                ["", "{}", "[]", "{\"k1\":\"invalid!\"}", "{\"k1\":\"YWJj\"}", "{\"k1\":\"a\",\"k1\":\"b\"}"]
        it "preserva conteúdo, vincula estudante, rejeita adulteração e usa nonce novo" $ do
            raw <- getRandomBytes 32 :: IO BS.ByteString
            let json = UTF8.decodeUtf8 (LBS.toStrict (encode (object ["k1" .= UTF8.decodeUtf8 (B64.encode raw)])))
            let encoded = UTF8.decodeUtf8 (B64.encode raw)
            let duplicate = "{\"k1\":\"" <> encoded <> "\",\"k1\":\"" <> encoded <> "\"}"
            either (== NoteUnavailable) (const False) (parseNoteKeys "k1" duplicate) `shouldBe` True
            keys <- either (const (fail "configuração de teste")) pure (parseNoteKeys "k1" json)
            first <- sealNote keys "00000000-0000-0000-0000-000000000001" "fictício"
            second <- sealNote keys "00000000-0000-0000-0000-000000000001" "fictício"
            (first /= second) `shouldBe` True
            case first of
                Left _ -> expectationFailure "falha criptográfica"
                Right envelope -> do
                    (openNote keys "00000000-0000-0000-0000-000000000001" envelope == Right "fictício") `shouldBe` True
                    openNote keys "00000000-0000-0000-0000-000000000002" envelope `shouldBe` Left InvalidStoredNote
                    openNote keys "00000000-0000-0000-0000-000000000001" (T.replace "SGAF1" "SGAF2" envelope) `shouldBe` Left InvalidStoredNote
