{-# LANGUAGE OverloadedStrings #-}
module Application.Domain.AcademicConfig where

import Prelude
import Control.Monad.Reader (Reader, ask, asks)
import Data.Text (Text)
import qualified Application.Domain.Validation as Validation
import Application.Domain.Grade (numeroFinito)

-- Validation configuration consumed by the grade create/update flow.
-- Independent of IHP's ConfigBuilder; callers supply the Reader environment.
-- The minimum weight is EXCLUSIVE: zero preserves the current weight > 0 rule.
data AcademicConfig = AcademicConfig
    { notaMaxima :: Double
    , pesoMinimoExclusivo :: Double
    , registrosPorPagina :: Int
    } deriving (Eq, Show)

configAcademicaPadrao :: AcademicConfig
configAcademicaPadrao = AcademicConfig 10 0 20

validarAvaliacao :: Double -> Double -> Reader AcademicConfig (Either Text (Double, Double))
validarAvaliacao nota peso = do
    resultadoNota <- validarNotaConfigurada nota
    resultadoPeso <- validarPesoConfigurado peso
    pure $ do
        notaValida <- resultadoNota
        pesoValido <- resultadoPeso
        pure (notaValida, pesoValido)

-- Separate fields retain IHP's field-specific errors in create/update forms.
validarNotaConfigurada :: Double -> Reader AcademicConfig (Either Text Double)
validarNotaConfigurada nota = do
    config <- ask
    pure $ do
        validarConfig config
        -- Baseline constraints still apply: configuration cannot permit > 10.
        notaValida <- Validation.validarNota nota
        if notaValida > notaMaxima config
            then Left "A nota excede o máximo configurado."
            else Right notaValida

validarPesoConfigurado :: Double -> Reader AcademicConfig (Either Text Double)
validarPesoConfigurado peso = do
    config <- ask
    pure $ do
        validarConfig config
        pesoValido <- Validation.validarPeso peso
        if pesoValido <= pesoMinimoExclusivo config
            then Left "O peso deve superar o mínimo configurado."
            else Right pesoValido

validarConfig :: AcademicConfig -> Either Text ()
validarConfig config
    | numeroFinito (notaMaxima config) && notaMaxima config > 0
        && numeroFinito (pesoMinimoExclusivo config) && pesoMinimoExclusivo config >= 0 = Right ()
    | otherwise = Left "Configuração acadêmica inválida."

-- Demonstration only: does not impose pagination on existing controllers.
primeiraPagina :: [a] -> Reader AcademicConfig [a]
primeiraPagina registros = do
    limite <- asks registrosPorPagina
    pure (take (max 0 limite) registros)
