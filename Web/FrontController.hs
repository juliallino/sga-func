module Web.FrontController where

import IHP.RouterPrelude
import Web.Controller.Prelude
import Web.View.Layout (defaultLayout)

-- Controller Imports
import Web.Controller.Sessions ()
import Web.Controller.Users ()
import Web.Controller.Teachers ()
import Web.Controller.TeacherSubjects ()
import Web.Controller.Subjects ()
import Web.Controller.Grades ()
import Web.Controller.Enrollments ()
import Web.Controller.Courses ()
import Web.Controller.Students ()
import Web.Controller.StudentConfidentialNotes ()
import Web.Controller.Static ()

instance FrontController WebApplication where
    controllers = 
        [ startPage WelcomeAction
        -- Generator Marker
        , parseRoute @StaticController
        , parseRoute @UsersController
        , parseRoute @SessionsController
        , parseRoute @TeacherSubjectsController
        , parseRoute @TeachersController
        , parseRoute @SubjectsController
        , parseRoute @GradesController
        , parseRoute @EnrollmentsController
        , parseRoute @CoursesController
        , parseRoute @StudentConfidentialNotesController
        , parseRoute @StudentsController
        ]

instance InitControllerContext WebApplication where
    initContext = do
        setLayout defaultLayout
