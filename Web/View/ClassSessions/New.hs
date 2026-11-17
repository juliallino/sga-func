module Web.View.ClassSessions.New where

import Web.View.Prelude
import Web.View.ClassSessions.Form (RosterEntry, renderForm)

data NewView = NewView
    { classSession :: ClassSession
    , subject :: Subject
    , roster :: [RosterEntry]
    , presentIds :: [UUID]
    }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>Nova chamada · {subject.name}</h1>
        {renderForm classSession (pathTo (CreateClassSessionAction subject.id)) roster presentIds (pathTo (ClassSessionsAction subject.id))}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Frequência" ClassSessionSubjectsAction
                , breadcrumbLink [hsx|{subject.name}|] (ClassSessionsAction subject.id)
                , breadcrumbText "Nova chamada"
                ]
