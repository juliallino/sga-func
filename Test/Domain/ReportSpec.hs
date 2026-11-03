module Test.Domain.ReportSpec (spec) where

import Prelude
import Test.Hspec
import Application.Domain.Erro
import Application.Domain.Report
import Application.Domain.Validation

cursoCalculo, cursoFisica :: String
cursoCalculo = "11111111-1111-1111-1111-111111111111"
cursoFisica = "22222222-2222-2222-2222-222222222222"

calculo, fisica :: (String, String)
calculo = (cursoCalculo, "Cálculo")
fisica = (cursoFisica, "Física")

linha :: String -> String -> (String, String) -> StatusMatricula -> [(Double, Double)] -> LinhaDesempenho
linha matricula aluno (cursoId, curso) = LinhaDesempenho matricula ("aluno-" ++ matricula) aluno cursoId curso

-- Médias: Ana 6.5 | Bruno 10 | Carla 8.625 (8.63) | Diego sem avaliações | Eva 10
ana, bruno, carla, diego, eva :: LinhaDesempenho
ana = linha "m1" "Ana" calculo MatriculaAtiva [(8, 1), (6, 3)]
bruno = linha "m2" "Bruno" calculo MatriculaAtiva [(10, 1)]
carla = linha "m3" "Carla" fisica MatriculaConcluida [(7.5, 1), (9, 3)]
diego = linha "m4" "Diego" fisica MatriculaSuspensa []
eva = linha "m5" "Eva" calculo MatriculaAtiva [(10, 2)]

todas :: [LinhaDesempenho]
todas = [ana, bruno, carla, diego, eva]

camposComErro :: Validacao ErroCampo a -> [String]
camposComErro = either (map erroCampo) (const []) . emEither

spec :: Spec
spec = do
    describe "Médias" $ do
        it "usa a média ponderada e a exibe com duas casas" $ do
            mediaMatricula carla `shouldBe` Just 8.625
            mediaArredondada carla `shouldBe` Just 8.63
            mediaArredondada ana `shouldBe` Just 6.5
        it "não tem média sem avaliações" $
            mediaArredondada diego `shouldBe` Nothing
        it "arredonda meio para cima" $ do
            arredondar2 8.625 `shouldBe` 8.63
            arredondar2 1.234 `shouldBe` 1.23
    describe "Resumo geral" $ do
        it "conta matrículas com e sem média e agrega a média simples" $
            resumoGeral todas `shouldBe` ResumoGeral 5 4 1 (Just 8.78) (Just 10) (Just 6.5)
        it "é vazio sem dados" $
            resumoGeral [] `shouldBe` ResumoGeral 0 0 0 Nothing Nothing Nothing
    describe "Resumo por curso" $ do
        it "agrega por curso, em ordem alfabética" $
            resumosPorCurso todas
                `shouldBe`
                    [ ResumoCurso cursoCalculo "Cálculo" 3 (Just 8.83) (Just 10)
                    , ResumoCurso cursoFisica "Física" 2 (Just 8.63) (Just 8.63)
                    ]
    describe "Ranking" $ do
        it "ordena por média; empates dividem a posição e a seguinte pula" $
            map (\p -> (prPosicao p, prAluno p)) (ranking todas)
                `shouldBe` [(1, "Bruno"), (1, "Eva"), (3, "Carla"), (4, "Ana")]
        it "não inclui matrículas sem média" $
            map prAluno (ranking todas) `shouldNotContain` ["Diego"]
        it "é vazio sem dados" $
            ranking [] `shouldBe` []
    describe "Distribuição" $ do
        it "distribui as médias em faixas; o 10 fica na última" $
            map fnQuantidade (distribuicao todas) `shouldBe` [0, 0, 0, 1, 3]
        it "coloca o limite inferior exato na faixa seguinte" $
            map fnQuantidade (distribuicao [linha "x" "Zé" calculo MatriculaAtiva [(2, 1)]])
                `shouldBe` [0, 1, 0, 0, 0]
    describe "Filtros" $ do
        it "sem filtro, mantém tudo" $
            aplicarFiltro filtroVazio todas `shouldBe` todas
        it "filtra por curso" $
            aplicarFiltro filtroVazio { filtroCurso = Just cursoCalculo } todas
                `shouldBe` [ana, bruno, eva]
        it "filtra por situação" $
            aplicarFiltro filtroVazio { filtroStatus = Just MatriculaConcluida } todas
                `shouldBe` [carla]
        it "filtra por média mínima e exclui matrículas sem média" $ do
            aplicarFiltro filtroVazio { filtroMediaMinima = criarNota 9 } todas
                `shouldBe` [bruno, eva]
            aplicarFiltro filtroVazio { filtroMediaMinima = criarNota 0 } todas
                `shouldBe` [ana, bruno, carla, eva]
        it "busca por aluno ou curso sem diferenciar maiúsculas" $ do
            aplicarFiltro filtroVazio { filtroBusca = Just "ANA" } todas `shouldBe` [ana]
            aplicarFiltro filtroVazio { filtroBusca = Just "FÍSI" } todas `shouldBe` [carla, diego]
        it "combina filtros em conjunção" $
            aplicarFiltro filtroVazio { filtroCurso = Just cursoCalculo, filtroMediaMinima = criarNota 10 } todas
                `shouldBe` [bruno, eva]
    describe "Relatório completo" $ do
        it "limita só o ranking; o resumo considera todas as linhas filtradas" $ do
            let relatorio = gerarRelatorio filtroVazio { filtroLimite = 2 } todas
            length (relRanking relatorio) `shouldBe` 2
            rgMatriculas (relResumo relatorio) `shouldBe` 5
        it "aplica o filtro antes de agregar" $ do
            let relatorio = gerarRelatorio filtroVazio { filtroCurso = Just cursoFisica } todas
            map rcCurso (relPorCurso relatorio) `shouldBe` ["Física"]
            rgMatriculas (relResumo relatorio) `shouldBe` 2
    describe "Validação dos parâmetros do filtro" $ do
        it "sem parâmetros, usa o filtro vazio" $
            validarFiltro paramsVazios `shouldBe` Sucesso filtroVazio
        it "trata valores em branco como ausentes" $
            validarFiltro paramsVazios { pfCurso = Just "  ", pfStatus = Just "", pfLimite = Just " " }
                `shouldBe` Sucesso filtroVazio
        it "converte parâmetros válidos para tipos" $
            validarFiltro paramsVazios
                { pfCurso = Just "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
                , pfStatus = Just "ACTIVE"
                , pfMediaMinima = Just "7,5"
                , pfBusca = Just " ana "
                , pfLimite = Just "5"
                }
                `shouldBe` Sucesso
                    (FiltroRelatorio (Just "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") (Just MatriculaAtiva) (criarNota 7.5) (Just "ana") 5)
        it "acumula todos os erros, na ordem dos campos" $
            camposComErro (validarFiltro paramsVazios
                { pfCurso = Just "abc"
                , pfStatus = Just "zzz"
                , pfMediaMinima = Just "11"
                , pfLimite = Just "0"
                })
                `shouldBe` ["courseId", "status", "minAverage", "top"]
        it "rejeita limite e média nos extremos inválidos, aceita os válidos" $ do
            map (\t -> camposComErro (validarFiltro paramsVazios { pfLimite = Just t })) ["100", "101", "5.5", "abc"]
                `shouldBe` [[], ["top"], ["top"], ["top"]]
            map (\t -> camposComErro (validarFiltro paramsVazios { pfMediaMinima = Just t })) ["0", "10", "-1", "abc"]
                `shouldBe` [[], [], ["minAverage"], ["minAverage"]]
        it "rejeita busca acima de 100 caracteres" $
            camposComErro (validarFiltro paramsVazios { pfBusca = Just (replicate 101 'a') })
                `shouldBe` ["q"]
        it "resolverFiltro mostra os erros e cai no filtro vazio" $ do
            let (filtro, erros) = resolverFiltro paramsVazios { pfStatus = Just "zzz" }
            filtro `shouldBe` filtroVazio
            map erroCampo erros `shouldBe` ["status"]
        it "prepararConsulta falha na mônada Resultado com erro de validação" $
            prepararConsulta paramsVazios { pfLimite = Just "0" }
                `shouldBe` Left (ErroValidacao [ErroCampo "top" "O limite deve ser um inteiro entre 1 e 100."])
        it "prepararConsulta devolve o filtro quando tudo é válido" $
            prepararConsulta paramsVazios `shouldBe` Right filtroVazio
