module Test.Domain.ErroSpec (spec) where

import Prelude
import Test.Hspec
import Application.Domain.Erro

spec :: Spec
spec = do
    describe "Classificação de erros SQL por SQLSTATE" $ do
        it "reconhece violação de unicidade" $
            classificarErroSql "SqlError {code = \"23505\", detail = duplicate key}"
                `shouldBe` Just ErroConflito
        it "reconhece violação de chave estrangeira" $
            classificarErroSql "ERROR: 23503 foreign key violation"
                `shouldBe` Just ErroDependencia
        it "reconhece violações de CHECK e NOT NULL" $
            map classificarErroSql ["code 23514", "code 23502"]
                `shouldBe` [Just ErroRestricao, Just ErroRestricao]
        it "reconhece falhas transitórias (deadlock, serialização, conexão)" $
            map classificarErroSql ["code 40P01", "code 40001", "code 08006"]
                `shouldBe` replicate 3 (Just ErroIndisponivel)
        it "não confunde o código com trechos de UUID ou de outros valores" $
            map classificarErroSql
                [ "id = 9f1a23503b-0000"
                , "id = 00000000-0000-0000-0000-000000023503"
                ]
                `shouldBe` [Nothing, Nothing]
        it "devolve Nothing para exceções desconhecidas" $
            classificarErroSql "connection reset by peer" `shouldBe` Nothing
    describe "Status HTTP e mensagens" $ do
        it "mapeia cada erro para um status" $
            map statusHttp
                [ ErroValidacao []
                , ErroNaoEncontrado "Matrícula"
                , ErroNaoAutorizado
                , ErroConflito
                , ErroDependencia
                , ErroRestricao
                , ErroIndisponivel
                ]
                `shouldBe` [422, 404, 403, 409, 409, 422, 503]
        it "lista os campos inválidos na mensagem de validação" $
            mensagemUsuario (ErroValidacao [ErroCampo "top" "inválido", ErroCampo "q" "longo"])
                `shouldBe` "Dados inválidos: top: inválido; q: longo"
        it "expõe os campos apenas em erros de validação" $ do
            camposInvalidos (ErroValidacao [ErroCampo "top" "inválido"])
                `shouldBe` [ErroCampo "top" "inválido"]
            camposInvalidos ErroConflito `shouldBe` []
        it "considera recuperável somente a falha transitória" $
            map recuperavel [ErroIndisponivel, ErroConflito, ErroDependencia, ErroNaoAutorizado]
                `shouldBe` [True, False, False, False]
    describe "Resultado como mônada" $ do
        it "interrompe a cadeia no primeiro erro" $ do
            let cadeia = do
                    exigir ErroNaoAutorizado True
                    exigir ErroConflito False
                    exigir ErroRestricao False
            cadeia `shouldBe` Left ErroConflito
        it "segue até o fim quando todas as condições valem" $ do
            let cadeia = do
                    exigir ErroNaoAutorizado True
                    exigir ErroConflito True
            cadeia `shouldBe` Right ()
