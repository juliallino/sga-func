module Application.Helper.Controller where

import IHP.ControllerPrelude

-- Here you can add functions which are available in all your controllers

-- Return a consistent 404 for missing records in every environment.
fetchOr404 recordId = do
    record <- fetchOneOrNothing recordId
    maybe (earlyReturn renderNotFound) pure record

-- Adapter only: convert pure Either errors into IHP form field errors.
validacaoEither :: (a -> Either Text b) -> a -> ValidatorResult
validacaoEither validar valor = either Failure (const Success) (validar valor)
