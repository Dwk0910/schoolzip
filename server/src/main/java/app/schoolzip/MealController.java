package app.schoolzip;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import java.net.URI;
import java.net.http.*;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.util.UriComponentsBuilder;

@RestController
@RequestMapping("/api")
public class MealController {
    private final HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
    private final ObjectMapper mapper;
    private final String apiKey;
    private final Cache<List<String>, JsonNode> schools = Caffeine.newBuilder().maximumSize(512).expireAfterWrite(Duration.ofDays(1)).build();
    private final Cache<List<String>, List<Meal>> menus = Caffeine.newBuilder().maximumSize(1024).expireAfterWrite(Duration.ofMinutes(10)).build();
    public MealController(ObjectMapper mapper, @Value("${NEIS_API_KEY:}") String apiKey) {
        this.mapper = mapper;
        this.apiKey = apiKey;
    }
    public record Meal(String type, String calories, List<String> dishes) {}
    @GetMapping("/meals")
    public List<Meal> meals(@RequestParam String name, @RequestParam(defaultValue="") String region, @RequestParam LocalDate date) {
        JsonNode school = schools.get(List.of(name, region), key -> findSchool(name, region));
        String office = school.path("ATPT_OFCDC_SC_CODE").asText();
        String code = school.path("SD_SCHUL_CODE").asText();
        String day = date.format(DateTimeFormatter.BASIC_ISO_DATE);
        return menus.get(List.of(office, code, day), key -> {
            var rows = query("mealServiceDietInfo", Map.of("ATPT_OFCDC_SC_CODE",office,"SD_SCHUL_CODE",code,"MLSV_YMD",day));
            return rows.stream().map(row -> new Meal(row.path("MMEAL_SC_NM").asText(),row.path("CAL_INFO").asText(),
                Arrays.stream(row.path("DDISH_NM").asText().split("(?i)<br\\s*/?>")).map(String::strip).filter(s -> !s.isEmpty()).toList())).toList();
        });
    }
    private JsonNode findSchool(String name,String region) {
        var aliases = Map.of("경남","경상남","경북","경상북","전남","전라남","전북","전북","충남","충청남","충북","충청북");
        String prefix = aliases.getOrDefault(region,region);
        var candidates = query("schoolInfo",Map.of("SCHUL_NM",name)).stream().filter(s -> name.equals(s.path("SCHUL_NM").asText())).toList();
        if (!region.isBlank()) {
            var local = candidates.stream().filter(s -> s.path("ATPT_OFCDC_SC_NM").asText().startsWith(prefix)).toList();
            if (local.size()==1) return local.getFirst();
        }
        if (candidates.size()==1) return candidates.getFirst();
        throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"급식 학교를 특정할 수 없어요");
    }
    private List<JsonNode> query(String service,Map<String,String> params) {
        var uri = UriComponentsBuilder.fromUriString("https://open.neis.go.kr/hub/"+service).queryParam("Type","json");
        params.forEach((k,v)->uri.queryParam(k,v));
        if (!apiKey.isBlank()) uri.queryParam("KEY",apiKey);
        var rows = new ArrayList<JsonNode>();
        for(int page=1;page<=50;page++) {
            try {
                URI endpoint=uri.cloneBuilder().queryParam("pIndex",page).queryParam("pSize",5).build().encode().toUri();
                var response=client.send(HttpRequest.newBuilder(endpoint).timeout(Duration.ofSeconds(8)).GET().build(),HttpResponse.BodyHandlers.ofString());
                var root=mapper.readTree(response.body());
                if(response.statusCode()!=200) throw new IllegalStateException();
                if("INFO-200".equals(root.path("RESULT").path("CODE").asText())) return rows;
                var body=root.path(service);
                var batch=body.path(1).path("row");
                if(!batch.isArray() || batch.isEmpty()) throw new IllegalStateException();
                batch.forEach(rows::add);
                if(rows.size()>=body.path(0).path("head").path(0).path("list_total_count").asInt()) return rows;
            } catch(InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);
            } catch(Exception e) {
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,"급식 조회 실패");
            }
        }
        throw new ResponseStatusException(HttpStatus.BAD_GATEWAY);
    }
}
