{-# LANGUAGE OverloadedStrings #-}
module Examples.Monads where

import Prelude
import Control.Monad.Reader (runReader)
import Application.Domain.Grade (mediaPonderada)
import Application.Domain.Validation
import Application.Domain.AcademicConfig

-- IO is restricted to presentation; every argument below is computed purely.
main :: IO ()
main = do
    print (mediaPonderada [(8,2),(6,3),(10,5)])
    print (mediaPonderada [])
    print (mediaPonderada [(8,0)])
    print (validarEstudante "Ana" "ana@example.com" "2026-001")
    print (validarNota 11)
    print (validarDadosMatricula (Just (1 :: Int)) (Just (2 :: Int)) "active")
    print (runReader (validarAvaliacao 9 2) configAcademicaPadrao)
    print (runReader (validarAvaliacao 9 2) (AcademicConfig 8 1 2))
    print (runReader (primeiraPagina [1..5 :: Int]) (AcademicConfig 10 0 2))
