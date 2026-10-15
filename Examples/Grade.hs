-- No ambiente de desenvolvimento: runghc -i. Examples/Grade.hs
-- Somente a apresentação faz IO; as funções de domínio permanecem puras.
module Examples.Grade where

import Prelude
import Application.Domain.Grade

main :: IO ()
main = do
    putStrLn "Média ponderada: Just 6.5"
    print (mediaPonderada [(8, 1), (6, 3)])
    putStrLn "Pattern matching em Maybe: Média: 6.5"
    case mediaPonderada [(8, 1), (6, 3)] of
        Nothing -> putStrLn "Sem média válida"
        Just media -> putStrLn ("Média: " ++ show media)
    putStrLn "Closure com pesos 1 e 3: Just 6.5"
    let calcular = criarCalculadoraMedia [(0, 1), (0, 3)]
    print (calcular [(8, 99), (6, 99)])
    putStrLn "Currying e filter: [7.0,9.0]"
    let aprovadas = filtrarNotasAprovadas 7
    print (aprovadas [5, 7, 9])
    putStrLn "map: [7.0,10.0,10.0]"
    print (aplicarBonus 2 [5, 9, 10])
    putStrLn "foldl: 21.0"
    print (somarNotas [5, 7, 9])
    putStrLn "concatMap: [3.0,6.0,5.0,10.0]"
    print (duplicarInformacoesNotas [3, 5])
    putStrLn "List comprehension (nota * peso): [8.0,18.0]"
    print [nota * peso | (nota, peso) <- [(8, 1), (6, 3)] :: [(Double, Double)]]
    putStrLn "Validações (nota inválida, peso zero, NaN): [Nothing,Nothing,Nothing]"
    print (map mediaPonderada [[(11, 1)], [(8, 0)], [(0/0, 1)]])
