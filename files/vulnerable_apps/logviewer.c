/*
 * logviewer.c — Intentionally vulnerable program
 * Usage: logviewer <filename>
 *
 * VULNERABILITY:
 *   The filename passed on the command line is interpolated directly
 *   into a call to system().  Semicolons, pipes, and shell
 *   metacharacters are NOT sanitised, giving the caller arbitrary
 *   command execution as root (the binary runs with SUID root).
 *
 * LEGITIMATE INTENT:
 *   Display the contents of any log file the user requests.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_INPUT 256

int main(int argc, char *argv[]) {
    char cmd[MAX_INPUT];

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <log_file>\n", argv[0]);
        return 1;
    }

    if (strlen(argv[1]) >= MAX_INPUT - 8) {
        fprintf(stderr, "Error: filename too long\n");
        return 1;
    }

    printf("Viewing log file: %s\n", argv[1]);
    printf("---\n");

    /*
     * BUG: unsanitized argv[1] passed directly to system().
     * An attacker can run: logviewer "; id; "
     * which becomes: system("/bin/cat ; id; ")
     */
    snprintf(cmd, sizeof(cmd), "/bin/cat %s", argv[1]);
    system(cmd);

    printf("---\nEnd of log.\n");
    return 0;
}
