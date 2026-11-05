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
        rows <- unsafeSqlQuery
            "WITH averages AS (SELECT e.student_id, SUM(g.score*g.weight)::double precision / SUM(g.weight)::double precision AS average FROM enrollments e JOIN grades g ON g.enrollment_id=e.id WHERE e.subject_id=? GROUP BY e.student_id), ranked AS (SELECT student_id, average, RANK() OVER (ORDER BY average DESC) AS position FROM averages) SELECT r.position,s.name,s.enrollment_number,r.average FROM ranked r JOIN students s ON s.id=r.student_id WHERE (?::uuid IS NULL OR r.student_id=?::uuid) ORDER BY r.position,s.enrollment_number"
            (unpackId subject.id, own, own) :: IO [(Int64, Text, Text, Double)]
        pure (RankingGroup subject.name (map toEntry rows))
    generalGroups <- if (currentUser @User).role_ == Roleteacher
        then pure []
        else do
            courses <- query @Course |> filterWhereIn (#id, map (Id . (.courseId)) subjects) |> fetch
            forM courses \course -> do
                rows <- unsafeSqlQuery
                    "WITH discipline_averages AS (SELECT e.student_id,e.subject_id,SUM(g.score*g.weight)::double precision / SUM(g.weight)::double precision AS average FROM enrollments e JOIN subjects d ON d.id=e.subject_id JOIN grades g ON g.enrollment_id=e.id WHERE d.course_id=? GROUP BY e.student_id,e.subject_id), complete AS (SELECT student_id,AVG(average) AS average FROM discipline_averages GROUP BY student_id HAVING COUNT(*)=(SELECT COUNT(*) FROM subjects WHERE course_id=?)), ranked AS (SELECT student_id,average,RANK() OVER (ORDER BY average DESC) AS position FROM complete) SELECT r.position,s.name,s.enrollment_number,r.average FROM ranked r JOIN students s ON s.id=r.student_id WHERE (?::uuid IS NULL OR r.student_id=?::uuid) ORDER BY r.position,s.enrollment_number"
                    (unpackId course.id, unpackId course.id, own, own) :: IO [(Int64, Text, Text, Double)]
                pure (RankingGroup ("Geral · " <> course.name) (map toEntry rows))
    let groups = disciplineGroups <> generalGroups
    let selfOnly = isJust own
    render IndexView { .. }

toEntry :: (Int64, Text, Text, Double) -> RankingEntry
toEntry (position,name,registration,average) = RankingEntry { .. }
