module Web.Controller.Enrollments where

import Web.Controller.Prelude
import qualified Application.Domain.Grade as GradeDomain
import qualified Application.Domain.EnrollmentCPS as EnrollmentCPS
import Web.View.Enrollments.Index
import Web.View.Enrollments.New
import Web.View.Enrollments.Edit
import Web.View.Enrollments.Show
import Application.Helper.Portal (attendanceSummary)
import qualified Application.Domain.Period as PeriodDomain

instance Controller EnrollmentsController where
    action EnrollmentsAction = do
        requireLogin
        enrollments <- visibleEnrollments
        students <- query @Student |> filterWhereIn (#id, map (Id . (.studentId)) enrollments) |> fetch
        subjects <- query @Subject |> filterWhereIn (#id, map (Id . (.subjectId)) enrollments) |> fetch
        periods <- enrollmentPeriods enrollments
        render IndexView { .. }

    action NewEnrollmentAction = do
        requireAdmin
        students <- query @Student |> fetch
        subjects <- query @Subject |> fetch
        periods <- allPeriods
        today <- localDay . zonedTimeToLocalTime <$> getZonedTime
        -- Sugere o período em andamento (ou o último iniciado).
        let suggested = PeriodDomain.periodoAtual today [(unpackId period.id, (period.startsOn, period.endsOn)) | period <- periods]
        let enrollment = newRecord @Enrollment |> set #academicPeriodId suggested
        render NewView { .. }

    action ShowEnrollmentAction { enrollmentId } = do
        requireLogin
        enrollment <- fetchOr404 enrollmentId
        requireEnrollment enrollment
        student <- fetchOr404 (Id enrollment.studentId :: Id Student)
        subject <- fetchOr404 (Id enrollment.subjectId :: Id Subject)
        grades <- query @Grade
            |> filterWhere (#enrollmentId, unpackId enrollmentId)
            |> fetch
        let media = calcularMediaEnrollment grades
        attendanceRecords <- query @Attendance |> filterWhere (#enrollmentId, unpackId enrollmentId) |> fetch
        sessions <- query @ClassSession |> filterWhereIn (#id, map (Id . (.classSessionId)) attendanceRecords) |> orderByDesc #classDate |> fetch
        let attendance = attendanceSummary attendanceRecords enrollment
        let attendanceRows = mapMaybe (\session -> (\entry -> (session, entry.present)) <$> find (\entry -> entry.classSessionId == unpackId session.id) attendanceRecords) sessions
        period <- case enrollment.academicPeriodId of
            Just periodId -> query @AcademicPeriod |> filterWhere (#id, Id periodId) |> fetchOneOrNothing
            Nothing -> pure Nothing
        render ShowView { .. }
        
    action EditEnrollmentAction { enrollmentId } = do
        requireAdmin
        enrollment <- fetchOr404 enrollmentId
        students <- query @Student |> fetch
        subjects <- query @Subject |> fetch
        periods <- allPeriods
        render EditView { .. }

    action UpdateEnrollmentAction { enrollmentId } = do
        requireAdmin
        enrollment <- fetchOr404 enrollmentId
        let originalSubjectId = enrollment.subjectId
        students <- query @Student |> fetch
        subjects <- query @Subject |> fetch
        periods <- allPeriods
        presenca <- query @Attendance |> filterWhere (#enrollmentId, unpackId enrollmentId) |> fetchOneOrNothing
        enrollment <- validarEnrollment (buildEnrollment enrollment) >>= validarPeriodoMatricula
        -- Presenças pertencem às aulas da disciplina original.
        let enrollmentChecked = if isJust presenca && enrollment.subjectId /= originalSubjectId
                then attachFailure #subjectId "Não é possível trocar a disciplina de uma matrícula com chamadas registradas." enrollment
                else enrollment
        enrollmentChecked |> ifValid \case
            Left enrollment -> render EditView { .. }
            Right enrollment -> do
                enrollment <- enrollment |> updateRecord
                setSuccessMessage "Matrícula atualizada com sucesso."
                redirectTo EditEnrollmentAction { .. }

    action CreateEnrollmentAction = do
        requireAdmin
        let enrollment = newRecord @Enrollment
        students <- query @Student |> fetch
        subjects <- query @Subject |> fetch
        periods <- allPeriods
        enrollment <- validarEnrollment (buildEnrollment enrollment) >>= validarPeriodoMatricula
        enrollment |> ifValid \case
            Left enrollment -> render NewView { .. }
            Right enrollment -> do
                enrollment <- enrollment |> createRecord
                setSuccessMessage "Matrícula cadastrada com sucesso."
                redirectTo EnrollmentsAction

    action DeleteEnrollmentAction { enrollmentId } = do
        requireAdmin
        enrollment <- fetchOr404 enrollmentId
        dependencias <- query @Grade
            |> filterWhere (#enrollmentId, unpackId enrollmentId)
            |> fetchOneOrNothing
        presencas <- query @Attendance
            |> filterWhere (#enrollmentId, unpackId enrollmentId)
            |> fetchOneOrNothing
        if isJust dependencias
            then setErrorMessage "Não é possível excluir uma matrícula com notas. Use \"Desativar\": a matrícula fica Inativa e deixa de aparecer para o estudante."
            else if isJust presencas
            then setErrorMessage "Não é possível excluir uma matrícula com chamadas registradas. Use \"Desativar\": a matrícula fica Inativa e deixa de aparecer para o estudante."
            else do
                deleteRecord enrollment
                setSuccessMessage "Matrícula excluída com sucesso."
        redirectTo EnrollmentsAction

    -- Desativar preserva notas e chamadas; a matrícula some para o estudante.
    -- É reversível: o Admin pode editar a situação de volta.
    action DeactivateEnrollmentAction { enrollmentId } = do
        requireAdmin
        enrollment <- fetchOr404 enrollmentId
        _ <- enrollment |> set #status Inactive |> updateRecord
        setSuccessMessage "Matrícula desativada. Ela continua visível para Admin e professores, mas não para o estudante."
        redirectTo EnrollmentsAction

buildEnrollment enrollment = enrollment
    -- Leave the date untouched: PostgreSQL uses CURRENT_DATE on creation,
    -- and updates preserve the stored creation date, ignoring request parameters.
    |> fill @'["studentId", "subjectId", "status", "academicPeriodId"]

-- Only query references after UUID and enum parsing has succeeded.
validarEnrollment :: (?modelContext :: ModelContext) => Enrollment -> IO Enrollment
validarEnrollment enrollment
    | not (isValid enrollment) = pure enrollment
    | otherwise = do
        student <- query @Student
            |> filterWhere (#id, Id enrollment.studentId)
            |> fetchOneOrNothing
        subject <- query @Subject
            |> filterWhere (#id, Id enrollment.subjectId)
            |> fetchOneOrNothing
        duplicada <- matriculaDuplicada enrollment
        -- IO supplies facts; the CPS stage chooses a continuation purely.
        -- Parsing/defaults remain with IHP, preserving create/update behavior.
        EnrollmentCPS.validarRegrasMatriculaCPS
            (EnrollmentCPS.VerificacaoMatricula (isJust student) (isJust subject) duplicada)
            (\() -> pure enrollment)
            (\erros -> pure (foldl anexarErro enrollment erros))
    where
        anexarErro registro erro = case erro of
            EnrollmentCPS.EstudanteInexistente -> attachFailure #studentId (EnrollmentCPS.mensagemErroRegra erro) registro
            EnrollmentCPS.DisciplinaInexistente -> attachFailure #subjectId (EnrollmentCPS.mensagemErroRegra erro) registro
            EnrollmentCPS.MatriculaDuplicada -> attachFailure #subjectId (EnrollmentCPS.mensagemErroRegra erro) registro

calcularMediaEnrollment :: [Grade] -> Maybe Double
calcularMediaEnrollment grades =
    GradeDomain.mediaDaMatricula
        (map (\grade -> (realToFrac grade.score, realToFrac grade.weight)) grades)

matriculaDuplicada :: (?modelContext :: ModelContext) => Enrollment -> IO Bool
matriculaDuplicada enrollment = do
    matriculas <- query @Enrollment
        |> filterWhere (#studentId, enrollment.studentId)
        |> filterWhere (#subjectId, enrollment.subjectId)
        -- A mesma disciplina pode ser refeita em outro período.
        |> filterWhere (#academicPeriodId, enrollment.academicPeriodId)
        |> fetch

    pure (any (\matricula -> matricula.id /= enrollment.id) matriculas)

-- O período é opcional; quando informado, precisa existir.
validarPeriodoMatricula :: (?modelContext :: ModelContext) => Enrollment -> IO Enrollment
validarPeriodoMatricula enrollment = case enrollment.academicPeriodId of
    Nothing -> pure enrollment
    Just periodId -> do
        period <- query @AcademicPeriod |> filterWhere (#id, Id periodId) |> fetchOneOrNothing
        pure (if isJust period then enrollment else attachFailure #academicPeriodId "Selecione um período válido." enrollment)

allPeriods :: (?modelContext :: ModelContext) => IO [AcademicPeriod]
allPeriods = query @AcademicPeriod |> orderByDesc #startsOn |> fetch

-- Somente os períodos das matrículas já autorizadas.
enrollmentPeriods :: (?modelContext :: ModelContext) => [Enrollment] -> IO [AcademicPeriod]
enrollmentPeriods enrollments = query @AcademicPeriod
    |> filterWhereIn (#id, map Id (mapMaybe (.academicPeriodId) enrollments))
    |> fetch
