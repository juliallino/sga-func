module Application.Domain.Academic where
import Prelude
import Application.Domain.Grade (numeroFinito, notaValida)

-- Each discipline contributes one mean. Absence is never replaced by zero.
mediaGeralCompleta :: Int -> [Maybe Double] -> Maybe Double
mediaGeralCompleta quantidade medias
    | quantidade <= 0 || length medias /= quantidade = Nothing
    | otherwise = do
        valores <- sequence medias
        if all numeroFinito valores
            then Just (sum valores / fromIntegral quantidade)
            else Nothing

-- No approval threshold or assessment-closing rule exists in the current model.
-- Keep the policy absent until the academic owner supplies both criteria.
data ApprovalPolicy = ApprovalPolicy
    { passingAverage :: Double
    , requireCompleted :: Bool
    } deriving (Eq, Show)

approvalPolicy :: Maybe ApprovalPolicy
approvalPolicy = Nothing

data AcademicStanding = NoAverage | PolicyPending | InProgress | Approved | Insufficient
    deriving (Eq, Show)

validPolicy :: Maybe ApprovalPolicy -> Maybe ApprovalPolicy
validPolicy policy = case policy of
    Just value | notaValida (passingAverage value) -> Just value
    _ -> Nothing

classifyAverage :: Maybe ApprovalPolicy -> Bool -> Maybe Double -> AcademicStanding
classifyAverage policy completed average = case average of
    Just value | notaValida value -> case validPolicy policy of
        Nothing -> PolicyPending
        Just rule | requireCompleted rule && not completed -> InProgress
                  | value >= passingAverage rule -> Approved
                  | otherwise -> Insufficient
    _ -> NoAverage

-- Analytical class mean: each available enrollment average contributes once.
-- This is a current descriptive measure, not an official approval decision.
mediaAtualTurma :: [Maybe Double] -> Maybe Double
mediaAtualTurma averages = mediaGeralCompleta (length available) (map Just available)
    where available = [value | Just value <- averages, numeroFinito value, value >= 0, value <= 10]

data Performance = Performance
    { currentClassAverage :: Maybe Double
    , availableAverages :: Int
    , missingAverages :: Int
    , approvedCount :: Maybe Int
    , insufficientCount :: Maybe Int
    , pendingCount :: Maybe Int
    } deriving (Eq, Show)

performance :: Maybe ApprovalPolicy -> [(Bool, Maybe Double)] -> Performance
performance policy results = Performance
    (mediaAtualTurma (map snd results))
    (length results - length (filter (== NoAverage) standings))
    (length (filter (== NoAverage) standings))
    (count Approved)
    (count Insufficient)
    (fmap (length results -) (count Approved))
    where
        standings = map (uncurry (classifyAverage policy)) results
        count value = case validPolicy policy of
            Nothing -> Nothing
            Just _ -> Just (length (filter (== value) standings))
