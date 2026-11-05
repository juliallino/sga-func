module Test.Domain.AcademicSpec (spec) where
import Prelude
import Test.Hspec
import Application.Domain.Academic
spec :: Spec
spec = describe "Média geral completa" $ do
    it "não usa nota zero para ausência" $
        mediaGeralCompleta 2 [Just 8, Nothing] `shouldBe` Nothing
    it "exige todas as disciplinas" $
        mediaGeralCompleta 5 [Just 8,Just 9] `shouldBe` Nothing
    it "calcula média simples das médias ponderadas disponíveis" $
        mediaGeralCompleta 2 [Just 8,Just 9] `shouldBe` Just 8.5
    it "rejeita lista vazia e valores não finitos" $ do
        mediaGeralCompleta 0 [] `shouldBe` Nothing
        mediaGeralCompleta 1 [Just (0/0)] `shouldBe` Nothing
