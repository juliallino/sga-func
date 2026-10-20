module Web.Types where

import IHP.Prelude
import IHP.ModelSupport
import Generated.Types

data WebApplication = WebApplication deriving (Eq, Show)


data StaticController
    = WelcomeAction | MyProfileAction | StudentSubjectsAction | StudentAveragesAction
    | TeacherStudentsAction | TeacherAssessmentsAction
    deriving (Eq, Show, Data)

data StudentsController
    = StudentsAction
    | NewStudentAction
    | ShowStudentAction { studentId :: !(Id Student) }
    | CreateStudentAction
    | EditStudentAction { studentId :: !(Id Student) }
    | UpdateStudentAction { studentId :: !(Id Student) }
    | DeleteStudentAction { studentId :: !(Id Student) }
    deriving (Eq, Show, Data)

data CoursesController
    = CoursesAction
    | NewCourseAction
    | ShowCourseAction { courseId :: !(Id Course) }
    | CreateCourseAction
    | EditCourseAction { courseId :: !(Id Course) }
    | UpdateCourseAction { courseId :: !(Id Course) }
    | DeleteCourseAction { courseId :: !(Id Course) }
    deriving (Eq, Show, Data)

data EnrollmentsController
    = EnrollmentsAction
    | NewEnrollmentAction
    | ShowEnrollmentAction { enrollmentId :: !(Id Enrollment) }
    | CreateEnrollmentAction
    | EditEnrollmentAction { enrollmentId :: !(Id Enrollment) }
    | UpdateEnrollmentAction { enrollmentId :: !(Id Enrollment) }
    | DeleteEnrollmentAction { enrollmentId :: !(Id Enrollment) }
    deriving (Eq, Show, Data)

data GradesController
    = GradesAction
    | NewGradeAction
    | ShowGradeAction { gradeId :: !(Id Grade) }
    | CreateGradeAction
    | EditGradeAction { gradeId :: !(Id Grade) }
    | UpdateGradeAction { gradeId :: !(Id Grade) }
    | DeleteGradeAction { gradeId :: !(Id Grade) }
    deriving (Eq, Show, Data)

data TeachersController
    = TeachersAction
    | NewTeacherAction
    | ShowTeacherAction { teacherId :: !(Id Teacher) }
    | CreateTeacherAction
    | EditTeacherAction { teacherId :: !(Id Teacher) }
    | UpdateTeacherAction { teacherId :: !(Id Teacher) }
    | DeleteTeacherAction { teacherId :: !(Id Teacher) }
    deriving (Eq, Show, Data)

data SubjectsController
    = SubjectsAction
    | NewSubjectAction
    | ShowSubjectAction { subjectId :: !(Id Subject) }
    | CreateSubjectAction
    | EditSubjectAction { subjectId :: !(Id Subject) }
    | UpdateSubjectAction { subjectId :: !(Id Subject) }
    | DeleteSubjectAction { subjectId :: !(Id Subject) }
    deriving (Eq, Show, Data)

data SessionsController = NewSessionAction | CreateSessionAction | DeleteSessionAction
    deriving (Eq, Show, Data)

data UsersController
    = UsersAction | NewUserAction | CreateUserAction
    | EditUserAction { userId :: !(Id User) }
    | UpdateUserAction { userId :: !(Id User) }
    | DeleteUserAction { userId :: !(Id User) }
    deriving (Eq, Show, Data)

data TeacherSubjectsController
    = TeacherSubjectsAction | CreateTeacherSubjectAction
    | DeleteTeacherSubjectAction { teacherSubjectId :: !(Id TeacherSubject) }
    deriving (Eq, Show, Data)
