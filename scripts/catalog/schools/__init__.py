# -*- coding: utf-8 -*-
"""Every school the catalog can fetch, by its code.

A school module provides:
  CODE                   its key in schools.json and in course_catalog.school
  default_semesters()    what to fetch when --semesters is not given, in the
                         app's own format ("115-1")
  fetch(semester)        -> common.Fetched(records, source_count, complete, note)

Each record is a dict of:
  key          unique within the school and semester; becomes the row id
  title        required
  course_code, class_no, serial_no, teacher, required, time_text   text or None
  credits      a number or None
  audience     a list of names; the same key's audiences are merged
  sessions     [common.session(...)]: the school's times already read, so the
               app needs no parser of its own (common.periods_to_sessions)

Adding a school: see README.md.
"""
from schools import nthu, ntu

REGISTRY = {m.CODE: m for m in (ntu, nthu)}
