module Application.Domain.Grade where
import Prelude
-- Calcula a média ponderada a partir de pares (nota, peso).
mediaPonderada :: [(Double, Double)] -> Maybe Double
mediaPonderada [] = Nothing
mediaPonderada notas
    | any (\(nota, peso) -> not (notaValida nota && pesoValido peso)) notas = Nothing
    | pesoTotal == 0 = Nothing
    | not (numeroFinito somaPonderada && numeroFinito pesoTotal) = Nothing
    | otherwise = Just (somaPonderada / pesoTotal)
    where
        somaPonderada = sum [nota * peso | (nota, peso) <- notas]
        pesoTotal = sum [peso | (_, peso) <- notas]

-- Verifica se uma nota está entre 0 e 10.
notaValida :: Double -> Bool
notaValida nota = numeroFinito nota && nota >= 0 && nota <= 10

-- Verifica se um peso é positivo.
pesoValido :: Double -> Bool
pesoValido peso = numeroFinito peso && peso > 0

-- Double também representa NaN e infinitos, que não são valores acadêmicos.
numeroFinito :: Double -> Bool
numeroFinito valor = not (isNaN valor || isInfinite valor)


-- Cria uma função de média com pesos fixos.
criarCalculadoraMedia :: [(Double, Double)] -> ([(Double, Double)] -> Maybe Double)
criarCalculadoraMedia pesosFixos = \notas ->
    if length notas /= length pesosFixos
        then Nothing
        else mediaPonderada (zipWith combinar notas pesosFixos)
    where
        combinar (nota, _) (_, pesoFixo) = (nota, pesoFixo)


-- Filtra notas que atingem a média mínima.
filtrarNotasAprovadas :: Double -> [Double] -> [Double]
filtrarNotasAprovadas mediaMinima notas =
    filter (>= mediaMinima) notas


-- Aplica um bônus às notas sem ultrapassar o limite de 10.
aplicarBonus :: Double -> [Double] -> [Double]
aplicarBonus bonus notas =
    map (min 10 . (+ bonus)) notas


-- Soma todas as notas de uma lista.
somarNotas :: [Double] -> Double
somarNotas notas =
    foldl (+) 0 notas

-- Gera duas informações para cada nota: a nota original e a nota dobrada.
duplicarInformacoesNotas :: [Double] -> [Double]
duplicarInformacoesNotas notas =
    concatMap (\nota -> [nota, nota * 2]) notas

-- Converte uma nota e um peso para Double.
converterNotaPeso :: (Real a, Real b) => a -> b -> (Double, Double)
converterNotaPeso nota peso = (realToFrac nota, realToFrac peso)

-- Calcula a média ponderada a partir de notas e pesos numéricos.
calcularMediaNotas :: (Real a, Real b) => [(a, b)] -> Maybe Double
calcularMediaNotas notas =
    mediaPonderada (map (uncurry converterNotaPeso) notas)

-- Calcula a média ponderada das avaliações de uma matrícula.
mediaDaMatricula :: [(Double, Double)] -> Maybe Double
mediaDaMatricula = calcularMediaNotas

