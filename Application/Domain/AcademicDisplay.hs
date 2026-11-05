{-# LANGUAGE OverloadedStrings #-}
-- Display-only transformations. Never persist these derived values.
module Application.Domain.AcademicDisplay where

import Prelude
import Data.Text (Text)
import qualified Data.Text as Text

nomesParaExibicao :: [Text] -> [Text]
nomesParaExibicao = fmap (Text.toUpper . Text.strip)

-- One transformation reused across list, Maybe and Either contexts.
notasParaExibicao :: Functor f => f Double -> f Text
notasParaExibicao = fmap (\nota -> "Nota: " <> Text.pack (show nota))
