module Test.Domain.ValidationSpec (spec) where

import Prelude
import Test.Hspec
import Application.Domain.Validation

falha :: [String] -> Validacao String Int
falha = Falha

sucesso :: Int -> Validacao String Int
sucesso = Sucesso

spec :: Spec
spec = do
    describe "Validacao (Applicative que acumula erros)" $ do
        it "acumula os erros de todos os campos, na ordem" $
            ((,) <$> falha ["a"] <*> falha ["b"]) `shouldBe` Falha ["a", "b"]
        it "mantém o erro quando apenas um dos lados falha" $ do
            ((,) <$> sucesso 1 <*> falha ["b"]) `shouldBe` Falha ["b"]
            ((,) <$> falha ["a"] <*> sucesso 2) `shouldBe` Falha ["a"]
        it "combina valores quando tudo é válido" $
            ((+) <$> sucesso 1 <*> sucesso 2) `shouldBe` Sucesso 3
        it "converte para Either" $ do
            emEither (falha ["a", "b"]) `shouldBe` Left ["a", "b"]
            emEither (sucesso 7) `shouldBe` Right 7
    describe "Nota (tipo opaco)" $ do
        it "aceita 0, 10 e valores intermediários" $
            map (fmap valorNota . criarNota) [0, 7.5, 10]
                `shouldBe` [Just 0, Just 7.5, Just 10]
        it "rejeita valores fora de 0 a 10, NaN e infinitos" $
            map criarNota [-0.01, 10.01, 0 / 0, 1 / 0] `shouldBe` replicate 4 Nothing
    describe "Leitura de números" $ do
        it "lê decimais com ponto ou vírgula e ignora espaços" $
            map lerDecimal ["7.5", "7,5", " 8 "] `shouldBe` [Just 7.5, Just 7.5, Just 8]
        it "rejeita texto, vazio, NaN e infinito" $
            map lerDecimal ["abc", "", "NaN", "Infinity", "7,5,1"] `shouldBe` replicate 5 Nothing
        it "lê inteiros e rejeita decimais" $
            map lerInteiro ["10", " 3 ", "10.5", "x"] `shouldBe` [Just 10, Just 3, Nothing, Nothing]
        it "não perde valores enormes por estouro de Int" $
            lerInteiro "99999999999999999999" `shouldBe` Just 99999999999999999999
        it "remove espaços das pontas" $
            aparar "  a b  " `shouldBe` "a b"
