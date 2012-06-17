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
    this(string aStr, int aLine = 0) {
        str = aStr;
        format = Token.STRING;
        line = cast(ushort)aLine;
    }
    this(int aCode, int aLine = 0) {
        code = aCode;
        format = Token.CODE;
        line = cast(ushort)aLine;
    }
    bool isCode(int aCode) {
        return format == CODE
            && code == aCode;
    }
    bool isString(string aStr) {
        return format == STRING
            && str == aStr;
    }
    debug{
        import std.conv;
        string toString() {
            if (format==CODE) {
                return " {code:"~to!string(code)~"}";
            }
            if (format==STRING) {
                return " {str:"~str~"}";
            }
            return "{}";
        }
    } // debug

    enum : ubyte {NULL=0, STRING, CODE, FLOAT, INT};
    ubyte format = Token.NULL;
    ushort line;
    union {
        string  str;
        int     code;
        float   floatVal;
        int   intVal;
    }
}