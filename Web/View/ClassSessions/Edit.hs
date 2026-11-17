module Web.View.ClassSessions.Edit where

import Web.View.Prelude
import Web.View.ClassSessions.Form (RosterEntry, renderForm, formatDay)

data EditView = EditView
    { classSession :: ClassSession
    , subject :: Subject
    , roster :: [RosterEntry]
    , presentIds :: [UUID]
    }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Editar chamada · {subject.name}</h1>
        {renderForm classSession (pathTo (UpdateClassSessionAction classSession.id)) roster presentIds (pathTo (ClassSessionsAction subject.id))}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Frequência" ClassSessionSubjectsAction
                , breadcrumbLink [hsx|{subject.name}|] (ClassSessionsAction subject.id)
                , breadcrumbText [hsx|Chamada de {formatDay classSession.classDate}|]
                ]
