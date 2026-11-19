import hashlib
import json
import re
import sys

from pycomcigan import TimeTable, get_school_code


class SchoolTimeTable(TimeTable):
    @staticmethod
    def _format_teacher_name(name):
        return name.strip() if isinstance(name, str) else ''

    def _build_timetable(self, data, teacher_list, *args):
        # The index is authoritative only within this school/year/roster.
        # Never infer a permanent person ID from masked names or subjects.
        scope = hashlib.sha256(json.dumps(
            [self.school_code, self.school_year, teacher_list],
            ensure_ascii=False).encode()).hexdigest()[:24]
        tagged = [TeacherName(name, f'{scope}:{index}')
                  for index, name in enumerate(teacher_list)]
        self.teacher_registry = [teacher_fields(name) for name in tagged if name]
        return super()._build_timetable(data, tagged, *args)


class TeacherName(str):
    def __new__(cls, name, identity):
        value = super().__new__(cls, name)
        value.identity = identity
        return value


def teacher_fields(name):
    result = {'teacher': str(name)}
    if name and getattr(name, 'identity', None):
        result['teacherId'] = name.identity
    return result


def search(query):
    return [
        dict(region=region, name=name, code=code)
        for _, region, name, code in get_school_code(query)
    ]


def period_windows(entries, school):
    # Comcigan usually supplies just the start bell. Mark inferred ends explicitly.
    duration = next((minutes for suffix, minutes in (
        ("초등학교", 40), ("중학교", 45), ("고등학교", 50)
    ) if school.endswith(suffix)), None)
    clock = r"([01]?\d|2[0-3]):([0-5]\d)"
    pattern = rf"\s*(\d+)\s*\(\s*{clock}(?:\s*[~–-]\s*{clock})?\s*\)\s*"
    times = {}
    for entry in entries or []:
        match = re.fullmatch(pattern, str(entry))
        if match:
            period, hour, minute, end_hour, end_minute = match.groups()
            start = int(hour) * 60 + int(minute)
            end = int(end_hour) * 60 + int(end_minute) if end_hour else None
            times[int(period)] = (start, end)

    windows = {}
    for period, (start, end) in times.items():
        fields = {"startMinute": start}
        estimated = end is None
        if estimated and duration:
            end = start + duration
        if end is not None:
            next_start = times.get(period + 1, (1440, None))[0]
            end = min(end, next_start, 1440)
            if start < end:
                fields.update(endMinute=end, estimatedEnd=estimated)
        windows[period] = fields
    return windows


def lesson_data(lesson, windows):
    data = dict(period=lesson.period, subject=lesson.subject, **teacher_fields(lesson.teacher),
                changed=lesson.replaced, **windows.get(lesson.period, {}))
    if lesson.replaced and lesson.original:
        data["original"] = dict(subject=lesson.original.subject, **teacher_fields(lesson.original.teacher))
    return data


def weekly(name, code, week):
    table = SchoolTimeTable(name, school_code=int(code), week_num=int(week))
    windows = period_windows(table.day_time, table.school_name)
    grades = {}
    for grade, rooms in enumerate(table.timetable[1:], 1):
        grades[grade] = {
            room: [
                [lesson_data(p, windows) for p in day if p.subject]
                for day in days[1:]
            ]
            for room, days in enumerate(rooms[1:], 1)
        }
    return dict(start=table.start_date, updated=table.update_date, grades=grades, teachers=table.teacher_registry)


if __name__ == "__main__":
    result = search(sys.argv[2]) if sys.argv[1] == "search" else weekly(*sys.argv[2:])
    print(json.dumps(result, ensure_ascii=True))
