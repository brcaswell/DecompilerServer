#!/bin/sh
curl -X POST 'http://decompiler-seq:80/api/events/raw?clef' \
  -H 'Content-Type: application/vnd.serilog.clef' \
  -d '{"@t":"2026-02-03T10:40:00.000Z","@m":"Test from Docker network","Level":"Information"}'
