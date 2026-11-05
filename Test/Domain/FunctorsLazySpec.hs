{-# LANGUAGE OverloadedStrings #-}
module Test.Domain.FunctorsLazySpec (spec) where

import Prelude
import Data.Text (Text)
import Test.Hspec
import Application.Domain.Grade (aplicarBonus, mediaPonderada)
import Application.Domain.Validation (validarNota)
import Application.Domain.AcademicDisplay
import Application.Domain.LazyExamples

spec :: Spec
spec = do
    describe "Functor: transformações acadêmicas" $ do
        it "bonifica a lista existente com fmap e preserva o teto" $ do
            aplicarBonus 0.5 [6.0, 7.5, 9.0] `shouldBe` [6.5, 8.0, 9.5]
            aplicarBonus 0.5 [9.8, 10] `shouldBe` [10, 10]
            aplicarBonus 0.5 [] `shouldBe` []
        it "produz novos dados sem alterar notas e nomes originais" $ do
            let notas = [6.0, 7.5, 9.0]
                nomes = [" Ana Silva ", "Bruno Costa"]
            aplicarBonus 0.5 notas `shouldBe` [6.5, 8.0, 9.5]
            notas `shouldBe` [6.0, 7.5, 9.0]
            nomesParaExibicao nomes `shouldBe` ["ANA SILVA", "BRUNO COSTA"]
            nomes `shouldBe` [" Ana Silva ", "Bruno Costa"]
        it "formata nomes vazios e coleções vazias" $ do
            nomesParaExibicao [] `shouldBe` []
            nomesParaExibicao ["   "] `shouldBe` [""]
        it "usa a mesma transformação em lista, Maybe e Either" $ do
            notasParaExibicao [6, 8] `shouldBe` ["Nota: 6.0", "Nota: 8.0"]
            notasParaExibicao (mediaPonderada [(8,2),(6,3),(10,5)] )
                `shouldBe` Just "Nota: 8.4"
            notasParaExibicao (validarNota 8) `shouldBe` Right "Nota: 8.0"
        it "preserva Nothing e a mensagem de Left" $ do
            notasParaExibicao (Nothing :: Maybe Double) `shouldBe` Nothing
            notasParaExibicao (validarNota 11)
                `shouldBe` Left "A nota deve estar entre 0 e 10."
        it "não avalia a transformação em contextos sem valor" $ do
            fmap (error "transformação não deve ser avaliada" :: Double -> Text) Nothing
                `shouldBe` (Nothing :: Maybe Text)
            fmap (error "transformação não deve ser avaliada" :: Double -> Text) (Left "erro")
                `shouldBe` (Left "erro" :: Either Text Text)
        it "demonstra identidade e composição nos três contextos" $ do
            let verificar contexto = do
                    fmap id contexto `shouldBe` contexto
                    fmap ((+ 1) . (* 2)) contexto `shouldBe` (fmap (+ 1) . fmap (* 2)) contexto
            verificar [6, 8 :: Double]
            verificar (Just (8 :: Double))
            verificar (Nothing :: Maybe Double)
            verificar (Right 8 :: Either Text Double)
            verificar (Left "erro" :: Either Text Double)
    describe "Lazy Evaluation: consumo finito de sequências infinitas" $ do
        it "take consome somente cinco números" $
            take 5 numerosFicticios `shouldBe` [1,2,3,4,5]
        it "map gera somente o prefixo solicitado de matrículas fictícias" $
            take 3 matriculasFicticias `shouldBe` ["DEMO-1", "DEMO-2", "DEMO-3"]
        it "filter procura pares conforme a demanda" $
            take 5 numerosParesFicticios `shouldBe` [2,4,6,8,10]
        it "take zero não força a sequência" $
            take 0 (error "lista não deve ser avaliada" :: [Integer]) `shouldBe` []
        it "map e filter não forçam a cauda desnecessária" $ do
            take 2 (map (* 2) (1 : 2 : error "cauda não deve ser avaliada" :: [Integer]))
                `shouldBe` [2,4]
            take 2 (filter even (1 : 2 : 3 : 4 : error "cauda não deve ser avaliada" :: [Integer]))
                `shouldBe` [2,4]
        it "a bonificação existente também aceita consumo sob demanda" $
            take 3 (aplicarBonus 0.5 (repeat 6)) `shouldBe` [6.5,6.5,6.5]
