-- | Relatórios e dashboard (Sprint 4: agregações, ranking e filtros).
--
-- Núcleo puro: recebe uma lista imutável de 'LinhaDesempenho' (já carregada
-- pela camada de controle) e devolve um 'Relatorio'. Não há IO nem estado
-- mutável: tudo é composição de filter, map, sortBy e dobras (foldl').
-- Não define regra de aprovação; as faixas de média são apenas descritivas.
module Application.Domain.Report
    ( StatusMatricula (..)
    , LinhaDesempenho (..)
    , ParamsFiltro (..)
    , FiltroRelatorio (..)
    , ResumoGeral (..)
    , ResumoCurso (..)
    , PosicaoRanking (..)
    , FaixaNota (..)
    , Relatorio (..)
    , paramsVazios
    , filtroVazio
    , limiteRankingPadrao
    , limiteRankingMaximo
    , validarFiltro
    , resolverFiltro
    , prepararConsulta
    , arredondar2
    , mediaMatricula
    , mediaArredondada
    , aplicarFiltro
    , resumoGeral
    , resumosPorCurso
    , ranking
    , distribuicao
    , gerarRelatorio
    ) where

import Prelude
import Data.Char (isHexDigit, toLower)
import Data.List (foldl', isInfixOf, sortBy)
import Data.Maybe (catMaybes, fromMaybe)
import qualified Data.Map.Strict as Map
import Application.Domain.Erro (ErroApp (..), ErroCampo (..), Resultado)
import Application.Domain.Grade (mediaPonderada)
import Application.Domain.Validation

-- ---------------------------------------------------------------------------
-- Tipos

data StatusMatricula
    = MatriculaAtiva
    | MatriculaSuspensa
    | MatriculaConcluida
    deriving (Eq, Show, Enum, Bounded)

-- | Uma matrícula com suas avaliações como pares (nota, peso).
data LinhaDesempenho = LinhaDesempenho
    { ldMatricula :: String
    , ldAlunoId :: String
    , ldAluno :: String
    , ldCursoId :: String
    , ldCurso :: String
    , ldStatus :: StatusMatricula
    , ldAvaliacoes :: [(Double, Double)]
    } deriving (Eq, Show)

-- | Parâmetros brutos, como chegam da requisição (texto, possivelmente ausente).
data ParamsFiltro = ParamsFiltro
    { pfCurso :: Maybe String
    , pfStatus :: Maybe String
    , pfMediaMinima :: Maybe String
    , pfBusca :: Maybe String
    , pfLimite :: Maybe String
    } deriving (Eq, Show)

-- | Filtro já validado e tipado.
data FiltroRelatorio = FiltroRelatorio
    { filtroCurso :: Maybe String
    , filtroStatus :: Maybe StatusMatricula
    , filtroMediaMinima :: Maybe Nota
    , filtroBusca :: Maybe String
    , filtroLimite :: Int
    } deriving (Eq, Show)

data ResumoGeral = ResumoGeral
    { rgMatriculas :: Int
    , rgComMedia :: Int
    , rgSemMedia :: Int
    , rgMediaGeral :: Maybe Double
    , rgMaiorMedia :: Maybe Double
    , rgMenorMedia :: Maybe Double
    } deriving (Eq, Show)

data ResumoCurso = ResumoCurso
    { rcCursoId :: String
    , rcCurso :: String
    , rcMatriculas :: Int
    , rcMediaCurso :: Maybe Double
    , rcMelhorMedia :: Maybe Double
    } deriving (Eq, Show)

data PosicaoRanking = PosicaoRanking
    { prPosicao :: Int
    , prMatricula :: String
    , prAluno :: String
    , prCurso :: String
    , prMedia :: Double
    } deriving (Eq, Show)

data FaixaNota = FaixaNota
    { fnRotulo :: String
    , fnMinimo :: Double
    , fnMaximo :: Double
    , fnQuantidade :: Int
    } deriving (Eq, Show)

data Relatorio = Relatorio
    { relResumo :: ResumoGeral
    , relPorCurso :: [ResumoCurso]
    , relRanking :: [PosicaoRanking]
    , relDistribuicao :: [FaixaNota]
    } deriving (Eq, Show)

limiteRankingPadrao :: Int
limiteRankingPadrao = 10

limiteRankingMaximo :: Int
limiteRankingMaximo = 100

limiteBusca :: Int
limiteBusca = 100

paramsVazios :: ParamsFiltro
paramsVazios = ParamsFiltro Nothing Nothing Nothing Nothing Nothing

filtroVazio :: FiltroRelatorio
filtroVazio = FiltroRelatorio Nothing Nothing Nothing Nothing limiteRankingPadrao

-- ---------------------------------------------------------------------------
-- Validação dos filtros (formulário tipado, validação no servidor)

-- | Valida todos os parâmetros e acumula todos os erros encontrados.
-- Parâmetros ausentes ou em branco significam "sem filtro".
validarFiltro :: ParamsFiltro -> Validacao ErroCampo FiltroRelatorio
validarFiltro params = FiltroRelatorio
    <$> opcional "courseId" lerCurso (pfCurso params)
    <*> opcional "status" lerStatus (pfStatus params)
    <*> opcional "minAverage" lerMediaMinima (pfMediaMinima params)
    <*> opcional "q" lerBusca (pfBusca params)
    <*> fmap (fromMaybe limiteRankingPadrao) (opcional "top" lerLimite (pfLimite params))

-- | Para páginas HTML: em caso de erro, mostra os erros e usa o filtro vazio.
resolverFiltro :: ParamsFiltro -> (FiltroRelatorio, [ErroCampo])
resolverFiltro params = case validarFiltro params of
    Sucesso filtro -> (filtro, [])
    Falha erros -> (filtroVazio, erros)

-- | Para a API JSON: em caso de erro, falha na mônada 'Resultado'.
prepararConsulta :: ParamsFiltro -> Resultado FiltroRelatorio
prepararConsulta params = case validarFiltro params of
    Sucesso filtro -> Right filtro
    Falha erros -> Left (ErroValidacao erros)

opcional :: String -> (String -> Either String a) -> Maybe String -> Validacao ErroCampo (Maybe a)
opcional campo leitor valor = case fmap aparar valor of
    Nothing -> Sucesso Nothing
    Just "" -> Sucesso Nothing
    Just texto -> case leitor texto of
        Left mensagem -> Falha [ErroCampo campo mensagem]
        Right resultado -> Sucesso (Just resultado)

lerCurso :: String -> Either String String
lerCurso texto
    | ehUuid texto = Right (map toLower texto)
    | otherwise = Left "Selecione um curso válido."

ehUuid :: String -> Bool
ehUuid texto = length texto == 36 && and (zipWith confere [0 :: Int ..] texto)
  where
    confere indice c
        | indice `elem` [8, 13, 18, 23] = c == '-'
        | otherwise = isHexDigit c

lerStatus :: String -> Either String StatusMatricula
lerStatus texto = case map toLower texto of
    "active" -> Right MatriculaAtiva
    "suspended" -> Right MatriculaSuspensa
    "completed" -> Right MatriculaConcluida
    _ -> Left "Situação inválida: use active, suspended ou completed."

lerMediaMinima :: String -> Either String Nota
lerMediaMinima texto = case lerDecimal texto >>= criarNota of
    Just nota -> Right nota
    Nothing -> Left "A média mínima deve ser um número entre 0 e 10."

lerBusca :: String -> Either String String
lerBusca texto
    | length texto <= limiteBusca = Right texto
    | otherwise = Left ("A busca deve ter no máximo " ++ show limiteBusca ++ " caracteres.")

lerLimite :: String -> Either String Int
lerLimite texto = case lerInteiro texto of
    Just n | n >= 1 && n <= toInteger limiteRankingMaximo -> Right (fromInteger n)
    _ -> Left ("O limite deve ser um inteiro entre 1 e " ++ show limiteRankingMaximo ++ ".")

-- ---------------------------------------------------------------------------
-- Médias

-- | Arredonda para duas casas (meio para cima), como a média é exibida.
-- Ranking, filtros e agregações usam o valor arredondado para que o que o
-- usuário vê seja exatamente o que foi comparado.
arredondar2 :: Double -> Double
arredondar2 valor = fromIntegral (floor (valor * 100 + 0.5) :: Integer) / 100

-- | Média ponderada da matrícula; 'Nothing' sem avaliações ou com dados inválidos.
mediaMatricula :: LinhaDesempenho -> Maybe Double
mediaMatricula = mediaPonderada . ldAvaliacoes

mediaArredondada :: LinhaDesempenho -> Maybe Double
mediaArredondada = fmap arredondar2 . mediaMatricula

mediasDe :: [LinhaDesempenho] -> [Double]
mediasDe = catMaybes . map mediaArredondada

mediaSimples :: [Double] -> Maybe Double
mediaSimples [] = Nothing
mediaSimples valores = Just (sum valores / fromIntegral (length valores))

extremo :: ([Double] -> Double) -> [Double] -> Maybe Double
extremo _ [] = Nothing
extremo escolher valores = Just (escolher valores)

-- ---------------------------------------------------------------------------
-- Filtros

-- | Aplica, em conjunção, apenas os filtros informados.
aplicarFiltro :: FiltroRelatorio -> [LinhaDesempenho] -> [LinhaDesempenho]
aplicarFiltro filtro = filter (\linha -> all ($ linha) (predicados filtro))

predicados :: FiltroRelatorio -> [LinhaDesempenho -> Bool]
predicados filtro = catMaybes
    [ fmap (\curso linha -> ldCursoId linha == curso) (filtroCurso filtro)
    , fmap (\status linha -> ldStatus linha == status) (filtroStatus filtro)
    , fmap (\minima linha -> maybe False (>= valorNota minima) (mediaArredondada linha)) (filtroMediaMinima filtro)
    , fmap (\busca linha -> contemTexto busca (ldAluno linha) || contemTexto busca (ldCurso linha)) (filtroBusca filtro)
    ]

contemTexto :: String -> String -> Bool
contemTexto busca campo = map toLower busca `isInfixOf` map toLower campo

-- ---------------------------------------------------------------------------
-- Agregações

resumoGeral :: [LinhaDesempenho] -> ResumoGeral
resumoGeral linhas = ResumoGeral
    { rgMatriculas = length linhas
    , rgComMedia = length medias
    , rgSemMedia = length linhas - length medias
    , rgMediaGeral = fmap arredondar2 (mediaSimples medias)
    , rgMaiorMedia = extremo maximum medias
    , rgMenorMedia = extremo minimum medias
    }
  where
    medias = mediasDe linhas

-- | Agrupa preservando a ordem original dentro de cada grupo; os grupos saem
-- em ordem crescente da chave.
agruparPor :: Ord k => (a -> k) -> [a] -> [(k, [a])]
agruparPor chave itens =
    map (fmap reverse) (Map.toList (Map.fromListWith (++) [(chave item, [item]) | item <- itens]))

-- | Resumo por curso, em ordem alfabética do nome do curso.
resumosPorCurso :: [LinhaDesempenho] -> [ResumoCurso]
resumosPorCurso linhas =
    [ resumirCurso cursoId nome grupo
    | ((nome, cursoId), grupo) <- agruparPor (\linha -> (ldCurso linha, ldCursoId linha)) linhas
    ]

resumirCurso :: String -> String -> [LinhaDesempenho] -> ResumoCurso
resumirCurso cursoId nome grupo = ResumoCurso
    { rcCursoId = cursoId
    , rcCurso = nome
    , rcMatriculas = length grupo
    , rcMediaCurso = fmap arredondar2 (mediaSimples medias)
    , rcMelhorMedia = extremo maximum medias
    }
  where
    medias = mediasDe grupo

-- | Ranking por média decrescente (desempate por nome do aluno e do curso).
-- Empates dividem a mesma posição e a seguinte "pula": 1, 1, 3, 4.
-- Matrículas sem média válida não entram no ranking.
ranking :: [LinhaDesempenho] -> [PosicaoRanking]
ranking linhas = posicionar (sortBy ordem candidatos)
  where
    candidatos = [(linha, media) | linha <- linhas, Just media <- [mediaArredondada linha]]
    ordem (a, mediaA) (b, mediaB) =
        compare mediaB mediaA
            <> compare (ldAluno a) (ldAluno b)
            <> compare (ldCurso a) (ldCurso b)

posicionar :: [(LinhaDesempenho, Double)] -> [PosicaoRanking]
posicionar itens = reverse (snd (foldl' passo (0 :: Int, []) itens))
  where
    passo (indice, acumulado) (linha, media) =
        let proximo = indice + 1
            posicao = case acumulado of
                (anterior : _) | prMedia anterior == media -> prPosicao anterior
                _ -> proximo
            entrada = PosicaoRanking posicao (ldMatricula linha) (ldAluno linha) (ldCurso linha) media
        in (proximo, entrada : acumulado)

faixasPadrao :: [(String, Double, Double)]
faixasPadrao =
    [ ("0 a 2", 0, 2)
    , ("2 a 4", 2, 4)
    , ("4 a 6", 4, 6)
    , ("6 a 8", 6, 8)
    , ("8 a 10", 8, 10)
    ]

-- | Distribuição das médias em faixas; a última faixa inclui o 10.
distribuicao :: [LinhaDesempenho] -> [FaixaNota]
distribuicao linhas =
    [ FaixaNota rotulo minimo maximo (length (filter (pertence minimo maximo) medias))
    | (rotulo, minimo, maximo) <- faixasPadrao
    ]
  where
    medias = mediasDe linhas

pertence :: Double -> Double -> Double -> Bool
pertence minimo maximo media = media >= minimo && (media < maximo || (maximo >= 10 && media <= maximo))

-- | Relatório completo: aplica o filtro e agrega o resultado.
gerarRelatorio :: FiltroRelatorio -> [LinhaDesempenho] -> Relatorio
gerarRelatorio filtro linhas = Relatorio
    { relResumo = resumoGeral filtradas
    , relPorCurso = resumosPorCurso filtradas
    , relRanking = take (filtroLimite filtro) (ranking filtradas)
    , relDistribuicao = distribuicao filtradas
    }
  where
    filtradas = aplicarFiltro filtro linhas
