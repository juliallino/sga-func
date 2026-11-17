module Web.Controller.ClassSessions where

import Web.Controller.Prelude
import qualified Data.Text as Text
import Application.Helper.Portal (attendanceSummary)
import Web.View.ClassSessions.Form (RosterEntry (..))
import Web.View.ClassSessions.Subjects
import Web.View.ClassSessions.Index
import Web.View.ClassSessions.New
import Web.View.ClassSessions.Edit

-- Chamadas (aulas) e presenças. Admin acessa todas as disciplinas; professores,
-- somente as autorizadas em teacher_subjects. Estudantes consultam a própria
-- frequência nos portais e não acessam estas telas.
instance Controller ClassSessionsController where
    action ClassSessionSubjectsAction = do
        requireGradeWriter
        subjects <- visibleSubjects
        courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) subjects) |> fetch
        sessions <- query @ClassSession |> filterWhereIn (#subjectId, map (unpackId . (.id)) subjects) |> fetch
        let sessionCounts = map (\subject -> (unpackId subject.id, length (filter (\s -> s.subjectId == unpackId subject.id) sessions))) subjects
        render SubjectsView { .. }

    action ClassSessionsAction { subjectId } = do
        requireGradeWriter
        requireSubject subjectId
        subject <- fetchOr404 subjectId
        sessions <- query @ClassSession
            |> filterWhere (#subjectId, unpackId subjectId)
            |> orderByDesc #classDate
            |> fetch
        attendances <- query @Attendance |> filterWhereIn (#classSessionId, map (unpackId . (.id)) sessions) |> fetch
        enrollments <- query @Enrollment |> filterWhere (#subjectId, unpackId subjectId) |> fetch
        students <- query @Student |> filterWhereIn (#id, map (Id . (.studentId)) enrollments) |> fetch
        let sessionRows = map (sessionRow attendances) sessions
        let studentRows = map (\enrollment -> (rosterEntry students enrollment, attendanceSummary attendances enrollment)) (sortByStudent students enrollments)
        render IndexView { .. }

    action NewClassSessionAction { subjectId } = do
        requireGradeWriter
        requireSubject subjectId
        subject <- fetchOr404 subjectId
        roster <- loadRoster subjectId []
        today <- currentDay
        let classSession = newRecord @ClassSession
                |> set #subjectId (unpackId subjectId)
                |> set #classDate today
        -- Por padrão todos começam presentes; o professor desmarca as faltas.
        let presentIds = map (unpackId . (.id) . (.rosterEnrollment)) roster
        render NewView { .. }

    action CreateClassSessionAction { subjectId } = withTransaction do
        requireSubjectWrite subjectId
        subject <- fetchOr404 subjectId
        roster <- loadRoster subjectId []
        when (null roster) do
            setErrorMessage "Não há matrículas ativas nesta disciplina para registrar a chamada."
            earlyReturn (redirectTo ClassSessionsAction { subjectId })
        presentIds <- readPresentIds roster
        today <- currentDay
        let classSession = newRecord @ClassSession
                |> set #subjectId (unpackId subjectId)
                |> buildClassSession today
        classSession |> ifValid \case
            Left classSession -> render NewView { .. }
            Right classSession -> do
                created <- createRecord classSession
                forEach roster \entry -> do
                    let enrollmentId = unpackId entry.rosterEnrollment.id
                    _ <- newRecord @Attendance
                        |> set #classSessionId (unpackId created.id)
                        |> set #enrollmentId enrollmentId
                        |> set #present (enrollmentId `elem` presentIds)
                        |> createRecord
                    pure ()
                setSuccessMessage "Chamada registrada com sucesso."
                redirectTo ClassSessionsAction { subjectId }

    action EditClassSessionAction { classSessionId } = do
        requireGradeWriter
        classSession <- fetchOr404 classSessionId
        let subjectId = Id classSession.subjectId :: Id Subject
        requireSubject subjectId
        subject <- fetchOr404 subjectId
        records <- query @Attendance |> filterWhere (#classSessionId, unpackId classSessionId) |> fetch
        roster <- loadRoster subjectId records
        let presentIds = map (.enrollmentId) (filter (.present) records)
        render EditView { .. }

    action UpdateClassSessionAction { classSessionId } = withTransaction do
        requireGradeWriter
        _ <- unsafeSqlQuery "SELECT id FROM class_sessions WHERE id = ? FOR UPDATE" (Only (unpackId classSessionId)) :: IO [Only UUID]
        original <- fetchOr404 classSessionId
        let subjectId = Id original.subjectId :: Id Subject
        requireSubjectWrite subjectId
        subject <- fetchOr404 subjectId
        records <- query @Attendance |> filterWhere (#classSessionId, unpackId classSessionId) |> fetch
        roster <- loadRoster subjectId records
        presentIds <- readPresentIds roster
        today <- currentDay
        let classSession = buildClassSession today original
        classSession |> ifValid \case
            Left classSession -> render EditView { .. }
            Right classSession -> do
                _ <- updateRecord classSession
                forEach roster \entry -> do
                    let enrollmentId = unpackId entry.rosterEnrollment.id
                    let present = enrollmentId `elem` presentIds
                    case find (\existing -> existing.enrollmentId == enrollmentId) records of
                        Just existing -> when (existing.present /= present) do
                            _ <- existing |> set #present present |> updateRecord
                            pure ()
                        Nothing -> do
                            _ <- newRecord @Attendance
                                |> set #classSessionId (unpackId classSessionId)
                                |> set #enrollmentId enrollmentId
                                |> set #present present
                                |> createRecord
                            pure ()
                setSuccessMessage "Chamada atualizada com sucesso."
                redirectTo ClassSessionsAction { subjectId }

    action DeleteClassSessionAction { classSessionId } = withTransaction do
        requireGradeWriter
        _ <- unsafeSqlQuery "SELECT id FROM class_sessions WHERE id = ? FOR UPDATE" (Only (unpackId classSessionId)) :: IO [Only UUID]
        classSession <- fetchOr404 classSessionId
        let subjectId = Id classSession.subjectId :: Id Subject
        requireSubjectWrite subjectId
        records <- query @Attendance |> filterWhere (#classSessionId, unpackId classSessionId) |> fetch
        deleteRecords records
        deleteRecord classSession
        setSuccessMessage "Chamada excluída com sucesso."
        redirectTo ClassSessionsAction { subjectId }

-- Data local do servidor (no WSL, normalmente o fuso do Windows).
currentDay :: IO Day
currentDay = localDay . zonedTimeToLocalTime <$> getZonedTime

-- Somente data e conteúdo vêm do formulário; a disciplina nunca muda.
buildClassSession today classSession = classSession
    |> fill @'["classDate", "topic"]
    |> modify #topic normalizeTopic
    |> validateField #classDate (\day -> if day > today then Failure "A data da aula não pode estar no futuro." else Success)

normalizeTopic :: Maybe Text -> Maybe Text
normalizeTopic topic = case Text.strip <$> topic of
    Just value | not (Text.null value) -> Just value
    _ -> Nothing

-- Chamada nova: matrículas ativas. Edição: também as que já têm registro nesta
-- aula, para que uma matrícula concluída ou suspensa depois não perca o histórico.
loadRoster :: (?modelContext :: ModelContext) => Id Subject -> [Attendance] -> IO [RosterEntry]
loadRoster subjectId records = do
    enrollments <- query @Enrollment |> filterWhere (#subjectId, unpackId subjectId) |> fetch
    let recorded = map (.enrollmentId) records
    let selected = filter (\enrollment -> enrollment.status == Active || unpackId enrollment.id `elem` recorded) enrollments
    students <- query @Student |> filterWhereIn (#id, map (Id . (.studentId)) selected) |> fetch
    pure (map (rosterEntry students) (sortByStudent students selected))

rosterEntry :: [Student] -> Enrollment -> RosterEntry
rosterEntry students enrollment = RosterEntry enrollment (find (\student -> unpackId student.id == enrollment.studentId) students)

sortByStudent :: [Student] -> [Enrollment] -> [Enrollment]
sortByStudent students = sortOn (\enrollment -> maybe "" (.name) (find (\student -> unpackId student.id == enrollment.studentId) students))

sessionRow :: [Attendance] -> ClassSession -> (ClassSession, Int, Int)
sessionRow attendances classSession = (classSession, length (filter (.present) records), length records)
    where records = filter (\entry -> entry.classSessionId == unpackId classSession.id) attendances

-- Valores inválidos ou matrículas fora da lista de presença indicam requisição
-- manipulada: nada é gravado.
readPresentIds :: (?request :: Request, ?respond :: Respond) => [RosterEntry] -> IO [UUID]
readPresentIds roster = do
    let values = paramListOrNothing @UUID "presentEnrollmentIds"
    let allowed = map (unpackId . (.id) . (.rosterEnrollment)) roster
    let ids = catMaybes values
    when (any isNothing values || any (`notElem` allowed) ids) (earlyReturn renderNotFound)
    pure (nub ids)
