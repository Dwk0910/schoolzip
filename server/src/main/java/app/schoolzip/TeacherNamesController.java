package app.schoolzip;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.sql.*;
import java.nio.file.*;
import java.util.*;

@RestController
@RequestMapping("/api/teacher-names")
public class TeacherNamesController {
    private final String url;
    private final TimetableController timetable;
    public record Entry(String teacherId, String original, String value) {}
    public record Submission(List<Entry> entries) {}
    public record Candidate(String teacherId, String original, String value, int submissions) {}
    public TeacherNamesController(TimetableController timetable,
            @Value("${SCHOOLZIP_NAMES_DB:./data/teacher-names}") String path) throws Exception {
        this.timetable = timetable;
        Path file = Path.of(path).toAbsolutePath();
        Files.createDirectories(file.getParent());
        url = "jdbc:h2:file:" + file + ";DB_CLOSE_ON_EXIT=FALSE";
        try (var c = connect(); var s = c.createStatement()) {
            s.execute("CREATE TABLE IF NOT EXISTS teacher_names (school INT NOT NULL, teacher_id VARCHAR(100) NOT NULL, contributor VARCHAR(80) NOT NULL, original VARCHAR(80) NOT NULL, display_name VARCHAR(80) NOT NULL, updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(school, teacher_id, contributor))");
        }
    }
    private Connection connect() throws SQLException { return DriverManager.getConnection(url, "sa", ""); }
    private Map<String,String> roster(String name, int code) {
        var result = new HashMap<String,String>();
        collect(timetable.timetable(name, code, 0), result);
        return result;
    }
    private void collect(JsonNode node, Map<String,String> result) {
        if (node.isObject() && node.hasNonNull("teacherId")) result.put(node.path("teacherId").asText(), node.path("teacher").asText());
        if (node.isContainerNode()) node.forEach(child -> collect(child, result));
    }
    private ResponseStatusException bad() { return new ResponseStatusException(HttpStatus.BAD_REQUEST, "이름 공유 요청을 확인해 주세요"); }
    @PutMapping("/{code}")
    public Map<String,Boolean> submit(@PathVariable int code, @RequestParam String name,
            @RequestHeader("X-Schoolzip-Installation") String contributor, @RequestBody Submission body) throws SQLException {
        if (!contributor.matches("[a-f0-9]{64}") || body.entries() == null || body.entries().size() > 300) throw bad();
        var roster = roster(name, code);
        var seen = new HashSet<String>();
        for (var e : body.entries()) {
            if (e == null || e.teacherId() == null || !seen.add(e.teacherId()) ||
                !roster.containsKey(e.teacherId()) || !Objects.equals(roster.get(e.teacherId()), e.original()) || e.value() == null ||
                e.value().isBlank() || e.value().length() > 40 || e.value().chars().anyMatch(Character::isISOControl)) throw bad();
        }
        try (var c = connect()) {
            c.setAutoCommit(false);
            try {
                // Replace this installation's set only. Imported suggestions are not votes.
                try (var s = c.prepareStatement("DELETE FROM teacher_names WHERE school=? AND contributor=?")) {
                    s.setInt(1, code); s.setString(2, contributor); s.executeUpdate();
                }
                try (var s = c.prepareStatement("INSERT INTO teacher_names(school,teacher_id,contributor,original,display_name) VALUES(?,?,?,?,?)")) {
                    for (var e : body.entries()) {
                        s.setInt(1, code); s.setString(2, e.teacherId()); s.setString(3, contributor);
                        s.setString(4, e.original()); s.setString(5, e.value().strip()); s.addBatch();
                    }
                    s.executeBatch();
                }
                c.commit();
            } catch (SQLException error) { c.rollback(); throw error; }
        }
        return Map.of("saved", true);
    }
    @GetMapping("/{code}")
    public List<Candidate> candidates(@PathVariable int code, @RequestParam String name) throws SQLException {
        var roster = roster(name, code);
        var result = new ArrayList<Candidate>();
        try (var c = connect(); var s = c.prepareStatement("SELECT teacher_id,original,display_name,COUNT(*) AS n FROM teacher_names WHERE school=? GROUP BY teacher_id,original,display_name ORDER BY n DESC,display_name LIMIT 3000")) {
            s.setInt(1, code);
            try (var rows = s.executeQuery()) {
                while (rows.next()) {
                    String id = rows.getString(1), raw = rows.getString(2);
                    if (Objects.equals(roster.get(id), raw)) result.add(new Candidate(id, raw, rows.getString(3), rows.getInt(4)));
                }
            }
        }
        return result;
    }
}
