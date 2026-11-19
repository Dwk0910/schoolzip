import unittest
from parser import SchoolTimeTable

class TeacherMaskTest(unittest.TestCase):
    def test_all_masked_teacher_is_not_erased(self):
        self.assertEqual(SchoolTimeTable._format_teacher_name('*'), '*')

    def test_partial_mask_and_normal_name_are_preserved(self):
        for name in ('김*', '김*수', '민', '이혜'):
            self.assertEqual(SchoolTimeTable._format_teacher_name(name), name)

    def test_missing_teacher_stays_empty(self):
        self.assertEqual(SchoolTimeTable._format_teacher_name(''), '')
        self.assertEqual(SchoolTimeTable._format_teacher_name(None), '')

if __name__ == '__main__':
    unittest.main()

class TeacherIdentityTest(unittest.TestCase):
    def test_roster_index_survives_and_scope_changes_safely(self):
        from unittest.mock import patch
        from pycomcigan import TimeTable
        from parser import teacher_fields
        instance = object.__new__(SchoolTimeTable)
        instance.school_code = 10
        instance.school_year = 2026
        with patch.object(TimeTable, '_build_timetable', side_effect=lambda data, names, *args: names):
            first = instance._build_timetable({}, ['', '김가*', '김가*', '*'])
            repeat = instance._build_timetable({}, ['', '김가*', '김가*', '*'])
            moved = instance._build_timetable({}, ['', '*', '김가*', '김가*'])
            self.assertEqual(teacher_fields(first[1]), teacher_fields(repeat[1]))
            self.assertNotEqual(first[1].identity, first[2].identity)
            self.assertNotEqual(first[1].identity, moved[1].identity)
            self.assertEqual(str(first[3]), '*')
            instance.school_year = 2027
            next_year = instance._build_timetable({}, ['', '김가*', '김가*', '*'])
            self.assertNotEqual(first[1].identity, next_year[1].identity)
