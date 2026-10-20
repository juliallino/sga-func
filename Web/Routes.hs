module Web.Routes where
import IHP.RouterPrelude
import Generated.Types
import Web.Types

-- The welcome page at '/' is served by the static controller below.
-- Additional [routes|...|] blocks get appended by `new-controller`.
[routes|StaticController
GET /    WelcomeAction
GET /MyProfile MyProfileAction
GET /MySubjects StudentSubjectsAction
GET /MyAverages StudentAveragesAction
GET /TeacherStudents TeacherStudentsAction
GET /TeacherAssessments TeacherAssessmentsAction
|]

[routes|StudentsController
GET /Students StudentsAction
GET /NewStudent NewStudentAction
POST /CreateStudent CreateStudentAction
GET /ShowStudent?studentId ShowStudentAction
GET /EditStudent?studentId EditStudentAction
POST /UpdateStudent?studentId UpdateStudentAction
DELETE /DeleteStudent?studentId DeleteStudentAction
|]


[routes|CoursesController
GET /Courses CoursesAction
GET /NewCourse NewCourseAction
POST /CreateCourse CreateCourseAction
GET /ShowCourse?courseId ShowCourseAction
GET /EditCourse?courseId EditCourseAction
POST /UpdateCourse?courseId UpdateCourseAction
DELETE /DeleteCourse?courseId DeleteCourseAction
|]


[routes|EnrollmentsController
GET /Enrollments EnrollmentsAction
GET /NewEnrollment NewEnrollmentAction
POST /CreateEnrollment CreateEnrollmentAction
GET /ShowEnrollment?enrollmentId ShowEnrollmentAction
GET /EditEnrollment?enrollmentId EditEnrollmentAction
POST /UpdateEnrollment?enrollmentId UpdateEnrollmentAction
DELETE /DeleteEnrollment?enrollmentId DeleteEnrollmentAction
|]


[routes|GradesController
GET /Grades GradesAction
GET /NewGrade NewGradeAction
POST /CreateGrade CreateGradeAction
GET /ShowGrade?gradeId ShowGradeAction
GET /EditGrade?gradeId EditGradeAction
POST /UpdateGrade?gradeId UpdateGradeAction
DELETE /DeleteGrade?gradeId DeleteGradeAction
|]


[routes|TeachersController
GET /Teachers TeachersAction
GET /NewTeacher NewTeacherAction
POST /CreateTeacher CreateTeacherAction
GET /ShowTeacher?teacherId ShowTeacherAction
GET /EditTeacher?teacherId EditTeacherAction
POST /UpdateTeacher?teacherId UpdateTeacherAction
DELETE /DeleteTeacher?teacherId DeleteTeacherAction
|]

[routes|SubjectsController
GET /Subjects SubjectsAction
GET /NewSubject NewSubjectAction
POST /CreateSubject CreateSubjectAction
GET /ShowSubject?subjectId ShowSubjectAction
GET /EditSubject?subjectId EditSubjectAction
POST /UpdateSubject?subjectId UpdateSubjectAction
DELETE /DeleteSubject?subjectId DeleteSubjectAction
|]

[routes|SessionsController
GET /Login NewSessionAction
POST /Login CreateSessionAction
POST /Logout DeleteSessionAction
|]

[routes|UsersController
GET /Users UsersAction
GET /NewUser NewUserAction
POST /CreateUser CreateUserAction
GET /EditUser?userId EditUserAction
POST /UpdateUser?userId UpdateUserAction
DELETE /DeleteUser?userId DeleteUserAction
|]

[routes|TeacherSubjectsController
GET /TeacherSubjects TeacherSubjectsAction
POST /CreateTeacherSubject CreateTeacherSubjectAction
DELETE /DeleteTeacherSubject?teacherSubjectId DeleteTeacherSubjectAction
|]
