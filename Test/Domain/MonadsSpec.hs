{-# LANGUAGE OverloadedStrings #-}
module Test.Domain.MonadsSpec (spec) where

import Prelude
import Control.Monad.Reader (runReader, local)
import Data.Either (isLeft)
import Test.Hspec
import Application.Domain.Validation
import Application.Domain.AcademicConfig
import Application.Domain.Grade (mediaPonderada)

spec :: Spec
spec = do
    describe "Either: validações acadêmicas puras" $ do
        it "aceita dados válidos e preserva seus valores" $ do
            validarEstudante "Ana" "ana@example.com" "2026-001"
                `shouldBe` Right ("Ana", "ana@example.com", "2026-001")
            validarNota 0 `shouldBe` Right 0
            validarNota 10 `shouldBe` Right 10
            validarPeso 0.001 `shouldBe` Right 0.001
        it "retorna mensagens descritivas para campos obrigatórios" $ do
            validarNomeEstudante "" `shouldBe` Left "Informe o nome."
            validarEmail "" `shouldBe` Left "Informe o e-mail."
            validarEmail "invalido" `shouldBe` Left "Informe um e-mail válido."
            validarNumeroMatricula "" `shouldBe` Left "Informe o número de matrícula."
        it "interrompe o encadeamento no primeiro erro" $
            validarEstudante "" "invalido" "" `shouldBe` Left "Informe o nome."
        it "rejeita notas fora do intervalo e valores não finitos" $
            map (isLeft . validarNota) [-1, 11, 0/0, 1/0, -1/0]
                `shouldBe` replicate 5 True
        it "rejeita pesos não positivos e valores não finitos" $
            map (isLeft . validarPeso) [0, -1, 0/0, 1/0, -1/0]
                `shouldBe` replicate 5 True
        it "valida os dados necessários para matrícula sem consultar o banco" $ do
            validarDadosMatricula (Just (1 :: Int)) (Just (2 :: Int)) "active"
                `shouldBe` Right (1, 2, "active")
            map (validarDadosMatricula (Just (1 :: Int)) (Just (2 :: Int))) ["suspended", "completed"]
                `shouldBe` [Right (1, 2, "suspended"), Right (1, 2, "completed")]
            validarDadosMatricula (Nothing :: Maybe Int) (Just (2 :: Int)) "active"
                `shouldBe` Left "Selecione um estudante."
            validarDadosMatricula (Just (1 :: Int)) (Nothing :: Maybe Int) "active"
                `shouldBe` Left "Selecione uma disciplina."
            validarDadosMatricula (Just (1 :: Int)) (Just (2 :: Int)) "invalid"
                `shouldSatisfy` isLeft
    describe "Reader: configuração explícita sem IO" $ do
        it "preserva os validadores dos campos web com a configuração de produção" $ do
            mapM_ (\nota -> runReader (validarNotaConfigurada nota) configAcademicaPadrao
                `shouldBe` validarNota nota) [-1, 0, 8, 10, 11]
            mapM_ (\peso -> runReader (validarPesoConfigurado peso) configAcademicaPadrao
                `shouldBe` validarPeso peso) [-1, 0, 0.001, 1, 999.99]
        it "transporta os limites aos dois campos sem alterar o ambiente padrão" $ do
            let restrita = AcademicConfig 8 1 20
            runReader (validarNotaConfigurada 9) restrita
                `shouldBe` Left "A nota excede o máximo configurado."
            runReader (validarPesoConfigurado 1) restrita
                `shouldBe` Left "O peso deve superar o mínimo configurado."
            runReader (validarNotaConfigurada 9) configAcademicaPadrao `shouldBe` Right 9
            runReader (validarPesoConfigurado 1) configAcademicaPadrao `shouldBe` Right 1
        it "rejeita configuração inválida em cada campo antes da persistência" $ do
            let invalida = AcademicConfig 10 (-1) 20
            runReader (validarNotaConfigurada 8) invalida
                `shouldBe` Left "Configuração acadêmica inválida."
            runReader (validarPesoConfigurado 2) invalida
                `shouldBe` Left "Configuração acadêmica inválida."
        it "preserva as regras atuais na configuração padrão" $ do
            runReader (validarAvaliacao 10 0.001) configAcademicaPadrao
                `shouldBe` Right (10, 0.001)
            runReader (validarAvaliacao 8 0) configAcademicaPadrao `shouldSatisfy` isLeft
        it "permite demonstrar outra configuração sem alterar a padrão" $ do
            let restrita = AcademicConfig 8 1 2
            runReader (validarAvaliacao 9 2) restrita
                `shouldBe` Left "A nota excede o máximo configurado."
            runReader (validarAvaliacao 8 1) restrita
                `shouldBe` Left "O peso deve superar o mínimo configurado."
            runReader (validarAvaliacao 8 2) restrita `shouldBe` Right (8, 2)
            runReader (primeiraPagina [1..5 :: Int]) restrita `shouldBe` [1, 2]
        it "local restringe o ambiente somente à computação interna" $ do
            let exemplo = do
                    interna <- local (\c -> c { registrosPorPagina = 1 }) (primeiraPagina [1..5 :: Int])
                    externa <- primeiraPagina [1..5 :: Int]
                    pure (interna, externa)
            runReader exemplo (AcademicConfig 10 0 3) `shouldBe` ([1], [1, 2, 3])
        it "trata limites de paginação não positivos" $ do
            runReader (primeiraPagina [1..5 :: Int]) (AcademicConfig 10 0 0) `shouldBe` []
            runReader (primeiraPagina [1..5 :: Int]) (AcademicConfig 10 0 (-1)) `shouldBe` []
        it "rejeita configuração numérica inválida sem relaxar o domínio" $ do
            map (\c -> isLeft (runReader (validarAvaliacao 8 1) c))
                [AcademicConfig (0/0) 0 20, AcademicConfig 10 (-1) 20, AcademicConfig 0 0 20]
                `shouldBe` [True, True, True]
            runReader (validarAvaliacao 11 1) (AcademicConfig 20 0 20) `shouldSatisfy` isLeft
    describe "Maybe e separação de efeitos" $ do
        it "compõe cálculo e ausência com bind de Maybe" $ do
            (mediaPonderada [(8,2),(6,3),(10,5)] >>= (Just . (+ 1))) `shouldBe` Just 9.4
            (mediaPonderada [] >>= (Just . (+ 1))) `shouldBe` Nothing
        it "executa o fluxo puro sem contexto IHP, autenticação ou conexão" $ do
            -- The type excludes IO. Only this test's assertion performs IO.
            let resultado :: Either a Double -> Maybe Double
                resultado = either (const Nothing) Just
                fluxo = do
                    _ <- validarEstudante "Ana" "ana@example.com" "A1"
                    _ <- runReader (validarAvaliacao 8 2) configAcademicaPadrao
                    pure 8
            resultado fluxo `shouldBe` Just 8
