package app.schoolzip;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.web.server.ResponseStatusException;
import java.nio.file.Path;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class TeacherNamesControllerTest {
    @TempDir Path temp;
    private TimetableController timetable() throws Exception {
        var mock = mock(TimetableController.class);
        var data = new ObjectMapper().readTree("{\"grades\":{\"1\":{\"1\":[[{\"teacherId\":\"roster:1\",\"teacher\":\"김가*\"}]]}}}");
        when(mock.timetable(anyString(), anyInt(), eq(0))).thenReturn(data);
        return mock;
    }
    private TeacherNamesController.Submission set(String value) {
        return new TeacherNamesController.Submission(List.of(new TeacherNamesController.Entry("roster:1", "김가*", value)));
    }
    @Test void persistsSeparatesSchoolsAndCountsDistinctInstallations() throws Exception {
        var table = timetable(); String db = temp.resolve("names").toString();
        var first = new TeacherNamesController(table, db);
        first.submit(1, "학교", "a".repeat(64), set("김가람"));
        first.submit(1, "학교", "a".repeat(64), set("김가람"));
        first.submit(1, "학교", "b".repeat(64), set("김가람"));
        first.submit(1, "학교", "c".repeat(64), set("김가은"));
        var reopened = new TeacherNamesController(table, db);
        assertEquals(2, reopened.candidates(1, "학교").size());
        assertEquals(2, reopened.candidates(1, "학교").getFirst().submissions());
        assertTrue(reopened.candidates(2, "다른학교").isEmpty());
        first.submit(1, "학교", "a".repeat(64), new TeacherNamesController.Submission(List.of()));
        assertEquals(1, reopened.candidates(1, "학교").stream().filter(e -> e.value().equals("김가람")).findFirst().orElseThrow().submissions());
    }
    @Test void rejectsInvalidIdentityWithoutDeletingPreviousSubmission() throws Exception {
        var service = new TeacherNamesController(timetable(), temp.resolve("names").toString());
        service.submit(1, "학교", "a".repeat(64), set("김가람"));
        assertThrows(ResponseStatusException.class, () -> service.submit(1, "학교", "a".repeat(64), new TeacherNamesController.Submission(List.of(new TeacherNamesController.Entry("wrong", "김가*", "누군가")))));
        assertEquals("김가람", service.candidates(1, "학교").getFirst().value());
        assertThrows(ResponseStatusException.class, () -> service.submit(1, "학교", "bad", set("김가람")));
    }
    @Test void changedRosterDoesNotReuseOldSuggestions() throws Exception {
        var table = timetable(); var service = new TeacherNamesController(table, temp.resolve("names").toString());
        service.submit(1, "학교", "a".repeat(64), set("김가람"));
        when(table.timetable(anyString(), anyInt(), eq(0))).thenReturn(new ObjectMapper().readTree("{\"grades\":{\"teacherId\":\"new:1\",\"teacher\":\"김가*\"}}"));
        assertTrue(service.candidates(1, "학교").isEmpty());
    }
}
