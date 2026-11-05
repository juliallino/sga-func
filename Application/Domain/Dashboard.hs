{-# LANGUAGE OverloadedStrings #-}
module Application.Domain.Dashboard where

import Prelude
import Data.List (sortOn, groupBy, nub)
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Application.Domain.Grade (mediaDaMatricula, notaValida)

-- Database-independent projection. No inferred enrollment/subject relationship.
data AcademicResult = AcademicResult
    { resultEnrollmentId :: Text
    , resultStudentId :: Text
    , resultStudentName :: Text
    , resultCourseId :: Text
    , resultCourseName :: Text
    , resultStatus :: Text
    , resultAssessments :: [(Text, Double, Double)]
    , resultAverage :: Maybe Double
    , resultSubjectId :: Text
    , resultSubjectName :: Text
    } deriving (Eq, Show)

makeResult :: Text -> Text -> Text -> Text -> Text -> Text -> [(Text, Double, Double)] -> AcademicResult
makeResult enrollmentId studentId name courseId courseName status assessments = AcademicResult
    enrollmentId studentId name courseId courseName status assessments
    (mediaDaMatricula (map (\(_, score, weight) -> (score, weight)) assessments)) "" ""

makeSubjectResult :: Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> [(Text,Double,Double)] -> AcademicResult
makeSubjectResult enrollment student name course courseName subject subjectName status assessments =
    (makeResult enrollment student name course courseName status assessments)
        { resultSubjectId = subject, resultSubjectName = subjectName }

data DashboardFilters = DashboardFilters
    { filterName :: Text
    , filterCourse :: Text
    , filterSubject :: Text
    , filterStatus :: Text
    , filterMinimum :: Text
    , filterMaximum :: Text
    } deriving (Eq, Show)

emptyFilters :: DashboardFilters
emptyFilters = DashboardFilters "" "" "" "" "" ""

-- Parsing remains pure: invalid bounds must never silently broaden a result.
parseBounds :: DashboardFilters -> Either Text (Maybe Double, Maybe Double)
parseBounds filters = do
    minimum <- parseBound (filterMinimum filters)
    maximum <- parseBound (filterMaximum filters)
    case (minimum, maximum) of
        (Just low, Just high) | low > high -> Left "A média mínima deve ser menor ou igual à máxima."
        _ -> Right (minimum, maximum)
    where
        parseBound raw
            | Text.null (Text.strip raw) = Right Nothing
            | otherwise = case reads (Text.unpack (Text.strip raw)) of
                [(value, "")] | notaValida value -> Right (Just value)
                _ -> Left "Informe médias válidas entre 0 e 10."

filterResults :: DashboardFilters -> [AcademicResult] -> Either Text [AcademicResult]
filterResults filters results = do
    (minimum, maximum) <- parseBounds filters
    pure (filter (matches minimum maximum) results)
    where
        matches minimum maximum result =
            Text.toCaseFold (Text.strip (filterName filters)) `Text.isInfixOf` Text.toCaseFold (resultStudentName result)
            && optional (filterCourse filters) (resultCourseId result)
            && optional (filterStatus filters) (resultStatus result)
            && optional (filterSubject filters) (resultSubjectId result)
            && maybe True (\low -> maybe False (>= low) (resultAverage result)) minimum
            && maybe True (\high -> maybe False (<= high) (resultAverage result)) maximum
        optional wanted actual = Text.null wanted || wanted == actual

validAverageCount :: [AcademicResult] -> Int
validAverageCount = foldl (\total result -> total + maybe 0 (const 1) (resultAverage result)) 0

assessmentCount :: [AcademicResult] -> Int
assessmentCount = length . concatMap resultAssessments

-- Explicit subject cohorts; missing averages never enter a ranking.
data RankingEntry = RankingEntry { rankingPosition :: Int, rankingResult :: AcademicResult }
    deriving (Eq, Show)
data RankingGroup = RankingGroup
    { rankingCourse :: Text
    , rankingStatus :: Text
    , rankingPlan :: [(Text, Double)]
    , rankingSubject :: Text
    , rankingEntries :: [RankingEntry]
    } deriving (Eq, Show)

rankingGroups :: [AcademicResult] -> [RankingGroup]
rankingGroups results = map makeGroup cohorts
    where
        eligible = filter (\r -> not (Text.null (resultSubjectId r)) && maybe False notaValida (resultAverage r)) results
        ordered = sortOn cohortKey eligible
        cohorts = groupBy (\a b -> cohortKey a==cohortKey b) ordered
        makeGroup rows = case rows of
            [] -> RankingGroup "" "" [] "" []
            first:_ -> RankingGroup (resultCourseName first) "" [] (resultSubjectName first)
                (assignPositions (sortOn orderKey rows))
        cohortKey r = (resultCourseId r,resultSubjectId r)
        orderKey r = (Down (resultAverage r),Text.toCaseFold (resultStudentName r),resultStudentId r,resultEnrollmentId r)
        assignPositions = go 1 Nothing 0
        go _ _ _ [] = []
        go index previous previousPosition (r:rs) =
            let position = if previous==Just (resultAverage r) then previousPosition else index
            in RankingEntry position r : go (index+1) (Just (resultAverage r)) position rs

-- Filter the displayed entries AFTER assigning positions in the full cohort.
-- Searching for a student never improves their ranking position.
visibleRankingGroups :: [AcademicResult] -> [RankingGroup] -> [RankingGroup]
visibleRankingGroups visible = filter (not . null . rankingEntries) . map selectEntries
    where
        ids = map resultEnrollmentId visible
        selectEntries group = group { rankingEntries = filter ((`elem` ids) . resultEnrollmentId . rankingResult) (rankingEntries group) }
