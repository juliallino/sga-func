module Test.Domain.GradeSpec (spec) where

import Prelude
import Test.Hspec
import Application.Domain.Grade

spec :: Spec
spec = do
    describe "Média ponderada" $ do
        it "retorna Nothing sem avaliações" $
            mediaPonderada [] `shouldBe` Nothing
        it "considera os pesos e aceita notas decimais" $
            mediaPonderada [(7.5, 1), (9, 3)] `shouldBe` Just 8.625
        it "aceita os limites 0 e 10" $
            mediaPonderada [(0, 1), (10, 1)] `shouldBe` Just 5
        it "rejeita notas fora do intervalo" $
            map mediaPonderada [[(-1, 1)], [(11, 1)]]
                `shouldBe` [Nothing, Nothing]
        it "rejeita pesos nulos e negativos" $
            map mediaPonderada [[(8, 0)], [(8, -1)]]
                `shouldBe` [Nothing, Nothing]
        it "rejeita NaN e infinitos em notas e pesos" $
            map mediaPonderada [[(0/0, 1)], [(1/0, 1)], [(8, 0/0)], [(8, 1/0)]]
                `shouldBe` replicate 4 Nothing
        it "não retorna uma média não finita quando as somas transbordam" $
            mediaPonderada [(10, 1e308), (10, 1e308)] `shouldBe` Nothing
        it "converte entradas integrais e mantém a API usada pelo controller" $ do
            calcularMediaNotas [(8 :: Int, 1 :: Int), (6, 3)] `shouldBe` Just 6.5
            mediaDaMatricula [(8, 1), (6, 3)] `shouldBe` Just 6.5
    describe "Validações funcionais" $ do
        it "valida notas inclusive nos limites" $
            map notaValida [-1, 0, 10, 11, 0/0, 1/0]
                `shouldBe` [False, True, True, False, False, False]
        it "exige pesos positivos e finitos" $
            map pesoValido [-1, 0, 0.5, 0/0, 1/0]
                `shouldBe` [False, False, True, False, False]
    describe "Funções de ordem superior" $ do
        it "captura os pesos fixos na closure" $ do
            let calcular = criarCalculadoraMedia [(0, 1), (0, 3)]
            calcular [(8, 99), (6, 99)] `shouldBe` Just 6.5
            calcular [(10, 1), (10, 1)] `shouldBe` Just 10
            calcular [(8, 1)] `shouldBe` Nothing
        it "permite aplicação parcial e filtra incluindo a média mínima" $ do
            let aprovadas = filtrarNotasAprovadas 7
            aprovadas [5, 7, 9] `shouldBe` [7, 9]
        it "aplica bônus com teto de 10 usando map" $
            aplicarBonus 2 [5, 9, 10] `shouldBe` [7, 10, 10]
        it "soma com foldl, inclusive a lista vazia" $ do
            somarNotas [5, 7, 9] `shouldBe` 21
            somarNotas [] `shouldBe` 0
        it "expande e concatena com concatMap" $
            duplicarInformacoesNotas [3, 5] `shouldBe` [3, 6, 5, 10]
