{-# LANGUAGE OverloadedStrings #-}
-- Pure validators: no request, model context, database or IO.
module Application.Domain.Validation where

import Prelude
import Data.Text (Text)
import qualified Application.Domain.Grade as Grade
import IHP.ValidationSupport.ValidateField (nonEmpty, isEmail)
import IHP.ValidationSupport.Types (ValidatorResult (..))

-- Reuse IHP's existing pure rules, preserving accepted inputs and messages.
validarCom :: (a -> ValidatorResult) -> Text -> a -> Either Text a
validarCom regra mensagem valor = case regra valor of
    Success -> Right valor
    Failure _ -> Left mensagem
    FailureHtml _ -> Left mensagem

validarNomeEstudante :: Text -> Either Text Text
validarNomeEstudante = validarCom nonEmpty "Informe o nome."

validarEmail :: Text -> Either Text Text
validarEmail email = do
    _ <- validarCom nonEmpty "Informe o e-mail." email
    validarCom isEmail "Informe um e-mail válido." email

validarNumeroMatricula :: Text -> Either Text Text
validarNumeroMatricula = validarCom nonEmpty "Informe o número de matrícula."

validarNota :: Double -> Either Text Double
validarNota nota
    | Grade.notaValida nota = Right nota
    | otherwise = Left "A nota deve estar entre 0 e 10."

validarPeso :: Double -> Either Text Double
validarPeso peso
    | Grade.pesoValido peso = Right peso
    | otherwise = Left "O peso deve ser maior que zero."

-- do chains Either computations: the first Left stops the validation.
validarEstudante :: Text -> Text -> Text -> Either Text (Text, Text, Text)
validarEstudante nome email matricula = do
    nomeValido <- validarNomeEstudante nome
    emailValido <- validarEmail email
    matriculaValida <- validarNumeroMatricula matricula
    pure (nomeValido, emailValido, matriculaValida)

-- Presence and status are pure. Existence, uniqueness and permission checks
-- remain in controllers, after fetching the references from PostgreSQL.
validarDadosMatricula :: Maybe aluno -> Maybe disciplina -> Text -> Either Text (aluno, disciplina, Text)
validarDadosMatricula aluno disciplina situacao = do
    alunoValido <- maybe (Left "Selecione um estudante.") Right aluno
    disciplinaValido <- maybe (Left "Selecione uma disciplina.") Right disciplina
    if situacao `elem` ["active", "suspended", "completed"]
        then Right (alunoValido, disciplinaValido, situacao)
        else Left "Informe uma situação de matrícula válida: active, suspended ou completed."
