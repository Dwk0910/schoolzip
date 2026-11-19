package app.schoolzip;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import java.io.IOException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api")
public class TimetableController {
    private final ObjectMapper mapper;
    private final String python;
    private final Cache<List<String>, JsonNode> cache = Caffeine.newBuilder()
            .maximumSize(64).expireAfterWrite(Duration.ofMinutes(2)).build();
    private final ExecutorService readers = Executors.newVirtualThreadPerTaskExecutor();
    private final Semaphore slots = new Semaphore(4);

    public TimetableController(ObjectMapper mapper, @Value("${SCHOOLZIP_PYTHON:python}") String python) {
        this.mapper = mapper;
        this.python = python;
    }

    @GetMapping("/schools")
    public JsonNode search(@RequestParam String q) {
        return cached(List.of("search", validName(q)));
    }

    @GetMapping("/timetable")
    public JsonNode timetable(@RequestParam String name,
                              @RequestParam int code, @RequestParam(defaultValue = "0") int week) {
        if (code < 1 || week < 0 || week > 1)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        return cached(List.of("week", validName(name),
                String.valueOf(code), String.valueOf(week)));
    }

    private String validName(String name) {
        if (name.isBlank() || name.length() > 80 || name.chars().anyMatch(Character::isISOControl))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        return name.strip();
    }

    private JsonNode cached(List<String> args) {
        return cache.get(args, this::fetch);
    }

    private JsonNode fetch(List<String> args) {
        if (!slots.tryAcquire()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);
        Process process = null;
        try {
            var command = new ArrayList<>(List.of(python, "parser.py"));
            command.addAll(args);
            process = new ProcessBuilder(command).redirectError(ProcessBuilder.Redirect.INHERIT).start();
            var stdout = process.getInputStream();
            var result = readers.submit(() -> {
                try (stdout) { return mapper.readTree(stdout); }
            });
            if (!process.waitFor(30, TimeUnit.SECONDS))
                throw new ResponseStatusException(HttpStatus.GATEWAY_TIMEOUT);
            if (process.exitValue() != 0) throw new ResponseStatusException(HttpStatus.BAD_GATEWAY);
            return result.get();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);
        } catch (IOException | java.util.concurrent.ExecutionException e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "시간표 조회 실패", e);
        } finally {
            if (process != null && process.isAlive()) process.destroyForcibly();
            slots.release();
        }
    }

    @PreDestroy
    void close() { readers.shutdownNow(); }
}
