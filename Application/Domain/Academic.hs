module Application.Domain.Academic where
import Prelude
import Application.Domain.Grade (numeroFinito)

-- Each discipline contributes one mean. Absence is never replaced by zero.
mediaGeralCompleta :: Int -> [Maybe Double] -> Maybe Double
mediaGeralCompleta quantidade medias
    | quantidade <= 0 || length medias /= quantidade = Nothing
    | otherwise = do
        valores <- sequence medias
        if all numeroFinito valores
            then Just (sum valores / fromIntegral quantidade)
            else Nothing
