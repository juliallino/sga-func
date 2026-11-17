module Web.View.ClassSessions.Form (RosterEntry (..), renderForm, formatDay) where

import Web.View.Prelude

-- Uma linha da lista de presença: a matrícula e o estudante correspondente.
data RosterEntry = RosterEntry
    { rosterEnrollment :: Enrollment
    , rosterStudent :: Maybe Student
    }

-- Exibição das datas no padrão brasileiro.
formatDay :: Day -> Text
formatDay day = cs (formatTime defaultTimeLocale "%d/%m/%Y" day)

renderForm :: (?request :: Request) => ClassSession -> Text -> [RosterEntry] -> [UUID] -> Text -> Html
renderForm classSession formAction roster presentIds cancelUrl = formFor' classSession formAction [hsx|
    {(dateField #classDate) { fieldLabel = "Data da aula", required = True }}
    {(textField #topic) { fieldLabel = "Conteúdo da aula (opcional)" }}
    <fieldset>
        <legend class="form-label">Presença</legend>
        <p class="form-text">Marque os estudantes presentes. Quem ficar desmarcado recebe falta nesta aula.</p>
        {when (null roster) noRoster}
        <ul class="attendance-roster">{forEach roster (renderRosterEntry presentIds)}</ul>
    </fieldset>
    {formActions (submitButton { label = "Salvar chamada" }) cancelUrl}
|]

renderRosterEntry :: [UUID] -> RosterEntry -> Html
renderRosterEntry presentIds entry = [hsx|
    <li>
        <input class="form-check-input" type="checkbox" name="presentEnrollmentIds" value={show enrollmentId} id={inputId} checked={enrollmentId `elem` presentIds}/>
        <label class="form-check-label" for={inputId}>{studentName}<small> · {studentNumber}</small></label>
    </li>
|]
    where
        enrollmentId = unpackId entry.rosterEnrollment.id
        inputId = "present-" <> show enrollmentId
        studentName = maybe "Estudante indisponível" (.name) entry.rosterStudent
        studentNumber = maybe "—" (.enrollmentNumber) entry.rosterStudent

noRoster :: Html
noRoster = emptyState "students" "Nenhuma matrícula ativa nesta disciplina" "A chamada lista as matrículas com situação Ativa."
