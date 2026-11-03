{-# LANGUAGE OverloadedStrings #-}
module Examples.FunctorsLazy where

import Prelude
import Data.Text (Text)
import Application.Domain.Grade (aplicarBonus, mediaPonderada)
import Application.Domain.Validation (validarNota)
import Application.Domain.AcademicDisplay
import Application.Domain.LazyExamples

main :: IO ()
main = do
    let notas = [6.0, 7.5, 9.0]
    print notas
    print (aplicarBonus 0.5 notas)
    print notas
    print (nomesParaExibicao [" Ana Silva ", "Bruno Costa"])
    print (notasParaExibicao notas)
    print (notasParaExibicao (mediaPonderada [(8,2),(6,3),(10,5)]))
    print (notasParaExibicao (Nothing :: Maybe Double))
    print (notasParaExibicao (validarNota 8))
    print (notasParaExibicao (Left "Nota inválida" :: Either Text Double))
    print (take 5 numerosFicticios)
    print (take 5 matriculasFicticias)
    print (take 5 numerosParesFicticios)
