#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    size_t Count, NumLines = 0, NumRead;
    char Buffer[4096], *End;
    if (argc != 2) { fprintf(stderr, "usage: %s <expected line count>\n", argv[0]); return 2; }
    Count = strtoul(argv[1], &End, 10);
    if (*End != '\0' && End != argv[1]) { fprintf(stderr, "invalid count\n"); return 2; }
    do {
        size_t i;
        NumRead = fread(Buffer, 1, sizeof(Buffer), stdin);
        for (i = 0; i != NumRead; ++i) if (Buffer[i] == '\n') ++NumLines;
    } while (NumRead == sizeof(Buffer));
    if (Count != NumLines) { fprintf(stderr, "Expected %zu lines, got %zu.\n", Count, NumLines); return 1; }
    return 0;
}
