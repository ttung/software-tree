#!/usr/bin/python

import argparse
import codecs
import os
import sqlite3
import sys
import tempfile

def open_db_connection(filename):
    return sqlite3.connect(filename)


def create_table(conn, cursor):
    cursor.execute("""SELECT type FROM sqlite_master WHERE type='table' AND name='history'""")

    results = cursor.fetchall()
    if (len(results) > 1):
        raise Exception("WTF?  Schema not as expected.")
    elif (len(results) == 1):
        return

    cursor.execute("""CREATE TABLE history (date REAL, command TEXT, PRIMARY KEY(date, command))""")
    cursor.execute("""CREATE INDEX IF NOT EXISTS date_index ON history (date)""")


def read_one(conn, cursor, input_stream):
    line = input_stream.read().rstrip("\n")
    cursor.execute(
        """INSERT OR IGNORE INTO history(date, command) VALUES(STRFTIME("%s", "now"), ?)""",
        (line,))
    conn.commit()


def read_history(conn, cursor, input_stream):
    def input_generator(input_stream):
        timestamp = None
        command = []

        for line in input_stream:
            line = codecs.decode(line, 'utf8')
            splitted = line.strip().split(None, 4)

            # if we have the markers, this is some sort of a history entry.
            if (len(splitted) >= 5 and splitted[1] == '*****' and splitted[3] == '*****'):
                if (timestamp is not None):
                    # yield the previous entry.
                    for count, line in enumerate(command):
                        yield int(timestamp), line

                    timestamp = None
                    command = []

                if (len(splitted) == 4 and splitted[0][-1] == '*'):
                    # this may be a modified entry.  ignore those.
                    continue

                history_id, start_marker, timestamp, end_marker, entry = splitted
                command = [entry]
            else:
                # this has to be a continuation.
                command.append(line.strip())

        if (timestamp is not None):
            # yield the previous entry.
            for line in command:
                yield int(timestamp), line

            timestamp = None
            command = []


    cursor.executemany("""INSERT OR IGNORE INTO history(date, command) VALUES(?, ?)""",
                       input_generator(input_stream))
    conn.commit()


def trim_history(conn, cursor, history_count):
    cursor.execute("""SELECT COUNT(1) FROM history""")
    results = cursor.fetchall()
    assert(len(results) == 1)
    if results[0][0] < history_count:
        return

    # find the nth item when ordered by time.
    cursor.execute("""SELECT date FROM history ORDER BY DATE DESC LIMIT %d,1""" % history_count)

    results = cursor.fetchall()
    assert(len(results) <= 1)

    if (len(results) == 0):
        # don't need trimming
        return

    cursor.execute("""DELETE FROM history WHERE date < %d""" % results[0][0])
    conn.commit()


def dump_history(conn, cursor, output_stream, limit):
    cursor.execute(
        """SELECT date, command from (
        SELECT date, command FROM history ORDER BY DATE DESC LIMIT ?)
        ORDER BY DATE ASC""", (limit,))

    for result in cursor:
        #sys.stderr.write("#%d\n%s\n" % result)
        output_stream.write(("#%d\n%s\n" % result).encode('utf8'))


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--action",
        choices=("ingest-and-output", "ingest-one"),
        default="ingest-and-output",
    )
    parser.add_argument(
        "-d", "--db",
        type=str,
        default=os.path.expanduser("~/.shell_history"),
    )
    parser.add_argument(
        "--trim-to",
        type=int,
        default=sys.maxsize,
        help=(
            "Trim the database to %(dest) rows.  If unspecified, database is "
            "not trimmed"
        ),
    )
    parser.add_argument(
        "-l", "--output-limit",
        type=int,
        default=1000,
    )

    args = parser.parse_args()

    conn = open_db_connection(args.db)
    cursor = conn.cursor()
    create_table(conn, cursor)

    if args.action == "ingest-and-output":
        read_history(conn, cursor, sys.stdin)
    if args.action == "ingest-one":
        read_one(conn, cursor, sys.stdin)

    trim_history(conn, cursor, args.trim_to)

    if args.action == "ingest-and-output":
        # write this to a temp file.
        tfh = tempfile.NamedTemporaryFile(delete=False)
        name = tfh.name

        dump_history(conn, cursor, tfh, args.output_limit)
        print(name)

    conn.close()


if __name__ == "__main__":
    main()
