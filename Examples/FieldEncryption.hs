{-# LANGUAGE OverloadedStrings #-}
module Examples.FieldEncryption where

import Prelude
import Application.Security.FieldEncryption

-- Only synthetic data. Never print keys, plaintext or the encrypted envelope.
main :: IO ()
main = do
    configured <- loadEncryptionKey
    case configured of
        Left _ -> ioError (userError "Configure SGA_FIELD_ENCRYPTION_KEY com 32 bytes aleatórios em Base64.")
        Right key -> do
            encrypted <- encryptField key "demo:observacao:estudante-ficticio" "Observação acadêmica fictícia"
            case encrypted of
                Left _ -> ioError (userError "Falha na criptografia.")
                Right envelope -> do
                    if decryptField key "demo:observacao:estudante-ficticio" envelope == Right "Observação acadêmica fictícia"
                        then putStrLn "AES-256-GCM: criptografia e recuperação autenticada verificadas."
                        else ioError (userError "Falha na recuperação autenticada.")
                    if decryptField key "demo:outro-estudante" envelope == Left AuthenticationFailed
                        then putStrLn "Troca de contexto rejeitada. Nenhum dado foi persistido."
                        else ioError (userError "Falha na proteção de contexto.")
