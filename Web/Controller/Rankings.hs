module Web.Controller.Rankings where
import Web.Controller.Prelude
import IHP.LoginSupport.Helper.Controller (currentUser)
import Web.View.Rankings.Index

renderRankings :: (?request :: Request, ?respond :: Respond, ?modelContext :: ModelContext) => IO ResponseReceived
renderRankings = do
    requireLogin
    subjects <- visibleSubjects
    own <- if (currentUser @User).role_ == Rolestudent
        then Just . unpackId . (.id) <$> myStudent
        else pure Nothing
    disciplineGroups <- forM subjects \subject -> do
        -- Filtering by the current student's identity happens AFTER ranking
        -- inside SQL: no other student's grades or identity leave this query.
        -- Só conta a matrícula mais recente (por período) de cada estudante na
        -- disciplina, ignorando matrículas inativas: refazer não mistura notas.
        rows <- unsafeSqlQuery
            "WITH latest AS (SELECT DISTINCT ON (e.student_id) e.id, e.student_id FROM enrollments e LEFT JOIN academic_periods p ON p.id=e.academic_period_id WHERE e.subject_id=? AND e.status<>'inactive' ORDER BY e.student_id, p.starts_on DESC NULLS LAST, e.enrollment_date DESC, e.id), averages AS (SELECT l.student_id, SUM(g.score*g.weight)::double precision / SUM(g.weight)::double precision AS average FROM latest l JOIN grades g ON g.enrollment_id=l.id GROUP BY l.student_id), ranked AS (SELECT student_id, average, RANK() OVER (ORDER BY average DESC) AS position FROM averages) SELECT r.position,s.name,s.enrollment_number,r.average FROM ranked r JOIN students s ON s.id=r.student_id WHERE (?::uuid IS NULL OR r.student_id=?::uuid) ORDER BY r.position,s.enrollment_number"
            (unpackId subject.id, own, own) :: IO [(Int64, Text, Text, Double)]
        pure (RankingGroup subject.name (map toEntry rows))
    generalGroups <- if (currentUser @User).role_ == Roleteacher
        then pure []
        else do
            courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) subjects) |> fetch
            forM courses \course -> do
                rows <- unsafeSqlQuery
                    "WITH latest AS (SELECT DISTINCT ON (e.student_id,e.subject_id) e.id,e.student_id,e.subject_id FROM enrollments e JOIN subjects d ON d.id=e.subject_id LEFT JOIN academic_periods p ON p.id=e.academic_period_id WHERE d.course_id=? AND e.status<>'inactive' ORDER BY e.student_id,e.subject_id,p.starts_on DESC NULLS LAST,e.enrollment_date DESC,e.id), discipline_averages AS (SELECT l.student_id,l.subject_id,SUM(g.score*g.weight)::double precision / SUM(g.weight)::double precision AS average FROM latest l JOIN grades g ON g.enrollment_id=l.id GROUP BY l.student_id,l.subject_id), complete AS (SELECT student_id,AVG(average) AS average FROM discipline_averages GROUP BY student_id HAVING COUNT(*)=(SELECT COUNT(*) FROM subjects WHERE course_id=?)), ranked AS (SELECT student_id,average,RANK() OVER (ORDER BY average DESC) AS position FROM complete) SELECT r.position,s.name,s.enrollment_number,r.average FROM ranked r JOIN students s ON s.id=r.student_id WHERE (?::uuid IS NULL OR r.student_id=?::uuid) ORDER BY r.position,s.enrollment_number"
                    (unpackId course.id, unpackId course.id, own, own) :: IO [(Int64, Text, Text, Double)]
                pure (RankingGroup ("Geral · " <> course.name) (map toEntry rows))
    let groups = disciplineGroups <> generalGroups
    let selfOnly = isJust own
    render IndexView { .. }

toEntry :: (Int64, Text, Text, Double) -> RankingEntry
toEntry (position,name,registration,average) = RankingEntry { .. }
