{-# LANGUAGE OverloadedStrings #-}
module Application.Domain.AcademicConfig where

import Prelude
import Control.Monad.Reader (Reader, ask, asks)
import Data.Text (Text)
import qualified Application.Domain.Validation as Validation
import Application.Domain.Grade (numeroFinito)

-- Example configuration, independent of IHP's ConfigBuilder.
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
    config <- ask
    pure $ do
        if numeroFinito (notaMaxima config) && notaMaxima config > 0
            && numeroFinito (pesoMinimoExclusivo config) && pesoMinimoExclusivo config >= 0
            then Right ()
            else Left "Configuração acadêmica inválida."
        -- Baseline constraints still apply: configuration cannot permit > 10.
        notaValida <- Validation.validarNota nota
        pesoValido <- Validation.validarPeso peso
        if notaValida > notaMaxima config
            then Left "A nota excede o máximo configurado."
            else if pesoValido <= pesoMinimoExclusivo config
                then Left "O peso deve superar o mínimo configurado."
                else Right (notaValida, pesoValido)

-- Demonstration only: does not impose pagination on existing controllers.
primeiraPagina :: [a] -> Reader AcademicConfig [a]
primeiraPagina registros = do
    limite <- asks registrosPorPagina
    pure (take (max 0 limite) registros)
