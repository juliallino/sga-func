{-# LANGUAGE OverloadedStrings #-}
module Examples.EnrollmentCPS where

import Prelude
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Application.Domain.EnrollmentCPS

-- Fictional identifiers, not database records. No request or database needed.
exemploMatricula :: Bool -> Text
exemploMatricula duplicada =
    validarMatriculaCPS (Just ("EST-DEMO-1" :: Text)) (Just ("CURSO-DEMO-1" :: Text)) "active"
        (VerificacaoMatricula True True duplicada)
        (\(aluno, disciplina, _) -> "Sucesso: " <> aluno <> " em " <> disciplina)
        (\erros -> "Erro: " <> Text.intercalate "; " erros)

main :: IO ()
main = do
    TextIO.putStrLn (exemploMatricula False)
    TextIO.putStrLn (exemploMatricula True)
    -- The pure CPS function can return IO actions supplied by its caller.
    validarMatriculaCPS (Nothing :: Maybe Text) (Just ("CURSO-DEMO-1" :: Text)) "active"
        (VerificacaoMatricula True True False)
        (\_ -> putStrLn "Sucesso")
        (\erros -> TextIO.putStrLn (Text.intercalate "; " erros))
