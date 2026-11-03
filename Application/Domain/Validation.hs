-- | Validação tipada e acumulativa (Sprint 4: formulários tipados).
--
-- 'Validacao' é um Functor Applicative que acumula todos os erros de um
-- formulário, em vez de parar no primeiro. Ela propositalmente NÃO é uma
-- mônada: a mônada ('Either') interrompe no primeiro erro, e isso é o que
-- se quer em cadeias dependentes (veja "Application.Domain.Erro"); já num
-- formulário o usuário deve ver todos os campos inválidos de uma vez.
--
-- Módulo puro: apenas base e "Application.Domain.Grade".
module Application.Domain.Validation
    ( Validacao (..)
    , emEither
    , Nota
    , valorNota
    , criarNota
    , aparar
    , lerDecimal
    , lerInteiro
    ) where

import Prelude
import Data.Char (isSpace)
import Text.Read (readMaybe)
import Application.Domain.Grade (notaValida, numeroFinito)

-- | Resultado de uma validação: ou todos os erros, ou o valor construído.
data Validacao e a
    = Falha [e]
    | Sucesso a
    deriving (Eq, Show)

instance Functor (Validacao e) where
    fmap _ (Falha erros) = Falha erros
    fmap f (Sucesso valor) = Sucesso (f valor)

instance Applicative (Validacao e) where
    pure = Sucesso
    Falha a <*> Falha b = Falha (a ++ b)
    Falha a <*> Sucesso _ = Falha a
    Sucesso _ <*> Falha b = Falha b
    Sucesso f <*> Sucesso valor = Sucesso (f valor)

-- | Converte para 'Either', para encadear com o restante do código monádico.
emEither :: Validacao e a -> Either [e] a
emEither (Falha erros) = Left erros
emEither (Sucesso valor) = Right valor

-- | Nota válida (finita, entre 0 e 10). O construtor não é exportado: a única
-- forma de obter uma 'Nota' é 'criarNota', logo toda 'Nota' é válida por tipo.
newtype Nota = Nota Double
    deriving (Eq, Ord, Show)

valorNota :: Nota -> Double
valorNota (Nota valor) = valor

criarNota :: Double -> Maybe Nota
criarNota valor
    | notaValida valor = Just (Nota valor)
    | otherwise = Nothing

-- | Remove espaços do início e do fim.
aparar :: String -> String
aparar = reverse . dropWhile isSpace . reverse . dropWhile isSpace

-- | Lê um decimal finito. Aceita vírgula ou ponto ("7,5" e "7.5"); rejeita
-- texto livre, NaN e infinitos.
lerDecimal :: String -> Maybe Double
lerDecimal texto = do
    valor <- readMaybe (map trocarVirgula (aparar texto))
    if numeroFinito valor then Just valor else Nothing
  where
    trocarVirgula c = if c == ',' then '.' else c

-- | Lê um inteiro. Usa 'Integer' para que valores enormes não "deem a volta"
-- silenciosamente, como aconteceria ao ler direto para 'Int'.
lerInteiro :: String -> Maybe Integer
lerInteiro = readMaybe . aparar
