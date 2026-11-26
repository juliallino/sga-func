module Web.Controller.AcademicPeriods where

import Web.Controller.Prelude
import qualified Data.Text as Text
import qualified Application.Domain.Period as PeriodDomain
import Web.View.AcademicPeriods.Index
import Web.View.AcademicPeriods.New
import Web.View.AcademicPeriods.Edit

-- Períodos letivos: somente o Admin cadastra, edita e exclui.
instance Controller AcademicPeriodsController where
    action AcademicPeriodsAction = do
        requireAdmin
        academicPeriods <- query @AcademicPeriod |> orderByDesc #startsOn |> fetch
        enrollments <- query @Enrollment |> filterWhereNot (#academicPeriodId, Nothing) |> fetch
        let enrollmentCounts = [ (unpackId period.id, length (filter (\enrollment -> enrollment.academicPeriodId == Just (unpackId period.id)) enrollments))
                               | period <- academicPeriods ]
        render IndexView { .. }

    action NewAcademicPeriodAction = do
        requireAdmin
        today <- localDay . zonedTimeToLocalTime <$> getZonedTime
        let academicPeriod = newRecord @AcademicPeriod
                |> set #startsOn today
                |> set #endsOn today
        render NewView { .. }

    action CreateAcademicPeriodAction = do
        requireAdmin
        academicPeriod <- newRecord @AcademicPeriod |> buildAcademicPeriod |> validateAcademicPeriod
        academicPeriod |> ifValid \case
            Left academicPeriod -> render NewView { .. }
            Right academicPeriod -> do
                _ <- createRecord academicPeriod
                setSuccessMessage "Período cadastrado com sucesso."
                redirectTo AcademicPeriodsAction

    action EditAcademicPeriodAction { academicPeriodId } = do
        requireAdmin
        academicPeriod <- fetchOr404 academicPeriodId
        render EditView { .. }

    action UpdateAcademicPeriodAction { academicPeriodId } = do
        requireAdmin
        academicPeriod <- fetchOr404 academicPeriodId
        academicPeriod <- academicPeriod |> buildAcademicPeriod |> validateAcademicPeriod
        academicPeriod |> ifValid \case
            Left academicPeriod -> render EditView { .. }
            Right academicPeriod -> do
                _ <- updateRecord academicPeriod
                setSuccessMessage "Período atualizado com sucesso."
                redirectTo AcademicPeriodsAction

    action DeleteAcademicPeriodAction { academicPeriodId } = do
        requireAdmin
        academicPeriod <- fetchOr404 academicPeriodId
        enrollment <- query @Enrollment
            |> filterWhere (#academicPeriodId, Just (unpackId academicPeriodId))
            |> fetchOneOrNothing
        if isJust enrollment
            then setErrorMessage "Não é possível excluir um período com matrículas."
            else do
                deleteRecord academicPeriod
                setSuccessMessage "Período excluído com sucesso."
        redirectTo AcademicPeriodsAction

buildAcademicPeriod academicPeriod = academicPeriod
    |> fill @'["name", "startsOn", "endsOn"]
    |> modify #name Text.strip
    |> validateField #name (either Failure (const Success) . PeriodDomain.validarNomePeriodo)

-- Regras que dependem dos outros períodos: nome único e datas sem sobreposição.
validateAcademicPeriod :: (?modelContext :: ModelContext) => AcademicPeriod -> IO AcademicPeriod
validateAcademicPeriod academicPeriod
    | not (isValid academicPeriod) = pure academicPeriod
    | otherwise = do
        allPeriods <- query @AcademicPeriod |> fetch
        let others = filter (\other -> other.id /= academicPeriod.id) allPeriods
        let interval = (academicPeriod.startsOn, academicPeriod.endsOn)
        let overlapping = find (\other -> PeriodDomain.periodosSobrepostos (other.startsOn, other.endsOn) interval) others
        let withName = if any (\other -> other.name == academicPeriod.name) others
                then attachFailure #name "Este período já está cadastrado." academicPeriod
                else academicPeriod
        let withOrder = case PeriodDomain.validarOrdemDatas academicPeriod.startsOn academicPeriod.endsOn of
                Left message -> attachFailure #endsOn message withName
                Right () -> withName
        let withYear = case PeriodDomain.validarAnoInicio academicPeriod.name academicPeriod.startsOn of
                Left message -> attachFailure #startsOn message withOrder
                Right () -> withOrder
        pure case overlapping of
            Just other -> attachFailure #startsOn ("As datas se sobrepõem ao período " <> other.name <> ".") withYear
            Nothing -> withYear
