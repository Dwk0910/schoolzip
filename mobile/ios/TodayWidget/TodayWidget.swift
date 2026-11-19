import SwiftUI
import WidgetKit

private let store = UserDefaults(suiteName: "group.app.schoolzip.schoolzip")!
private let calendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return cal
}()
private func formatter() -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = calendar.timeZone
    f.dateFormat = "yyyy-MM-dd"
    return f
}

struct Lesson: Codable {
    let period: Int
    let subject: String
    var teacher: String? = nil
    var teacherId: String? = nil
    var startMinute: Int? = nil
    var endMinute: Int? = nil

    var window: Range<Int>? {
        guard let start = startMinute, let end = endMinute,
              start >= 0, start < end, end <= 1440 else { return nil }
        return start..<end
    }
}

struct DayEntry: TimelineEntry {
    let date: Date
    let lessons: [Lesson]
    let message: String
    let school: String
    let classLabel: String

    var active: Lesson? {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return lessons.first { $0.window?.contains(minute) == true }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), lessons: [
            Lesson(period: 1, subject: "국어", teacher: "김민"),
            Lesson(period: 2, subject: "수학", teacher: "이서")
        ], message: "", school: "스쿨집고등학교", classLabel: "1학년 1반")
    }
    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(Date()))
    }
    private func entry(_ date: Date) -> DayEntry {
        let config = store.dictionary(forKey: "class") as? [String:String]
        let cache = store.dictionary(forKey: "schedule")
        let matches = config != nil && (cache?["class"] as? [String:String]) == config
        let blob = matches ? cache?["days"] as? Data : nil
        let days = blob.flatMap { try? JSONDecoder().decode([String:[Lesson]].self,from:$0) }
        let query = config?["url"].flatMap { URLComponents(string: $0) }?.queryItems
        let code = query?.first(where: { $0.name == "code" })?.value
        let names = code.flatMap { store.string(forKey: "teacherNames.\($0)")?.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([String:[String:String]].self, from: $0) } ?? [:]
        let lessons = days?[formatter().string(from:date)]?.map { lesson in
            var displayed = lesson
            if let original = lesson.teacher?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let key = lesson.teacherId.map { "@id:\($0)" } ?? lesson.subject
                let fallback = !original.contains("*") && original.count == 2 ? original + "*" : original
                displayed.teacher = names[key]?[original] ?? fallback
            }
            return displayed
        }
        let pending = config == nil ? "앱에서 학년·반을 선택해 주세요" : "오늘 시간표를 기다리는 중"
        let school = query?.first(where: { $0.name == "name" })?.value
        let classLabel: String
        if let grade = config?["grade"], let room = config?["room"] {
            classLabel = "\(grade)학년 \(room)반"
        } else {
            classLabel = ""
        }
        return DayEntry(date: date, lessons: lessons ?? [], message: lessons == nil ? pending : "오늘은 수업이 없어요",
                        school: school ?? "오늘 과목", classLabel: classLabel)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        func finish() {
            let now = Date()
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            let today = entry(now)
            let midnight = calendar.startOfDay(for: now)
            let minutes = Set(today.lessons.compactMap { $0.window }.flatMap { [$0.lowerBound, $0.upperBound] })
            let changes = minutes.sorted().compactMap { calendar.date(byAdding: .minute, value: $0, to: midnight) }
            let entries = [today] + changes.filter { now < $0 && $0 < tomorrow }.map {
                DayEntry(date: $0, lessons: today.lessons, message: today.message, school: today.school, classLabel: today.classLabel)
            } + [entry(tomorrow)]
            completion(Timeline(entries: entries, policy: .after(min(tomorrow, now.addingTimeInterval(3600)))))
        }
        guard let config = store.dictionary(forKey: "class") as? [String:String],
              let address = config["url"], let url = URL(string: address),
              let grade = config["grade"], let room = config["room"] else { finish(); return }
        URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 35)) { data, response, _ in
            defer { finish() }
            struct Week: Decodable { let start: String; let grades: [String:[String:[[Lesson]]]] }
            let f = formatter()
            guard (response as? HTTPURLResponse)?.statusCode == 200, let data = data,
                  let week = try? JSONDecoder().decode(Week.self, from: data),
                  let start = f.date(from: week.start), let days = week.grades[grade]?[room],
                  (store.dictionary(forKey:"class") as? [String:String]) == config else { return }
            var cache = [String:[Lesson]]()
            for i in 0..<max(days.count,7) {
                let date = calendar.date(byAdding: .day,value:i,to:start)!
                let subjects = i < days.count ? days[i].sorted { $0.period < $1.period } : []
                cache[f.string(from: date)] = subjects
            }
            if let blob = try? JSONEncoder().encode(cache) { store.set(["class":config,"days":blob],forKey:"schedule") }
        }.resume()
    }
}
@main
struct SchoolzipToday: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:"SchoolzipToday",provider:Provider()) { entry in
            let content = VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.school).font(.subheadline.bold()).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(entry.classLabel).font(.caption).foregroundStyle(.secondary).fixedSize()
                }
                HStack(spacing: 4) {
                    Text(entry.date, format: .dateTime.month(.defaultDigits).day().weekday(.abbreviated))
                    if let active = entry.active {
                        Text("·  \(active.period)교시 진행 중")
                    }
                }.font(.caption2).foregroundStyle(.secondary)
                Divider()
                if entry.lessons.isEmpty {
                    Text(entry.message).font(.subheadline).frame(maxWidth:.infinity,maxHeight:.infinity)
                } else {
                    ForEach(0..<((entry.lessons.count+1)/2), id: \.self) { row in
                        HStack(spacing:4) {
                            ForEach(0..<2, id: \.self) { column in
                                let index = row*2 + column
                                if index < entry.lessons.count {
                                    let lesson = entry.lessons[index]
                                    let active = entry.active?.period == lesson.period
                                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                                        Text("\(lesson.period)교시").font(.caption2).foregroundStyle(.secondary).fixedSize()
                                        Text(lesson.subject).font(.caption.weight(.semibold)).lineLimit(1).layoutPriority(1)
                                        if let teacher = lesson.teacher, !teacher.isEmpty {
                                            Text(teacher).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                    .padding(.horizontal, 5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                    .background(active ? Color.indigo.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                } else { Color.clear.frame(maxWidth:.infinity) }
                            }
                        }
                    }
                }
            }.environment(\.timeZone,calendar.timeZone)
            if #available(iOSApplicationExtension 17.0, *) {
                content.containerBackground(for:.widget) { Color(uiColor:.systemBackground) }
            } else { content.padding() }
        }.configurationDisplayName("오늘 과목").description("저장한 반의 오늘 수업을 교시 순서대로 표시해요.")
            .supportedFamilies([.systemMedium])
    }
}
