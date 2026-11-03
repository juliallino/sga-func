-- | Modelo de erros da aplicação (Sprint 5: tratamento de erros monádico).
--
-- Módulo puro: importa apenas a biblioteca base, sem IHP, banco ou IO.
-- 'Resultado' é uma mônada ('Either' 'ErroApp'): o primeiro erro interrompe
-- a cadeia de operações e chega intacto até a camada HTTP, que o traduz em
-- status e mensagem por meio de 'statusHttp' e 'mensagemUsuario'.
module Application.Domain.Erro
    ( ErroCampo (..)
    , ErroApp (..)
    , Resultado
    , exigir
    , camposInvalidos
    , classificarErroSql
    , mensagemUsuario
    , statusHttp
    , recuperavel
    ) where

import Prelude
import Data.Char (isAlphaNum)
import Data.List (intercalate)

-- | Erro associado a um campo de formulário ou parâmetro de consulta.
data ErroCampo = ErroCampo
    { erroCampo :: String
    , erroMensagem :: String
    } deriving (Eq, Show)

-- | Todas as falhas esperadas da aplicação, como um tipo algébrico fechado.
data ErroApp
    = ErroValidacao [ErroCampo]
    | ErroNaoEncontrado String
    | ErroNaoAutorizado
    | ErroConflito          -- ^ violação de unicidade (SQLSTATE 23505)
    | ErroDependencia       -- ^ violação de chave estrangeira (23503)
    | ErroRestricao         -- ^ violação de CHECK, NOT NULL ou faixa numérica
    | ErroIndisponivel      -- ^ falha transitória: pode valer a pena repetir
    deriving (Eq, Show)

-- | Resultado de uma operação que pode falhar com 'ErroApp'.
type Resultado = Either ErroApp

-- | Guarda monádica: continua a cadeia se a condição vale, falha caso contrário.
exigir :: ErroApp -> Bool -> Resultado ()
exigir erro condicao = if condicao then Right () else Left erro

-- | Erros de campo contidos em um erro de validação (vazio nos demais casos).
camposInvalidos :: ErroApp -> [ErroCampo]
camposInvalidos (ErroValidacao erros) = erros
camposInvalidos _ = []

-- | Traduz o texto de uma exceção do banco em um 'ErroApp', quando reconhece
-- o SQLSTATE. Devolve 'Nothing' para qualquer outra exceção, que deve seguir
-- propagando-se (falhas de programação e exceções assíncronas não são
-- "recuperáveis").
--
-- O reconhecimento é feito por palavra inteira: o código precisa aparecer como
-- um token isolado, o que evita confundi-lo com trechos de UUIDs ou nomes.
-- Os testes de integração confirmam o formato real do erro do IHP/hasql.
classificarErroSql :: String -> Maybe ErroApp
classificarErroSql texto =
    case [erro | (codigo, erro) <- tabelaSqlState, codigo `elem` fichas] of
        erro : _ -> Just erro
        [] -> Nothing
  where
    fichas = words (map (\c -> if isAlphaNum c then c else ' ') texto)

tabelaSqlState :: [(String, ErroApp)]
tabelaSqlState =
    [ ("23505", ErroConflito)
    , ("23503", ErroDependencia)
    , ("23514", ErroRestricao)
    , ("23502", ErroRestricao)
    , ("22003", ErroRestricao)
    , ("40001", ErroIndisponivel)
    , ("40P01", ErroIndisponivel)
    , ("57P01", ErroIndisponivel)
    , ("53300", ErroIndisponivel)
    , ("08006", ErroIndisponivel)
    , ("08003", ErroIndisponivel)
    , ("08001", ErroIndisponivel)
    ]

-- | Mensagem em português, segura para exibir ao usuário final.
mensagemUsuario :: ErroApp -> String
mensagemUsuario (ErroValidacao erros) =
    "Dados inválidos: " ++ intercalate "; " [campo ++ ": " ++ mensagem | ErroCampo campo mensagem <- erros]
mensagemUsuario (ErroNaoEncontrado recurso) = "Registro não encontrado: " ++ recurso ++ "."
mensagemUsuario ErroNaoAutorizado = "Acesso não autorizado."
mensagemUsuario ErroConflito = "Já existe um registro com esses dados."
mensagemUsuario ErroDependencia = "A operação conflita com registros vinculados."
mensagemUsuario ErroRestricao = "Os dados violam uma regra de integridade do banco."
mensagemUsuario ErroIndisponivel = "Serviço temporariamente indisponível. Tente novamente em instantes."

-- | Status HTTP correspondente a cada falha.
statusHttp :: ErroApp -> Int
statusHttp (ErroValidacao _) = 422
statusHttp (ErroNaoEncontrado _) = 404
statusHttp ErroNaoAutorizado = 403
statusHttp ErroConflito = 409
statusHttp ErroDependencia = 409
statusHttp ErroRestricao = 422
statusHttp ErroIndisponivel = 503

-- | Somente falhas transitórias justificam uma nova tentativa.
recuperavel :: ErroApp -> Bool
recuperavel ErroIndisponivel = True
recuperavel _ = False
