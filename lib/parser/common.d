module parser.common;

import std.ascii;

void skipUntil(ref string src, char target) {
    while ((src.length>0) && src[0]!=target) {
        advanceSrc(src);
    }
}

void skipWhite(ref string src) {
    while ((src.length>0) && isWhite(src[0])) {
        advanceSrc(src);
    }
}

bool isAlphaNumOrUnderscore(char c) {
    return (c.isAlphaNum()||c=='_');
}

bool advanceSrc(ref string src, uint n = 1) {
    if (src.length>=n) {
        src=src[n..$];
        return true;
    }
    return false;
}

// "window.width * (0.5 - panel.x)"

struct Token {
    enum : byte {NULL=0, STRING, CODE};
    byte type;
    ushort line;
    union {
        string  str;
        int     code;
    }
}