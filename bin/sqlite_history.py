#!/usr/bin/python

import sys

def open_db_connection(filename):
    import sqlite3

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


def read_history(conn, cursor, input_stream):
    def input_generator(input_stream):
        import codecs

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


# def trim_history(conn, cursor, history_count):
#     # find the nth item when ordered by time.
#     cursor.execute("""SELECT date FROM history ORDER BY DATE DESC LIMIT %d,1""" % history_count)

#     results = cursor.fetchall()
#     assert(len(results) <= 1)

#     if (len(results) == 0):
#         # don't need trimming
#         return

#     cursor.execute("""DELETE FROM history WHERE date < %d""" % results[0][0])
#     conn.commit()


def dump_history(conn, cursor, output_stream, limit):
    cursor.execute(
        """SELECT date, command from (
        SELECT date, command FROM history ORDER BY DATE DESC LIMIT ?)
        ORDER BY DATE ASC""", (limit,))

    for result in cursor:
        #sys.stderr.write("#%d\n%s\n" % result)
        output_stream.write(("#%d\n%s\n" % result).encode('utf8'))


def main(args):
    import optparse
    import os
    import tempfile

    parser = optparse.OptionParser()

    parser.add_option("-d", dest="db", type="string", default=os.path.expanduser("~/.shell_history"))
    parser.add_option("-m", dest="max", type="int", default=500000)
    parser.add_option("-l", dest="limit", type="int", default=1000)


    options, leftover = parser.parse_args(args)

    conn = open_db_connection(options.db)
    cursor = conn.cursor()
    create_table(conn, cursor)
    read_history(conn, cursor, sys.stdin)
    #trim_history(conn, cursor, options.max)

    # write this to a temp file.
    tfh = tempfile.NamedTemporaryFile(delete=False)
    name = tfh.name

    dump_history(conn, cursor, tfh, options.limit)
    conn.close()

    print(name)

if __name__ == "__main__":
    main(sys.argv)
