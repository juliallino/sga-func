module Application.Domain.Attendance
    ( frequenciaMinimaPercentual
    , ResumoFrequencia (..)
    , resumirFrequencia
    , faltas
    , frequencia
    , frequenciaSuficiente
    , SituacaoFrequencia (..)
    , classificarFrequencia
    , textoFrequencia
    ) where

import Prelude
import qualified Data.Text as Text
import Data.Text (Text)

-- Requisito acadêmico: presença mínima de 75 % das aulas registradas.
frequenciaMinimaPercentual :: Int
frequenciaMinimaPercentual = 75

-- Contagem de uma matrícula: presenças e aulas (chamadas) registradas.
data ResumoFrequencia = ResumoFrequencia
    { presencas :: Int
    , aulas :: Int
    } deriving (Eq, Show)

-- Cada registro de chamada é True (presente) ou False (falta).
resumirFrequencia :: [Bool] -> ResumoFrequencia
resumirFrequencia registros = ResumoFrequencia (length (filter id registros)) (length registros)

faltas :: ResumoFrequencia -> Int
faltas resumo = aulas resumo - presencas resumo

-- Sem aulas registradas não há frequência: ausência de dados não vira 0 %.
frequencia :: ResumoFrequencia -> Maybe Double
frequencia resumo
    | not (resumoValido resumo) || aulas resumo == 0 = Nothing
    | otherwise = Just (100 * fromIntegral (presencas resumo) / fromIntegral (aulas resumo))

-- Comparação inteira (100·p ≥ 75·a): evita arredondamento de ponto flutuante
-- no limite exato, por exemplo 3 presenças em 4 aulas.
frequenciaSuficiente :: ResumoFrequencia -> Bool
frequenciaSuficiente resumo =
    resumoValido resumo && 100 * presencas resumo >= frequenciaMinimaPercentual * aulas resumo

data SituacaoFrequencia = SemAulasRegistradas | FrequenciaRegular | FrequenciaAbaixoDoMinimo
    deriving (Eq, Show)

classificarFrequencia :: ResumoFrequencia -> SituacaoFrequencia
classificarFrequencia resumo
    | not (resumoValido resumo) || aulas resumo == 0 = SemAulasRegistradas
    | frequenciaSuficiente resumo = FrequenciaRegular
    | otherwise = FrequenciaAbaixoDoMinimo

-- Ex.: "75.0 % (3 de 4 aulas)". Mesmo separador decimal das médias do portal.
textoFrequencia :: ResumoFrequencia -> Text
textoFrequencia resumo = case frequencia resumo of
    Nothing -> Text.pack "Sem chamadas registradas"
    Just valor -> Text.pack (umaCasa valor ++ " % (" ++ show (presencas resumo) ++ " de " ++ show (aulas resumo) ++ " aulas)")
    where
        umaCasa valor =
            let decimos = round (valor * 10) :: Int
            in show (decimos `div` 10) ++ "." ++ show (decimos `mod` 10)

resumoValido :: ResumoFrequencia -> Bool
resumoValido resumo = presencas resumo >= 0 && aulas resumo >= 0 && presencas resumo <= aulas resumo
