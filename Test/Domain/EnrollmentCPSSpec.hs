{-# LANGUAGE OverloadedStrings #-}
module Test.Domain.EnrollmentCPSSpec (spec) where

import Prelude
import Data.Text (Text)
import Data.IORef (newIORef, modifyIORef', readIORef)
import Test.Hspec
import Application.Domain.EnrollmentCPS

dadosValidos :: VerificacaoMatricula
dadosValidos = VerificacaoMatricula True True False

executar :: Maybe Int -> Maybe Int -> Text -> VerificacaoMatricula -> Either [Text] (Int, Int, Text)
executar aluno disciplina situacao verificacao =
    validarMatriculaCPS aluno disciplina situacao verificacao Right Left

spec :: Spec
spec = do
    describe "CPS: pipeline de matrícula em disciplina" $ do
        it "entrega os dados válidos à continuação de sucesso" $
            executar (Just 1) (Just 2) "active" dadosValidos `shouldBe` Right (1,2,"active")
        it "aceita os três status existentes sem criar regras novas" $
            map (\status -> executar (Just 1) (Just 2) status dadosValidos) ["active","suspended","completed"]
                `shouldBe` map (\status -> Right (1,2,status)) ["active","suspended","completed"]
        it "valida estudante, disciplina e situação obrigatórios" $ do
            executar Nothing (Just 2) "active" dadosValidos `shouldBe` Left ["Selecione um estudante."]
            executar (Just 1) Nothing "active" dadosValidos `shouldBe` Left ["Selecione uma disciplina."]
            executar (Just 1) (Just 2) "invalida" dadosValidos
                `shouldBe` Left ["Informe uma situação de matrícula válida: active, suspended ou completed."]
        it "preserva as mensagens de referências inexistentes e duplicidade" $ do
            executar (Just 1) (Just 2) "active" (VerificacaoMatricula False True False)
                `shouldBe` Left ["O estudante informado não existe."]
            executar (Just 1) (Just 2) "active" (VerificacaoMatricula True False False)
                `shouldBe` Left ["A disciplina informada não existe."]
            executar (Just 1) (Just 2) "active" (VerificacaoMatricula True True True)
                `shouldBe` Left ["Este aluno já está matriculado nesta disciplina."]
        it "acumula os erros das regras na ordem usada pelo controller" $
            validarRegrasMatriculaCPS (VerificacaoMatricula False False True) (\() -> []) id
                `shouldBe` [EstudanteInexistente, DisciplinaInexistente, MatriculaDuplicada]
        it "não executa as regras nem o sucesso quando faltam dados" $
            validarMatriculaCPS (Nothing :: Maybe Int) (Just (2 :: Int)) "active"
                (error "a etapa de regras não deve ser avaliada")
                (\_ -> error "sucesso não deve ser avaliado") id
                `shouldBe` ["Selecione um estudante."]
        it "não avalia a continuação de erro no sucesso" $
            validarMatriculaCPS (Just (1 :: Int)) (Just (2 :: Int)) "active" dadosValidos
                (\_ -> "sucesso" :: Text) (\_ -> error "falha indevida") `shouldBe` "sucesso"
        it "não avalia a continuação de sucesso quando há duplicidade" $
            validarMatriculaCPS (Just (1 :: Int)) (Just (2 :: Int)) "active" (VerificacaoMatricula True True True)
                (\_ -> error "sucesso indevido") (const ("falha" :: Text)) `shouldBe` "falha"
        it "deixa o chamador escolher o resultado final" $ do
            validarMatriculaCPS (Just (1 :: Int)) (Just (2 :: Int)) "active" dadosValidos
                (\(aluno, disciplina, _) -> aluno + disciplina) (const 0) `shouldBe` 3
            validarMatriculaCPS (Just (1 :: Int)) (Just (2 :: Int)) "active" dadosValidos
                (const True) (const False) `shouldBe` True
        it "executa exatamente a continuação IO selecionada, uma vez" $ do
            chamadas <- newIORef ([] :: [Text])
            let sucesso _ = modifyIORef' chamadas (++ ["sucesso"])
                falha _ = modifyIORef' chamadas (++ ["falha"])
            validarMatriculaCPS (Just (1 :: Int)) (Just (2 :: Int)) "active" dadosValidos sucesso falha
            readIORef chamadas `shouldReturn` ["sucesso"]
            validarMatriculaCPS (Just (1 :: Int)) (Just (2 :: Int)) "active" (VerificacaoMatricula True True True) sucesso falha
            readIORef chamadas `shouldReturn` ["sucesso", "falha"]
