module Web.View.StudentConfidentialNotes.Show where
import Web.View.Prelude

data ShowView = ShowView { student :: Student, note :: Maybe Text }
instance View ShowView where
    html ShowView { .. } = [hsx|
        <p class="eyebrow">Administração</p>
        <h1>Observação confidencial</h1>
        <p>{student.name}</p>
        <p class="portal-notice">Conteúdo administrativo restrito ao Admin. Não é exibido nos portais acadêmicos.</p>
        {when (isNothing note) emptyNote}
        <form method="POST" action={SaveStudentConfidentialNoteAction student.id} autocomplete="off">
            <label class="form-label" for="confidential-note">Observação administrativa</label>
            <textarea class="form-control" id="confidential-note" name="note" rows="6" maxlength="2000">{fromMaybe "" note}</textarea>
            <div class="form-actions"><button class="btn btn-primary" type="submit">Salvar observação</button><a class="btn btn-outline-secondary" href={ShowStudentAction student.id}>Voltar ao estudante</a></div>
        </form>
        {when (isJust note) (removeForm student)}
    |]

emptyNote :: Html
emptyNote = [hsx|<p>Nenhuma observação cadastrada.</p>|]

removeForm :: Student -> Html
removeForm student = [hsx|
    <form method="POST" action={RemoveStudentConfidentialNoteAction student.id}>
        <button class="btn btn-outline-danger" type="submit">Remover observação</button>
    </form>
|]
