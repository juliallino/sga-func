{-# LANGUAGE OverloadedStrings #-}
-- Pure continuation-passing validation. Database facts are supplied by callers.
module Application.Domain.EnrollmentCPS where

import Prelude
import Data.Text (Text)
import Application.Domain.Validation (validarDadosMatricula)

-- Snapshot from IO queries, or explicit fictional facts in demonstrations.
-- These facts must correspond to the same enrollment being validated.
data VerificacaoMatricula = VerificacaoMatricula
    { estudanteExiste :: Bool
    , disciplinaExiste :: Bool
    , matriculaDuplicada :: Bool
    } deriving (Eq, Show)

data ErroRegraMatricula
    = EstudanteInexistente
    | DisciplinaInexistente
    | MatriculaDuplicada
    deriving (Eq, Show)

mensagemErroRegra :: ErroRegraMatricula -> Text
mensagemErroRegra EstudanteInexistente = "O estudante informado não existe."
mensagemErroRegra DisciplinaInexistente = "A disciplina informada não existe."
mensagemErroRegra MatriculaDuplicada = "Este aluno já está matriculado nesta disciplina."

-- The result is delivered to exactly one continuation, rather than returned
-- directly. r is chosen by the caller: text, Either, an IO action, etc.
validarObrigatoriosCPS
    :: Maybe aluno -> Maybe disciplina -> Text
    -> ((aluno, disciplina, Text) -> r) -> ([Text] -> r) -> r
validarObrigatoriosCPS aluno disciplina situacao sucesso falha =
    case validarDadosMatricula aluno disciplina situacao of
        Left mensagem -> falha [mensagem]
        Right dados -> sucesso dados

-- Preserve the controller's accumulated errors and their order.
validarRegrasMatriculaCPS
    :: VerificacaoMatricula -> (() -> r) -> ([ErroRegraMatricula] -> r) -> r
validarRegrasMatriculaCPS verificacao sucesso falha =
    case erros of
        [] -> sucesso ()
        _ -> falha erros
    where
        erros = [EstudanteInexistente | not (estudanteExiste verificacao)]
            ++ [DisciplinaInexistente | not (disciplinaExiste verificacao)]
            ++ [MatriculaDuplicada | matriculaDuplicada verificacao]

-- The success continuation of the first stage IS the next processing stage.
-- Mandatory failure skips the rule stage and the final success continuation.
validarMatriculaCPS
    :: Maybe aluno -> Maybe disciplina -> Text -> VerificacaoMatricula
    -> ((aluno, disciplina, Text) -> r) -> ([Text] -> r) -> r
validarMatriculaCPS aluno disciplina situacao verificacao sucesso falha =
    validarObrigatoriosCPS aluno disciplina situacao
        (\dados -> validarRegrasMatriculaCPS verificacao
            (\() -> sucesso dados)
            (falha . map mensagemErroRegra))
        falha
