module Application.Domain.Period
    ( validarNomePeriodo
    , validarDatasPeriodo
    , validarOrdemDatas
    , validarAnoInicio
    , periodosSobrepostos
    , periodoContem
    , periodoAtual
    ) where

import Prelude
import Data.Char (isDigit)
import Data.List (find, sortOn)
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Calendar (Day, toGregorian)

-- Períodos letivos semestrais: "AAAA.1" ou "AAAA.2" (ex.: 2026.1).
validarNomePeriodo :: Text -> Either Text Text
validarNomePeriodo bruto = case Text.splitOn (Text.pack ".") nome of
    [ano, semestre]
        | Text.length ano == 4 && Text.all isDigit ano && semestre `elem` [Text.pack "1", Text.pack "2"] -> Right nome
    _ -> Left (Text.pack "Use o formato ano.semestre, por exemplo 2026.1 ou 2026.2.")
    where nome = Text.strip bruto

-- O fim vem depois do início e o período começa no ano do próprio nome.
validarDatasPeriodo :: Text -> Day -> Day -> Either Text ()
validarDatasPeriodo nome inicio fim = validarOrdemDatas inicio fim >> validarAnoInicio nome inicio

validarOrdemDatas :: Day -> Day -> Either Text ()
validarOrdemDatas inicio fim
    | fim <= inicio = Left (Text.pack "A data de término deve ser posterior à data de início.")
    | otherwise = Right ()

-- Só se aplica a nomes válidos; o formato do nome é validado à parte.
validarAnoInicio :: Text -> Day -> Either Text ()
validarAnoInicio nome inicio = case validarNomePeriodo nome of
    Right valido | Text.pack (show ano) /= Text.takeWhile (/= '.') valido ->
        Left (Text.pack "A data de início deve estar no ano do período.")
    _ -> Right ()
    where (ano, _, _) = toGregorian inicio

-- Intervalos fechados [início, fim] que compartilham pelo menos um dia.
periodosSobrepostos :: (Day, Day) -> (Day, Day) -> Bool
periodosSobrepostos (inicioA, fimA) (inicioB, fimB) = inicioA <= fimB && inicioB <= fimA

periodoContem :: Day -> (Day, Day) -> Bool
periodoContem dia (inicio, fim) = inicio <= dia && dia <= fim

-- Período sugerido para novas matrículas: o que contém a data; se nenhum
-- contém, o que começou mais recentemente até a data; senão, nenhum.
periodoAtual :: Day -> [(a, (Day, Day))] -> Maybe a
periodoAtual hoje periodos = fst <$> case find (periodoContem hoje . snd) periodos of
    Just atual -> Just atual
    Nothing -> case sortOn (Down . fst . snd) (filter ((<= hoje) . fst . snd) periodos) of
        (recente : _) -> Just recente
        [] -> Nothing
