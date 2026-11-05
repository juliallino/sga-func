{-# LANGUAGE OverloadedStrings #-}
-- Infinite, fictional demonstration data; never use these as query inputs.
module Application.Domain.LazyExamples where

import Prelude
import Data.Text (Text)
import qualified Data.Text as Text

-- Integer avoids overflow in the unbounded sequence.
numerosFicticios :: [Integer]
numerosFicticios = [1..]

-- map builds labels only as the consumer demands them.
matriculasFicticias :: [Text]
matriculasFicticias = map (\numero -> "DEMO-" <> Text.pack (show numero)) numerosFicticios

-- Even numbers are just a demonstration predicate, not an academic rule.
numerosParesFicticios :: [Integer]
numerosParesFicticios = filter even numerosFicticios
