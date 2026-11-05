module Test.Domain.AcademicSpec (spec) where
import Prelude
import Test.Hspec
import Application.Domain.Academic
spec :: Spec
spec = do
  describe "Média geral completa" $ do
    it "não usa nota zero para ausência" $
        mediaGeralCompleta 2 [Just 8, Nothing] `shouldBe` Nothing
    it "exige todas as disciplinas" $
        mediaGeralCompleta 5 [Just 8,Just 9] `shouldBe` Nothing
    it "calcula média simples das médias ponderadas disponíveis" $
        mediaGeralCompleta 2 [Just 8,Just 9] `shouldBe` Just 8.5
    it "rejeita lista vazia e valores não finitos" $ do
        mediaGeralCompleta 0 [] `shouldBe` Nothing
        mediaGeralCompleta 1 [Just (0/0)] `shouldBe` Nothing

  describe "Desempenho descritivo e política explícita" $ do
    it "calcula a média atual sem transformar ausência em zero" $ do
        mediaAtualTurma [Just 8.5, Nothing, Just 6] `shouldBe` Just 7.25
        mediaAtualTurma [Nothing, Just (0/0), Just 11] `shouldBe` Nothing
    it "não inventa aprovação quando nenhuma política foi definida" $ do
        classifyAverage Nothing True (Just 10) `shouldBe` PolicyPending
        performance Nothing [(True, Just 8), (False, Nothing)]
            `shouldBe` Performance (Just 8) 1 1 Nothing Nothing Nothing
    it "usa um critério explícito de teste, inclusive o limite, sem torná-lo padrão" $ do
        let rule = Just (ApprovalPolicy 6.25 True)
        classifyAverage rule True (Just 6.25) `shouldBe` Approved
        classifyAverage rule True (Just 6.24) `shouldBe` Insufficient
        classifyAverage rule False (Just 9) `shouldBe` InProgress
        classifyAverage rule True Nothing `shouldBe` NoAverage
        performance rule [(True, Just 6.25), (True, Just 6), (False, Just 9), (False, Nothing)]
            `shouldBe` Performance (Just (21.25 / 3)) 3 1 (Just 1) (Just 1) (Just 3)
    it "recusa critérios inválidos e não usa médias inválidas na classificação" $ do
        validPolicy (Just (ApprovalPolicy (0/0) False)) `shouldBe` Nothing
        validPolicy (Just (ApprovalPolicy 11 False)) `shouldBe` Nothing
        classifyAverage Nothing True (Just (-1)) `shouldBe` NoAverage
