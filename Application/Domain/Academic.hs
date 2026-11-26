module Application.Domain.Academic where
import Prelude
import Application.Domain.Grade (numeroFinito, notaValida)
import Application.Domain.Attendance (SituacaoFrequencia (..))

-- Each discipline contributes one mean. Absence is never replaced by zero.
mediaGeralCompleta :: Int -> [Maybe Double] -> Maybe Double
mediaGeralCompleta quantidade medias
    | quantidade <= 0 || length medias /= quantidade = Nothing
    | otherwise = do
        valores <- sequence medias
        if all numeroFinito valores
            then Just (sum valores / fromIntegral quantidade)
            else Nothing

-- Critério definido pelo grupo: média ponderada mínima 5,0, avaliada somente
-- quando a matrícula está Concluída (antes disso a situação é "Em andamento").
data ApprovalPolicy = ApprovalPolicy
    { passingAverage :: Double
    , requireCompleted :: Bool
    } deriving (Eq, Show)

approvalPolicy :: Maybe ApprovalPolicy
approvalPolicy = Just (ApprovalPolicy 5 True)

-- AttendanceBelowMinimum: matrícula em andamento com frequência abaixo de 75 %.
-- FailedAttendance: matrícula concluída com frequência abaixo de 75 %.
data AcademicStanding = NoAverage | PolicyPending | InProgress | Approved | Insufficient
    | AttendanceBelowMinimum | FailedAttendance
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

-- A frequência mínima é requisito de aprovação independente da média e do
-- critério de nota: abaixo de 75 % nunca há aprovação. Sem chamadas registradas,
-- a frequência não é controlada e vale somente a classificação pela média.
classifyEnrollment :: Maybe ApprovalPolicy -> Bool -> SituacaoFrequencia -> Maybe Double -> AcademicStanding
classifyEnrollment policy completed attendance average = case attendance of
    FrequenciaAbaixoDoMinimo | completed -> FailedAttendance
                             | otherwise -> AttendanceBelowMinimum
    _ -> classifyAverage policy completed average

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
performance policy results =
    performanceWithAttendance policy [(completed, SemAulasRegistradas, average) | (completed, average) <- results]

-- Médias disponíveis/ausentes dependem só das notas; aprovados excluem quem
-- está abaixo da frequência mínima.
performanceWithAttendance :: Maybe ApprovalPolicy -> [(Bool, SituacaoFrequencia, Maybe Double)] -> Performance
performanceWithAttendance policy results = Performance
    (mediaAtualTurma [average | (_, _, average) <- results])
    (length results - length (filter (== NoAverage) averageStandings))
    (length (filter (== NoAverage) averageStandings))
    (count Approved)
    (count Insufficient)
    (fmap (length results -) (count Approved))
    where
        averageStandings = [classifyAverage policy completed average | (completed, _, average) <- results]
        standings = [classifyEnrollment policy completed attendance average | (completed, attendance, average) <- results]
        count value = case validPolicy policy of
            Nothing -> Nothing
            Just _ -> Just (length (filter (== value) standings))

-- Quantidade de matrículas abaixo da frequência mínima (em andamento ou concluídas).
attendanceBelowMinimumCount :: [SituacaoFrequencia] -> Int
attendanceBelowMinimumCount = length . filter (== FrequenciaAbaixoDoMinimo)
