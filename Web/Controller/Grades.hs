module Web.Controller.Grades where

import Web.Controller.Prelude
import qualified Application.Domain.AcademicConfig as AcademicConfig
import Control.Monad.Reader (runReader)
import Web.View.Grades.Form (EnrollmentOption (..), buildEnrollmentOptions)
import Web.View.Grades.Index
import Web.View.Grades.New
import Web.View.Grades.Edit
import Web.View.Grades.Show
import IHP.LoginSupport.Helper.Controller (currentUser)
import qualified Web.View.StudentPortal.Academic as StudentAcademic
import Application.Helper.Portal (studentEnrollmentRows)

instance Controller GradesController where
    action GradesAction = do
        requireLogin
        permitted <- visibleEnrollments
        selected <- readGradeContext "subjectId"
        forEach selected (\subjectId -> requireSubject (Id subjectId))
        selectedSubject <- case selected of
            Nothing -> pure Nothing
            Just value -> Just <$> fetchOr404 (Id value :: Id Subject)
        let enrollments = maybe permitted (\subjectId -> filter (\e -> e.subjectId == subjectId) permitted) selected
        grades <- query @Grade |> filterWhereIn (#enrollmentId, map (unpackId . (.id)) enrollments) |> fetch
        students <- query @Student |> filterWhereIn (#id, map (Id . (.studentId)) enrollments) |> fetch
        subjects <- query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) enrollments) |> fetch
        let enrollmentOptions = buildEnrollmentOptions enrollments students subjects
        if (currentUser @User).role_ == Rolestudent
            then do
                rows <- studentEnrollmentRows enrollments subjects grades
                render StudentAcademic.NotesView { .. }
            else render IndexView { .. }

    action NewGradeAction = do
        requireGradeWriter
        enrollmentOptions <- loadEnrollmentOptions
        selectedEnrollment <- readGradeContext "enrollmentId"
        forEach selectedEnrollment (\value -> unless (any (\option -> option.optionId == value) enrollmentOptions) (earlyReturn renderNotFound))
        let grade = maybe (newRecord @Grade) (\value -> newRecord @Grade |> set #enrollmentId value) selectedEnrollment
        render NewView { .. }

    action ShowGradeAction { gradeId } = do
        requireLogin
        grade <- fetchOr404 gradeId
        requireGrade grade
        enrollment <- fetchOr404 (Id grade.enrollmentId :: Id Enrollment)
        student <- fetchOr404 (Id enrollment.studentId :: Id Student)
        subject <- fetchOr404 (Id enrollment.subjectId :: Id Subject)
        course <- fetchOr404 (Id subject.courseId :: Id Course)
        render ShowView { .. }

    action EditGradeAction { gradeId } = do
        requireGradeWriter
        grade <- fetchOr404 gradeId
        requireGrade grade
        enrollmentOptions <- loadEnrollmentOptions
        render EditView { .. }

    action UpdateGradeAction { gradeId } = withTransaction do
        requireGradeWriter
        _ <- unsafeSqlQuery "SELECT id FROM grades WHERE id = ? FOR UPDATE" (Only (unpackId gradeId)) :: IO [Only UUID]
        original <- fetchOr404 gradeId
        requireEnrollmentWrite original.enrollmentId
        enrollmentOptions <- loadEnrollmentOptions
        let grade = buildGrade original
        grade |> ifValid \case
            Left grade -> render EditView { .. }
            Right grade -> do
                when ((currentUser @User).role_ == Roleteacher && grade.enrollmentId /= original.enrollmentId) forbidden
                requireEnrollmentWrite grade.enrollmentId
                _ <- updateRecord grade
                setSuccessMessage "Nota atualizada com sucesso."
                redirectTo EditGradeAction { .. }

    action CreateGradeAction = withTransaction do
        requireGradeWriter
        enrollmentOptions <- loadEnrollmentOptions
        let grade = buildGrade (newRecord @Grade)
        grade |> ifValid \case
            Left grade -> render NewView { .. }
            Right grade -> do
                exists <- validarMatricula grade
                if not exists then do
                    setErrorMessage "A matrícula informada não existe."
                    render NewView { .. }
                else do
                    requireEnrollmentWrite grade.enrollmentId
                    _ <- createRecord grade
                    setSuccessMessage "Nota cadastrada com sucesso."
                    redirectTo GradesAction

    action DeleteGradeAction { gradeId } = do
        requireAdmin
        grade <- fetchOr404 gradeId
        deleteRecord grade
        setSuccessMessage "Nota excluída com sucesso."
        redirectTo GradesAction

-- Keep the existing academic limits; the same Reader environment is supplied
-- to both field validators on every create/update, before persistence.
buildGrade grade = buildGradeWithConfig AcademicConfig.configAcademicaPadrao grade

buildGradeWithConfig config grade = grade
    |> fill @'["enrollmentId", "assessmentName", "score", "weight"]
    |> validateField #assessmentName (withCustomErrorMessage "Informe o nome da avaliação." nonEmpty)
    |> validateField #score (validacaoEither (\value -> runReader (AcademicConfig.validarNotaConfigurada (realToFrac value)) config))
    |> validateField #weight (validacaoEither (\value -> runReader (AcademicConfig.validarPesoConfigurado (realToFrac value)) config))
    |> validateField #weight validarPrecisaoPeso

validarMatricula :: (?modelContext :: ModelContext) => Grade -> IO Bool
validarMatricula grade = do
    resultado <- query @Enrollment
        |> filterWhere (#id, Id grade.enrollmentId)
        |> fetchOneOrNothing

    pure (isJust resultado)


loadEnrollmentOptions :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO [EnrollmentOption]
loadEnrollmentOptions = do
    permitted <- visibleEnrollments
    selected <- readGradeContext "subjectId"
    forEach selected (\subjectId -> requireSubject (Id subjectId))
    let enrollments = maybe permitted (\subjectId -> filter (\enrollment -> enrollment.subjectId == subjectId) permitted) selected
    students <- query @Student |> filterWhereIn (#id, map (Id . (.studentId)) enrollments) |> fetch
    subjects <- query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) enrollments) |> fetch
    pure (buildEnrollmentOptions enrollments students subjects)

-- NUMERIC(5,2) rounds before checking constraints. A positive input such as
-- 0.001 becomes zero; 1000 overflows. Match PostgreSQL's positive rounding
-- without changing inputs that it can already store (e.g. 0.005 -> 0.01).
validarPrecisaoPeso :: RealFrac value => value -> ValidatorResult
validarPrecisaoPeso value
    | cents >= 1 && cents <= 99999 = Success
    | otherwise = Failure "O peso deve permanecer positivo após arredondamento para duas casas e não exceder 999,99."
    where cents = floor (value * 100 + 0.5) :: Integer

-- Invalid context UUIDs must not silently widen a selected discipline.
readGradeContext :: (?request :: Request, ?respond :: Respond) => ByteString -> IO (Maybe UUID)
readGradeContext name = case paramOrError @UUID name of
    Left ParamNotFoundException {} -> pure Nothing
    Left _ -> earlyReturn renderNotFound
    Right value -> pure (Just value)
